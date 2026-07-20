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
    
    private init() {} // 确保外部无法实例化
    
    // 修改内容：P0 清理 — 移除 generatePlan/fetchItinerary/suggestEvents：
    // 1) 呼叫的 OpenAI engines endpoint 早已下線，執行必 404
    // 2) suggestEvents 回傳寫死假資料
    // 3) 全專案無任何呼叫點
    // 本類僅保留 EventCreateView 使用的時間計算工具。

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
