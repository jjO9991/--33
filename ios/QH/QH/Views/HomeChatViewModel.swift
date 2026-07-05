import Foundation
import SwiftUI
import UIKit
import UniformTypeIdentifiers

private let sessionIdKey = "homeChatSessionId"

@MainActor
final class HomeChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var inputText: String = ""
    @Published var isSending: Bool = false
    @Published var showError = false
    @Published var errorMessage = ""
    @Published var attachmentPreviews: [AttachmentPreview] = []

    nonisolated private let api = APIClient.shared
    private var sessionId: String?

    private var deviceId: String {
        UIDevice.current.identifierForVendor?.uuidString ?? "simulator"
    }

    private let forceNew: Bool
    private var pendingInitialMessage: String?

    init(forceNew: Bool = false, initialMessage: String? = nil) {
        self.forceNew = forceNew
        self.pendingInitialMessage = initialMessage
        Task { await bootstrap() }
    }

    private func bootstrap() async {
        if forceNew {
            await createNewSession()
            return
        }
        // 尝试恢复已有会话
        if let saved = UserDefaults.standard.string(forKey: sessionIdKey),
           !saved.isEmpty,
           await restoreSession(sessionId: saved) {
            return
        }
        // 恢复失败 → 新建
        await createNewSession()
    }

    private func restoreSession(sessionId sid: String) async -> Bool {
        let detail = try? await api.getChatDetail(sessionId: sid)
        guard let detail else { return false }
        let msgs = detail.chatHistory.compactMap { entry -> ChatMessage? in
            guard let role = entry["role"],
                  let content = entry["content"] else { return nil }
            return ChatMessage(
                id: UUID().uuidString,
                role: role,
                content: content,
                createdAt: Date(),
            )
        }
        await MainActor.run {
            self.sessionId = sid
            self.messages = msgs
        }
        return true
    }

    private func createNewSession() async {
        do {
            let session = try await api.createSession(deviceId: deviceId, type: "chat")
            let msgToSend = pendingInitialMessage
            await MainActor.run {
                self.sessionId = session.id
                UserDefaults.standard.set(session.id, forKey: sessionIdKey)
                addWelcome()
                // 发送 pending 的初始消息（进入首页时带入的提问）
                if let msg = msgToSend, !msg.trimmingCharacters(in: .whitespaces).isEmpty {
                    self.pendingInitialMessage = nil
                    self.inputText = msg
                    self.sendMessage()
                }
            }
        } catch {
            let desc = error.localizedDescription
            await MainActor.run {
                self.errorMessage = "创建会话失败：\(desc)"
                self.showError = true
            }
        }
    }

    @MainActor
    private func addWelcome() {
        messages.append(ChatMessage(
            id: UUID().uuidString,
            role: "assistant",
            content: "你好！我是契合，你的租房合同 AI 助手。有什么法律问题想聊聊吗？😊",
            createdAt: Date(),
        ))
    }

    func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isSending else { return }
        guard let sid = sessionId else { return }

        isSending = true
        messages.append(ChatMessage(
            id: UUID().uuidString, role: "user", content: text, createdAt: Date()
        ))
        inputText = ""

        Task.detached { [weak self] in
            guard let self else { return }
            do {
                let resp = try await self.api.sendChatMessage(sessionId: sid, message: text)
                await MainActor.run {
                    self.messages.append(ChatMessage(
                        id: UUID().uuidString, role: "assistant",
                        content: resp.reply, createdAt: Date()
                    ))
                    self.isSending = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.showError = true
                    self.isSending = false
                }
            }
        }
    }

    // MARK: - 上传图片 / 文件并发送（OCR 跑后台，结果 hop 回主线程）

    func uploadAndSendImage(_ image: UIImage) {
        let preview = AttachmentPreview(id: UUID().uuidString, name: "图片")
        attachmentPreviews.append(preview)
        isSending = true
        Task.detached { [weak self] in
            guard let self else { return }
            do {
                let extracted = try await OCRService.shared.recognizeText(from: image)
                await MainActor.run {
                    self.attachmentPreviews.removeAll { $0.id == preview.id }
                    if extracted.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        self.messages.append(ChatMessage(id: UUID().uuidString, role: "user", content: "[图片]", createdAt: Date()))
                        self.errorMessage = "图片中未识别到文字"
                        self.showError = true
                        self.isSending = false
                        return
                    }
                    self.messages.append(ChatMessage(id: UUID().uuidString, role: "user", content: "📷 合同图片（已识别 \(extracted.count) 字）", createdAt: Date()))
                    self.messages.append(ChatMessage(id: UUID().uuidString, role: "user", content: extracted, createdAt: Date()))
                    self.sendAIMessage(prompt: "用户发送了一份合同图片，以下是 OCR 识别出的文本，请用简洁的中文帮用户梳理要点或解答疑问：\n\n\(extracted)")
                }
            } catch {
                await MainActor.run {
                    self.attachmentPreviews.removeAll { $0.id == preview.id }
                    self.errorMessage = "图片识别失败：\(error.localizedDescription)"
                    self.showError = true
                    self.isSending = false
                }
            }
        }
    }

    func uploadAndSendFile(_ url: URL) {
        let preview = AttachmentPreview(id: UUID().uuidString, name: url.lastPathComponent)
        attachmentPreviews.append(preview)
        isSending = true
        Task.detached { [weak self] in
            guard let self else { return }
            do {
                let text = try await FileImportService.shared.extractText(from: url)
                await MainActor.run {
                    self.attachmentPreviews.removeAll { $0.id == preview.id }
                    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    if trimmed.isEmpty {
                        self.messages.append(ChatMessage(id: UUID().uuidString, role: "user", content: "[文件]", createdAt: Date()))
                        self.errorMessage = "文件内容为空"
                        self.showError = true
                        self.isSending = false
                        return
                    }
                    self.messages.append(ChatMessage(id: UUID().uuidString, role: "user", content: "📎 合同文件（\(trimmed.count) 字）", createdAt: Date()))
                    self.sendAIMessage(prompt: "用户发送了一份合同文件，以下是文本内容，请用简洁的中文帮用户梳理要点或解答疑问：\n\n\(trimmed)")
                }
            } catch {
                await MainActor.run {
                    self.attachmentPreviews.removeAll { $0.id == preview.id }
                    self.errorMessage = "文件读取失败：\(error.localizedDescription)"
                    self.showError = true
                    self.isSending = false
                }
            }
        }
    }

    /// 直接用文字 prompt 拿 AI 回复（不上传消息内容）
    @MainActor
    private func sendAIMessage(prompt: String) {
        guard let sid = sessionId else {
            errorMessage = "会话未就绪"
            showError = true
            isSending = false
            return
        }
        Task.detached { [weak self] in
            guard let self else { return }
            do {
                let resp = try await self.api.sendChatMessage(sessionId: sid, message: prompt)
                await MainActor.run {
                    self.messages.append(ChatMessage(
                        id: UUID().uuidString, role: "assistant",
                        content: resp.reply, createdAt: Date()
                    ))
                    self.isSending = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.showError = true
                    self.isSending = false
                }
            }
        }
    }

    func reset() {
        Task { @MainActor in
            messages = []
            inputText = ""
            isSending = false
            showError = false
            errorMessage = ""
            sessionId = nil
            await createNewSession()
        }
    }
}

// MARK: - 首页聊天页面

struct HomeChatView: View {
    let initialMessage: String

    @StateObject private var vm: HomeChatViewModel
    @FocusState private var inputFocused: Bool
    @State private var showActionSheet = false
    @State private var showCamera = false
    @State private var showPhotoPicker = false
    @State private var showFileImporter = false

    init(initialMessage: String) {
        self.initialMessage = initialMessage
        _vm = StateObject(wrappedValue: HomeChatViewModel(forceNew: true, initialMessage: initialMessage))
    }

    var body: some View {
        VStack(spacing: 0) {
            // 顶部导航 — 透明覆盖在系统导航栏上，保留系统返回按钮功能
            HStack {
                Spacer()
                Text("契合 · 法律助手")
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
                Button {
                    vm.reset()
                    vm.inputText = ""
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 15))
                        .foregroundColor(DraftStyle.primary.opacity(0.7))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.white.opacity(0.95))

            // 气泡：直接 push 到合同生成/审查（聊天留在栈底，返回时自然回到聊天）
            HStack(spacing: 10) {
                NavigationLink(destination: DraftFlowView()) {
                    Label("合同生成", systemImage: "doc.text.fill")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            LinearGradient(
                                colors: [Color(red: 0.26, green: 0.76, blue: 0.62),
                                         Color(red: 0.16, green: 0.56, blue: 0.42)],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                NavigationLink(destination: ReviewFlowView()) {
                    Label("合同审查", systemImage: "magnifyingglass")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            LinearGradient(
                                colors: [Color(red: 0.22, green: 0.50, blue: 0.96),
                                         Color(red: 0.12, green: 0.35, blue: 0.76)],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(Color(.systemGroupedBackground))

            Divider()

            // 聊天区
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(vm.messages) { msg in
                            ChatBubble(message: msg)
                                .id(msg.id)
                        }
                        if vm.isSending {
                            TypingIndicator()
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 16)
                }
                .onChange(of: vm.messages.count) { _, _ in
                    if let last = vm.messages.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
                .onChange(of: vm.isSending) { _, sending in
                    if sending, let last = vm.messages.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }

            Divider()

            // 输入区
            VStack(spacing: 0) {
                if !vm.attachmentPreviews.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(vm.attachmentPreviews) { preview in
                                AttachmentPreviewBadge(name: preview.name) {
                                    vm.attachmentPreviews.removeAll { $0.id == preview.id }
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                    }
                }

                HStack(spacing: 10) {
                    Button {
                        showActionSheet = true
                    } label: {
                        Image(systemName: "paperclip")
                            .font(.system(size: 18))
                            .foregroundColor(DraftStyle.primary.opacity(0.8))
                    }
                    .disabled(vm.isSending)

                    TextField("输入你的法律问题…", text: $vm.inputText)
                        .font(.system(size: 15))
                        .submitLabel(.send)
                        .focused($inputFocused)
                        .disabled(vm.isSending)
                        .onSubmit { sendIfValid() }

                    Button {
                        sendIfValid()
                    } label: {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 30, height: 30)
                            .background(
                                vm.inputText.trimmingCharacters(in: .whitespaces).isEmpty || vm.isSending
                                    ? Color.gray.opacity(0.35)
                                    : DraftStyle.primary
                            )
                            .clipShape(Circle())
                    }
                    .disabled(vm.inputText.trimmingCharacters(in: .whitespaces).isEmpty || vm.isSending)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.white)
            }
        }
        .background(Color(.systemGroupedBackground))
        // 显示系统导航栏：气泡 NavigationLink 需要它才能 push
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    vm.reset()
                    vm.inputText = ""
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(DraftStyle.primary)
                }
            }
        }
        .actionSheet(isPresented: $showActionSheet) {
            ActionSheet(title: Text("添加合同内容"), buttons: [
                .default(Text("📷 拍照识别")) { showCamera = true },
                .default(Text("🖼 相册选择")) { showPhotoPicker = true },
                .default(Text("📎 文件导入")) { showFileImporter = true },
                .cancel(),
            ])
        }
        .sheet(isPresented: $showCamera) {
            CameraPicker { image in vm.uploadAndSendImage(image) }
        }
        .sheet(isPresented: $showPhotoPicker) {
            PhotoPicker { image in vm.uploadAndSendImage(image) }
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.pdf, .plainText, UTType("org.openxmlformats.wordprocessingml.document")!],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                vm.uploadAndSendFile(url)
            }
        }
        .alert("错误", isPresented: $vm.showError) {
            Button("好的", role: .cancel) {}
        } message: {
            Text(vm.errorMessage)
        }
    }

    private func sendIfValid() {
        guard !vm.inputText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        vm.sendMessage()
    }
}

// MARK: - 附件预览 badge

struct AttachmentPreview: Identifiable, Equatable {
    let id: String
    let name: String
}

struct AttachmentPreviewBadge: View {
    let name: String
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "paperclip")
                .font(.caption2)
            Text(name)
                .font(.caption)
                .lineLimit(1)
            Button(action: onDelete) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(DraftStyle.primary.opacity(0.08))
        .foregroundColor(DraftStyle.primary)
        .clipShape(Capsule())
    }
}
