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

    init() {
        Task { await bootstrap() }
    }

    private func bootstrap() async {
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
