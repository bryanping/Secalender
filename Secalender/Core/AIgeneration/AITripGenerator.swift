//
//  AITripGenerator.swift
//  Secalender
//
//  AI增强的行程生成器 - 使用OpenAI生成真实景点和好玩建议
//

import Foundation
import CoreLocation

// 注意：这些类型在 InputClassifier.swift 和 PlanGenerator.swift 中定义
// 需要确保这些文件已导入

/// AI生成的行程活动详情
struct AITripActivity: Codable {
    let title: String           // 活动名称（如：外滩、武康路、豫园）
    let location: String        // 具体地址或地点
    let description: String     // 详细描述（包含文化背景和深度理解）
    let category: String        // 类别：景点、餐厅、购物、娱乐等
    let recommendedDuration: Int  // 建议时长（分钟）
    let openingHours: String?   // 开放时间（可选）
    let tips: [String]?         // 游玩建议/小贴士
    let priceLevel: String?     // 价格级别：免费、便宜、中等、昂贵
    let timeSlot: String?       // 时间段：上午/中午/下午/晚上
    let rationale: String?      // 安排思路和逻辑（为什么这样安排）
}

/// AI生成的一天行程建议
struct AIDayItinerary: Codable {
    let date: String            // yyyy-MM-dd
    let dayTheme: String?       // 每天的主题（如"经典上海·城市记忆线"）
    let dayKeywords: String?    // 关键词（如"历史、城市符号、夜景"）
    let activities: [AITripActivity]
    let daySummary: String      // 这一天行程的总结
    let transportation: [String]?  // 交通建议
}

/// AI生成的完整行程
struct AITripPlan: Codable {
    let destination: String
    let startDate: String
    let endDate: String
    let days: [AIDayItinerary]
    let generalTips: [String]   // 总体建议
}

/// AI行程生成器
final class AITripGenerator {
    static let shared = AITripGenerator()
    private init() {}
    
    /// 使用OpenAI生成包含真实地点的行程
    func generateAIItinerary(
        destination: String,
        startDate: Date,
        endDate: Date,
        durationDays: Int,
        interestTags: [String],
        pace: Pace,
        walkingLevel: WalkingLevel?,
        transportPreference: TransportPreference?,
        selectedAttractions: [String] = [],
        currentGPSLocation: CLLocation? = nil,
        accommodationAddress: String? = nil,
        accommodationType: String? = nil
    ) async throws -> AITripPlan {
        
        // 检查 OpenAI 开关
        guard AIConfig.shared.isOpenAIEnabled else {
            print("⚠️ [AITripGenerator] OpenAI API 已禁用，无法生成AI行程")
            throw AITripGenerationError.openAIDisabled("OpenAI API 已禁用。请在 AIConfig.swift 中设置 isOpenAIEnabled = true，或通过代码启用。")
        }
        
        let calendar = Calendar.current
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        let startDateString = dateFormatter.string(from: startDate)
        let endDateString = dateFormatter.string(from: endDate)
        
        // 构建详细的提示词
        let prompt = buildPrompt(
            destination: destination,
            startDate: startDateString,
            endDate: endDateString,
            durationDays: durationDays,
            interestTags: interestTags,
            pace: pace,
            walkingLevel: walkingLevel,
            transportPreference: transportPreference,
            selectedAttractions: selectedAttractions,
            currentGPSLocation: currentGPSLocation,
            accommodationAddress: accommodationAddress,
            accommodationType: accommodationType
        )
        
        print("🤖 [AITripGenerator] 提示词构建完成，长度: \(prompt.count) 字符")
        print("🤖 [AITripGenerator] 调用 OpenAIManager.generateStructuredItinerary()...")
        
        // 调用OpenAI API（这里是关键，必须使用OpenAI）
        let aiPlanJson = try await OpenAIManager.shared.generateStructuredItinerary(prompt: prompt)
        
        print("✅ [AITripGenerator] OpenAI API 调用成功，响应长度: \(aiPlanJson.count) 字符")
        
        // 解析JSON响应
        return try parseAIResponse(aiPlanJson, destination: destination, startDate: startDateString, endDate: endDateString)
    }
    
    /// 构建详细的提示词（参考 ChatGPT 高质量行程风格）
    private func buildPrompt(
        destination: String,
        startDate: String,
        endDate: String,
        durationDays: Int,
        interestTags: [String],
        pace: Pace,
        walkingLevel: WalkingLevel?,
        transportPreference: TransportPreference?,
        selectedAttractions: [String] = [],
        currentGPSLocation: CLLocation? = nil,
        accommodationAddress: String? = nil,
        accommodationType: String? = nil
    ) -> String {
        var prompt = """
        请为\(destination)规划一套**第一次来也适用、节奏合理、不走马看花**的\(durationDays)天行程规划。
        
        【核心原则】
        - 重点放在：城市记忆 + 现代风貌 + 生活感
        - 每天要有明确的主题和关键词（如"经典城市记忆"、"租界文化"、"现代高度"）
        - 不是"景点城市"，而是"结构城市" - 要理解城市的骨架和逻辑
        - 行程设计不是塞满，而是"感受转换"，让记忆会留下来
        - 每天一个主轴，避免来回折返
        
        【用户需求】
        """
        
        if !interestTags.isEmpty {
            prompt += "\n- 兴趣偏好：\(interestTags.joined(separator: "、"))"
        }
        
        // 添加用户选中的周边特色
        if !selectedAttractions.isEmpty {
            prompt += "\n- 必须包含的景点：\(selectedAttractions.joined(separator: "、"))（这些景点必须出现在行程中，请合理安排到每天的活动中）"
        }
        
        // 根据节奏给出更具体的指导
        let paceGuidance: String
        switch pace {
        case .relaxed:
            paceGuidance = "轻松节奏：每天3-4个主要区块，留足时间深度体验，不走马看花"
        case .moderate:
            paceGuidance = "中等节奏：每天4-5个主要区块，平衡体验和效率"
        case .tight:
            paceGuidance = "紧凑节奏：每天5-6个主要区块，高效但不过度疲劳"
        }
        prompt += "\n- 节奏要求：\(paceGuidance)"
        
        if let walking = walkingLevel {
            let walkingGuidance = walking == .low ? "少走路，优先选择交通便利的区域" : 
                                 walking == .high ? "可以多走，探索小巷和步行区域" : 
                                 "正常步行强度"
            prompt += "\n- 步行强度：\(walkingGuidance)"
        }
        
        if let transport = transportPreference {
            prompt += "\n- 交通偏好：\(transport.rawValue)为主"
        }
        
        // 添加GPS位置信息
        if let gpsLocation = currentGPSLocation {
            prompt += "\n- 出发位置：GPS坐标 (\(gpsLocation.coordinate.latitude), \(gpsLocation.coordinate.longitude))"
            prompt += "\n- 请计算从出发位置到目的地的交通时间和距离，并在第一天行程开始时添加交通时间块"
        }
        
        // 添加住宿信息
        if let accommodation = accommodationAddress, !accommodation.isEmpty {
            let accType = accommodationType ?? "自定义地址"
            prompt += "\n- 住宿位置：\(accommodation)（类型：\(accType)）"
            prompt += """
            
        【住宿对旅游的影响分析】
        住宿位置对行程规划有重要影响，请考虑以下因素：
        1. **地理位置影响**：
           - 住宿位置决定了每天出发和返回的交通时间
           - 如果住宿在市中心，可以节省往返时间，增加游玩时间
           - 如果住宿在郊区或景点附近，需要合理安排交通路线
        
        2. **行程优化建议**：
           - 根据住宿位置，优先安排距离住宿较近的景点在早上或晚上
           - 将距离较远的景点安排在中间时段，避免频繁往返
           - 考虑住宿周边的餐饮和购物便利性
        
        3. **交通时间计算**：
           - 每天开始前，计算从住宿到第一个景点的交通时间
           - 每天结束时，计算从最后一个景点返回住宿的交通时间
           - 将这些交通时间纳入行程规划中
        
        4. **住宿类型影响**：
           - 酒店：通常位置便利，交通方便，但价格较高
           - 民宿/公寓：可能位置较偏，但体验更本地化
           - 请根据住宿类型给出相应的行程建议
        """
        }
        
        prompt += """
        
        【规划要求 - 向 ChatGPT 顶级行程看齐】
        
        1. **具体地点名称**（最重要！）
           - 必须提供真实存在的具体地点名称（如"外滩"、"武康路"、"豫园"、"陆家嘴"）
           - 绝对不要使用泛泛的"景点参观"、"文化体验"等模板化名称
           - 每个地点都要有详细地址
        
        2. **每天的主题和思路**
           - 每天要有明确的主题（如"经典上海·城市记忆线"、"租界文化·生活美学线"）
           - 每个时间段（上午/中午/下午/晚上）都要有"思路"说明
           - 解释"为什么这样安排"、"这个选择的逻辑是什么"
        
        3. **深度描述和文化理解**
           - 每个活动要有深度的描述，不只是表面介绍
           - 说明"为什么值得去"、"有什么特色"、"如何体验"
           - 包含文化背景、城市理解、生活美学等深度内容
           - 例如："外滩是城市名片，早上人少、建筑细节清楚"、"这是'上海最不像中国、但最上海'的区域"
        
        4. **路线逻辑**
           - 考虑地理位置，合理规划路线，减少往返
           - 一天最多3-4个主要区块，不跨城区来回折返
           - 每个区块内的活动要连贯，有逻辑
        
        5. **餐厅和美食**
           - 推荐具体餐厅或区域（如"人民广场/南京东路"、"安福路/衡山路"）
           - 说明菜型和特色（如"本帮菜：红烧肉、油爆虾、蟹粉豆腐"）
           - 避免商场，优先街边店和本地特色
        
        6. **交通建议**
           - 提供具体的交通方式和路线建议
           - 说明核心原则（如"地铁为主"、"一天最多3个主要区块"）
        
        7. **体验转换**
           - 每天要有不同的体验类型转换（历史→现代、传统→摩登、安静→热闹）
           - 避免同质化，创造记忆锚点
        
        【输出格式】
        请返回一个JSON对象，格式如下：
        {
          "destination": "\(destination)",
          "startDate": "\(startDate)",
          "endDate": "\(endDate)",
          "days": [
            {
              "date": "2024-01-17",
              "dayTheme": "经典上海·城市记忆线",
              "dayKeywords": "历史、城市符号、夜景",
              "daySummary": "这一天行程的深度总结，说明主题和思路",
              "activities": [
                {
                  "title": "具体地点名称（如：外滩、武康路、豫园）",
                  "location": "详细地址（如：上海市黄浦区中山东一路）",
                  "description": "深度描述：为什么值得去、有什么特色、如何体验、文化背景。例如：'外滩是城市名片，早上人少、建筑细节清楚，是理解上海历史的最佳起点'",
                  "category": "景点/餐厅/购物/娱乐/文化",
                  "recommendedDuration": 90,
                  "openingHours": "09:00-22:00（如果有）",
                  "tips": ["实用小贴士1", "实用小贴士2"],
                  "priceLevel": "免费/便宜/中等/昂贵",
                  "timeSlot": "上午/中午/下午/晚上",
                  "rationale": "这个安排的思路和逻辑（为什么这样安排）"
                }
              ],
              "transportation": ["具体交通建议，如：地铁2号线到人民广场站"]
            }
          ],
          "generalTips": ["总体建议，如：'上海不是景点城市，是结构城市'、'行程设计不是塞满，而是感受转换'"]
        }
        
        【关键要求】
        - 所有地点必须是真实存在的具体名称（如"外滩"、"武康路"、"豫园"），绝对不要用"景点参观"、"文化体验"等模板化名称
        - 每个活动都要有"rationale"（思路说明），解释为什么这样安排
        - 描述要有深度、有思考，包含文化背景和城市理解
        - 每天要有明确的主题（dayTheme）和关键词（dayKeywords）
        - JSON格式必须正确，可以直接解析
        """
        
        return prompt
    }
    
    /// 解析OpenAI的JSON响应
    private func parseAIResponse(_ jsonString: String, destination: String, startDate: String, endDate: String) throws -> AITripPlan {
        print("🔍 [AITripGenerator] 开始解析JSON响应，原始长度: \(jsonString.count) 字符")
        
        // 尝试提取JSON（可能包含markdown代码块）
        var cleanedJson = jsonString.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 移除markdown代码块标记
        if cleanedJson.hasPrefix("```json") {
            cleanedJson = String(cleanedJson.dropFirst(7))
            print("🔍 [AITripGenerator] 移除了 ```json 前缀")
        } else if cleanedJson.hasPrefix("```") {
            cleanedJson = String(cleanedJson.dropFirst(3))
            print("🔍 [AITripGenerator] 移除了 ``` 前缀")
        }
        if cleanedJson.hasSuffix("```") {
            cleanedJson = String(cleanedJson.dropLast(3))
            print("🔍 [AITripGenerator] 移除了 ``` 后缀")
        }
        cleanedJson = cleanedJson.trimmingCharacters(in: .whitespacesAndNewlines)
        
        print("🔍 [AITripGenerator] 清理后JSON长度: \(cleanedJson.count) 字符")
        print("🔍 [AITripGenerator] JSON预览（前300字符）: \(String(cleanedJson.prefix(300)))")
        
        guard let jsonData = cleanedJson.data(using: .utf8) else {
            print("❌ [AITripGenerator] 无法将字符串转换为UTF-8数据")
            throw AITripGenerationError.invalidJSON("无法转换为JSON数据")
        }
        
        // 首先验证JSON格式是否正确
        do {
            _ = try JSONSerialization.jsonObject(with: jsonData, options: [])
            print("✅ [AITripGenerator] JSON格式验证通过")
        } catch {
            print("❌ [AITripGenerator] JSON格式验证失败: \(error.localizedDescription)")
            print("📄 [AITripGenerator] 原始JSON内容: \(cleanedJson)")
            throw AITripGenerationError.invalidJSON("JSON格式无效: \(error.localizedDescription)")
        }
        
        do {
            let decoder = JSONDecoder()
            let plan = try decoder.decode(AITripPlan.self, from: jsonData)
            print("✅ [AITripGenerator] JSON解析成功，共 \(plan.days.count) 天行程")
            return plan
        } catch let decodingError as DecodingError {
            print("❌ [AITripGenerator] JSON解码失败: \(decodingError)")
            
            // 打印详细的解码错误信息
            switch decodingError {
            case .typeMismatch(let type, let context):
                print("❌ [AITripGenerator] 类型不匹配: 期望 \(type), 路径: \(context.codingPath)")
            case .valueNotFound(let type, let context):
                print("❌ [AITripGenerator] 值未找到: 类型 \(type), 路径: \(context.codingPath)")
            case .keyNotFound(let key, let context):
                print("❌ [AITripGenerator] 键未找到: \(key.stringValue), 路径: \(context.codingPath)")
            case .dataCorrupted(let context):
                print("❌ [AITripGenerator] 数据损坏: \(context.debugDescription), 路径: \(context.codingPath)")
            @unknown default:
                print("❌ [AITripGenerator] 未知解码错误")
            }
            
            // 尝试修复常见JSON问题
            print("🔧 [AITripGenerator] 尝试修复JSON...")
            if let fixedJson = try? fixJSON(cleanedJson),
               let fixedData = fixedJson.data(using: .utf8) {
                let decoder = JSONDecoder()
                if let plan = try? decoder.decode(AITripPlan.self, from: fixedData) {
                    print("✅ [AITripGenerator] JSON修复成功")
                    return plan
                } else {
                    print("❌ [AITripGenerator] JSON修复后仍无法解析")
                }
            }
            
            throw AITripGenerationError.invalidJSON("JSON解析失败: \(decodingError.localizedDescription)")
        } catch {
            print("❌ [AITripGenerator] 未知错误: \(error.localizedDescription)")
            throw AITripGenerationError.invalidJSON("JSON解析失败: \(error.localizedDescription)")
        }
    }
    
    /// 修复常见的JSON问题
    private func fixJSON(_ json: String) throws -> String {
        print("🔧 [AITripGenerator] 开始修复JSON...")
        
        var fixed = json
        
        // 移除尾随逗号
        fixed = fixed.replacingOccurrences(of: ",\\s*\\}", with: "}", options: .regularExpression)
        fixed = fixed.replacingOccurrences(of: ",\\s*\\]", with: "]", options: .regularExpression)
        
        // 修复单引号（JSON要求双引号）
        fixed = fixed.replacingOccurrences(of: "'", with: "\"")
        
        // 修复未转义的控制字符
        fixed = fixed.replacingOccurrences(of: "\n", with: "\\n")
        fixed = fixed.replacingOccurrences(of: "\r", with: "\\r")
        fixed = fixed.replacingOccurrences(of: "\t", with: "\\t")
        
        // 尝试提取JSON对象（如果被其他文本包围）
        if let jsonStart = fixed.range(of: "\\{"),
           let jsonEnd = fixed.range(of: "\\}", options: .backwards) {
            let startIndex = fixed.index(jsonStart.lowerBound, offsetBy: 0)
            let endIndex = fixed.index(jsonEnd.upperBound, offsetBy: 0)
            fixed = String(fixed[startIndex..<endIndex])
        }
        
        print("🔧 [AITripGenerator] JSON修复完成，新长度: \(fixed.count) 字符")
        
        return fixed
    }
    
    /// 将AI生成的行程转换为PlanResult（结合时间规划）
    func convertToPlanResult(_ aiPlan: AITripPlan, slots: ExtractedSlots) throws -> PlanResult {
        let calendar = Calendar.current
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        var dayPlans: [DayPlan] = []
        var assumptions: [String] = []
        var riskFlags: [String] = []
        
        // 为每一天生成详细的TimeBlock
        for aiDay in aiPlan.days {
            guard let date = dateFormatter.date(from: aiDay.date) else {
                continue
            }
            
            let blocks = try convertDayActivitiesToBlocks(
                aiDay: aiDay,
                date: date,
                pace: slots.pace.value ?? .moderate
            )
            
            dayPlans.append(DayPlan(date: date, blocks: blocks))
        }
        
        // 添加总体建议到风险提示
        if !aiPlan.generalTips.isEmpty {
            riskFlags.append("💡 行程建议：\(aiPlan.generalTips.joined(separator: " "))")
        }
        
        return PlanResult(days: dayPlans, assumptions: assumptions, riskFlags: riskFlags)
    }
    
    /// 将AI活动转换为TimeBlock
    private func convertDayActivitiesToBlocks(aiDay: AIDayItinerary, date: Date, pace: Pace) throws -> [TimeBlock] {
        let calendar = Calendar.current
        var blocks: [TimeBlock] = []
        
        // 确定一天的开始时间
        let defaultStartHour = 9
        let defaultStartMinute = 30
        var currentTime = calendar.date(bySettingHour: defaultStartHour, minute: defaultStartMinute, second: 0, of: date) ?? date
        
        let dayEnd = calendar.date(bySettingHour: 20, minute: 30, second: 0, of: date) ?? date
        
        // 如果是第一天，添加从出发位置到目的地的交通时间
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let isFirstDay = aiDay.date == dateFormatter.string(from: date)
        if isFirstDay {
            // 这里可以添加GPS位置到目的地的交通时间计算
            // 暂时使用默认值，后续可以通过TravelTimeCalculator计算实际时间
            let initialTransitDuration: TimeInterval = 60 * 60  // 默认1小时
            let transitEnd = currentTime.addingTimeInterval(initialTransitDuration)
            
            if transitEnd <= dayEnd {
                blocks.append(TimeBlock(
                    type: .transit,
                    startTime: currentTime,
                    endTime: transitEnd,
                    title: "前往目的地",
                    location: nil,
                    isAnchor: false,
                    priority: 6,
                    description: "从出发位置前往目的地"
                ))
                currentTime = transitEnd
            }
        }
        
        for (index, activity) in aiDay.activities.enumerated() {
            // 如果不是第一个活动，添加交通时间
            if index > 0 {
                let transitDuration: TimeInterval = 30 * 60  // 30分钟默认交通时间
                let transitEnd = currentTime.addingTimeInterval(transitDuration)
                
                if transitEnd <= dayEnd {
                    blocks.append(TimeBlock(
                        type: .transit,
                        startTime: currentTime,
                        endTime: transitEnd,
                        title: activity.category.contains("餐厅") ? "前往餐厅" : "前往下一地点",
                        location: nil,
                        isAnchor: false,
                        priority: 5,
                        description: aiDay.transportation?[safe: index - 1]
                    ))
                    currentTime = transitEnd
                }
            }
            
            // 添加缓冲时间
            let bufferDuration: TimeInterval = 10 * 60  // 10分钟缓冲
            let bufferEnd = currentTime.addingTimeInterval(bufferDuration)
            
            if bufferEnd <= dayEnd {
                blocks.append(TimeBlock(
                    type: .buffer,
                    startTime: currentTime,
                    endTime: bufferEnd,
                    title: "缓冲时间",
                    location: nil,
                    isAnchor: false,
                    priority: 4,
                    description: nil
                ))
                currentTime = bufferEnd
            }
            
            // 计算活动时长
            let activityDuration = TimeInterval(activity.recommendedDuration * 60)
            let activityEnd = currentTime.addingTimeInterval(activityDuration)
            
            // 确保不超过一天结束时间
            let finalEnd = min(activityEnd, dayEnd)
            
            if currentTime < finalEnd {
                // 构建详细描述（包含思路说明）
                var description = activity.description
                
                // 添加思路说明（如果有）- 这是关键，让用户理解为什么这样安排
                if let rationale = activity.rationale, !rationale.isEmpty {
                    description += "\n\n💭 安排思路：\(rationale)"
                }
                
                if let tips = activity.tips, !tips.isEmpty {
                    description += "\n\n💡 小贴士：\n" + tips.map { "• \($0)" }.joined(separator: "\n")
                }
                if let openingHours = activity.openingHours {
                    description += "\n\n🕐 开放时间：\(openingHours)"
                }
                if let priceLevel = activity.priceLevel {
                    description += "\n\n💰 价格：\(priceLevel)"
                }
                
                blocks.append(TimeBlock(
                    type: .activity,
                    startTime: currentTime,
                    endTime: finalEnd,
                    title: activity.title,
                    location: activity.location,
                    isAnchor: false,
                    priority: 7,
                    description: description
                ))
                
                currentTime = finalEnd
            }
            
            // 如果下一个活动会超出时间，跳出
            if activityEnd >= dayEnd {
                break
            }
        }
        
        // 确保有FLEX和REST
        let remainingTime = dayEnd.timeIntervalSince(currentTime)
        
        if remainingTime >= 30 * 60 {  // 至少30分钟
            if !blocks.contains(where: { $0.type == .flex }) {
                let flexEnd = currentTime.addingTimeInterval(min(30 * 60, remainingTime))
                blocks.append(TimeBlock(
                    type: .flex,
                    startTime: currentTime,
                    endTime: flexEnd,
                    title: "弹性时间",
                    location: nil,
                    isAnchor: false,
                    priority: 2,
                    description: "自由安排"
                ))
                currentTime = flexEnd
            }
        }
        
        // 排序
        blocks.sort { $0.startTime < $1.startTime }
        
        return blocks
    }
}

// MARK: - 辅助扩展

extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

// MARK: - 错误定义

enum AITripGenerationError: LocalizedError {
    case openAIDisabled(String)
    case invalidJSON(String)
    case missingData
    case apiError(String)
    
    var errorDescription: String? {
        switch self {
        case .openAIDisabled(let reason):
            return reason
        case .invalidJSON(let reason):
            return "JSON解析失败：\(reason)"
        case .missingData:
            return "缺少必要数据"
        case .apiError(let reason):
            return "API错误：\(reason)"
        }
    }
}
