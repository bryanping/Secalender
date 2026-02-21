//
//  AITripGenerator.swift
//  Secalender
//
//  AI增强的行程生成器 - 使用OpenAI生成真实景点和好玩建议
//

import Foundation
import CoreLocation
import SwiftUI

// 注意：这些类型在 InputClassifier.swift 和 PlanGenerator.swift 中定义
// 需要确保这些文件已导入

/// AI生成的行程活动详情
struct AITripActivity: Codable {
    let title: String           // 活动名称（如：外滩、武康路、豫园）
    let location: String?       // 具体地址或地点（可选，餐饮类型必须为null）
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
        customTags: [String] = [],
        currentGPSLocation: CLLocation? = nil,
        accommodationAddress: String? = nil,
        accommodationType: String? = nil,
        hasOtherOption: Bool = false,
        adults: Int? = nil,
        children: Int? = nil
    ) async throws -> AITripPlan {
        
        // 检查 OpenAI 开关
        guard AIConfig.shared.isOpenAIEnabled else {
            print("⚠️ [AITripGenerator] OpenAI API 已禁用，无法生成AI行程")
            throw AITripGenerationError.openAIDisabled("OpenAI API 已禁用。请在 AIConfig.swift 中设置 isOpenAIEnabled = true，或通过代码启用。")
        }
        
        // 验证和转换目的地格式
        let validatedDestination = try validateAndNormalizeDestination(destination)
        print("✅ [AITripGenerator] 目的地验证通过: \(destination) -> \(validatedDestination)")
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        let startDateString = dateFormatter.string(from: startDate)
        let endDateString = dateFormatter.string(from: endDate)
        
        // 构建详细的提示词（使用验证后的目的地）
        let prompt = buildPrompt(
            destination: validatedDestination,
            startDate: startDateString,
            endDate: endDateString,
            durationDays: durationDays,
            interestTags: interestTags,
            pace: pace,
            walkingLevel: walkingLevel,
            transportPreference: transportPreference,
            selectedAttractions: selectedAttractions,
            customTags: customTags,
            currentGPSLocation: currentGPSLocation,
            accommodationAddress: accommodationAddress,
            accommodationType: accommodationType,
            hasOtherOption: hasOtherOption,
            adults: adults,
            children: children
        )
        
        print("🤖 [AITripGenerator] 提示词构建完成，长度: \(prompt.count) 字符")
        print("🤖 [AITripGenerator] 调用 OpenAIManager.generateStructuredItinerary()...")
        
        // 调用OpenAI API（这里是关键，必须使用OpenAI）
        let aiPlanJson = try await OpenAIManager.shared.generateStructuredItinerary(prompt: prompt)
        
        print("✅ [AITripGenerator] OpenAI API 调用成功，响应长度: \(aiPlanJson.count) 字符")
        
        // 解析JSON响应（使用原始目的地，保持数据一致性）
        return try parseAIResponse(aiPlanJson, destination: destination, startDate: startDateString, endDate: endDateString)
    }
    
    /// 验证和规范化目的地格式
    /// - Parameter destination: 原始目的地字符串（可能是 "国家 - 城市" 格式）
    /// - Returns: 规范化后的目的地字符串（例如 "東京, 日本" 或 "東京"）
    /// - Throws: 如果目的地不在支持列表中，抛出错误
    private func validateAndNormalizeDestination(_ destination: String) throws -> String {
        let dataManager = DestinationDataManager.shared
        
        // 解析 "国家 - 城市" 格式
        var country: String? = nil
        var city: String? = nil
        
        if destination.contains(" - ") {
            let components = destination.components(separatedBy: " - ")
            if components.count >= 2 {
                country = components[0].trimmingCharacters(in: .whitespaces)
                city = components[1].trimmingCharacters(in: .whitespaces)
            }
        } else {
            // 如果不是 "国家 - 城市" 格式，尝试查找城市对应的国家
            if let foundCountry = dataManager.getCountry(for: destination) {
                country = foundCountry
                city = destination
            } else {
                // 如果找不到，直接使用原字符串（可能是城市名）
                city = destination
            }
        }
        
        // 验证国家是否在支持列表中
        if let countryName = country {
            let allCountries = dataManager.getAllCountries()
            // 使用模糊匹配（支持简繁体）
            let matchedCountries = dataManager.searchCountries(countryName)
            if matchedCountries.isEmpty {
                print("⚠️ [AITripGenerator] 国家不在支持列表中: \(countryName)")
                // 不抛出错误，继续处理（可能是新国家或格式问题）
            } else {
                // 使用第一个匹配的国家（最准确的）
                country = matchedCountries.first
            }
        }
        
        // 验证城市是否在支持列表中（如果提供了国家）
        if let countryName = country, let cityName = city, !cityName.isEmpty {
            // 使用模糊匹配
            let matchedCities = dataManager.searchCities(in: countryName, searchTerm: cityName)
            if matchedCities.isEmpty {
                print("⚠️ [AITripGenerator] 城市不在支持列表中: \(cityName) (国家: \(countryName))")
                // 不抛出错误，继续处理（可能是新城市或格式问题）
            } else {
                // 使用第一个匹配的城市（最准确的）
                city = matchedCities.first
            }
        }
        
        // 构建规范化后的目的地字符串
        // 优先使用 "城市, 国家" 格式（更符合 OpenAI 的理解）
        if let cityName = city, let countryName = country {
            return "\(cityName), \(countryName)"
        } else if let cityName = city {
            return cityName
        } else if let countryName = country {
            return countryName
        } else {
            // 如果都为空，返回原始字符串
            return destination
        }
    }
    
    /// 获取当前应用语言
    private var currentLanguage: AppLanguage {
        // 直接使用备用方法，避免 MainActor 隔离问题
        // 如果需要获取用户设置的语言，可以通过其他方式
        return detectSystemLanguageFallback()
    }
    
    /// 检测系统语言（备用方法，不依赖 LocalizationManager）
    private func detectSystemLanguageFallback() -> AppLanguage {
        let preferredLanguage = Locale.preferredLanguages.first ?? "en"
        
        if preferredLanguage.hasPrefix("zh-Hans") || preferredLanguage.hasPrefix("zh-CN") {
            return .simplifiedChinese
        } else if preferredLanguage.hasPrefix("zh-Hant") || preferredLanguage.hasPrefix("zh-TW") || preferredLanguage.hasPrefix("zh-HK") {
            return .traditionalChinese
        } else if preferredLanguage.hasPrefix("de") {
            return .german
        } else if preferredLanguage.hasPrefix("fr") {
            return .french
        } else if preferredLanguage.hasPrefix("es") {
            return .spanish
        } else if preferredLanguage.hasPrefix("ja") {
            return .japanese
        } else {
            return .english
        }
    }
    
    /// 检测系统语言（用于 .system case）
    private func detectSystemLanguage() -> AppLanguage {
        return detectSystemLanguageFallback()
    }
    
    /// 国家到主要语言的映射
    /// 用于确定目的地国家的主要语言，确保地点名称使用正确的本地语言
    private let countryToLanguage: [String: String] = [
        // 葡萄牙语国家
        "巴西": "Portuguese",
        "葡萄牙": "Portuguese",
        "安哥拉": "Portuguese",
        "莫桑比克": "Portuguese",
        
        // 西班牙语国家
        "西班牙": "Spanish",
        "墨西哥": "Spanish",
        "阿根廷": "Spanish",
        "智利": "Spanish",
        "秘魯": "Spanish",
        "哥倫比亞": "Spanish",
        "哥斯達黎加": "Spanish",
        "巴拿馬": "Spanish",
        "委內瑞拉": "Spanish",
        "厄瓜多爾": "Spanish",
        "玻利維亞": "Spanish",
        "巴拉圭": "Spanish",
        "烏拉圭": "Spanish",
        "危地馬拉": "Spanish",
        "洪都拉斯": "Spanish",
        "薩爾瓦多": "Spanish",
        "尼加拉瓜": "Spanish",
        "多米尼加": "Spanish",
        "古巴": "Spanish",
        "波多黎各": "Spanish",
        
        // 法语国家
        "法國": "French",
        "突尼斯": "French",
        "阿爾及利亞": "French",
        "塞內加爾": "French",
        "馬里": "French",
        "布基納法索": "French",
        "尼日爾": "French",
        "乍得": "French",
        "馬達加斯加": "French",
        "毛里求斯": "French",
        "留尼汪": "French",
        
        // 德语国家
        "德國": "German",
        "奧地利": "German",
        "瑞士": "German", // 多语言国家，德语为主要语言之一
        "列支敦士登": "German",
        
        // 意大利语国家
        "義大利": "Italian",
        "聖馬力諾": "Italian",
        "梵蒂岡": "Italian",
        
        // 俄语国家
        "俄羅斯": "Russian",
        "白俄羅斯": "Russian",
        "哈薩克斯坦": "Russian",
        "吉爾吉斯斯坦": "Russian",
        "塔吉克斯坦": "Russian",
        "土庫曼斯坦": "Russian",
        "烏茲別克斯坦": "Russian",
        "烏克蘭": "Ukrainian", // 乌克兰语
        
        // 阿拉伯语国家
        "沙特阿拉伯": "Arabic",
        "阿聯酋": "Arabic",
        "卡達": "Arabic",
        "科威特": "Arabic",
        "巴林": "Arabic",
        "阿曼": "Arabic",
        "約旦": "Arabic",
        "黎巴嫩": "Arabic",
        "埃及": "Arabic",
        "摩洛哥": "Arabic", // 多语言国家，阿拉伯语为主要语言之一
        
        // 日语国家
        "日本": "Japanese",
        
        // 韩语国家
        "韓國": "Korean",
        
        // 泰语国家
        "泰國": "Thai",
        
        // 越南语国家
        "越南": "Vietnamese",
        
        // 印尼语国家
        "印尼": "Indonesian",
        
        // 印地语国家
        "印度": "Hindi", // 主要语言之一
        
        // 希腊语国家
        "希臘": "Greek",
        
        // 荷兰语国家
        "荷蘭": "Dutch",
        "比利時": "Dutch", // 多语言国家，荷兰语为主要语言之一
        
        // 土耳其语国家
        "土耳其": "Turkish",
        
        // 波兰语国家
        "波蘭": "Polish",
        
        // 捷克语国家
        "捷克": "Czech",
        
        // 匈牙利语国家
        "匈牙利": "Hungarian",
        
        // 罗马尼亚语国家
        "羅馬尼亞": "Romanian",
        
        // 保加利亚语国家
        "保加利亞": "Bulgarian",
        
        // 克罗地亚语国家
        "克羅地亞": "Croatian",
        
        // 塞尔维亚语国家
        "塞爾維亞": "Serbian",
        
        // 斯洛文尼亚语国家
        "斯洛文尼亞": "Slovenian",
        
        // 斯洛伐克语国家
        "斯洛伐克": "Slovak",
        
        // 爱沙尼亚语国家
        "愛沙尼亞": "Estonian",
        
        // 拉脱维亚语国家
        "拉脫維亞": "Latvian",
        
        // 立陶宛语国家
        "立陶宛": "Lithuanian",
        
        // 芬兰语国家
        "芬蘭": "Finnish",
        
        // 瑞典语国家
        "瑞典": "Swedish",
        
        // 挪威语国家
        "挪威": "Norwegian",
        
        // 丹麦语国家
        "丹麥": "Danish",
        
        // 冰岛语国家
        "冰島": "Icelandic",
        
        // 爱尔兰语国家（但主要使用英语）
        "愛爾蘭": "English",
        
        // 英语国家（默认）
        "美國": "English",
        "英國": "English",
        "加拿大": "English", // 部分英语区
        "澳大利亞": "English",
        "紐西蘭": "English",
        "新加坡": "English", // 主要语言之一
        "南非": "English", // 主要语言之一
        "菲律賓": "English", // 主要语言之一
        
        // 中文国家/地区
        "中國": "Chinese",
        "台灣": "Chinese",
        "香港": "Chinese",
        "澳門": "Chinese"
    ]
    
    /// 获取目的地国家的主要语言
    /// - Parameter country: 国家名称（中文）
    /// - Returns: 主要语言名称（如 "Portuguese", "Spanish" 等），如果未找到则返回 nil
    private func getDestinationLanguage(for country: String?) -> String? {
        guard let country = country else { return nil }
        return countryToLanguage[country]
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
        customTags: [String] = [],
        currentGPSLocation: CLLocation? = nil,
        accommodationAddress: String? = nil,
        accommodationType: String? = nil,
        hasOtherOption: Bool = false,
        adults: Int? = nil,
        children: Int? = nil
    ) -> String {
        // 检测目的地国家
        let dataManager = DestinationDataManager.shared
        var destinationCountry: String? = nil
        
        // 解析目的地以获取国家
        if destination.contains(" - ") {
            let components = destination.components(separatedBy: " - ")
            if components.count >= 2 {
                destinationCountry = components[0].trimmingCharacters(in: .whitespaces)
            }
        } else if let country = dataManager.getCountry(for: destination) {
            destinationCountry = country
        }
        
        // 获取目的地国家的主要语言
        let destinationLanguage = getDestinationLanguage(for: destinationCountry)
        
        // 根据当前语言环境生成 prompt
        let language = currentLanguage
        var prompt = buildLocalizedPrompt(
            language: language,
            destination: destination,
            startDate: startDate,
            endDate: endDate,
            durationDays: durationDays,
            interestTags: interestTags,
            pace: pace,
            walkingLevel: walkingLevel,
            transportPreference: transportPreference,
            selectedAttractions: selectedAttractions,
            customTags: customTags,
            currentGPSLocation: currentGPSLocation,
            accommodationAddress: accommodationAddress,
            accommodationType: accommodationType,
            destinationLanguage: destinationLanguage,
            hasOtherOption: hasOtherOption,
            adults: adults,
            children: children
        )
        
        return prompt
    }
    
    /// 根据语言环境构建本地化的 prompt
    private func buildLocalizedPrompt(
        language: AppLanguage,
        destination: String,
        startDate: String,
        endDate: String,
        durationDays: Int,
        interestTags: [String],
        pace: Pace,
        walkingLevel: WalkingLevel?,
        transportPreference: TransportPreference?,
        selectedAttractions: [String],
        customTags: [String],
        currentGPSLocation: CLLocation?,
        accommodationAddress: String?,
        accommodationType: String?,
        destinationLanguage: String? = nil,
        hasOtherOption: Bool = false,
        adults: Int? = nil,
        children: Int? = nil
    ) -> String {
        switch language {
        case .simplifiedChinese, .traditionalChinese:
            return buildChinesePrompt(
                destination: destination,
                startDate: startDate,
                endDate: endDate,
                durationDays: durationDays,
                interestTags: interestTags,
                pace: pace,
                walkingLevel: walkingLevel,
                transportPreference: transportPreference,
                selectedAttractions: selectedAttractions,
                customTags: customTags,
                currentGPSLocation: currentGPSLocation,
                accommodationAddress: accommodationAddress,
                accommodationType: accommodationType,
                destinationLanguage: destinationLanguage,
                hasOtherOption: hasOtherOption,
                adults: adults,
                children: children
            )
        case .english:
            return buildEnglishPrompt(
                destination: destination,
                startDate: startDate,
                endDate: endDate,
                durationDays: durationDays,
                interestTags: interestTags,
                pace: pace,
                walkingLevel: walkingLevel,
                transportPreference: transportPreference,
                selectedAttractions: selectedAttractions,
                customTags: customTags,
                currentGPSLocation: currentGPSLocation,
                accommodationAddress: accommodationAddress,
                accommodationType: accommodationType,
                destinationLanguage: destinationLanguage,
                hasOtherOption: hasOtherOption
            )
        case .german:
            return buildGermanPrompt(
                destination: destination,
                startDate: startDate,
                endDate: endDate,
                durationDays: durationDays,
                interestTags: interestTags,
                pace: pace,
                walkingLevel: walkingLevel,
                transportPreference: transportPreference,
                selectedAttractions: selectedAttractions,
                customTags: customTags,
                currentGPSLocation: currentGPSLocation,
                accommodationAddress: accommodationAddress,
                accommodationType: accommodationType,
                destinationLanguage: destinationLanguage,
                hasOtherOption: hasOtherOption
            )
        case .french:
            return buildFrenchPrompt(
                destination: destination,
                startDate: startDate,
                endDate: endDate,
                durationDays: durationDays,
                interestTags: interestTags,
                pace: pace,
                walkingLevel: walkingLevel,
                transportPreference: transportPreference,
                selectedAttractions: selectedAttractions,
                customTags: customTags,
                currentGPSLocation: currentGPSLocation,
                accommodationAddress: accommodationAddress,
                accommodationType: accommodationType,
                destinationLanguage: destinationLanguage,
                hasOtherOption: hasOtherOption
            )
        case .spanish:
            return buildSpanishPrompt(
                destination: destination,
                startDate: startDate,
                endDate: endDate,
                durationDays: durationDays,
                interestTags: interestTags,
                pace: pace,
                walkingLevel: walkingLevel,
                transportPreference: transportPreference,
                selectedAttractions: selectedAttractions,
                customTags: customTags,
                currentGPSLocation: currentGPSLocation,
                accommodationAddress: accommodationAddress,
                accommodationType: accommodationType,
                destinationLanguage: destinationLanguage,
                hasOtherOption: hasOtherOption
            )
        case .japanese:
            return buildJapanesePrompt(
                destination: destination,
                startDate: startDate,
                endDate: endDate,
                durationDays: durationDays,
                interestTags: interestTags,
                pace: pace,
                walkingLevel: walkingLevel,
                transportPreference: transportPreference,
                selectedAttractions: selectedAttractions,
                customTags: customTags,
                currentGPSLocation: currentGPSLocation,
                accommodationAddress: accommodationAddress,
                accommodationType: accommodationType,
                destinationLanguage: destinationLanguage,
                hasOtherOption: hasOtherOption
            )
        case .system:
            // 系统语言：根据系统设置选择语言，默认使用英语
            // 检测系统语言并递归调用
            let systemLang = detectSystemLanguage()
            return buildLocalizedPrompt(
                language: systemLang,
                destination: destination,
                startDate: startDate,
                endDate: endDate,
                durationDays: durationDays,
                interestTags: interestTags,
                pace: pace,
                walkingLevel: walkingLevel,
                transportPreference: transportPreference,
                selectedAttractions: selectedAttractions,
                customTags: customTags,
                currentGPSLocation: currentGPSLocation,
                accommodationAddress: accommodationAddress,
                accommodationType: accommodationType,
                destinationLanguage: destinationLanguage,
                hasOtherOption: hasOtherOption
            )
        }
    }
    
    /// 构建中文 prompt（简体/繁体）
    private func buildChinesePrompt(
        destination: String,
        startDate: String,
        endDate: String,
        durationDays: Int,
        interestTags: [String],
        pace: Pace,
        walkingLevel: WalkingLevel?,
        transportPreference: TransportPreference?,
        selectedAttractions: [String],
        customTags: [String],
        currentGPSLocation: CLLocation?,
        accommodationAddress: String?,
        accommodationType: String?,
        destinationLanguage: String? = nil,
        hasOtherOption: Bool = false,
        adults: Int? = nil,
        children: Int? = nil
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
        
        // 如果选择了"其他"选项，这是最重要的行程目标和搜索依据
        if hasOtherOption {
            prompt += """
            
        【⚠️ 最重要的行程目标 - 优先处理】
        用户选择了"其他"选项，这意味着：
        - **这是本次行程最重要的搜索依据和行程目标**
        - 请广泛搜索\(destination)周边所有可能的历史、艺术、文化相关地点
        - 不要局限于常见的推荐景点，要深入挖掘隐藏的历史艺术特色
        - 优先考虑那些能够体现当地深度文化、历史底蕴、艺术氛围的地点
        - 包括但不限于：历史街区、艺术工作室、文化中心、传统工艺坊、历史建筑、艺术画廊、文化遗址、博物馆、文化空间等
        - 行程规划应围绕这些深度文化体验展开，让用户能够真正感受到目的地的文化内涵
        
        """
        }
        
        if !interestTags.isEmpty {
            prompt += "\n- 兴趣偏好：\(interestTags.joined(separator: "、"))"
        }
        
        // 添加用户选中的周边特色
        if !selectedAttractions.isEmpty {
            prompt += "\n- 必须包含的景点：\(selectedAttractions.joined(separator: "、"))（这些景点必须出现在行程中，请合理安排到每天的活动中）"
        }
        
        // 添加用户自訂標籤（可能為模糊描述，請 AI 理解為該類型的真實景點）
        if !customTags.isEmpty {
            prompt += "\n- 用户自定义兴趣/类型标签：\(customTags.joined(separator: "、"))。这些可能为模糊描述（如「文青咖啡」「网红店」），请理解为目的地周边符合该描述的真实知名景点，安排具体行程时选择该类型的优质地点，避免因标签命名不明确导致行程偏差。"
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
        
        // 添加人数信息（用于计算餐饮时间）
        let totalPeople = (adults ?? 1) + (children ?? 0)
        if let adultsCount = adults, let childrenCount = children {
            prompt += "\n- 同行人数：\(adultsCount)位大人，\(childrenCount)位小孩（共\(totalPeople)人）"
        } else if let adultsCount = adults {
            prompt += "\n- 同行人数：\(adultsCount)位大人"
        }
        if totalPeople > 1 {
            prompt += "\n- **重要：餐饮时间计算**："
            prompt += "\n  * 人数越多，用餐时间越长（点餐、等待、用餐、结账都需要更多时间）"
            prompt += "\n  * 有小孩的家庭需要额外时间（小孩可能吃得慢、需要照顾、可能吵闹）"
            prompt += "\n  * 根据人数和节奏调整餐饮时间："
            let baseMealTime = 60  // 基础60分钟
            let additionalTimePerPerson = 10  // 每人额外10分钟
            let childrenMultiplier = 1.5  // 小孩按1.5倍计算
            let calculatedTime = baseMealTime + (adults ?? 1) * additionalTimePerPerson + Int(Double(children ?? 0) * Double(additionalTimePerPerson) * childrenMultiplier)
            let paceMultiplier: Double = pace == .relaxed ? 1.2 : (pace == .tight ? 0.9 : 1.0)
            let finalMealTime = Int(Double(calculatedTime) * paceMultiplier)
            prompt += "\n    - 基础时间：\(baseMealTime)分钟"
            prompt += "\n    - 人数调整：+\(additionalTimePerPerson)分钟/人（小孩按1.5倍计算）"
            prompt += "\n    - 节奏调整：\(pace == .relaxed ? "宽松" : pace == .tight ? "紧凑" : "中等")节奏 × \(String(format: "%.1f", paceMultiplier))"
            prompt += "\n    - **建议餐饮时间：\(finalMealTime)分钟**（请确保在行程中预留充足时间）"
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
            
        【住宿对旅游的影响分析 - 重要！】
        住宿位置对行程规划有重要影响，请务必考虑以下因素：
        
        1. **第一天 Check-in 安排**：
           - 第一天到达后，需要先前往住宿地点办理 Check-in（通常下午2-3点后可以入住）
           - 从出发位置到住宿的交通时间必须计算在内
           - Check-in 通常需要30-60分钟（办理手续、放置行李、稍作休息）
           - 第一天下午的活动应该安排在 Check-in 之后，且优先选择距离住宿较近的景点
           - 考虑行李因素：如果携带大件行李，第一天不适合安排需要大量步行的活动
        
        2. **每天从住宿出发的交通**：
           - 每天开始前，必须计算从住宿到第一个景点的交通时间
           - 根据住宿位置，优先安排距离住宿较近的景点在早上或晚上
           - 将距离较远的景点安排在中间时段，避免频繁往返住宿
           - 考虑住宿周边的餐饮和购物便利性
        
        3. **每天返回住宿的交通**：
           - 每天结束时，必须计算从最后一个景点返回住宿的交通时间
           - 将这些交通时间纳入行程规划中
           - 晚上活动应该考虑返回住宿的便利性
        
        4. **最后一天 Check-out 安排**：
           - 最后一天通常需要在早上 Check-out（通常是上午10-11点前）
           - Check-out 后需要处理行李：可以寄存在酒店、使用行李寄存服务，或携带行李
           - 最后一天的活动安排必须考虑：
             * 如果行李寄存在住宿，最后需要返回取行李
             * 如果携带行李，不适合安排需要大量步行或不便携带行李的活动（如爬山、远距离徒步）
             * 建议安排轻松的活动，如购物、轻食、参观室内景点
           - 如果最后一天需要前往机场/车站，必须预留足够时间（通常提前2-3小时）
        
        5. **行李因素考虑**：
           - 第一天：携带行李，不适合安排需要大量步行的活动，优先选择交通便利、可以寄存行李的景点
           - 中间天数：行李在住宿，可以安排任何类型的活动
           - 最后一天：根据行李处理方式安排活动
             * 行李寄存：可以安排正常活动，但需要预留返回取行李的时间
             * 携带行李：只能安排轻松、室内、交通便利的活动
        
        6. **住宿类型影响**：
           - 酒店：通常位置便利，交通方便，但价格较高，通常有行李寄存服务
           - 民宿/公寓：可能位置较偏，但体验更本地化，行李寄存可能有限
           - 请根据住宿类型给出相应的行程建议
        
        7. **关键时间节点**：
           - 第一天：出发位置 → 住宿（Check-in）→ 下午/晚上活动
           - 中间天数：住宿 → 景点 → 住宿
           - 最后一天：住宿（Check-out）→ 活动（考虑行李）→ 出发位置/机场/车站
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
        
        5. **餐厅和美食**（重要！）
           - **不推荐具体餐厅或地点**：为了节省AI使用，餐饮地点不做AI规划，只预留时间即可
           - 餐饮活动只需要：
             * title: 使用通用标题（如"午餐"、"晚餐"、"早餐"、"下午茶"等）
             * location: **必须为空或null**（不设置具体地点）
             * category: 必须包含"餐厅"或"Restaurant"
             * description: 可以简单说明用餐建议（如"建议在当地特色餐厅用餐"）
           - **餐饮时间必须充足**：
             * 必须考虑人数因素：人数越多，用餐时间越长
             * 有小孩的家庭需要额外时间（小孩可能吃得慢、需要照顾）
             * 根据人数和节奏调整 recommendedDuration：
               - 1-2人：60-75分钟
               - 3-4人：75-90分钟
               - 5-6人：90-120分钟
               - 7人以上：120-150分钟
             * 有小孩的家庭：在上述基础上增加15-30分钟
             * 宽松节奏：可以适当延长10-20分钟
             * 紧凑节奏：可以适当缩短10-15分钟，但不要少于基础时间
           - **重要**：餐饮活动的 location 字段在JSON中必须写 null（不是空字符串""，不是省略字段，必须明确写 null），用户会通过点击卡片跳转到地图应用查找附近餐厅
           - **JSON格式示例（餐饮类型）**：
             {
               "title": "午餐",
               "location": null,
               "description": "建议在当地特色餐厅用餐",
               "category": "餐厅",
               "recommendedDuration": 90
             }
        
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
                  "title": "具体地点名称（如：外滩、武康路、豫园）或餐饮类型（如：午餐、晚餐、早餐）",
                  "location": "详细地址（如：上海市黄浦区中山东一路）。**重要**：如果是餐饮类型（category包含'餐厅'或'Restaurant'），location必须为null（不是空字符串，必须明确写null）",
                  "description": "深度描述：为什么值得去、有什么特色、如何体验、文化背景。例如：'外滩是城市名片，早上人少、建筑细节清楚，是理解上海历史的最佳起点'。餐饮类型可以简单说明用餐建议",
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
        - **餐饮类型location字段要求**：如果category包含"餐厅"或"Restaurant"，location字段必须明确写null（不能省略，不能为空字符串""，必须写null）。例如：{"title": "午餐", "location": null, "category": "餐厅", ...}
        """
        
        // 如果目的地有特定的本地语言，明确要求使用该语言的地点名称
        if let destLang = destinationLanguage, destLang != "Chinese" {
            prompt += """
            
        【重要：地点名称语言要求】
        - 目的地的主要语言是\(destLang)
        - **所有地点名称（title 和 location 字段）必须使用\(destLang)的本地名称**
        - 例如：如果目的地是巴西（葡萄牙语），地点名称应使用葡萄牙语，如"Copacabana"、"Ipanema"、"Cristo Redentor"等
        - 描述（description）和其他文本内容可以使用中文，但地点名称必须使用\(destLang)
        - 这确保了地点名称的准确性和可搜索性，避免因翻译导致的搜索失败
        """
        }
        
        return prompt
    }
    
    /// 构建英文 prompt
    private func buildEnglishPrompt(
        destination: String,
        startDate: String,
        endDate: String,
        durationDays: Int,
        interestTags: [String],
        pace: Pace,
        walkingLevel: WalkingLevel?,
        transportPreference: TransportPreference?,
        selectedAttractions: [String],
        customTags: [String],
        currentGPSLocation: CLLocation?,
        accommodationAddress: String?,
        accommodationType: String?,
        destinationLanguage: String? = nil,
        hasOtherOption: Bool = false
    ) -> String {
        var prompt = """
        Please create a **well-paced, first-time visitor friendly, and non-rushed** \(durationDays)-day itinerary for \(destination).
        
        【Core Principles】
        - Focus on: city memories + modern vibes + local life
        - Each day should have a clear theme and keywords (e.g., "Classic City Memories", "Colonial Culture", "Modern Heights")
        - Not a "sightseeing city", but a "structural city" - understand the city's skeleton and logic
        - Itinerary design is not about filling up, but about "feeling transitions" that create lasting memories
        - One main theme per day, avoid back-and-forth travel
        
        【User Requirements】
        """
        
        // 如果选择了"其他"选项，这是最重要的行程目标和搜索依据
        if hasOtherOption {
            prompt += """
            
        【⚠️ MOST IMPORTANT ITINERARY OBJECTIVE - PRIORITY】
        The user has selected the "Other" option, which means:
        - **This is the MOST IMPORTANT search criterion and itinerary objective for this trip**
        - Please extensively search for ALL possible historical, artistic, and cultural-related locations around \(destination)
        - Do not limit yourself to common recommended attractions; dig deep into hidden historical and artistic features
        - Prioritize locations that reflect the local deep culture, historical heritage, and artistic atmosphere
        - Include but not limited to: historical districts, art studios, cultural centers, traditional craft workshops, historical buildings, art galleries, cultural sites, museums, cultural spaces, etc.
        - The itinerary should revolve around these deep cultural experiences, allowing users to truly feel the cultural essence of the destination
        
        """
        }
        
        if !interestTags.isEmpty {
            prompt += "\n- Interests: \(interestTags.joined(separator: ", "))"
        }
        
        if !selectedAttractions.isEmpty {
            prompt += "\n- Must include attractions: \(selectedAttractions.joined(separator: ", ")) (These attractions must appear in the itinerary, please arrange them reasonably in daily activities)"
        }
        
        if !customTags.isEmpty {
            prompt += "\n- User custom interest/type tags: \(customTags.joined(separator: ", ")). These may be vague descriptions (e.g. \"hipster cafes\", \"Instagram spots\"). Please interpret as real, well-known attractions that match the description near the destination. When arranging the itinerary, select quality places of that type to avoid incorrect itineraries due to ambiguous tag names."
        }
        
        let paceGuidance: String
        switch pace {
        case .relaxed:
            paceGuidance = "Relaxed pace: 3-4 main blocks per day, plenty of time for deep experiences, not rushed"
        case .moderate:
            paceGuidance = "Moderate pace: 4-5 main blocks per day, balanced experience and efficiency"
        case .tight:
            paceGuidance = "Tight pace: 5-6 main blocks per day, efficient but not overly tiring"
        }
        prompt += "\n- Pace requirement: \(paceGuidance)"
        
        if let walking = walkingLevel {
            let walkingGuidance = walking == .low ? "Minimal walking, prioritize easily accessible areas" :
                                 walking == .high ? "More walking, explore alleys and pedestrian areas" :
                                 "Normal walking intensity"
            prompt += "\n- Walking intensity: \(walkingGuidance)"
        }
        
        if let transport = transportPreference {
            prompt += "\n- Transportation preference: \(transport.rawValue) preferred"
        }
        
        if let gpsLocation = currentGPSLocation {
            prompt += "\n- Departure location: GPS coordinates (\(gpsLocation.coordinate.latitude), \(gpsLocation.coordinate.longitude))"
            prompt += "\n- Please calculate travel time and distance from departure location to destination, and add a transit time block at the start of the first day"
        }
        
        if let accommodation = accommodationAddress, !accommodation.isEmpty {
            let accType = accommodationType ?? "Custom address"
            prompt += "\n- Accommodation location: \(accommodation) (Type: \(accType))"
            prompt += """
            
        【Accommodation Impact Analysis - CRITICAL!】
        Accommodation location significantly affects itinerary planning. You MUST consider the following:
        
        1. **First Day Check-in Arrangement**:
           - On the first day, after arrival, need to go to accommodation for Check-in (usually available after 2-3 PM)
           - Travel time from departure location to accommodation must be calculated
           - Check-in usually takes 30-60 minutes (check-in procedures, storing luggage, brief rest)
           - Afternoon activities on the first day should be arranged after Check-in, prioritizing attractions near accommodation
           - Consider luggage factor: If carrying large luggage, first day is not suitable for activities requiring extensive walking
        
        2. **Daily Departure from Accommodation**:
           - Before each day starts, must calculate travel time from accommodation to first attraction
           - Based on accommodation location, prioritize attractions closer to accommodation in morning or evening
           - Arrange distant attractions in middle periods, avoid frequent back-and-forth to accommodation
           - Consider dining and shopping convenience around accommodation
        
        3. **Daily Return to Accommodation**:
           - At end of each day, must calculate travel time from last attraction back to accommodation
           - Include these travel times in itinerary planning
           - Evening activities should consider convenience of returning to accommodation
        
        4. **Last Day Check-out Arrangement**:
           - Last day usually requires Check-out in the morning (usually before 10-11 AM)
           - After Check-out, need to handle luggage: can store at hotel, use luggage storage service, or carry luggage
           - Last day activities must consider:
             * If luggage stored at accommodation, need to return to pick up luggage
             * If carrying luggage, not suitable for activities requiring extensive walking or inconvenient with luggage (e.g., hiking, long-distance walking)
             * Suggest light activities such as shopping, light meals, visiting indoor attractions
           - If last day needs to go to airport/station, must reserve sufficient time (usually 2-3 hours in advance)
        
        5. **Luggage Factor Consideration**:
           - First day: Carrying luggage, not suitable for activities requiring extensive walking, prioritize attractions with convenient transportation and luggage storage
           - Middle days: Luggage at accommodation, can arrange any type of activities
           - Last day: Arrange activities based on luggage handling method
             * Luggage storage: Can arrange normal activities, but need to reserve time to return and pick up luggage
             * Carrying luggage: Can only arrange light, indoor, easily accessible activities
        
        6. **Accommodation Type Impact**:
           - Hotels: Usually convenient location, easy transportation, but higher price, usually have luggage storage service
           - B&Bs/Apartments: May be more remote, but more local experience, luggage storage may be limited
           - Please provide corresponding itinerary suggestions based on accommodation type
        
        7. **Key Time Points**:
           - First day: Departure location → Accommodation (Check-in) → Afternoon/evening activities
           - Middle days: Accommodation → Attractions → Accommodation
           - Last day: Accommodation (Check-out) → Activities (consider luggage) → Departure location/airport/station
        """
        }
        
        prompt += """
        
        【Planning Requirements - Match ChatGPT Top Itineraries】
        
        1. **Specific Location Names** (Most Important!)
           - Must provide real, specific location names (e.g., "The Bund", "Wukang Road", "Yu Garden", "Lujiazui")
           - Never use generic names like "sightseeing visit", "cultural experience" etc.
           - Each location must have detailed address
        
        2. **Daily Themes and Rationale**
           - Each day should have a clear theme (e.g., "Classic Shanghai · City Memory Line", "Colonial Culture · Life Aesthetics Line")
           - Each time slot (morning/noon/afternoon/evening) should have "rationale" explanation
           - Explain "why this arrangement", "what's the logic of this choice"
        
        3. **Deep Descriptions and Cultural Understanding**
           - Each activity should have deep description, not just surface introduction
           - Explain "why it's worth visiting", "what's special", "how to experience"
           - Include cultural background, city understanding, life aesthetics and other deep content
           - Example: "The Bund is the city's calling card, fewer people in the morning, clear architectural details"
        
        4. **Route Logic**
           - Consider geographic location, plan routes reasonably, reduce back-and-forth
           - Maximum 3-4 main blocks per day, don't cross districts back and forth
           - Activities within each block should be coherent and logical
        
        5. **Restaurants and Food**
           - Recommend specific restaurants or areas (e.g., "People's Square/Nanjing East Road", "Anfu Road/Hengshan Road")
           - Explain cuisine types and specialties (e.g., "Shanghai cuisine: braised pork, oil-blasted shrimp, crab roe tofu")
           - Avoid shopping malls, prioritize street shops and local specialties
        
        6. **Transportation Suggestions**
           - Provide specific transportation methods and route suggestions
           - Explain core principles (e.g., "subway main", "maximum 3 main blocks per day")
        
        7. **Experience Transitions**
           - Each day should have different experience type transitions (history→modern, traditional→trendy, quiet→lively)
           - Avoid homogeneity, create memory anchors
        
        【Output Format】
        Please return a JSON object in the following format:
        {
          "destination": "\(destination)",
          "startDate": "\(startDate)",
          "endDate": "\(endDate)",
          "days": [
            {
              "date": "2024-01-17",
              "dayTheme": "Classic Shanghai · City Memory Line",
              "dayKeywords": "History, City Symbols, Night View",
              "daySummary": "Deep summary of this day's itinerary, explaining theme and rationale",
              "activities": [
                {
                  "title": "Specific location name (e.g., The Bund, Wukang Road, Yu Garden)",
                  "location": "Detailed address (e.g., Zhongshan East Road, Huangpu District, Shanghai)",
                  "description": "Deep description: why it's worth visiting, what's special, how to experience, cultural background. Example: 'The Bund is the city's calling card, fewer people in the morning, clear architectural details, the best starting point to understand Shanghai's history'",
                  "category": "Attraction/Restaurant/Shopping/Entertainment/Culture",
                  "recommendedDuration": 90,
                  "openingHours": "09:00-22:00 (if available)",
                  "tips": ["Practical tip 1", "Practical tip 2"],
                  "priceLevel": "Free/Cheap/Moderate/Expensive",
                  "timeSlot": "Morning/Noon/Afternoon/Evening",
                  "rationale": "The rationale and logic of this arrangement (why arranged this way)"
                }
              ],
              "transportation": ["Specific transportation suggestions, e.g., Metro Line 2 to People's Square Station"]
            }
          ],
          "generalTips": ["General suggestions, e.g., 'Shanghai is not a sightseeing city, it's a structural city', 'Itinerary design is not about filling up, but about feeling transitions'"]
        }
        
        【Key Requirements】
        - All locations must be real, specific names (e.g., "The Bund", "Wukang Road", "Yu Garden"), never use generic names like "sightseeing visit", "cultural experience"
        - Each activity must have "rationale" (rationale explanation), explaining why arranged this way
        - Descriptions must be deep and thoughtful, including cultural background and city understanding
        - Each day must have clear theme (dayTheme) and keywords (dayKeywords)
        - JSON format must be correct and directly parseable
        - IMPORTANT: All text content (dayTheme, dayKeywords, daySummary, description, tips, rationale, generalTips) must be in English
        """
        
        // 如果目的地有特定的本地语言，明确要求使用该语言的地点名称
        if let destLang = destinationLanguage, destLang != "English" {
            prompt += """
            
        【Important: Location Name Language Requirement】
        - The destination's primary language is \(destLang)
        - **All location names (title and location fields) must use the local \(destLang) names**
        - For example: If the destination is Brazil (Portuguese), location names should use Portuguese, such as "Copacabana", "Ipanema", "Cristo Redentor", etc.
        - Descriptions and other text content can be in English, but location names must be in \(destLang)
        - This ensures accuracy and searchability of location names, avoiding search failures due to translation
        """
        }
        
        return prompt
    }
    
    /// 构建德文 prompt
    private func buildGermanPrompt(
        destination: String,
        startDate: String,
        endDate: String,
        durationDays: Int,
        interestTags: [String],
        pace: Pace,
        walkingLevel: WalkingLevel?,
        transportPreference: TransportPreference?,
        selectedAttractions: [String],
        customTags: [String],
        currentGPSLocation: CLLocation?,
        accommodationAddress: String?,
        accommodationType: String?,
        destinationLanguage: String? = nil,
        hasOtherOption: Bool = false
    ) -> String {
        var prompt = """
        Bitte erstellen Sie eine **gut getaktete, erstmalige Besucher-freundliche und nicht übereilte** \(durationDays)-Tage-Reiseroute für \(destination).
        
        【Kernprinzipien】
        - Fokus auf: Stadterinnerungen + moderne Atmosphäre + lokales Leben
        - Jeder Tag sollte ein klares Thema und Schlüsselwörter haben (z.B. "Klassische Stadterinnerungen", "Kolonialkultur", "Moderne Höhen")
        - Keine "Sehenswürdigkeits-Stadt", sondern eine "Struktur-Stadt" - verstehen Sie das Skelett und die Logik der Stadt
        - Reiserouten-Design ist nicht das Auffüllen, sondern "Gefühlsübergänge", die bleibende Erinnerungen schaffen
        - Ein Hauptthema pro Tag, vermeiden Sie Hin- und Her-Reisen
        
        【Benutzeranforderungen】
        """
        
        if !interestTags.isEmpty {
            prompt += "\n- Interessen: \(interestTags.joined(separator: ", "))"
        }
        
        if !selectedAttractions.isEmpty {
            prompt += "\n- Muss enthaltene Sehenswürdigkeiten: \(selectedAttractions.joined(separator: ", ")) (Diese Sehenswürdigkeiten müssen in der Reiseroute erscheinen, bitte ordnen Sie sie vernünftig in tägliche Aktivitäten ein)"
        }
        if !customTags.isEmpty {
            prompt += "\n- Benutzerdefinierte Interessen-Tags: \(customTags.joined(separator: ", ")). Diese können vage Beschreibungen sein. Bitte als echte, bekannte Sehenswürdigkeiten interpretieren, die der Beschreibung entsprechen."
        }
        
        let paceGuidance: String
        switch pace {
        case .relaxed:
            paceGuidance = "Entspanntes Tempo: 3-4 Hauptblöcke pro Tag, viel Zeit für tiefe Erfahrungen, nicht übereilt"
        case .moderate:
            paceGuidance = "Moderates Tempo: 4-5 Hauptblöcke pro Tag, ausgewogene Erfahrung und Effizienz"
        case .tight:
            paceGuidance = "Intensives Tempo: 5-6 Hauptblöcke pro Tag, effizient aber nicht übermäßig anstrengend"
        }
        prompt += "\n- Tempovorgabe: \(paceGuidance)"
        
        if let walking = walkingLevel {
            let walkingGuidance = walking == .low ? "Minimales Gehen, priorisieren Sie leicht zugängliche Bereiche" :
                                 walking == .high ? "Mehr Gehen, erkunden Sie Gassen und Fußgängerbereiche" :
                                 "Normale Gehintensität"
            prompt += "\n- Gehintensität: \(walkingGuidance)"
        }
        
        if let transport = transportPreference {
            prompt += "\n- Transportpräferenz: \(transport.rawValue) bevorzugt"
        }
        
        if let gpsLocation = currentGPSLocation {
            prompt += "\n- Abfahrtsort: GPS-Koordinaten (\(gpsLocation.coordinate.latitude), \(gpsLocation.coordinate.longitude))"
            prompt += "\n- Bitte berechnen Sie die Reisezeit und Entfernung vom Abfahrtsort zum Ziel und fügen Sie einen Transitzeitblock am Anfang des ersten Tages hinzu"
        }
        
        if let accommodation = accommodationAddress, !accommodation.isEmpty {
            let accType = accommodationType ?? "Benutzerdefinierte Adresse"
            prompt += "\n- Unterkunftslocation: \(accommodation) (Typ: \(accType))"
            prompt += """
            
        【Unterkunftseinflussanalyse - WICHTIG!】
        Die Unterkunftslocation beeinflusst die Reiseroutenplanung erheblich. Sie MÜSSEN folgende Faktoren beachten:
        
        1. **Check-in am ersten Tag**:
           - Am ersten Tag nach Ankunft muss zur Unterkunft für Check-in (meist nach 14-15 Uhr möglich)
           - Reisezeit vom Abfahrtsort zur Unterkunft muss berechnet werden
           - Check-in dauert normalerweise 30-60 Minuten (Anmeldung, Gepäckaufbewahrung, kurze Pause)
           - Aktivitäten am ersten Nachmittag sollten nach Check-in arrangiert werden, nahe Unterkunft gelegene Sehenswürdigkeiten priorisieren
           - Gepäckfaktor berücksichtigen: Bei großem Gepäck nicht für Aktivitäten mit viel Gehen geeignet
        
        2. **Tägliche Abfahrt von der Unterkunft**:
           - Vor jedem Tag Reisezeit von Unterkunft zum ersten Ziel berechnen
           - Nahe Ziele morgens oder abends priorisieren
           - Entfernte Ziele in mittleren Zeiträumen arrangieren, häufige Hin- und Her-Reisen vermeiden
           - Bequemlichkeit von Restaurants und Einkaufsmöglichkeiten um die Unterkunft berücksichtigen
        
        3. **Tägliche Rückkehr zur Unterkunft**:
           - Am Ende jedes Tages Reisezeit vom letzten Ziel zur Unterkunft berechnen
           - Diese Reisezeiten in die Reiseroutenplanung einbeziehen
           - Abendaktivitäten sollten die Bequemlichkeit der Rückkehr zur Unterkunft berücksichtigen
        
        4. **Check-out am letzten Tag**:
           - Letzter Tag erfordert Check-out am Morgen (meist vor 10-11 Uhr)
           - Nach Check-out Gepäck handhaben: Bei Unterkunft lagern, Aufbewahrungsservice nutzen oder tragen
           - Aktivitäten am letzten Tag müssen folgendes berücksichtigen:
             * Wenn Gepäck bei Unterkunft gelagert: Muss zurückkehren, um Gepäck abzuholen
             * Wenn Gepäck getragen: Nicht geeignet für Aktivitäten mit viel Gehen oder unpraktisch mit Gepäck (z.B. Wandern, lange Spaziergänge)
             * Leichte Aktivitäten vorschlagen: Einkaufen, leichte Mahlzeiten, Besuch von Indoor-Sehenswürdigkeiten
           - Wenn am letzten Tag zum Flughafen/Bahnhof: Ausreichend Zeit einplanen (meist 2-3 Stunden im Voraus)
        
        5. **Gepäckfaktor**:
           - Erster Tag: Gepäck tragen, keine anstrengenden Aktivitäten, Sehenswürdigkeiten mit bequemer Anreise und Gepäckaufbewahrung priorisieren
           - Mittlere Tage: Gepäck in Unterkunft, alle Aktivitätstypen möglich
           - Letzter Tag: Aktivitäten je nach Gepäckbehandlungsmethode
             * Gepäckaufbewahrung: Normale Aktivitäten möglich, aber Zeit zum Zurückkehren und Abholen des Gepäcks einplanen
             * Gepäck tragen: Nur leichte, Indoor, leicht zugängliche Aktivitäten
        
        6. **Unterkunftstyp-Einfluss**:
           - Hotels: Meist bequeme Lage, einfache Verkehrsanbindung, aber höherer Preis, meist Gepäckaufbewahrungsservice
           - Pensionen/Apartments: Möglicherweise abgelegener, aber lokaleres Erlebnis, Gepäckaufbewahrung möglicherweise begrenzt
           - Bitte entsprechende Reiseroutenvorschläge basierend auf Unterkunftstyp geben
        
        7. **Wichtige Zeitpunkte**:
           - Erster Tag: Abfahrtsort → Unterkunft (Check-in) → Nachmittags-/Abendaktivitäten
           - Mittlere Tage: Unterkunft → Sehenswürdigkeiten → Unterkunft
           - Letzter Tag: Unterkunft (Check-out) → Aktivitäten (Gepäck berücksichtigen) → Abfahrtsort/Flughafen/Bahnhof
        """
        }
        
        prompt += """
        
        【Planungsanforderungen】
        
        1. **Spezifische Ortsnamen** (Wichtigste!)
           - Müssen echte, spezifische Ortsnamen bereitstellen
           - Verwenden Sie niemals generische Namen wie "Sehenswürdigkeitsbesuch", "Kulturerlebnis" usw.
           - Jeder Ort muss eine detaillierte Adresse haben
        
        2. **Tägliche Themen und Begründung**
           - Jeder Tag sollte ein klares Thema haben
           - Jeder Zeitabschnitt sollte eine "Begründung" haben
           - Erklären Sie "warum diese Anordnung", "was ist die Logik dieser Wahl"
        
        3. **Tiefe Beschreibungen und kulturelles Verständnis**
           - Jede Aktivität sollte eine tiefe Beschreibung haben
           - Erklären Sie "warum es einen Besuch wert ist", "was ist besonders", "wie man es erlebt"
        
        【Ausgabeformat】
        Bitte geben Sie ein JSON-Objekt im folgenden Format zurück:
        {
          "destination": "\(destination)",
          "startDate": "\(startDate)",
          "endDate": "\(endDate)",
          "days": [...]
        }
        
        【Wichtige Anforderungen】
        - Alle Textinhalte (dayTheme, dayKeywords, daySummary, description, tips, rationale, generalTips) müssen auf Deutsch sein
        - JSON-Format muss korrekt und direkt parsbar sein
        """
        
        // 如果目的地有特定的本地语言，明确要求使用该语言的地点名称
        if let destLang = destinationLanguage, destLang != "German" {
            prompt += """
            
        【Wichtig: Anforderung für Ortsnamensprache】
        - Die Hauptsprache des Reiseziels ist \(destLang)
        - **Alle Ortsnamen (title und location Felder) müssen die lokalen \(destLang) Namen verwenden**
        - Beschreibungen und andere Textinhalte können auf Deutsch sein, aber Ortsnamen müssen auf \(destLang) sein
        - Dies gewährleistet Genauigkeit und Auffindbarkeit von Ortsnamen
        """
        }
        
        return prompt
    }
    
    /// 构建法文 prompt
    private func buildFrenchPrompt(
        destination: String,
        startDate: String,
        endDate: String,
        durationDays: Int,
        interestTags: [String],
        pace: Pace,
        walkingLevel: WalkingLevel?,
        transportPreference: TransportPreference?,
        selectedAttractions: [String],
        customTags: [String],
        currentGPSLocation: CLLocation?,
        accommodationAddress: String?,
        accommodationType: String?,
        destinationLanguage: String? = nil,
        hasOtherOption: Bool = false
    ) -> String {
        var prompt = """
        Veuillez créer un itinéraire de \(durationDays) jours **bien rythmé, adapté aux visiteurs pour la première fois et non précipité** pour \(destination).
        
        【Principes fondamentaux】
        - Focus sur: souvenirs de la ville + ambiance moderne + vie locale
        - Chaque jour devrait avoir un thème clair et des mots-clés
        - Pas une "ville de sites touristiques", mais une "ville structurelle"
        - La conception d'itinéraire n'est pas de remplir, mais de créer des "transitions de sentiment"
        
        【Exigences de l'utilisateur】
        """
        
        if !interestTags.isEmpty {
            prompt += "\n- Intérêts: \(interestTags.joined(separator: ", "))"
        }
        
        if !selectedAttractions.isEmpty {
            prompt += "\n- Attractions à inclure: \(selectedAttractions.joined(separator: ", "))"
        }
        if !customTags.isEmpty {
            prompt += "\n- Tags personnalisés: \(customTags.joined(separator: ", ")). Ce sont des descriptions possibles. Interprétez-les comme des lieux réels et de qualité correspondant à la description."
        }
        
        let paceGuidance: String
        switch pace {
        case .relaxed:
            paceGuidance = "Rythme détendu: 3-4 blocs principaux par jour"
        case .moderate:
            paceGuidance = "Rythme modéré: 4-5 blocs principaux par jour"
        case .tight:
            paceGuidance = "Rythme serré: 5-6 blocs principaux par jour"
        }
        prompt += "\n- Exigence de rythme: \(paceGuidance)"
        
        if let accommodation = accommodationAddress, !accommodation.isEmpty {
            let accType = accommodationType ?? "Adresse personnalisée"
            prompt += "\n- Emplacement de l'hébergement: \(accommodation) (Type: \(accType))"
            prompt += """
            
        【Analyse de l'impact de l'hébergement - CRITIQUE!】
        L'emplacement de l'hébergement affecte considérablement la planification de l'itinéraire. Vous DEVEZ considérer:
        
        1. **Arrangement Check-in le premier jour**:
           - Le premier jour, après l'arrivée, aller à l'hébergement pour Check-in (généralement après 14-15h)
           - Temps de voyage du lieu de départ à l'hébergement doit être calculé
           - Check-in prend généralement 30-60 minutes
           - Activités de l'après-midi le premier jour doivent être arrangées après Check-in
           - Considérer le facteur bagages: Si portant de gros bagages, premier jour pas adapté aux activités nécessitant beaucoup de marche
        
        2. **Départ quotidien de l'hébergement**:
           - Avant chaque jour, calculer le temps de voyage de l'hébergement à la première attraction
        
        3. **Retour quotidien à l'hébergement**:
           - À la fin de chaque jour, calculer le temps de voyage de la dernière attraction à l'hébergement
        
        4. **Arrangement Check-out le dernier jour**:
           - Dernier jour nécessite généralement Check-out le matin (généralement avant 10-11h)
           - Après Check-out, gérer les bagages: stocker, utiliser service de stockage, ou porter
           - Activités du dernier jour doivent considérer les bagages
           - Si aller à l'aéroport/gare, réserver 2-3 heures à l'avance
        
        5. **Facteur bagages**:
           - Premier jour: Porter bagages, pas d'activités exigeantes
           - Jours intermédiaires: Bagages à l'hébergement, toutes activités possibles
           - Dernier jour: Activités selon méthode de gestion des bagages
        """
        }
        
        prompt += """
        
        【Format de sortie】
        Veuillez retourner un objet JSON au format suivant:
        {
          "destination": "\(destination)",
          "startDate": "\(startDate)",
          "endDate": "\(endDate)",
          "days": [...]
        }
        
        【Exigences clés】
        - Tout le contenu texte doit être en français
        - Le format JSON doit être correct et directement analysable
        """
        
        // 如果目的地有特定的本地语言，明确要求使用该语言的地点名称
        if let destLang = destinationLanguage, destLang != "French" {
            prompt += """
            
        【Important: Exigence de langue pour les noms de lieux】
        - La langue principale de la destination est \(destLang)
        - **Tous les noms de lieux (champs title et location) doivent utiliser les noms locaux en \(destLang)**
        - Les descriptions et autres contenus textuels peuvent être en français, mais les noms de lieux doivent être en \(destLang)
        - Cela garantit la précision et la recherchabilité des noms de lieux
        """
        }
        
        return prompt
    }
    
    /// 构建西班牙文 prompt
    private func buildSpanishPrompt(
        destination: String,
        startDate: String,
        endDate: String,
        durationDays: Int,
        interestTags: [String],
        pace: Pace,
        walkingLevel: WalkingLevel?,
        transportPreference: TransportPreference?,
        selectedAttractions: [String],
        customTags: [String],
        currentGPSLocation: CLLocation?,
        accommodationAddress: String?,
        accommodationType: String?,
        destinationLanguage: String? = nil,
        hasOtherOption: Bool = false
    ) -> String {
        var prompt = """
        Por favor, cree un itinerario de \(durationDays) días **bien ritmado, amigable para visitantes por primera vez y no apresurado** para \(destination).
        
        【Principios fundamentales】
        - Enfoque en: recuerdos de la ciudad + ambiente moderno + vida local
        - Cada día debe tener un tema claro y palabras clave
        - No una "ciudad de atracciones", sino una "ciudad estructural"
        - El diseño del itinerario no es llenar, sino crear "transiciones de sentimiento"
        
        【Requisitos del usuario】
        """
        
        if !interestTags.isEmpty {
            prompt += "\n- Intereses: \(interestTags.joined(separator: ", "))"
        }
        
        if !selectedAttractions.isEmpty {
            prompt += "\n- Atracciones a incluir: \(selectedAttractions.joined(separator: ", "))"
        }
        if !customTags.isEmpty {
            prompt += "\n- Etiquetas personalizadas: \(customTags.joined(separator: ", ")). Pueden ser descripciones vagas. Interprete como lugares reales y de calidad que coincidan con la descripción."
        }
        
        let paceGuidance: String
        switch pace {
        case .relaxed:
            paceGuidance = "Ritmo relajado: 3-4 bloques principales por día"
        case .moderate:
            paceGuidance = "Ritmo moderado: 4-5 bloques principales por día"
        case .tight:
            paceGuidance = "Ritmo intenso: 5-6 bloques principales por día"
        }
        prompt += "\n- Requisito de ritmo: \(paceGuidance)"
        
        if let accommodation = accommodationAddress, !accommodation.isEmpty {
            let accType = accommodationType ?? "Dirección personalizada"
            prompt += "\n- Ubicación del alojamiento: \(accommodation) (Tipo: \(accType))"
            prompt += """
            
        【Análisis del impacto del alojamiento - ¡CRÍTICO!】
        La ubicación del alojamiento afecta significativamente la planificación del itinerario. DEBE considerar:
        
        1. **Arreglo de Check-in el primer día**:
           - Primer día, después de la llegada, ir al alojamiento para Check-in (generalmente después de 14-15h)
           - Tiempo de viaje desde lugar de salida al alojamiento debe calcularse
           - Check-in generalmente toma 30-60 minutos
           - Actividades de la tarde del primer día deben arreglarse después del Check-in
           - Considerar factor equipaje: Si lleva equipaje grande, primer día no adecuado para actividades que requieren mucha caminata
        
        2. **Salida diaria del alojamiento**:
           - Antes de cada día, calcular tiempo de viaje del alojamiento a primera atracción
        
        3. **Regreso diario al alojamiento**:
           - Al final de cada día, calcular tiempo de viaje de última atracción al alojamiento
        
        4. **Arreglo de Check-out el último día**:
           - Último día generalmente requiere Check-out por la mañana (generalmente antes de 10-11h)
           - Después del Check-out, manejar equipaje: almacenar, usar servicio de almacenamiento, o llevar
           - Actividades del último día deben considerar el equipaje
           - Si va al aeropuerto/estación, reservar 2-3 horas de antelación
        
        5. **Factor equipaje**:
           - Primer día: Llevar equipaje, no actividades extenuantes
           - Días intermedios: Equipaje en alojamiento, todas las actividades posibles
           - Último día: Actividades según método de manejo de equipaje
        """
        }
        
        prompt += """
        
        【Formato de salida】
        Por favor, devuelva un objeto JSON en el siguiente formato:
        {
          "destination": "\(destination)",
          "startDate": "\(startDate)",
          "endDate": "\(endDate)",
          "days": [...]
        }
        
        【Requisitos clave】
        - Todo el contenido de texto debe estar en español
        - El formato JSON debe ser correcto y directamente analizable
        """
        
        // 如果目的地有特定的本地语言，明确要求使用该语言的地点名称
        if let destLang = destinationLanguage, destLang != "Spanish" {
            prompt += """
            
        【Importante: Requisito de idioma para nombres de lugares】
        - El idioma principal del destino es \(destLang)
        - **Todos los nombres de lugares (campos title y location) deben usar los nombres locales en \(destLang)**
        - Las descripciones y otros contenidos de texto pueden estar en español, pero los nombres de lugares deben estar en \(destLang)
        - Esto garantiza la precisión y la capacidad de búsqueda de los nombres de lugares
        """
        }
        
        return prompt
    }
    
    /// 构建日文 prompt
    private func buildJapanesePrompt(
        destination: String,
        startDate: String,
        endDate: String,
        durationDays: Int,
        interestTags: [String],
        pace: Pace,
        walkingLevel: WalkingLevel?,
        transportPreference: TransportPreference?,
        selectedAttractions: [String],
        customTags: [String],
        currentGPSLocation: CLLocation?,
        accommodationAddress: String?,
        accommodationType: String?,
        destinationLanguage: String? = nil,
        hasOtherOption: Bool = false
    ) -> String {
        var prompt = """
        \(destination)のための**ペースが良く、初めての訪問者にも親しみやすく、急がせない**\(durationDays)日間の旅程を作成してください。
        
        【基本原則】
        - 重点：都市の記憶 + モダンな雰囲気 + ローカルライフ
        - 各日には明確なテーマとキーワードが必要（例：「クラシックな都市の記憶」、「植民地文化」、「モダンな高さ」）
        - 「観光スポット都市」ではなく「構造都市」- 都市の骨格と論理を理解する
        - 旅程設計は詰め込むことではなく、「感情の転換」を生み出し、記憶を残すこと
        - 1日1つの主軸、往復を避ける
        
        【ユーザー要件】
        """
        
        if !interestTags.isEmpty {
            prompt += "\n- 興味のタグ：\(interestTags.joined(separator: "、"))"
        }
        
        if !selectedAttractions.isEmpty {
            prompt += "\n- 含める必要がある観光スポット：\(selectedAttractions.joined(separator: "、"))（これらの観光スポットは旅程に必ず含まれ、毎日の活動に適切に配置してください）"
        }
        if !customTags.isEmpty {
            prompt += "\n- ユーザー独自のタグ：\(customTags.joined(separator: "、"))。曖昧な説明の可能性あり。目的地周辺で該当する実在の有名スポットとして解釈し、高品質な場所を選んで日程に組み込んでください。"
        }
        
        let paceGuidance: String
        switch pace {
        case .relaxed:
            paceGuidance = "リラックスしたペース：1日3-4つの主要ブロック、深い体験のための十分な時間、急がせない"
        case .moderate:
            paceGuidance = "中程度のペース：1日4-5つの主要ブロック、体験と効率のバランス"
        case .tight:
            paceGuidance = "タイトなペース：1日5-6つの主要ブロック、効率的だが過度に疲れない"
        }
        prompt += "\n- ペース要件：\(paceGuidance)"
        
        if let walking = walkingLevel {
            let walkingGuidance = walking == .low ? "歩行を最小限に、交通の便が良い地域を優先" :
                                 walking == .high ? "より多く歩く、路地や歩行者エリアを探索" :
                                 "通常の歩行強度"
            prompt += "\n- 歩行強度：\(walkingGuidance)"
        }
        
        if let transport = transportPreference {
            prompt += "\n- 交通の好み：\(transport.rawValue)を優先"
        }
        
        if let gpsLocation = currentGPSLocation {
            prompt += "\n- 出発位置：GPS座標（\(gpsLocation.coordinate.latitude), \(gpsLocation.coordinate.longitude)）"
            prompt += "\n- 出発位置から目的地までの移動時間と距離を計算し、最初の日の旅程開始時に移動時間ブロックを追加してください"
        }
        
        if let accommodation = accommodationAddress, !accommodation.isEmpty {
            let accType = accommodationType ?? "カスタムアドレス"
            prompt += "\n- 宿泊場所：\(accommodation)（タイプ：\(accType)）"
            prompt += """
            
        【宿泊が旅行に与える影響の分析 - 重要！】
        宿泊場所は旅程計画に重要な影響を与えます。以下の要因を必ず考慮してください：
        
        1. **最初の日のチェックイン配置**：
           - 最初の日に到着後、宿泊場所でチェックインする必要があります（通常午後2-3時以降に入室可能）
           - 出発位置から宿泊までの移動時間を計算する必要があります
           - チェックインには通常30-60分かかります（手続き、荷物の保管、少し休憩）
           - 最初の日の午後の活動はチェックイン後に配置し、宿泊に近い観光スポットを優先してください
           - 荷物の要因を考慮：大きな荷物を持っている場合、最初の日は大量の歩行を必要とする活動には適していません
        
        2. **宿泊からの毎日の出発**：
           - 各日の開始前に、宿泊から最初の観光スポットまでの移動時間を計算する必要があります
           - 宿泊場所に基づいて、宿泊に近い観光スポットを朝または夜に優先的に配置
           - 遠い観光スポットを中間時間帯に配置し、宿泊への頻繁な往復を避ける
           - 宿泊周辺の飲食とショッピングの利便性を考慮
        
        3. **宿泊への毎日の帰還**：
           - 各日の終了時に、最後の観光スポットから宿泊への移動時間を計算する必要があります
           - これらの移動時間を旅程計画に含める
           - 夜の活動は宿泊への帰還の利便性を考慮
        
        4. **最後の日のチェックアウト配置**：
           - 最後の日は通常朝にチェックアウトする必要があります（通常午前10-11時前）
           - チェックアウト後、荷物を処理する必要があります：ホテルに預ける、荷物預かりサービスを利用する、または荷物を持ち歩く
           - 最後の日の活動配置は以下を考慮する必要があります：
             * 荷物を宿泊に預けた場合、最後に戻って荷物を取る必要があります
             * 荷物を持ち歩く場合、大量の歩行や荷物を持ち歩くのに不便な活動（登山、長距離の徒歩など）には適していません
             * ショッピング、軽食、室内観光スポットの訪問など、軽い活動を提案してください
           - 最後の日に空港/駅に行く必要がある場合、十分な時間を確保する必要があります（通常2-3時間前）
        
        5. **荷物の要因の考慮**：
           - 最初の日：荷物を持ち歩く、大量の歩行を必要とする活動には適していない、交通が便利で荷物預かりができる観光スポットを優先
           - 中間日：荷物は宿泊にあり、あらゆるタイプの活動を配置できます
           - 最後の日：荷物の処理方法に基づいて活動を配置
             * 荷物預かり：通常の活動を配置できますが、戻って荷物を取る時間を確保する必要があります
             * 荷物を持ち歩く：軽い、室内、交通が便利な活動のみ配置できます
        
        6. **宿泊タイプの影響**：
           - ホテル：通常、場所が便利で、交通が容易ですが、価格が高く、通常荷物預かりサービスがあります
           - 民宿/アパート：場所がより離れている可能性がありますが、よりローカルな体験ができ、荷物預かりは限られている可能性があります
           - 宿泊タイプに応じて適切な旅程提案を提供してください
        
        7. **重要な時間ポイント**：
           - 最初の日：出発位置 → 宿泊（チェックイン）→ 午後/夜の活動
           - 中間日：宿泊 → 観光スポット → 宿泊
           - 最後の日：宿泊（チェックアウト）→ 活動（荷物を考慮）→ 出発位置/空港/駅
        """
        }
        
        prompt += """
        
        【計画要件 - ChatGPTトップ旅程に合わせる】
        
        1. **具体的な場所名**（最重要！）
           - 実在する具体的な場所名を提供する必要があります（例：「外灘」、「武康路」、「豫園」、「陸家嘴」）
           - 「観光スポット訪問」、「文化体験」などの汎用的なテンプレート名を絶対に使用しないでください
           - 各場所には詳細な住所が必要です
        
        2. **毎日のテーマと論理**
           - 各日には明確なテーマが必要（例：「クラシック上海・都市記憶線」、「租界文化・生活美学線」）
           - 各時間帯（午前/正午/午後/夜）には「論理」の説明が必要
           - 「なぜこの配置か」、「この選択の論理は何か」を説明
        
        3. **深い説明と文化的理解**
           - 各活動には深い説明が必要で、表面的な紹介だけではありません
           - 「なぜ訪れる価値があるか」、「何が特別か」、「どのように体験するか」を説明
           - 文化的背景、都市理解、生活美学などの深い内容を含める
           - 例：「外灘は都市の名刺、朝は人が少なく、建築の細部がはっきりしている」
        
        4. **ルートの論理**
           - 地理的位置を考慮し、ルートを合理的に計画し、往復を減らす
           - 1日最大3-4つの主要ブロック、地区を越えて往復しない
           - 各ブロック内の活動は一貫性があり、論理的である必要があります
        
        5. **レストランと美食**
           - 具体的なレストランや地域を推奨（例：「人民広場/南京東路」、「安福路/衡山路」）
           - 料理の種類と特色を説明（例：「本帮菜：紅焼肉、油爆蝦、蟹粉豆腐」）
           - ショッピングモールを避け、街の店舗とローカル特色を優先
        
        6. **交通の提案**
           - 具体的な交通手段とルート提案を提供
           - 核心原則を説明（例：「地下鉄を主に」、「1日最大3つの主要ブロック」）
        
        7. **体験の転換**
           - 各日には異なる体験タイプの転換が必要（歴史→現代、伝統→モダン、静か→賑やか）
           - 同質化を避け、記憶のアンカーを作成
        
        【出力形式】
        以下の形式でJSONオブジェクトを返してください：
        {
          "destination": "\(destination)",
          "startDate": "\(startDate)",
          "endDate": "\(endDate)",
          "days": [
            {
              "date": "2024-01-17",
              "dayTheme": "クラシック上海・都市記憶線",
              "dayKeywords": "歴史、都市シンボル、夜景",
              "daySummary": "この日の旅程の深い要約、テーマと論理を説明",
              "activities": [
                {
                  "title": "具体的な場所名（例：外灘、武康路、豫園）",
                  "location": "詳細な住所（例：上海市黄浦区中山东一路）",
                  "description": "深い説明：なぜ訪れる価値があるか、何が特別か、どのように体験するか、文化的背景。例：'外灘は都市の名刺、朝は人が少なく、建築の細部がはっきりしており、上海の歴史を理解する最良の出発点'",
                  "category": "観光スポット/レストラン/ショッピング/エンターテイメント/文化",
                  "recommendedDuration": 90,
                  "openingHours": "09:00-22:00（利用可能な場合）",
                  "tips": ["実用的なヒント1", "実用的なヒント2"],
                  "priceLevel": "無料/安い/中程度/高価",
                  "timeSlot": "午前/正午/午後/夜",
                  "rationale": "この配置の論理と理由（なぜこのように配置したか）"
                }
              ],
              "transportation": ["具体的な交通提案、例：地下鉄2号線で人民広場駅へ"]
            }
          ],
          "generalTips": ["全体的な提案、例：'上海は観光スポット都市ではなく、構造都市'、'旅程設計は詰め込むことではなく、感情の転換を感じること'"]
        }
        
        【重要な要件】
        - すべての場所は実在する具体的な名前である必要があります（例：「外灘」、「武康路」、「豫園」）、「観光スポット訪問」、「文化体験」などの汎用的なテンプレート名を絶対に使用しないでください
        - 各活動には「rationale」（論理の説明）が必要で、なぜこのように配置したかを説明します
        - 説明は深く、思考を含み、文化的背景と都市理解を含む必要があります
        - 各日には明確なテーマ（dayTheme）とキーワード（dayKeywords）が必要です
        - JSON形式は正しく、直接解析可能である必要があります
        - 重要：すべてのテキストコンテンツ（dayTheme、dayKeywords、daySummary、description、tips、rationale、generalTips）は日本語で記述する必要があります
        """
        
        // 如果目的地有特定的本地语言，明确要求使用该语言的地点名称
        if let destLang = destinationLanguage, destLang != "Japanese" {
            prompt += """
            
        【重要：場所名の言語要件】
        - 目的地の主要言語は\(destLang)です
        - **すべての場所名（titleとlocationフィールド）は\(destLang)のローカル名を使用する必要があります**
        - 例：目的地がブラジル（ポルトガル語）の場合、場所名はポルトガル語を使用し、「Copacabana」、「Ipanema」、「Cristo Redentor」など
        - 説明（description）やその他のテキストコンテンツは日本語で記述できますが、場所名は\(destLang)を使用する必要があります
        - これにより、場所名の正確性と検索可能性が確保され、翻訳による検索失敗を避けることができます
        """
        }
        
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
    
    /// 行程轉換上下文（出發地、住宿、交通方式，用於計算實際交通時間）
    struct PlanConversionContext {
        var departureLocation: CLLocation?
        var accommodationAddress: String?
        var accommodationCoordinate: CLLocationCoordinate2D?
        var transportPreference: TransportPreference?
    }
    
    /// 将AI生成的行程转换为PlanResult（同步版，使用預設交通時間）
    func convertToPlanResult(_ aiPlan: AITripPlan, slots: ExtractedSlots, adults: Int? = nil, children: Int? = nil) throws -> PlanResult {
        try convertToPlanResult(aiPlan, slots: slots, adults: adults, children: children, context: nil)
    }
    
    /// 将AI生成的行程转换为PlanResult（支持上下文，可選異步計算實際交通時間）
    func convertToPlanResult(
        _ aiPlan: AITripPlan,
        slots: ExtractedSlots,
        adults: Int? = nil,
        children: Int? = nil,
        context: PlanConversionContext?
    ) throws -> PlanResult {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        var dayPlans: [DayPlan] = []
        let assumptions: [String] = []
        var riskFlags: [String] = []
        
        for aiDay in aiPlan.days {
            guard let date = dateFormatter.date(from: aiDay.date) else { continue }
            
            let blocks = try convertDayActivitiesToBlocks(
                aiDay: aiDay,
                date: date,
                pace: slots.pace.value ?? .moderate,
                adults: adults ?? slots.adults.value,
                children: children ?? slots.children.value,
                context: context,
                isFirstDay: aiDay.date == aiPlan.days.first?.date,
                isLastDay: aiDay.date == aiPlan.days.last?.date
            )
            
            dayPlans.append(DayPlan(date: date, blocks: blocks))
        }
        
        if !aiPlan.generalTips.isEmpty {
            riskFlags.append("💡 行程建议：\(aiPlan.generalTips.joined(separator: " "))")
        }
        
        return PlanResult(days: dayPlans, assumptions: assumptions, riskFlags: riskFlags)
    }
    
    /// 将AI活动转换为TimeBlock（支持出發地、住宿、交通偏好）
    private func convertDayActivitiesToBlocks(
        aiDay: AIDayItinerary,
        date: Date,
        pace: Pace,
        adults: Int? = nil,
        children: Int? = nil,
        context: PlanConversionContext? = nil,
        isFirstDay: Bool = false,
        isLastDay: Bool = false
    ) throws -> [TimeBlock] {
        let calendar = Calendar.current
        var blocks: [TimeBlock] = []
        
        let defaultStartHour = 9
        let defaultStartMinute = 30
        var currentTime = calendar.date(bySettingHour: defaultStartHour, minute: defaultStartMinute, second: 0, of: date) ?? date
        
        let dayEnd = calendar.date(bySettingHour: 20, minute: 30, second: 0, of: date) ?? date
        
        // MARK: - 第一天：出發 → 住宿(Check-in) → 放行李 → 首個景點
        let accAddr = context?.accommodationAddress ?? ""
        let hasAccommodation = !accAddr.isEmpty || context?.accommodationCoordinate != nil
        let hasDeparture = context?.departureLocation != nil
        
        if isFirstDay {
            
            if hasDeparture && hasAccommodation {
                // 1. 出發 → 住宿：交通塊
                let transitToAccommodation: TimeInterval = 50 * 60  // 預設約 50 分鐘，PlanDetailView 可依 GPS 更新
                let transitEnd = currentTime.addingTimeInterval(transitToAccommodation)
                if transitEnd <= dayEnd {
                    blocks.append(TimeBlock(
                        type: .transit,
                        startTime: currentTime,
                        endTime: transitEnd,
                        title: "前往住宿地點",
                        location: context?.accommodationAddress,
                        isAnchor: false,
                        priority: 6,
                        description: "從出發地前往住宿辦理入住，建議下午 2–3 點後可入住"
                    ))
                    currentTime = transitEnd
                }
                
                // 2. 辦理入住 · 放置行李（30–45 分鐘）
                let checkInDuration: TimeInterval = 45 * 60
                let checkInEnd = currentTime.addingTimeInterval(checkInDuration)
                if checkInEnd <= dayEnd {
                    blocks.append(TimeBlock(
                        type: .activity,
                        startTime: currentTime,
                        endTime: checkInEnd,
                        title: "辦理入住 · 放置行李",
                        location: context?.accommodationAddress,
                        isAnchor: false,
                        priority: 6,
                        description: "辦理 Check-in、放置行李、稍作休息後再出發。若有大型行李，建議第一天安排交通便利的景點。"
                    ))
                    currentTime = checkInEnd
                }
            } else if hasDeparture {
                // 無住宿資訊：出發 → 目的地（首個活動）
                let initialTransit: TimeInterval = 60 * 60
                let transitEnd = currentTime.addingTimeInterval(initialTransit)
                if transitEnd <= dayEnd {
                    blocks.append(TimeBlock(
                        type: .transit,
                        startTime: currentTime,
                        endTime: transitEnd,
                        title: "前往目的地",
                        location: nil,
                        isAnchor: false,
                        priority: 6,
                        description: "從出發位置前往目的地"
                    ))
                    currentTime = transitEnd
                }
            }
        }
        
        // MARK: - 最後一天：辦理退房（若有住宿）
        if isLastDay && hasAccommodation {
            let checkOutDuration: TimeInterval = 20 * 60
            let checkOutEnd = currentTime.addingTimeInterval(checkOutDuration)
            if checkOutEnd <= dayEnd {
                blocks.append(TimeBlock(
                    type: .activity,
                    startTime: currentTime,
                    endTime: checkOutEnd,
                    title: "辦理退房",
                    location: context?.accommodationAddress ?? accAddr,
                    isAnchor: false,
                    priority: 6,
                    description: "Check-out 後處理行李（可寄存或隨身攜帶）。若攜帶行李，建議安排室內、交通便利的活動。"
                ))
                currentTime = checkOutEnd
            }
        }
        
        // MARK: - 中間天數：從住宿出發
        if !isFirstDay && hasAccommodation, let firstActivity = aiDay.activities.first,
           let firstLocation = firstActivity.location, !firstLocation.isEmpty,
           !(firstActivity.category.contains("餐厅") || firstActivity.category.contains("Restaurant")) {
            let transitFromAccommodation: TimeInterval = 30 * 60
            let transitEnd = currentTime.addingTimeInterval(transitFromAccommodation)
            if transitEnd <= dayEnd {
                blocks.append(TimeBlock(
                    type: .transit,
                    startTime: currentTime,
                    endTime: transitEnd,
                    title: "從住宿前往 \(firstActivity.title)",
                    location: firstLocation,
                    isAnchor: false,
                    priority: 6,
                    description: "考慮住宿與行程距離，預留交通時間"
                ))
                currentTime = transitEnd
            }
        }
        
        for (index, activity) in aiDay.activities.enumerated() {
            // 如果不是第一个活动，添加交通时间
            // 但前往餐厅的交通不需要添加（因为餐厅已经跳转地图可以直接导航过去）
            if index > 0 {
                let previousActivity = aiDay.activities[index - 1]
                let isCurrentRestaurant = activity.category.contains("餐厅") || 
                                         activity.category.contains("Restaurant") ||
                                         activity.title.contains("餐廳") ||
                                         activity.title.contains("餐厅") ||
                                         activity.title.contains("restaurant") ||
                                         activity.title.contains("美食") ||
                                         activity.title.contains("午餐") ||
                                         activity.title.contains("晚餐") ||
                                         activity.title.contains("早餐")
                
                let isPreviousRestaurant = previousActivity.category.contains("餐厅") || 
                                          previousActivity.category.contains("Restaurant") ||
                                          previousActivity.title.contains("餐廳") ||
                                          previousActivity.title.contains("餐厅") ||
                                          previousActivity.title.contains("restaurant") ||
                                          previousActivity.title.contains("美食") ||
                                          previousActivity.title.contains("午餐") ||
                                          previousActivity.title.contains("晚餐") ||
                                          previousActivity.title.contains("早餐")
                
                // 如果当前活动是餐厅，不添加前往餐厅的交通块（用户会通过地图导航）
                if isCurrentRestaurant {
                    // 不添加交通块，直接继续
                }
                // 如果前一个活动是餐厅，当前活动是景点，添加"从餐厅到下一个景点"的交通块，需要实时确认
                else if isPreviousRestaurant {
                    // 从餐厅到下一个景点：添加一个特殊的交通块，标记需要实时确认
                    // 这个交通块会在 PlanDetailView 中通过GPS实时更新
                    let transitDuration: TimeInterval = 30 * 60  // 默认30分钟，会被实时更新
                    let transitEnd = currentTime.addingTimeInterval(transitDuration)
                    
                    if transitEnd <= dayEnd {
                        // 在 description 中标记这是从餐厅出发的交通，需要实时确认
                        var transitDescription = "从餐厅前往下一地点（实时GPS确认）"
                        if let transport = aiDay.transportation?[safe: index - 1] {
                            transitDescription += "\n\(transport)"
                        }
                        
                        blocks.append(TimeBlock(
                            type: .transit,
                            startTime: currentTime,
                            endTime: transitEnd,
                            title: "从餐厅前往下一地点",
                            location: activity.location,  // 设置目标地点，用于GPS导航计算
                            isAnchor: false,
                            priority: 5,
                            description: transitDescription
                        ))
                        currentTime = transitEnd
                    }
                }
                // 其他情况：正常添加交通时间块（含目標地點以供 PlanDetailView 計算實際交通時間）
                else {
                    let transitDuration: TimeInterval = 30 * 60
                    let transitEnd = currentTime.addingTimeInterval(transitDuration)
                    let destLocation = activity.location
                    
                    if transitEnd <= dayEnd {
                        var desc = aiDay.transportation?[safe: index - 1] ?? ""
                        if let pref = context?.transportPreference, !desc.contains(pref.rawValue) {
                            desc = "\(pref.rawValue) · \(desc)".trimmingCharacters(in: .whitespaces)
                        }
                        blocks.append(TimeBlock(
                            type: .transit,
                            startTime: currentTime,
                            endTime: transitEnd,
                            title: "前往下一地点",
                            location: destLocation,
                            isAnchor: false,
                            priority: 5,
                            description: desc.isEmpty ? nil : desc
                        ))
                        currentTime = transitEnd
                    }
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
            
            // 计算活动时长（餐饮类型需要根据人数和节奏调整）
            var activityDuration = TimeInterval(activity.recommendedDuration * 60)
            
            // 如果是餐饮类型，根据人数和节奏调整时间
            let isRestaurant = activity.category.contains("餐厅") || 
                              activity.category.contains("Restaurant") ||
                              activity.title.contains("餐廳") ||
                              activity.title.contains("餐厅") ||
                              activity.title.contains("restaurant") ||
                              activity.title.contains("美食") ||
                              activity.title.contains("午餐") ||
                              activity.title.contains("晚餐") ||
                              activity.title.contains("早餐")
            
            if isRestaurant {
                let adultsCount = adults ?? 1
                let childrenCount = children ?? 0
                let totalPeople = adultsCount + childrenCount
                
                // 基础餐饮时间（分钟）
                var baseMealTime: Int = 60
                
                // 根据人数调整
                if totalPeople <= 2 {
                    baseMealTime = 60
                } else if totalPeople <= 4 {
                    baseMealTime = 75
                } else if totalPeople <= 6 {
                    baseMealTime = 90
                } else {
                    baseMealTime = 120
                }
                
                // 有小孩的家庭需要额外时间
                if childrenCount > 0 {
                    baseMealTime += 15 + (childrenCount * 5)  // 每个小孩额外5分钟
                }
                
                // 根据节奏调整
                let paceMultiplier: Double
                switch pace {
                case .relaxed:
                    paceMultiplier = 1.2  // 宽松节奏，可以延长20%
                case .tight:
                    paceMultiplier = 0.9  // 紧凑节奏，可以缩短10%，但不少于基础时间
                case .moderate:
                    paceMultiplier = 1.0
                }
                
                let adjustedMealTime = Int(Double(baseMealTime) * paceMultiplier)
                activityDuration = TimeInterval(adjustedMealTime * 60)  // 转换为秒
                
                print("🍽️ [餐饮时间计算] \(activity.title): 人数=\(totalPeople)(\(adultsCount)大人+\(childrenCount)小孩), 节奏=\(pace.rawValue), 基础=\(baseMealTime)分钟, 调整后=\(adjustedMealTime)分钟")
            }
            
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
                
                // 如果是餐饮类型，不设置location（节省AI使用，用户通过地图应用查找）
                let finalLocation: String? = isRestaurant ? nil : activity.location
                
                blocks.append(TimeBlock(
                    type: .activity,
                    startTime: currentTime,
                    endTime: finalEnd,
                    title: activity.title,
                    location: finalLocation,
                    isAnchor: false,
                    priority: 7,
                    description: description
                ))
                
                currentTime = finalEnd
            }
            
            if activityEnd >= dayEnd { break }
        }
        
        // MARK: - 每日結束：返回住宿（考慮住宿與行程距離）
        if hasAccommodation && !isLastDay, let lastActivityWithLocation = aiDay.activities.last(where: { $0.location != nil && !($0.location?.isEmpty ?? true) }) {
            let returnTransitDuration: TimeInterval = 30 * 60
            let returnEnd = currentTime.addingTimeInterval(returnTransitDuration)
            if returnEnd <= dayEnd {
                blocks.append(TimeBlock(
                    type: .transit,
                    startTime: currentTime,
                    endTime: returnEnd,
                    title: "返回住宿",
                    location: context?.accommodationAddress ?? accAddr,
                    isAnchor: false,
                    priority: 5,
                    description: "從最後景點返回住宿，預留交通時間"
                ))
                currentTime = returnEnd
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
