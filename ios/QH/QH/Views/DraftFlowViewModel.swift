import Foundation
import SwiftUI

@MainActor
final class DraftFlowViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var inputText: String = ""
    @Published var isSending: Bool = false
    @Published var completeness: Double = 0.0
    @Published var showFieldPanel: Bool = false
    @Published var showError: Bool = false
    @Published var errorMessage: String = ""

    @Published var fields: [FieldStatus] = [
        FieldStatus(key: "lessor", label: "出租方", value: nil),
        FieldStatus(key: "lessee", label: "承租方", value: nil),
        FieldStatus(key: "address", label: "房屋地址", value: nil),
        FieldStatus(key: "lease_start", label: "租期起", value: nil),
        FieldStatus(key: "lease_end", label: "租期止", value: nil),
        FieldStatus(key: "rent_amount", label: "月租金", value: nil),
        FieldStatus(key: "rent_cycle", label: "付款周期", value: nil),
        FieldStatus(key: "deposit", label: "押金", value: nil),
    ]

    private var sessionId: String?
    private let api = APIClient.shared
    private let deviceId: String = UIDevice.current.identifierForVendor?.uuidString ?? "simulator"

    init() {
        Task { await bootstrap() }
    }

    private func bootstrap() async {
        do {
            let session = try await api.createSession(deviceId: deviceId, type: "draft")
            sessionId = session.id

            // 开场消息
            messages.append(ChatMessage(
                id: UUID().uuidString,
                role: "assistant",
                content: "你好！我是契合，专注帮你搞定房屋租赁合同。\n\n我先帮你理清几个关键信息：\n- 出租方和承租方是谁？\n- 房子在哪个地址？\n- 打算租多久？\n\n你一条一条说也可以，一口气说完也行 😊",
                createdAt: Date()
            ))
        } catch {
            errorMessage = "创建会话失败：\(error.localizedDescription)"
            showError = true
        }
    }

    func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isSending else { return }

        // 用户消息
        messages.append(ChatMessage(
            id: UUID().uuidString,
            role: "user",
            content: text,
            createdAt: Date()
        ))
        inputText = ""
        isSending = true

        // 模拟 AI 响应（MVP 阶段走 Mock，后续接 Claude）
        Task { await mockAIResponse(userInput: text) }
    }

    private func mockAIResponse(userInput: String) async {
        // 模拟思考延迟
        try? await Task.sleep(nanoseconds: 1_200_000_000)

        // 简单字段提取（演示用）
        extractFields(from: userInput)

        // 生成下一轮问题
        let reply = generateFollowUp()

        messages.append(ChatMessage(
            id: UUID().uuidString,
            role: "assistant",
            content: reply,
            createdAt: Date()
        ))

        isSending = false
    }

    private func extractFields(from text: String) {
        // 极简 NLP —— 正式接 Claude 时替换
        let lower = text.lowercased()
        for i in fields.indices {
            switch fields[i].key {
            case "address" where lower.contains("路") || lower.contains("号") || lower.contains("小区"):
                fields[i].value = text
            case "rent_amount" where text.contains("元") || text.contains("块"):
                fields[i].value = text
            case "lease_start", "lease_end" where lower.contains("月") || lower.contains("年"):
                fields[i].value = text
            default:
                if fields[i].value == nil && text.count > 3 {
                    // 随机填充一个空字段做演示
                    fields[i].value = text
                }
            }
        }
        updateCompleteness()
    }

    private func generateFollowUp() -> String {
        let missing = fields.filter { $0.isMissing }
        if missing.isEmpty {
            return "字段已经收集齐了！我现在帮你生成完整合同草案，预计 20 秒左右 ✍️"
        }
        let next = missing.first!
        let prompts: [String: String] = [
            "lessor": "那么，出租方是谁？（姓名或公司名称）",
            "lessee": "承租方的姓名是？",
            "address": "请告诉我房子的具体地址：",
            "lease_start": "租期从什么时候开始？（例如 2026-08-01）",
            "lease_end": "到什么时候结束？",
            "rent_amount": "月租金是多少？",
            "rent_cycle": "多久付一次？（月付 / 季付 / 半年付）",
            "deposit": "押金收几个月？",
        ]
        return prompts[next.key] ?? "这一步：\(next.label)？"
    }

    private func updateCompleteness() {
        let filled = fields.filter { !$0.isMissing }.count
        completeness = Double(filled) / Double(fields.count)
    }
}
