//
//  APIClient.swift
//  Secalender
//
//  模板市集 API 客戶端，呼叫 SecalenderWeb 後端
//

import Foundation

/// API 回應：模板列表
private struct TemplatesResponse: Decodable {
    let ok: Bool
    let items: [TemplateDTO]
    let error: String?
}

/// API 回傳的模板 DTO（snake_case）
private struct TemplateDTO: Decodable {
    let id: String
    let title: String
    let description: String?
    let cover_image_url: String?
    let city: String?
    let country: String?
    let days: Int
    let tags: [String]?
    let price: Double
    let rating: Double?
    let review_count: Int?
    let download_count: Int?
    let author_name: String?
    let author_id: String?
    let category: String?
    let is_featured: Bool?
    let created_at: String?
}

final class APIClient {
    static let shared = APIClient()

    /// API 基底網址：從 Info.plist（xcconfig 注入）讀取 SECALENDER_API_BASE_URL
    private static let productionBaseURL = "https://app.huodonli.cn"

    private var baseURL: String {
        guard let url = Bundle.main.infoDictionary?["SECALENDER_API_BASE_URL"] as? String,
              !url.isEmpty,
              url != "$(SECALENDER_API_BASE_URL)" else {
            return Self.productionBaseURL
        }
        let trimmed = url.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        // 拒絕無效的 baseURL（如 "https://api" 缺少網域）
        if trimmed == "https://api" || trimmed == "http://api" {
            return Self.productionBaseURL
        }
        return trimmed
    }

    private init() {}

    /// 取得模板市集列表
    func fetchTemplates() async throws -> [StoreTemplate] {
        let urlString = "\(baseURL)/api/templates"
        guard let url = URL(string: urlString) else {
            throw APIClientError.invalidURL(urlString)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw APIClientError.invalidResponse
        }
        guard (200...299).contains(http.statusCode) else {
            throw APIClientError.httpError(statusCode: http.statusCode, data: data)
        }

        let decoded = try JSONDecoder().decode(TemplatesResponse.self, from: data)
        guard decoded.ok else {
            throw APIClientError.apiError(decoded.error ?? "Unknown error")
        }

        return decodeTemplates(decoded)
    }

    /// 取得模板內容（PlanResult）
    func fetchTemplateContent(id: String) async throws -> PlanResult {
        let urlString = "\(baseURL)/api/templates/\(id)/content"
        guard let url = URL(string: urlString) else {
            throw APIClientError.invalidURL(urlString)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw APIClientError.invalidResponse
        }
        guard (200...299).contains(http.statusCode) else {
            if let err = try? JSONDecoder().decode([String: String].self, from: data), let msg = err["error"] {
                throw APIClientError.apiError(msg)
            }
            throw APIClientError.httpError(statusCode: http.statusCode, data: data)
        }

        struct ContentResponse: Decodable {
            let plan: PlanResult
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: dateString) { return date }
            formatter.formatOptions = [.withInternetDateTime]
            guard let date = formatter.date(from: dateString) else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date: \(dateString)")
            }
            return date
        }

        let decoded = try decoder.decode(ContentResponse.self, from: data)
        return decoded.plan
    }

    private func decodeTemplates(_ decoded: TemplatesResponse) -> [StoreTemplate] {
        return decoded.items.map { dto in
            let tags = dto.tags ?? []
            let purchaseCount = dto.download_count ?? dto.review_count ?? 0
            let createdAt: Date? = {
                guard let raw = dto.created_at else { return nil }
                let withFractional = ISO8601DateFormatter()
                withFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                if let d = withFractional.date(from: raw) { return d }
                let withoutFractional = ISO8601DateFormatter()
                withoutFractional.formatOptions = [.withInternetDateTime]
                return withoutFractional.date(from: raw)
            }()

            return StoreTemplate(
                id: dto.id,
                title: dto.title,
                description: dto.description ?? "",
                tags: tags,
                price: dto.price,
                category: dto.category,
                coverImageURL: dto.cover_image_url,
                rating: dto.rating,
                purchaseCount: purchaseCount,
                daysCount: dto.days,
                authorName: dto.author_name,
                creatorId: dto.author_id,
                isFeatured: dto.is_featured ?? false,
                createdAt: createdAt,
                country: dto.country,
                city: dto.city
            )
        }
    }
}

enum APIClientError: LocalizedError {
    case invalidURL(String)
    case invalidResponse
    case httpError(statusCode: Int, data: Data)
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL(let url): return "無效的 API 網址: \(url)"
        case .invalidResponse: return "無效的伺服器回應"
        case .httpError(let code, _): return "HTTP 錯誤: \(code)"
        case .apiError(let msg): return msg
        }
    }
}
