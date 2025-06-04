import Foundation

struct TripPlan {
    let destination: String
    let startDate: String   // "yyyy-MM-dd"
    let endDate: String     // "yyyy-MM-dd"
    let itinerary: [String]
}

final class AIPlanner {
    
    static let shared = AIPlanner() // 添加单例支持
    
    private let apiKey = "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" // 替换为你的 OpenAI API 密钥
    
    private init() {} // 确保外部无法实例化
    
    func generatePlan(for destination: String, startDate: String, endDate: String) async throws -> TripPlan {
        let itinerary = try await fetchItinerary(destination: destination, startDate: startDate, endDate: endDate)
        return TripPlan(destination: destination, startDate: startDate, endDate: endDate, itinerary: itinerary)
    }
    
    private func fetchItinerary(destination: String, startDate: String, endDate: String) async throws -> [String] {
        let prompt = "为我计划一个从 \(startDate) 到 \(endDate) 的 \(destination) 旅游行程。"
        
        guard let url = URL(string: "https://api.openai.com/v1/engines/davinci-codex/completions") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "prompt": prompt,
            "max_tokens": 150
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        if let response = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
           let choices = response["choices"] as? [[String: Any]],
           let text = choices.first?["text"] as? String {
            return text.components(separatedBy: "\n").filter { !$0.isEmpty }
        } else {
            throw NSError(domain: "AIPlanner", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to parse response"])
        }
    }
    
    // 添加 suggestEvents 方法
    func suggestEvents(for month: String, completion: @escaping (Result<[Event], Error>) -> Void) {
        // month: "yyyy-MM"
        let simulatedEvents = [
            Event(title: "AI Event 1", creatorOpenid: "ai_openid", color: "#FF6280", date: "\(month)-01", startTime: "09:00:00", endTime: "10:00:00", destination: "AI会场", mapObj: "", openChecked: 1, personChecked: 0, createTime: "\(month)-01 08:00:00"),
            Event(title: "AI Event 2", creatorOpenid: "ai_openid", color: "#5EDA74", date: "\(month)-02", startTime: "14:00:00", endTime: "16:00:00", destination: "AI实验室", mapObj: "", openChecked: 0, personChecked: 1, createTime: "\(month)-02 13:00:00")
        ]
        completion(.success(simulatedEvents))
    }
}
