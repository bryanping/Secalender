//
//  EntitlementService.swift
//  Secalender
//
//  訂閱控制：為商業設計預留
//  Free：每日 3 次自動排程
//  Pro：無限
//

import Foundation

final class EntitlementService {
    static let shared = EntitlementService()
    private let dailySchedulerCountKey = "entitlement_daily_scheduler_count"
    private let dailySchedulerDateKey = "entitlement_daily_scheduler_date"
    private let maxFreeDailyScheduler = 3
    
    private init() {}
    
    var isProUser: Bool {
        // TODO: 接 IAP 訂閱狀態
        false
    }
    
    var schedulerEnabled: Bool {
        isProUser || dailySchedulerRemaining > 0
    }
    
    /// 今日剩餘免費自動排程次數
    var dailySchedulerRemaining: Int {
        let ud = UserDefaults.standard
        let today = Calendar.current.startOfDay(for: Date())
        if let lastDate = ud.object(forKey: dailySchedulerDateKey) as? Date,
           Calendar.current.isDate(lastDate, inSameDayAs: today) {
            let used = ud.integer(forKey: dailySchedulerCountKey)
            return max(0, maxFreeDailyScheduler - used)
        }
        return maxFreeDailyScheduler
    }
    
    /// 消耗一次自動排程（Free 用戶）
    func consumeSchedulerUse() {
        guard !isProUser else { return }
        let ud = UserDefaults.standard
        let today = Calendar.current.startOfDay(for: Date())
        if let lastDate = ud.object(forKey: dailySchedulerDateKey) as? Date,
           !Calendar.current.isDate(lastDate, inSameDayAs: today) {
            ud.set(0, forKey: dailySchedulerCountKey)
        }
        let used = ud.integer(forKey: dailySchedulerCountKey)
        ud.set(used + 1, forKey: dailySchedulerCountKey)
        ud.set(today, forKey: dailySchedulerDateKey)
    }
}
