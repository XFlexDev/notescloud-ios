import Foundation

public struct APIResponse<T: Codable>: Codable {
    public let success: Bool
    public let data: T?
    public let error: String?
}

public class APIService {
    public static let shared = APIService()

    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    public var serverURLString: String {
        get {
            UserDefaults.standard.string(forKey: "server_url") ?? "https://notes.kreatix.dev"
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "server_url")
        }
    }

    public var baseURL: URL {
        URL(string: serverURLString) ?? URL(string: "https://notes.kreatix.dev")!
    }

    private init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: configuration)

        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateStr = try container.decode(String.self)

            // Try ISO8601 with fractional seconds
            let isoFormatter = ISO8601DateFormatter()
            isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = isoFormatter.date(from: dateStr) {
                return date
            }

            // Fallback without fractional seconds
            isoFormatter.formatOptions = [.withInternetDateTime]
            if let date = isoFormatter.date(from: dateStr) {
                return date
            }

            // Fallback to standard RFC3339
            let df = DateFormatter()
            df.locale = Locale(identifier: "en_US_POSIX")
            df.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
            if let date = df.date(from: dateStr) {
                return date
            }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot decode date string \(dateStr)"
            )
        }

        self.encoder = JSONEncoder()
        self.encoder.dateEncodingStrategy = .iso8601
    }

    // MARK: - Folders

    public func fetchFolders() async throws -> [Folder] {
        let url = baseURL.appendingPathComponent("api/folders")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        let (data, response) = try await session.data(for: request)
        try validateResponse(response)

        let apiResponse = try decoder.decode(APIResponse<[Folder]>.self, from: data)
        guard let folders = apiResponse.data else {
            throw APIError.serverError(apiResponse.error ?? "Failed to fetch folders")
        }
        return folders
    }

    public func createFolder(name: String, icon: String = "folder", color: String = "#E8A738") async throws -> Folder {
        let url = baseURL.appendingPathComponent("api/folders")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = ["name": name, "icon": icon, "color": color]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        try validateResponse(response)

        let apiResponse = try decoder.decode(APIResponse<Folder>.self, from: data)
        guard let folder = apiResponse.data else {
            throw APIError.serverError(apiResponse.error ?? "Failed to create folder")
        }
        return folder
    }

    public func deleteFolder(id: String) async throws {
        let url = baseURL.appendingPathComponent("api/folders").appendingPathComponent(id)
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"

        let (_, response) = try await session.data(for: request)
        try validateResponse(response)
    }

    // MARK: - Notes

    public func fetchNotes(folderId: String? = nil, search: String? = nil, pinned: Bool? = nil) async throws -> [NoteSummary] {
        var components = URLComponents(url: baseURL.appendingPathComponent("api/notes"), resolvingAgainstBaseURL: false)!
        var queryItems: [URLQueryItem] = []

        if let folderId = folderId, folderId != "all" {
            queryItems.append(URLQueryItem(name: "folder_id", value: folderId))
        }
        if let search = search, !search.isEmpty {
            queryItems.append(URLQueryItem(name: "search", value: search))
        }
        if let pinned = pinned {
            queryItems.append(URLQueryItem(name: "pinned", value: pinned ? "true" : "false"))
        }

        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }

        guard let url = components.url else { throw APIError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        let (data, response) = try await session.data(for: request)
        try validateResponse(response)

        let apiResponse = try decoder.decode(APIResponse<[NoteSummary]>.self, from: data)
        guard let notes = apiResponse.data else {
            throw APIError.serverError(apiResponse.error ?? "Failed to fetch notes")
        }
        return notes
    }

    public func fetchNote(id: String) async throws -> Note {
        let url = baseURL.appendingPathComponent("api/notes").appendingPathComponent(id)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        let (data, response) = try await session.data(for: request)
        try validateResponse(response)

        let apiResponse = try decoder.decode(APIResponse<Note>.self, from: data)
        guard let note = apiResponse.data else {
            throw APIError.serverError(apiResponse.error ?? "Note not found")
        }
        return note
    }

    public func createNote(folderId: String, title: String, body: String, isPinned: Bool = false) async throws -> Note {
        let url = baseURL.appendingPathComponent("api/notes")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload: [String: Any] = [
            "folder_id": folderId,
            "title": title,
            "body": body,
            "is_pinned": isPinned
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await session.data(for: request)
        try validateResponse(response)

        let apiResponse = try decoder.decode(APIResponse<Note>.self, from: data)
        guard let note = apiResponse.data else {
            throw APIError.serverError(apiResponse.error ?? "Failed to create note")
        }
        return note
    }

    public func updateNote(id: String, folderId: String? = nil, title: String? = nil, body: String? = nil, isPinned: Bool? = nil) async throws -> Note {
        let url = baseURL.appendingPathComponent("api/notes").appendingPathComponent(id)
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var payload: [String: Any] = [:]
        if let folderId = folderId { payload["folder_id"] = folderId }
        if let title = title { payload["title"] = title }
        if let body = body { payload["body"] = body }
        if let isPinned = isPinned { payload["is_pinned"] = isPinned }

        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await session.data(for: request)
        try validateResponse(response)

        let apiResponse = try decoder.decode(APIResponse<Note>.self, from: data)
        guard let note = apiResponse.data else {
            throw APIError.serverError(apiResponse.error ?? "Failed to update note")
        }
        return note
    }

    public func deleteNote(id: String, permanent: Bool = false) async throws {
        var components = URLComponents(url: baseURL.appendingPathComponent("api/notes").appendingPathComponent(id), resolvingAgainstBaseURL: false)!
        if permanent {
            components.queryItems = [URLQueryItem(name: "permanent", value: "true")]
        }
        guard let url = components.url else { throw APIError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"

        let (_, response) = try await session.data(for: request)
        try validateResponse(response)
    }

    public func togglePin(id: String) async throws -> Bool {
        let url = baseURL.appendingPathComponent("api/notes").appendingPathComponent(id).appendingPathComponent("pin")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        let (data, response) = try await session.data(for: request)
        try validateResponse(response)

        let apiResponse = try decoder.decode(APIResponse<Bool>.self, from: data)
        return apiResponse.data ?? false
    }

    // MARK: - Attachments & B2 Upload

    public func uploadAttachment(
        noteId: String,
        fileData: Data,
        fileName: String,
        mimeType: String
    ) async throws -> Attachment {
        let url = baseURL.appendingPathComponent("api/notes").appendingPathComponent(noteId).appendingPathComponent("attachments")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        let (data, response) = try await session.data(for: request)
        try validateResponse(response)

        let apiResponse = try decoder.decode(APIResponse<Attachment>.self, from: data)
        guard let attachment = apiResponse.data else {
            throw APIError.serverError(apiResponse.error ?? "Failed to upload attachment")
        }
        return attachment
    }

    private func validateResponse(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.httpStatus(httpResponse.statusCode)
        }
    }
}

public enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpStatus(Int)
    case serverError(String)

    public var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid server URL"
        case .invalidResponse: return "Invalid response from server"
        case .httpStatus(let code): return "HTTP error code: \(code)"
        case .serverError(let msg): return msg
        }
    }
}
