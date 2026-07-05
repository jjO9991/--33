import Foundation

// MARK: - 通用响应包装

struct ApiResponse<T: Codable>: Codable {
    let code: Int
    let message: String
    let data: T?
}

// MARK: - 会话

struct Session: Codable, Identifiable {
    let id: String
    let deviceId: String
    let type: String
    let status: String
    let title: String
    let errorMessage: String?
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case deviceId = "device_id"
        case type, status, title
        case errorMessage = "error_message"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct SessionCreateRequest: Codable {
    let deviceId: String
    let type: String

    enum CodingKeys: String, CodingKey {
        case deviceId = "device_id"
        case type
    }
}

// MARK: - 文件

struct FileUploadResponse: Codable {
    let fileId: String
    let originalName: String?
    let sha256: String
    let sizeBytes: Int
    let mimeType: String?

    enum CodingKeys: String, CodingKey {
        case fileId = "file_id"
        case originalName = "original_name"
        case sha256
        case sizeBytes = "size_bytes"
        case mimeType = "mime_type"
    }
}

// MARK: - 聊天

struct ChatRequest: Codable {
    let message: String
}

struct FieldInfo: Codable {
    let key: String
    let label: String
    let value: String?
    let isMissing: Bool

    enum CodingKeys: String, CodingKey {
        case key, label, value
        case isMissing = "is_missing"
    }
}

struct ChatResponse: Codable {
    let reply: String
    let fields: [FieldInfo]
    let completeness: Double
}

// MARK: - 草稿详情（恢复历史会话）

private struct StringOrNull: Decodable {
    let value: String?
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() { value = nil }
        else { value = try container.decode(String.self) }
    }
}

struct DraftDetailResponse: Codable {
    let fields: [String: String]  // null JSON 值转为空字符串
    let missingFields: [String]
    let chatHistory: [[String: String]]
    let completeness: Double

    enum CodingKeys: String, CodingKey {
        case fields
        case missingFields = "missing_fields"
        case chatHistory = "chat_history"
        case completeness
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rawFields = try container.decode([String: StringOrNull].self, forKey: .fields)
        self.fields = rawFields.mapValues { $0.value ?? "" }
        self.missingFields = try container.decode([String].self, forKey: .missingFields)
        self.chatHistory = try container.decode([[String: String]].self, forKey: .chatHistory)
        self.completeness = try container.decode(Double.self, forKey: .completeness)
    }
}

// MARK: - 合同审查

struct Citation: Codable {
    let sourceType: String     // "law" / "regulation" 等
    let title: String
    let urlOrRef: String
    let verified: Bool
    enum CodingKeys: String, CodingKey {
        case sourceType = "source_type"
        case title
        case urlOrRef = "url_or_ref"
        case verified
    }
}

struct HighlightRange: Codable {
    let start: Int
    let end: Int
}

struct RiskCard: Codable, Identifiable {
    let riskId: String
    let level: String          // "red" / "yellow" / "green"
    let type: String
    let title: String
    let quote: String
    let plainExplanation: String
    let suggestedRevision: String
    let citations: [Citation]
    let highlightRange: HighlightRange
    let needsLawyer: Bool

    var id: String { riskId }

    enum CodingKeys: String, CodingKey {
        case riskId = "risk_id"
        case level, type, title, quote
        case plainExplanation = "plain_explanation"
        case suggestedRevision = "suggested_revision"
        case citations
        case highlightRange = "highlight_range"
        case needsLawyer = "needs_lawyer"
    }
}

struct ReviewSummary: Codable {
    let totalRisks: Int
    let redCount: Int
    let yellowCount: Int
    let greenCount: Int
    let suggestion: String
    enum CodingKeys: String, CodingKey {
        case totalRisks = "total_risks"
        case redCount = "red_count"
        case yellowCount = "yellow_count"
        case greenCount = "green_count"
        case suggestion
    }
}

struct ReviewAnalyzeRequest: Codable {
    let sessionId: String
    let userRole: String
    let text: String
    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case userRole = "user_role"
        case text
    }
}

struct ReviewDetailResponse: Codable {
    let status: String
    let summary: ReviewSummary?
    let risks: [RiskCard]
}

struct ReviewAnalyzeResponse: Codable {
    let sessionId: String
    let status: String
    let summary: ReviewSummary
    let risks: [RiskCard]
    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case status, summary, risks
    }
}
