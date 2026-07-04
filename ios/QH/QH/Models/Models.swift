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
    let errorMessage: String?
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case deviceId = "device_id"
        case type, status
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
