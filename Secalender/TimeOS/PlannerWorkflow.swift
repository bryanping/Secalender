//
//  PlannerWorkflow.swift
//  Secalender
//
//  修改内容：Time OS 工作流定義 — 每個生活場景是一個 Workflow（非單一事件）。
//  Time OS 只負責入口；所有入口導向同一 AIPlannerView，僅帶不同 plannerModelType / 預設輸入。
//  文案使用情境用語，不露技術模型名稱。
//

import Foundation
import SwiftUI

/// 工作流場景（Time OS 入口卡片）
enum PlannerWorkflowType: String, Codable, CaseIterable {
    // 快速開始
    case arrangeToday       // 安排今天
    case breakdownGoal      // 拆解目標
    case fillFreeSlots      // 排進空檔
    case planTrip           // 規劃行程
    // 生活協作
    case grocery            // 買菜
    case petCare            // 餵狗
    case cleaning           // 打掃
    case tutoring           // 家教
    case assignTasks        // 分配任務
    case findCommonTime     // 找共同時間
}

/// 修改内容：生活協作 — 工作流步驟模板項（預設清單，可編輯）
struct WorkflowPresetItem: Identifiable, Hashable {
    var id: String = UUID().uuidString
    var title: String
    var durationMin: Int
}

/// 工作流預設：標題、圖示、導向 AIPlannerView 的預設值
struct PlannerWorkflow: Identifiable, Hashable {
    let type: PlannerWorkflowType
    var id: String { type.rawValue }
    let title: String
    let subtitle: String
    let icon: String
    let colorHex: String
    /// 導向 AIPlannerView 的規劃模型（引擎已支援：multiPhase / floatingTask / availabilityCoordination）
    let modelType: PlannerModelType
    /// 預填一句話輸入（使用者可改）
    let seedInput: String
    /// 多人協作場景（PlanDetailView 顯示「發送給成員確認」）
    let isCollaborative: Bool
    /// 修改内容：Step A — 跳過一句話輸入頁，直接落結構化表單（適合「知道要做什麼、只要拆」的場景）
    var startsAtForm: Bool = false
    /// 修改内容：Step A — 導向 TravelPlannerContent 四步驟（旅遊專屬流程），不走通用表單
    var usesTravelFlow: Bool = false
    /// 修改内容：Step C — 導向今日工作台（零輸入、context-first）
    var usesTodayWorkspace: Bool = false
    /// 修改内容：生活協作 — 工作流步驟模板（買菜=清單、打掃=區域拆分、餵狗=每日重複）；非空即走 LifeWorkflowView
    var presetItems: [WorkflowPresetItem] = []
    /// 修改内容：生活協作 — 每日重複（未來 7 天每天各排一次，如餵狗）
    var repeatsDaily: Bool = false

    var usesLifeFlow: Bool { !presetItems.isEmpty }

    var color: Color {
        let hex = colorHex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        guard Scanner(string: hex).scanHexInt64(&int), hex.count == 6 else { return .blue }
        return Color(red: Double(int >> 16) / 255, green: Double(int >> 8 & 0xFF) / 255, blue: Double(int & 0xFF) / 255)
    }

    static func workflow(_ type: PlannerWorkflowType) -> PlannerWorkflow {
        switch type {
        // MARK: 快速開始（情境文案）
        case .arrangeToday:
            // 修改内容：Step C — 改導今日工作台（顯示今天行程與空檔，零輸入）
            return PlannerWorkflow(type: type, title: "安排今天", subtitle: "看今天空檔，AI 幫你填", icon: "sun.max.fill", colorHex: "#FF9500",
                                   modelType: .floatingTask, seedInput: "", isCollaborative: false, usesTodayWorkspace: true)
        case .breakdownGoal:
            // 修改内容：Step A — 直落結構化表單（目標＋截止日＋每日時數），不經一句話輸入
            return PlannerWorkflow(type: type, title: "拆解目標", subtitle: "填目標與截止日，AI 拆步驟", icon: "target", colorHex: "#FF3B30",
                                   modelType: .floatingTask, seedInput: "", isCollaborative: false, startsAtForm: true)
        case .fillFreeSlots:
            return PlannerWorkflow(type: type, title: "排進空檔", subtitle: "把待辦塞進行事曆空檔", icon: "square.stack.3d.up.fill", colorHex: "#5856D6",
                                   modelType: .floatingTask, seedInput: "把這些事排進我的空檔：", isCollaborative: false)
        case .planTrip:
            // 修改内容：Step A — 導向最完善的 TravelPlannerContent 四步驟流程
            return PlannerWorkflow(type: type, title: "規劃行程", subtitle: "旅行、出遊、一日行程", icon: "airplane", colorHex: "#007AFF",
                                   modelType: .multiPhase, seedInput: "", isCollaborative: false, usesTravelFlow: true)
        // MARK: 生活協作
        // 修改内容：生活協作 — 帶步驟模板走 LifeWorkflowView（工作流：清單→勾選→排程），不再只是預填文字
        case .grocery:
            return PlannerWorkflow(type: type, title: "買菜", subtitle: "勾清單、排進空檔", icon: "cart.fill", colorHex: "#34C759",
                                   modelType: .floatingTask, seedInput: "", isCollaborative: false,
                                   presetItems: [
                                       WorkflowPresetItem(title: "列購物清單", durationMin: 15),
                                       WorkflowPresetItem(title: "採買蔬果生鮮", durationMin: 60),
                                       WorkflowPresetItem(title: "補日用品", durationMin: 30)
                                   ])
        case .petCare:
            return PlannerWorkflow(type: type, title: "餵狗", subtitle: "每日照顧、自動重複", icon: "pawprint.fill", colorHex: "#A2845E",
                                   modelType: .floatingTask, seedInput: "", isCollaborative: false,
                                   presetItems: [
                                       WorkflowPresetItem(title: "早上餵食", durationMin: 15),
                                       WorkflowPresetItem(title: "傍晚遛狗", durationMin: 30),
                                       WorkflowPresetItem(title: "晚上餵食", durationMin: 15)
                                   ],
                                   repeatsDaily: true)
        case .cleaning:
            return PlannerWorkflow(type: type, title: "打掃", subtitle: "拆區域、分天排入", icon: "sparkles", colorHex: "#00C7BE",
                                   modelType: .floatingTask, seedInput: "", isCollaborative: false,
                                   presetItems: [
                                       WorkflowPresetItem(title: "打掃客廳", durationMin: 45),
                                       WorkflowPresetItem(title: "打掃廚房", durationMin: 45),
                                       WorkflowPresetItem(title: "打掃浴室", durationMin: 30),
                                       WorkflowPresetItem(title: "打掃臥室", durationMin: 30)
                                   ])
        case .tutoring:
            return PlannerWorkflow(type: type, title: "家教", subtitle: "對出老師學生都可的時間", icon: "book.fill", colorHex: "#AF52DE",
                                   modelType: .availabilityCoordination, seedInput: "安排家教上課時間", isCollaborative: true)
        case .assignTasks:
            return PlannerWorkflow(type: type, title: "分配任務", subtitle: "把事情分給家人或團隊", icon: "person.2.badge.gearshape.fill", colorHex: "#FF2D55",
                                   modelType: .availabilityCoordination, seedInput: "把這些任務分配給成員：", isCollaborative: true)
        case .findCommonTime:
            return PlannerWorkflow(type: type, title: "找共同時間", subtitle: "收集空檔、交集找時段", icon: "person.3.sequence.fill", colorHex: "#30B0C7",
                                   modelType: .availabilityCoordination, seedInput: "找出大家都有空的時間", isCollaborative: true)
        }
    }

    /// 修改内容：Step A/C — 快速開始只留有真差異的入口：
    /// 安排今天＝今日工作台（Step C 回歸）、拆解目標＝直落表單、規劃行程＝旅遊四步驟；
    /// 排進空檔已升級為「待安排」建議收件匣（獨立區塊）。
    static var quickStart: [PlannerWorkflow] {
        [.arrangeToday, .breakdownGoal, .planTrip].map(workflow)
    }

    static var lifeCollaboration: [PlannerWorkflow] {
        [.grocery, .petCare, .cleaning, .tutoring, .assignTasks, .findCommonTime].map(workflow)
    }
}

// MARK: - 最近使用（UserDefaults，最多 8 筆）
enum PlannerWorkflowRecents {
    private static let key = "timeos_recent_workflows"

    struct Entry: Codable, Identifiable {
        let typeRaw: String
        let usedAt: Date
        var id: String { typeRaw }
        var workflow: PlannerWorkflow? {
            PlannerWorkflowType(rawValue: typeRaw).map { PlannerWorkflow.workflow($0) }
        }
    }

    static func record(_ workflow: PlannerWorkflow) {
        var list = load().filter { $0.typeRaw != workflow.type.rawValue }
        list.insert(Entry(typeRaw: workflow.type.rawValue, usedAt: Date()), at: 0)
        if list.count > 8 { list = Array(list.prefix(8)) }
        if let data = try? JSONEncoder().encode(list) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    static func load() -> [Entry] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let list = try? JSONDecoder().decode([Entry].self, from: data) else { return [] }
        return list
    }
}
