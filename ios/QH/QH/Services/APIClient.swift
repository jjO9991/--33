import Foundation

enum APIError: Error, LocalizedError {
    case badURL
    case requestFailed(String)
    case decodingFailed
    case serverError(Int)

    var errorDescription: String? {
        switch self {
        case .badURL: return "无效的 URL"
        case .requestFailed(let msg): return msg
        case .decodingFailed: return "数据解析失败"
        case .serverError(let code): return "服务器错误 (\(code))"
        }
    }
}

actor APIClient {
    static let shared = APIClient()

    private let baseURL = "http://localhost:8000"
    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 120
        self.session = URLSession(configuration: config)
    }

    // MARK: - 健康检查

    func health() async throws -> [String: String] {
        try await get("/health", type: [String: String].self)
    }

    // MARK: - 会话

    func createSession(deviceId: String, type: String) async throws -> Session {
        let body = SessionCreateRequest(deviceId: deviceId, type: type)
        let resp: ApiResponse<Session> = try await post("/api/v1/sessions", body: body)
        guard let session = resp.data else {
            throw APIError.requestFailed(resp.message)
        }
        return session
    }

    // MARK: - 历史会话

    func getSessions(deviceId: String, type: String? = nil) async throws -> [Session] {
        var path = "/api/v1/sessions?device_id=\(deviceId)"
        if let t = type { path += "&type=\(t)" }
        let resp: ApiResponse<[Session]> = try await get(path, type: ApiResponse<[Session]>.self)
        return resp.data ?? []
    }

    func deleteSession(id: String) async throws {
        _ = try await delete("/api/v1/sessions/\(id)", type: ApiResponse<[String: Bool]>.self)
    }

    func getDraftDetail(sessionId: String) async throws -> DraftDetailResponse {
        let resp: ApiResponse<DraftDetailResponse> = try await get(
            "/api/v1/sessions/\(sessionId)/draft",
            type: ApiResponse<DraftDetailResponse>.self
        )
        guard let data = resp.data else {
            throw APIError.requestFailed(resp.message)
        }
        return data
    }

    // MARK: - 聊天

    func sendChatMessage(sessionId: String, message: String) async throws -> ChatResponse {
        let body = ChatRequest(message: message)
        let resp: ApiResponse<ChatResponse> = try await post("/api/v1/sessions/\(sessionId)/chat", body: body)
        guard let data = resp.data else {
            throw APIError.requestFailed(resp.message)
        }
        return data
    }

    func getChatDetail(sessionId: String) async throws -> DraftDetailResponse {
        let resp: ApiResponse<DraftDetailResponse> = try await get(
            "/api/v1/sessions/\(sessionId)/chat",
            type: ApiResponse<DraftDetailResponse>.self
        )
        guard let data = resp.data else {
            throw APIError.requestFailed(resp.message)
        }
        return data
    }

    // MARK: - 合同审查

    func analyzeReview(sessionId: String, text: String, userRole: String) async throws -> ReviewAnalyzeResponse {
        let body = ReviewAnalyzeRequest(sessionId: sessionId, userRole: userRole, text: text)
        let resp: ApiResponse<ReviewAnalyzeResponse> = try await post("/api/v1/reviews/analyze", body: body)
        guard let data = resp.data else {
            throw APIError.requestFailed(resp.message)
        }
        return data
    }

    func getReviewDetail(sessionId: String) async throws -> ReviewDetailResponse {
        let resp: ApiResponse<ReviewDetailResponse> = try await get(
            "/api/v1/sessions/\(sessionId)/review",
            type: ApiResponse<ReviewDetailResponse>.self
        )
        guard let data = resp.data else {
            throw APIError.requestFailed(resp.message)
        }
        return data
    }

    // MARK: - 通用请求

    private func get<T: Decodable>(_ path: String, type: T.Type) async throws -> T {
        guard let url = URL(string: baseURL + path) else { throw APIError.badURL }
        let (data, resp) = try await session.data(from: url)
        try check(resp: resp, data: data)
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func post<E: Encodable, D: Decodable>(_ path: String, body: E, type: D.Type? = nil) async throws -> D {
        guard let url = URL(string: baseURL + path) else { throw APIError.badURL }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.timeoutInterval = 120
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(body)
        let (data, resp) = try await session.data(for: req)
        try check(resp: resp, data: data)
        return try JSONDecoder().decode(D.self, from: data)
    }

    private func delete<D: Decodable>(_ path: String, type: D.Type) async throws -> D {
        guard let url = URL(string: baseURL + path) else { throw APIError.badURL }
        var req = URLRequest(url: url)
        req.httpMethod = "DELETE"
        let (data, resp) = try await session.data(for: req)
        try check(resp: resp, data: data)
        return try JSONDecoder().decode(D.self, from: data)
    }

    private func check(resp: URLResponse, data: Data) throws {
        guard let http = resp as? HTTPURLResponse else { return }
        guard (200..<300).contains(http.statusCode) else {
            throw APIError.serverError(http.statusCode)
        }
    }
}
