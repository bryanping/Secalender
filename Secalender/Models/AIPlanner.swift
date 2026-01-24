import Foundation
import CoreLocation

// 需要导入 Event 和 TravelTimeCalculator
// 注意：这些类型在其他文件中定义，这里只是声明依赖关系

struct TripPlan {
    let destination: String
    let startDate: String   // "yyyy-MM-dd"
    let endDate: String     // "yyyy-MM-dd"
    let itinerary: [String]
}

// MARK: - 多日行程时间计算结果
struct TravelTimeCalculationResult {
    let earliestArrivalTime: Date
    let travelTime: TimeInterval
    let preparationTime: TimeInterval
    let routeInfo: String?
}

final class AIPlanner {
    
    static let shared = AIPlanner() // 添加单例支持
    
    /// 从 Info.plist 读取 OpenAI API Key（通过 Secrets.xcconfig 配置）
    private var apiKey: String {
        get throws {
            // 方法1: 从 Info.plist 读取（从 Secrets.xcconfig 传递）
            if let key = Bundle.main.infoDictionary?["OPENAI_API_KEY"] as? String,
               !key.isEmpty,
               key != "$(OPENAI_API_KEY)" {  // 检查是否被正确替换
                return key
            }
            
            // 方法2: 尝试从环境变量读取（用于调试）
            if let envKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"],
               !envKey.isEmpty {
                print("⚠️ [AIPlanner] 从环境变量读取 API Key")
                return envKey
            }
            
            // 如果都无法读取，抛出错误
            let errorMessage = """
            ⚠️ OpenAI API Key 未配置
            
            请检查以下配置：
            1. Secrets.xcconfig 文件中的 OPENAI_API_KEY 是否已设置
            2. Info.plist 中是否包含 OPENAI_API_KEY = $(OPENAI_API_KEY)
            3. Xcode 项目 Build Settings 中是否正确引用了 Secrets.xcconfig
            
            当前 Info.plist 中的值: \(Bundle.main.infoDictionary?["OPENAI_API_KEY"] ?? "nil")
            """
            throw NSError(
                domain: "AIPlanner",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: errorMessage]
            )
        }
    }
    
    private init() {} // 确保外部无法实例化
    
    func generatePlan(for destination: String, startDate: String, endDate: String) async throws -> TripPlan {
        let itinerary = try await fetchItinerary(destination: destination, startDate: startDate, endDate: endDate)
        return TripPlan(destination: destination, startDate: startDate, endDate: endDate, itinerary: itinerary)
    }
    
    private func fetchItinerary(destination: String, startDate: String, endDate: String) async throws -> [String] {
        // 获取 API Key
        let key = try apiKey
        
        let prompt = "为我计划一个从 \(startDate) 到 \(endDate) 的 \(destination) 旅游行程。"
        
        guard let url = URL(string: "https://api.openai.com/v1/engines/davinci-codex/completions") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
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
    
    // MARK: - 智能时间计算
    
    /// 计算从上一个行程到当前行程的最快到达时间
    /// - Parameters:
    ///   - previousEndTime: 上一个行程的结束时间
    ///   - previousCoordinate: 上一个行程的地点坐标
    ///   - currentCoordinate: 当前行程的地点坐标
    ///   - completion: 完成回调，返回计算结果
    func calculateOptimalArrivalTime(
        previousEndTime: Date,
        previousCoordinate: CLLocationCoordinate2D,
        currentCoordinate: CLLocationCoordinate2D,
        completion: @escaping (TravelTimeCalculationResult?) -> Void
    ) {
        let fromLocation = CLLocation(latitude: previousCoordinate.latitude, longitude: previousCoordinate.longitude)
        let toLocation = CLLocation(latitude: currentCoordinate.latitude, longitude: currentCoordinate.longitude)
        
        // 使用 TravelTimeCalculator 计算交通时间
        TravelTimeCalculator.shared.calculateTravelTime(from: fromLocation, to: toLocation) { efficientTime, taxiTime, routeInfo in
            guard let travelTime = efficientTime else {
                completion(nil)
                return
            }
            
            // 准备时间：随机5-10分钟
            let preparationMinutes = Int.random(in: 5...10)
            let preparationTime = TimeInterval(preparationMinutes * 60)
            
            // 最快到达时间：上一个行程结束时间 + 交通时间 + 准备时间
            let earliestArrivalTime = previousEndTime.addingTimeInterval(travelTime + preparationTime)
            
            let result = TravelTimeCalculationResult(
                earliestArrivalTime: earliestArrivalTime,
                travelTime: travelTime,
                preparationTime: preparationTime,
                routeInfo: routeInfo
            )
            
            completion(result)
        }
    }
    
    /// 确保时间顺序：当前行程时间不早于上一个行程
    /// - Parameters:
    ///   - previousEndTime: 上一个行程的结束时间
    ///   - currentStartTime: 当前行程的开始时间
    ///   - currentDate: 当前行程的日期
    /// - Returns: 调整后的开始时间和日期
    func ensureTimeOrder(
        previousEndTime: Date,
        currentStartTime: Date,
        currentDate: Date
    ) -> (startTime: Date, date: Date) {
        let calendar = Calendar.current
        let previousEnd = calendar.date(bySettingHour: calendar.component(.hour, from: previousEndTime),
                                        minute: calendar.component(.minute, from: previousEndTime),
                                        second: 0,
                                        of: previousEndTime) ?? previousEndTime
        
        let currentStart = calendar.date(bySettingHour: calendar.component(.hour, from: currentStartTime),
                                        minute: calendar.component(.minute, from: currentStartTime),
                                        second: 0,
                                        of: currentDate) ?? currentStartTime
        
        // 如果当前开始时间早于上一个结束时间，自动调整
        if currentStart < previousEnd {
            // 设置为上一个结束时间后30分钟
            if let adjustedTime = calendar.date(byAdding: .minute, value: 30, to: previousEnd) {
                return (adjustedTime, calendar.startOfDay(for: adjustedTime))
            }
        }
        
        return (currentStartTime, currentDate)
    }
}
