
import Foundation

final class OpenAIManager {
    static let shared = OpenAIManager()
    private init() {}

    /// TODO: 填入您自己的 OpenAI API 金鑰
    private let apiKey = ""

    /// 根據使用者輸入的提示請求 OpenAI 產生行程計畫，
    /// 回傳 ScheduleItem 陣列（日期格式須為 yyyy-MM-dd，時間為 HH:mm）。
    func generateSchedule(prompt: String) async throws -> [ScheduleItem] {
        // 構建請求
        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        // 請求內容：引導 AI 回傳 JSON 格式的行程陣列
        let messages: [[String: String]] = [
            [
                "role": "system",
                "content": "You are a helpful scheduling assistant. Given a user request, you will return a JSON array of schedule items. Each item should have title, date (yyyy-MM-dd), startTime (HH:mm), endTime (HH:mm), location, and description."
            ],
            [
                "role": "user",
                "content": prompt
            ]
        ]
        let body: [String: Any] = [
            "model": "gpt-4o",
            "messages": messages,
            "temperature": 0.7,
            "max_tokens": 1024
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        // 發送請求
        let (data, _) = try await URLSession.shared.data(for: request)

        // 解析回應
        guard
            let responseObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let choices = responseObject["choices"] as? [[String: Any]],
            let first = choices.first,
            let message = first["message"] as? [String: Any],
            let content = message["content"] as? String
        else {
            throw NSError(domain: "OpenAIManager", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }

        // 將 OpenAI 回傳的 JSON 字串解析為 ScheduleItem 陣列
        guard
            let jsonData = content.data(using: .utf8),
            let jsonArray = try? JSONSerialization.jsonObject(with: jsonData) as? [[String: Any]]
        else {
            throw NSError(domain: "OpenAIManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to parse schedule JSON"])
        }

        var scheduleItems: [ScheduleItem] = []
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"

        for dict in jsonArray {
            guard
                let title = dict["title"] as? String,
                let dateString = dict["date"] as? String,
                let startString = dict["startTime"] as? String,
                let endString = dict["endTime"] as? String,
                let location = dict["location"] as? String,
                let desc = dict["description"] as? String,
                let date = dateFormatter.date(from: dateString),
                let startTime = timeFormatter.date(from: startString),
                let endTime = timeFormatter.date(from: endString)
            else { continue }

            scheduleItems.append(
                ScheduleItem(
                    title: title,
                    date: date,
                    startTime: startTime,
                    endTime: endTime,
                    location: location,
                    description: desc
                )
            )
        }

        return scheduleItems
    }
}
