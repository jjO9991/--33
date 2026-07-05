import Foundation
import SwiftUI
import UIKit

private let sessionIdKey = "homeChatSessionId"

@MainActor
final class HomeChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var inputText: String = ""
    @Published var isSending: Bool = false
    @Published var showError = false
    @Published var errorMessage = ""

    private let api = APIClient.shared
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
        self.sessionId = sid
        self.messages = detail.chatHistory
            .compactMap { entry -> ChatMessage? in
                guard let role = entry["role"],
                      let content = entry["content"] else { return nil }
                return ChatMessage(
                    id: UUID().uuidString,
                    role: role,
                    content: content,
                    createdAt: Date(),
                )
            }
        return true
    }

    private func createNewSession() async {
        do {
            let session = try await api.createSession(deviceId: deviceId, type: "chat")
            self.sessionId = session.id
            UserDefaults.standard.set(session.id, forKey: sessionIdKey)
            addWelcome()
            // 发送 pending 的初始消息（进入首页时带入的提问）
            if let msg = pendingInitialMessage, !msg.trimmingCharacters(in: .whitespaces).isEmpty {
                pendingInitialMessage = nil
                inputText = msg
                sendMessage()
            }
        } catch {
            errorMessage = "创建会话失败：\(error.localizedDescription)"
            showError = true
        }
    }

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
        guard !text.isEmpty, !isSending, let sid = sessionId else { return }

        isSending = true
        // 立即追加用户消息
        messages.append(ChatMessage(
            id: UUID().uuidString,
            role: "user",
            content: text,
            createdAt: Date(),
        ))
        inputText = ""

        Task {
            do {
                let resp = try await api.sendChatMessage(sessionId: sid, message: text)
                await MainActor.run {
                    messages.append(ChatMessage(
                        id: UUID().uuidString,
                        role: "assistant",
                        content: resp.reply,
                        createdAt: Date(),
                    ))
                    isSending = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                    isSending = false
                }
            }
        }
    }

    func reset() {
        messages = []
        inputText = ""
        isSending = false
        showError = false
        errorMessage = ""
        sessionId = nil
        Task {
            await createNewSession()
        }
    }
}

// MARK: - 首页聊天页面

struct HomeChatView: View {
    let initialMessage: String
    var onDismiss: (() -> Void)?
    var onNavigateToDraft: (() -> Void)?
    var onNavigateToReview: (() -> Void)?

    @StateObject private var vm: HomeChatViewModel
    @FocusState private var inputFocused: Bool

    init(initialMessage: String, onDismiss: (() -> Void)? = nil,
         onNavigateToDraft: (() -> Void)? = nil,
         onNavigateToReview: (() -> Void)? = nil) {
        self.initialMessage = initialMessage
        self.onDismiss = onDismiss
        self.onNavigateToDraft = onNavigateToDraft
        self.onNavigateToReview = onNavigateToReview
        _vm = StateObject(wrappedValue: HomeChatViewModel(forceNew: true, initialMessage: initialMessage))
    }

    var body: some View {
        VStack(spacing: 0) {
            // 顶部导航
            HStack {
                Button {
                    onDismiss?()
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(DraftStyle.primary)
                }

                Spacer()

                Text("契合 · 法律助手")
                    .font(.system(size: 16, weight: .semibold))

                Spacer()

                Button {
                    vm.reset()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 15))
                        .foregroundColor(DraftStyle.primary.opacity(0.7))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.white.opacity(0.95))

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

            // 快捷操作气泡
            HStack(spacing: 10) {
                Button {
                    onNavigateToDraft?()
                } label: {
                    Label("合同生成", systemImage: "doc.text.fill")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            LinearGradient(
                                colors: [Color(red: 0.26, green: 0.76, blue: 0.62), Color(red: 0.16, green: 0.56, blue: 0.42)],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                Button {
                    onNavigateToReview?()
                } label: {
                    Label("合同审查", systemImage: "magnifyingglass")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            LinearGradient(
                                colors: [Color(red: 0.22, green: 0.50, blue: 0.96), Color(red: 0.12, green: 0.35, blue: 0.76)],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(.systemGroupedBackground))

            Divider()

            // 输入区
            HStack(spacing: 10) {
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
        .background(Color(.systemGroupedBackground))
        .navigationBarHidden(true)
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
