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
        config.timeoutIntervalForRequest = 30
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
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(body)
        let (data, resp) = try await session.data(for: req)
        try check(resp: resp, data: data)
        return try JSONDecoder().decode(D.self, from: data)
    }

    private func check(resp: URLResponse, data: Data) throws {
        guard let http = resp as? HTTPURLResponse else { return }
        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw APIError.serverError(http.statusCode)
        }
    }
}
