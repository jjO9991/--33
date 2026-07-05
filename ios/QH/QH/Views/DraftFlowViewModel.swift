import Foundation
import SwiftUI

// MARK: - 字段分类信息

struct FieldCategoryInfo {
    let name: String
    let icon: String
    let keys: [String]
}

// MARK: - ViewModel

@MainActor
final class DraftFlowViewModel: ObservableObject {
    // MARK: 发布属性

    @Published var messages: [ChatMessage] = []
    @Published var inputText: String = ""
    @Published var isSending: Bool = false
    @Published var completeness: Double = 0.0
    @Published var isBubbleExpanded: Bool = false
    @Published var showError: Bool = false
    @Published var errorMessage: String = ""

    @Published var fields: [FieldStatus] = []

    // MARK: 字段分类定义

    static let fieldCategories: [FieldCategoryInfo] = [
        FieldCategoryInfo(name: "双方姓名及身份证号", icon: "person.2.fill", keys: ["lessor_name", "lessor_id", "lessee_name", "lessee_id"]),
        FieldCategoryInfo(name: "双方联系电话", icon: "phone.fill", keys: ["lessor_phone", "lessee_phone"]),
        FieldCategoryInfo(name: "房屋地址", icon: "house.fill", keys: ["address"]),
        FieldCategoryInfo(name: "房屋面积和户型", icon: "rectangle.3.group.fill", keys: ["area", "layout"]),
        FieldCategoryInfo(name: "租期起止时间", icon: "calendar", keys: ["lease_start", "lease_end"]),
        FieldCategoryInfo(name: "租金金额", icon: "yensign.circle.fill", keys: ["rent_amount"]),
        FieldCategoryInfo(name: "付款周期", icon: "arrow.triangle.2.circlepath", keys: ["rent_cycle"]),
        FieldCategoryInfo(name: "押金金额、退款条件和时间", icon: "lock.shield.fill", keys: ["deposit", "refund_condition", "refund_time"]),
        FieldCategoryInfo(name: "水电气及物业费等", icon: "bolt.fill", keys: ["other_fees"]),
    ]

    static let fieldLabelMap: [String: String] = {
        var map: [String: String] = [:]
        for cat in fieldCategories {
            for key in cat.keys {
                switch key {
                case "lessor_name": map[key] = "出租方姓名"
                case "lessor_id": map[key] = "出租方身份证号"
                case "lessee_name": map[key] = "承租方姓名"
                case "lessee_id": map[key] = "承租方身份证号"
                case "lessor_phone": map[key] = "出租方电话"
                case "lessee_phone": map[key] = "承租方电话"
                case "address": map[key] = "房屋地址"
                case "area": map[key] = "房屋面积"
                case "layout": map[key] = "户型"
                case "lease_start": map[key] = "租期起"
                case "lease_end": map[key] = "租期止"
                case "rent_amount": map[key] = "月租金"
                case "rent_cycle": map[key] = "付款周期"
                case "deposit": map[key] = "押金金额"
                case "refund_condition": map[key] = "押金退款条件"
                case "refund_time": map[key] = "押金退款时间"
                case "other_fees": map[key] = "水电气及物业费等"
                default: map[key] = key
                }
            }
        }
        return map
    }()

    // MARK: 私有属性

    private var sessionId: String?
    private let api = APIClient.shared
    private let deviceId: String = UIDevice.current.identifierForVendor?.uuidString ?? "simulator"

    // MARK: UserDefaults Key

    static let lastSessionKey = "lastDraftSessionId"

    // MARK: 初始化

    init(restoreSessionId: String? = nil) {
        resetFields()
        Task { await bootstrap(restoreSessionId: restoreSessionId) }
    }

    private func resetFields() {
        var allFields: [FieldStatus] = []
        for cat in Self.fieldCategories {
            for key in cat.keys {
                allFields.append(FieldStatus(
                    key: key,
                    label: Self.fieldLabelMap[key] ?? key,
                    value: nil
                ))
            }
        }
        fields = allFields
    }

    /// 启动：优先恢复已有会话，找不到则新建
    private func bootstrap(restoreSessionId: String? = nil) async {
        let sid: String
        if let rid = restoreSessionId {
            sid = rid
        } else if let saved = UserDefaults.standard.string(forKey: Self.lastSessionKey) {
            sid = saved
        } else {
            await createNewSession()
            return
        }

        // 尝试恢复
        if await restoreSession(sessionId: sid) { return }

        // 恢复失败，新建
        await createNewSession()
    }

    /// 从后端恢复历史会话
    private func restoreSession(sessionId sid: String) async -> Bool {
        do {
            let detail = try await api.getDraftDetail(sessionId: sid)
            sessionId = sid

            // 恢复字段（detail.fields 是 [String: String]，null JSON 已转为 ""）
            for i in fields.indices {
                let key = fields[i].key
                let val = detail.fields[key] ?? ""
                if !val.isEmpty { fields[i].value = val }
            }

            // 恢复聊天记录（去掉系统参考后缀 和 JSON 快照）
            messages.removeAll()
            for msg in detail.chatHistory {
                if let role = msg["role"], let content = msg["content"] {
                    let clean = Self.cleanMessage(content)
                    messages.append(ChatMessage(
                        id: UUID().uuidString,
                        role: role,
                        content: clean,
                        createdAt: Date()
                    ))
                }
            }

            completeness = detail.completeness
            UserDefaults.standard.set(sid, forKey: Self.lastSessionKey)
            return true
        } catch {
            return false
        }
    }

    /// 创建全新的会话
    private func createNewSession() async {
        do {
            let session = try await api.createSession(deviceId: deviceId, type: "draft")
            sessionId = session.id
            UserDefaults.standard.set(session.id, forKey: Self.lastSessionKey)
            addWelcomeMessage()
        } catch {
            errorMessage = "创建会话失败：\(error.localizedDescription)"
            showError = true
        }
    }

    private func addWelcomeMessage() {
        messages.append(ChatMessage(
            id: UUID().uuidString,
            role: "assistant",
            content: "你好！我是「契合」，专注帮你搞定房屋租赁合同。😊\n\n您可以根据上方的可展开信息面板填写所有信息，也可以由我一步步询问。请问您想怎么开始？",
            createdAt: Date()
        ))
    }

    /// 清理聊天记录：去掉系统参考后缀 + JSON 字段快照
    private static func cleanMessage(_ content: String) -> String {
        var text = content
        // 去掉 [系统参考：...]
        if let range = text.range(of: "\n\n[系统参考：") {
            text = String(text[..<range.lowerBound])
        }
        // 去掉末尾的 {"field_state": {...}}  JSON 块
        if let jsonRange = text.range(of: "\n{\"field_state\":") {
            text = String(text[..<jsonRange.lowerBound])
        }
        // 去掉 AI 返回内容中的 ** 粗体标记
        text = text.replacingOccurrences(of: "**", with: "")
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 开启全新对话
    func startNewSession() {
        sessionId = nil
        messages.removeAll()
        resetFields()
        completeness = 0.0
        inputText = ""
        isBubbleExpanded = false
        UserDefaults.standard.removeObject(forKey: Self.lastSessionKey)
        Task { await createNewSession() }
    }

    var currentSessionId: String? { sessionId }

    // MARK: 字段绑定（使气泡内 TextField 可编辑）

    func fieldBinding(for key: String) -> Binding<String> {
        Binding<String>(
            get: { self.fields.first(where: { $0.key == key })?.value ?? "" },
            set: { newValue in
                if let idx = self.fields.firstIndex(where: { $0.key == key }) {
                    let trimmed = newValue.trimmingCharacters(in: .whitespaces)
                    self.fields[idx].value = trimmed.isEmpty ? nil : trimmed
                }
            }
        )
    }

    // MARK: 字段统计

    var filledCount: Int {
        fields.filter { !$0.isMissing }.count
    }

    var totalCount: Int {
        fields.count
    }

    func categoryFilledCount(_ category: FieldCategoryInfo) -> Int {
        fields.filter { category.keys.contains($0.key) && !$0.isMissing }.count
    }

    // MARK: 生成模板 — 把字段拉到输入框

    func generateTemplate() {
        var lines: [String] = []
        for category in Self.fieldCategories {
            lines.append("【\(category.name)】")
            for key in category.keys {
                guard let field = fields.first(where: { $0.key == key }) else { continue }
                let placeholder = field.value ?? "______"
                lines.append("  \(field.label)：\(placeholder)")
            }
            lines.append("")
        }
        inputText = lines.joined(separator: "\n")
    }

    // MARK: 气泡提交 — 只把已填的字段 + 输入框内容发给 AI

    func submitFromBubble() {
        // 只收集已填的字段，跳过空的
        var filledLines: [String] = []
        let allFilled = fields.filter { !$0.isMissing }
        for field in allFilled {
            if let val = field.value, !val.trimmingCharacters(in: .whitespaces).isEmpty {
                filledLines.append("- \(field.label)：\(val)")
            }
        }

        var combined = ""
        if !filledLines.isEmpty {
            combined = "我已填写以下信息：\n" + filledLines.joined(separator: "\n")
        }

        let userInput = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !userInput.isEmpty {
            if !combined.isEmpty { combined += "\n\n" }
            combined += userInput
        }

        guard !combined.isEmpty else { return }
        inputText = combined
        sendMessage()
    }

    // MARK: 发送消息

    func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isSending, let sid = sessionId else { return }

        // 用户消息
        messages.append(ChatMessage(
            id: UUID().uuidString,
            role: "user",
            content: text,
            createdAt: Date()
        ))
        inputText = ""
        isSending = true

        Task {
            do {
                let result = try await api.sendChatMessage(sessionId: sid, message: text)

                // 从 API 结果更新字段状态
                fields = result.fields.map { f in
                    FieldStatus(key: f.key, label: f.label, value: f.value)
                }
                completeness = result.completeness

                // AI 回复
                messages.append(ChatMessage(
                    id: UUID().uuidString,
                    role: "assistant",
                    content: result.reply,
                    createdAt: Date()
                ))
            } catch {
                errorMessage = "发送失败：\(error.localizedDescription)"
                showError = true
            }
            isSending = false
        }
    }
}
