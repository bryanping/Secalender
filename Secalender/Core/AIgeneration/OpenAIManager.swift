
import Foundation

// 注意：ScheduleItem 在 ScheduleItem.swift 中定义
// 确保项目结构正确，ScheduleItem 可以被访问

final class OpenAIManager {
    static let shared = OpenAIManager()
    private init() {}

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
                print("⚠️ [OpenAI] 从环境变量读取 API Key")
                return envKey
            }
            
            // 如果都无法读取，抛出错误而不是 fatalError
            let errorMessage = """
            ⚠️ OpenAI API Key 未配置
            
            请检查以下配置：
            1. Secrets.xcconfig 文件中的 OPENAI_API_KEY 是否已设置
            2. Info.plist 中是否包含 OPENAI_API_KEY = $(OPENAI_API_KEY)
            3. Xcode 项目 Build Settings 中是否正确引用了 Secrets.xcconfig
            
            当前 Info.plist 中的值: \(Bundle.main.infoDictionary?["OPENAI_API_KEY"] ?? "nil")
            """
            throw NSError(
                domain: "OpenAIManager",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: errorMessage]
            )
        }
    }

    /// 根據使用者輸入的提示請求 OpenAI 產生行程計畫，
    /// 回傳 ScheduleItem 陣列（日期格式須為 yyyy-MM-dd，時間為 HH:mm）。
    func generateSchedule(prompt: String) async throws -> [ScheduleItem] {
        // 获取 API Key
        let key = try apiKey
        
        // 構建請求
        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
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
            "model": "gpt-4o-mini",
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
    
    /// 获取实际使用的语言（如果 currentLanguage 是 .system，则返回系统语言）
    @MainActor
    private func getActiveLanguage() -> AppLanguage {
        let current = LocalizationManager.shared.currentLanguage
        if current == .system {
            // 如果选择跟随系统，则根据系统语言返回实际语言
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
        return current
    }
    
    /// 根据 prompt 长度和语言动态计算超时时间
    /// - Parameters:
    ///   - prompt: 用户输入的 prompt
    ///   - language: 当前语言环境
    ///   - baseTimeout: 基础超时时间（默认 90 秒）
    /// - Returns: 计算后的超时时间（秒）
    private func calculateTimeout(prompt: String, language: AppLanguage, baseTimeout: TimeInterval = 90.0) -> TimeInterval {
        // 基础超时
        var timeout = baseTimeout
        
        // 根据 prompt 长度增加超时（每 100 字符增加 5 秒）
        let promptLengthFactor = Double(prompt.count) / 100.0 * 5.0
        timeout += promptLengthFactor
        
        // 根据语言类型调整（中文、日文等需要更多 token 处理时间）
        let languageFactor: TimeInterval
        switch language {
        case .simplifiedChinese, .traditionalChinese, .japanese:
            // 中文字符和日文字符通常需要更多处理时间
            languageFactor = 20.0
        case .german, .french, .spanish:
            // 欧洲语言稍微增加
            languageFactor = 10.0
        case .english, .system:
            // 英语作为基准
            languageFactor = 0.0
        }
        timeout += languageFactor
        
        // 设置上限（最多 180 秒）和下限（至少 60 秒）
        timeout = max(60.0, min(timeout, 180.0))
        
        print("⏱️ [OpenAI] 超时计算: 基础=\(Int(baseTimeout))s, prompt长度=\(prompt.count)字符(+\(String(format: "%.1f", promptLengthFactor))s), 语言因子=+\(Int(languageFactor))s, 最终=\(Int(timeout))s")
        
        return timeout
    }
    
    /// 生成结构化的行程JSON（用于AITripGenerator）
    /// - Note: 国外目的地通常返回更长、更复杂的 JSON（真实地名+地址+多天行程），网络 RTT 也可能更高，因此默认超时设置更长，并在超时场景做一次安全重试。
    func generateStructuredItinerary(prompt: String, timeout: TimeInterval? = nil) async throws -> String {
        print("🤖 [OpenAI] generateStructuredItinerary 开始调用...")
        
        // apiKey 从 Info.plist 读取（通过 Secrets.xcconfig 配置）
        // 如果配置有问题，会抛出错误而不是 fatalError
        let key: String
        do {
            key = try apiKey
        } catch {
            print("❌ [OpenAI] API Key 读取失败: \(error.localizedDescription)")
            throw error
        }
        guard !key.isEmpty else {
            print("❌ [OpenAI] API Key 为空")
            throw NSError(domain: "OpenAIManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "API Key未配置，请检查 Secrets.xcconfig 和 Info.plist 配置"])
        }
        
        print("✅ [OpenAI] API Key 已加载（长度: \(key.count) 字符）")
        
        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            throw URLError(.badURL)
        }
        
        // 根据当前语言环境生成 system prompt 和计算超时
        let language = await MainActor.run {
            getActiveLanguage()
        }
        
        // 动态计算超时时间（如果未指定）
        let calculatedTimeout = timeout ?? calculateTimeout(prompt: prompt, language: language)
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = calculatedTimeout
        request.addValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        // 获取优化后的 system prompt（包含核心规则 + JSON schema + 示例）
        let systemPrompt = getOptimizedSystemPrompt(for: language)
        
        let messages: [[String: String]] = [
            ["role": "system", "content": systemPrompt],
            ["role": "user", "content": prompt]
        ]
        
        let body: [String: Any] = [
            "model": "gpt-4o",
            "messages": messages,
            "temperature": 0.8,  // 稍微提高创造性
            "max_tokens": 4000   // 增加token以支持完整的JSON响应
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        print("🤖 [OpenAI] 发送请求到 OpenAI API...")
        print("🤖 [OpenAI] 模型: gpt-4o, Temperature: 0.8, Max Tokens: 4000, 超时: \(Int(calculatedTimeout))秒, prompt长度: \(prompt.count)字符")
        
        // 发送请求（带超时处理 + 超时重试1次）
        let maxAttempts = 2
        var lastError: Error?
        var data: Data = Data()
        var response: URLResponse = URLResponse()
        
        for attempt in 1...maxAttempts {
            let attemptStart = Date()
            do {
                // 在重试时适当增加超时上限（避免国外目的地偶发慢响应）
                if attempt > 1 {
                    let increasedTimeout = min(calculatedTimeout + 60.0, 180.0)
                    request.timeoutInterval = increasedTimeout
                    print("🔁 [OpenAI] 第\(attempt)/\(maxAttempts)次尝试（上次超时），提高超时到 \(Int(increasedTimeout))秒后重试…")
                }
                
                (data, response) = try await URLSession.shared.data(for: request)
                let elapsed = Date().timeIntervalSince(attemptStart)
                print("✅ [OpenAI] 收到响应（第\(attempt)/\(maxAttempts)次），耗时: \(String(format: "%.2f", elapsed))秒")
                break
            } catch {
                lastError = error
                
                if let urlError = error as? URLError {
                    if urlError.code == .timedOut {
                        let elapsed = Date().timeIntervalSince(attemptStart)
                        print("❌ [OpenAI] 请求超时（第\(attempt)/\(maxAttempts)次，耗时: \(String(format: "%.2f", elapsed))秒）")
                        
                        if attempt < maxAttempts {
                            // 轻微退避，避免瞬时网络抖动/拥塞
                            try? await Task.sleep(nanoseconds: 600_000_000) // 0.6s
                            continue
                        }
                        
                        throw NSError(
                            domain: "OpenAIManager",
                            code: -408,
                            userInfo: [NSLocalizedDescriptionKey: "生成行程请求超时（已重试\(maxAttempts - 1)次，超时设置: \(Int(calculatedTimeout))秒）。国外目的地通常需要更长时间生成完整JSON。请检查网络，或减少天数/精简偏好后重试。"]
                        )
                    } else {
                        print("❌ [OpenAI] 网络错误: \(urlError.localizedDescription)")
                        throw NSError(
                            domain: "OpenAIManager",
                            code: urlError.code.rawValue,
                            userInfo: [NSLocalizedDescriptionKey: "网络错误: \(urlError.localizedDescription)"]
                        )
                    }
                }
                
                // 非 URLError 直接抛出
                throw error
            }
        }
        
        // 防御：如果循环结束仍没有有效 response/data
        if let lastError = lastError, data.isEmpty {
            throw lastError
        }
        
        // 检查HTTP状态
        if let httpResponse = response as? HTTPURLResponse {
            if httpResponse.statusCode != 200 {
                var detailedError: String = "HTTP错误: \(httpResponse.statusCode)"
                var errorCode: Int = httpResponse.statusCode
                
                if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let errorInfo = errorData["error"] as? [String: Any],
                   let errorMessage = errorInfo["message"] as? String {
                    detailedError = errorMessage
                    
                    // 特殊处理配额错误（429）
                    if httpResponse.statusCode == 429 {
                        if errorMessage.contains("quota") || errorMessage.contains("billing") {
                            detailedError = """
                            OpenAI API 配额已用完
                            可能的原因：
                            1. API Key 的额度已用完
                            2. 账户未绑定付款方式
                            3. 免费额度已用尽
                            解决方案：
                            1. 检查 OpenAI 账户余额：https://platform.openai.com/account/billing
                            2. 绑定付款方式或充值
                            3. 等待配额重置（如果是免费额度）
                            4. 或使用其他 API Key
                            """
                            errorCode = -429  // 使用负值表示特殊错误
                        }
                    }
                    
                    // 特殊处理"Country, region, or territory not supported"错误
                    if errorMessage.contains("Country") && (errorMessage.contains("region") || errorMessage.contains("territory")) && errorMessage.contains("not supported") {
                        detailedError = """
                        生成行程失败：目的地不支持
                        可能的原因：
                        1. 目的地格式不正确
                        2. OpenAI 无法识别该目的地
                        3. 目的地不在 OpenAI 支持的地区列表中
                        解决方案：
                        1. 请尝试使用更标准的目的地名称（例如："東京, 日本" 而不是 "日本 - 東京"）
                        2. 检查目的地拼写是否正确
                        3. 如果问题持续，请联系技术支持
                        """
                        errorCode = -400  // 使用负值表示特殊错误
                    }
                    
                    throw NSError(domain: "OpenAIManager", code: errorCode, userInfo: [NSLocalizedDescriptionKey: detailedError])
                }
                throw NSError(domain: "OpenAIManager", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "HTTP错误: \(httpResponse.statusCode)"])
            }
        }
        
        // 解析响应
        guard
            let responseObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let choices = responseObject["choices"] as? [[String: Any]],
            let first = choices.first,
            let message = first["message"] as? [String: Any],
            let content = message["content"] as? String
        else {
            // 打印原始响应以便调试
            if let responseString = String(data: data, encoding: .utf8) {
                print("❌ [OpenAI] 无法解析响应，原始内容: \(responseString)")
            }
            throw NSError(domain: "OpenAIManager", code: 0, userInfo: [NSLocalizedDescriptionKey: "无法解析OpenAI响应"])
        }
        
        print("✅ [OpenAI] 收到内容，长度: \(content.count) 字符")
        print("📄 [OpenAI] 内容预览（前500字符）: \(String(content.prefix(500)))")
        
        // 尝试解析并验证 JSON schema，如果失败则尝试自动修复
        var cleanedContent = content
        if let jsonData = cleanedContent.data(using: .utf8) {
            // 首先尝试直接解析
            if let jsonObject = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                if validateAITripPlanSchema(jsonObject) {
                    print("✅ [OpenAI] JSON Schema 验证通过")
                } else {
                    print("⚠️ [OpenAI] JSON Schema 验证失败，但继续处理（可能缺少部分可选字段）")
                }
            } else {
                // JSON 解析失败，尝试自动修复
                print("🔧 [OpenAI] JSON 解析失败，尝试自动修复...")
                if let fixedContent = try? autoCorrectJSON(cleanedContent) {
                    cleanedContent = fixedContent
                    print("✅ [OpenAI] JSON 自动修复成功")
                    
                    // 再次验证修复后的 JSON
                    if let fixedData = cleanedContent.data(using: .utf8),
                       let fixedObject = try? JSONSerialization.jsonObject(with: fixedData) as? [String: Any] {
                        if validateAITripPlanSchema(fixedObject) {
                            print("✅ [OpenAI] 修复后 JSON Schema 验证通过")
                        } else {
                            print("⚠️ [OpenAI] 修复后 JSON Schema 验证仍失败，但继续处理")
                        }
                    }
                } else {
                    print("❌ [OpenAI] JSON 自动修复失败")
                }
            }
        }
        
        return cleanedContent
    }
    
    /// 自动修复常见的 JSON 问题
    /// - Parameter jsonString: 原始 JSON 字符串
    /// - Returns: 修复后的 JSON 字符串
    private func autoCorrectJSON(_ jsonString: String) throws -> String {
        var fixed = jsonString.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 移除 markdown 代码块标记
        if fixed.hasPrefix("```json") {
            fixed = String(fixed.dropFirst(7))
        } else if fixed.hasPrefix("```") {
            fixed = String(fixed.dropFirst(3))
        }
        if fixed.hasSuffix("```") {
            fixed = String(fixed.dropLast(3))
        }
        fixed = fixed.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 移除尾随逗号（在 } 或 ] 之前）
        fixed = fixed.replacingOccurrences(of: ",\\s*\\}", with: "}", options: .regularExpression)
        fixed = fixed.replacingOccurrences(of: ",\\s*\\]", with: "]", options: .regularExpression)
        
        // 修复单引号（JSON 要求双引号）
        // 但要注意不要破坏字符串内容中的单引号，只修复键名和值
        // 这里使用更保守的方法：只修复明显的键名和值边界
        fixed = fixed.replacingOccurrences(of: "'([^']*)':", with: "\"$1\":", options: .regularExpression)
        fixed = fixed.replacingOccurrences(of: ":\\s*'([^']*)'", with: ": \"$1\"", options: .regularExpression)
        
        // 尝试提取 JSON 对象（如果被其他文本包围）
        if let jsonStart = fixed.range(of: "\\{", options: .regularExpression),
           let jsonEnd = fixed.range(of: "\\}", options: [.regularExpression, .backwards]) {
            let startIndex = fixed.index(jsonStart.lowerBound, offsetBy: 0)
            let endIndex = fixed.index(jsonEnd.upperBound, offsetBy: 0)
            fixed = String(fixed[startIndex..<endIndex])
        }
        
        // 验证修复后的 JSON 是否有效
        guard let _ = try? JSONSerialization.jsonObject(with: fixed.data(using: .utf8) ?? Data()) else {
            throw NSError(domain: "OpenAIManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "JSON 自动修复失败：修复后仍无法解析"])
        }
        
        return fixed
    }
    
    /// 验证 AITripPlan JSON Schema
    /// - Parameter dict: 解析后的 JSON 字典
    /// - Returns: 是否符合 schema
    private func validateAITripPlanSchema(_ dict: [String: Any]) -> Bool {
        // 验证顶层字段
        guard dict["destination"] is String,
              dict["startDate"] is String,
              dict["endDate"] is String,
              dict["days"] is [[String: Any]],
              dict["generalTips"] is [String] else {
            print("❌ [Schema] 顶层字段验证失败")
            return false
        }
        
        // 验证 days 数组中的每个 day
        if let days = dict["days"] as? [[String: Any]] {
            for (index, day) in days.enumerated() {
                guard day["date"] is String,
                      day["daySummary"] is String,
                      day["activities"] is [[String: Any]] else {
                    print("❌ [Schema] Day \(index) 基本字段验证失败")
                    return false
                }
                
                // 验证 activities 数组中的每个 activity
                if let activities = day["activities"] as? [[String: Any]] {
                    for (actIndex, activity) in activities.enumerated() {
                        guard activity["title"] is String,
                              activity["location"] is String,
                              activity["description"] is String,
                              activity["category"] is String,
                              activity["recommendedDuration"] is Int else {
                            print("❌ [Schema] Day \(index), Activity \(actIndex) 必需字段验证失败")
                            return false
                        }
                    }
                }
            }
        }
        
        return true
    }
    
    /// 获取优化后的 system prompt（核心规则 + JSON Schema + 示例）
    private func getOptimizedSystemPrompt(for language: AppLanguage) -> String {
        let coreRules = getCorePlanningRules(for: language)
        let jsonSchema = getJSONSchemaDescription(for: language)
        let jsonExample = getJSONExample(for: language)
        
        return coreRules + "\n\n" + jsonSchema + "\n\n" + jsonExample
    }
    
    /// 获取核心规划规则（不包含 JSON 格式说明）
    private func getCorePlanningRules(for language: AppLanguage) -> String {
        switch language {
        case .simplifiedChinese, .traditionalChinese:
            return """
            你是一位顶级的旅游行程规划师，拥有深厚的城市文化理解力和丰富的旅行经验。
            
            你的规划理念：
            1. 城市不是"景点集合"，而是"结构"和"记忆"的载体
            2. 行程设计不是塞满活动，而是创造"感受转换"和"记忆锚点"
            3. 每个安排都要有"思路"和"为什么"，不只是列出地点
            4. 避免走马看花，追求深度体验和城市理解
            
            你的规划风格：
            - 每天有明确的主题和关键词（如"城市记忆"、"租界文化"、"现代高度"）
            - 每个时间段都有"思路"说明，解释为什么这样安排
            - 提供具体、真实的地点名称（如"外滩"、"武康路"、"豫园"），不是泛泛的"景点参观"
            - 考虑地理位置和路线逻辑，避免来回折返
            - 根据节奏合理安排，不走马看花
            - 包含文化背景、城市理解、生活美学等深度内容
            
            重要：地点名称语言要求
            - 如果目的地国家的主要语言不是中文（例如：巴西使用葡萄牙语，西班牙使用西班牙语），则所有地点名称（title 和 location 字段）必须使用该国家的本地语言
            - 这确保了地点名称的准确性和可搜索性，避免因翻译导致的搜索失败
            - 描述和其他文本内容可以使用中文，但地点名称必须使用目的地本地语言
            """
        case .english:
            return """
            You are a top-tier travel itinerary planner with deep understanding of city culture and rich travel experience.
            
            Your planning philosophy:
            1. Cities are not "collections of attractions", but carriers of "structure" and "memory"
            2. Itinerary design is not about filling activities, but creating "feeling transitions" and "memory anchors"
            3. Every arrangement must have "rationale" and "why", not just listing places
            4. Avoid rushed sightseeing, pursue deep experiences and city understanding
            
            Your planning style:
            - Each day has clear themes and keywords (e.g., "City Memories", "Colonial Culture", "Modern Heights")
            - Each time slot has "rationale" explanation, explaining why arranged this way
            - Provide specific, real location names (e.g., "The Bund", "Wukang Road", "Yu Garden"), not generic "sightseeing visit"
            - Consider geographic location and route logic, avoid back-and-forth
            - Arrange reasonably according to pace, not rushed
            - Include cultural background, city understanding, life aesthetics and other deep content
            
            CRITICAL: Location Name Language Requirement
            - If the destination country's primary language is not English (e.g., Brazil uses Portuguese, Spain uses Spanish, France uses French), all location names (title and location fields) MUST use that country's local language
            - For example: If destination is Brazil, use Portuguese names like "Copacabana", "Ipanema", "Cristo Redentor", not English translations
            - This ensures accuracy and searchability of location names, avoiding search failures due to translation
            - Descriptions and other text content can be in English, but location names MUST be in the destination's local language
            """
        case .german:
            return """
            Sie sind ein erstklassiger Reiseroutenplaner mit tiefem Verständnis für Stadtkultur und reicher Reiseerfahrung.
            
            Ihre Planungsphilosophie:
            1. Städte sind keine "Sammlungen von Sehenswürdigkeiten", sondern Träger von "Struktur" und "Erinnerung"
            2. Reiserouten-Design ist nicht das Auffüllen von Aktivitäten, sondern das Schaffen von "Gefühlsübergängen" und "Erinnerungsankern"
            3. Jede Anordnung muss "Begründung" und "Warum" haben, nicht nur Orte auflisten
            4. Vermeiden Sie übereilte Besichtigungen, streben Sie tiefe Erfahrungen und Stadtverständnis an
            
            Ihr Planungsstil:
            - Jeder Tag hat klare Themen und Schlüsselwörter
            - Jeder Zeitabschnitt hat "Begründung", erklärt warum so angeordnet
            - Bieten Sie spezifische, echte Ortsnamen, keine generischen "Sehenswürdigkeitsbesuche"
            - Berücksichtigen Sie geografische Lage und Routenlogik, vermeiden Sie Hin- und Her-Reisen
            
            Wichtig: Ortsnamensprache
            - Wenn die Hauptsprache des Ziellandes nicht Deutsch ist, müssen alle Ortsnamen (title und location Felder) die lokale Sprache des Ziellandes verwenden
            """
        case .french:
            return """
            Vous êtes un planificateur d'itinéraires de voyage de premier plan avec une compréhension profonde de la culture urbaine et une riche expérience de voyage.
            
            Votre philosophie de planification:
            1. Les villes ne sont pas des "collections d'attractions", mais des porteurs de "structure" et de "mémoire"
            2. La conception d'itinéraire n'est pas de remplir les activités, mais de créer des "transitions de sentiment" et des "ancres de mémoire"
            3. Chaque arrangement doit avoir une "justification" et un "pourquoi", pas seulement lister les lieux
            4. Évitez les visites précipitées, poursuivez des expériences profondes et la compréhension de la ville
            
            Votre style de planification:
            - Chaque jour a des thèmes et mots-clés clairs
            - Chaque créneau horaire a une "justification", explique pourquoi arrangé ainsi
            - Fournissez des noms de lieux spécifiques et réels, pas de "visite touristique" générique
            """
        case .spanish:
            return """
            Eres un planificador de itinerarios de viaje de primer nivel con una comprensión profunda de la cultura urbana y una rica experiencia de viaje.
            
            Tu filosofía de planificación:
            1. Las ciudades no son "colecciones de atracciones", sino portadores de "estructura" y "memoria"
            2. El diseño del itinerario no es llenar actividades, sino crear "transiciones de sentimiento" y "anclas de memoria"
            3. Cada arreglo debe tener "justificación" y "por qué", no solo listar lugares
            4. Evita las visitas apresuradas, busca experiencias profundas y comprensión de la ciudad
            
            Tu estilo de planificación:
            - Cada día tiene temas y palabras clave claros
            - Cada franja horaria tiene "justificación", explica por qué arreglado así
            - Proporciona nombres de lugares específicos y reales, no "visita turística" genérica
            """
        case .japanese:
            return """
            あなたは、都市文化への深い理解と豊富な旅行経験を持つトップクラスの旅行旅程プランナーです。
            
            あなたの計画理念：
            1. 都市は「観光スポットの集合」ではなく、「構造」と「記憶」の担い手です
            2. 旅程設計は活動を詰め込むことではなく、「感情の転換」と「記憶のアンカー」を作り出すことです
            3. 各配置には「論理」と「なぜ」が必要で、単に場所をリストアップするだけではありません
            4. 急がせた観光を避け、深い体験と都市理解を追求します
            
            あなたの計画スタイル：
            - 各日には明確なテーマとキーワードがあります（例：「都市の記憶」、「植民地文化」、「モダンな高さ」）
            - 各時間帯には「論理」の説明があり、なぜこのように配置したかを説明します
            - 具体的で実在する場所名を提供します（例：「外灘」、「武康路」、「豫園」）、汎用的な「観光スポット訪問」ではありません
            - 地理的位置とルートの論理を考慮し、往復を避けます
            - ペースに応じて合理的に配置し、急がせません
            - 文化的背景、都市理解、生活美学などの深い内容を含めます
            
            重要：場所名の言語要件
            - 目的地の国の主要言語が日本語でない場合、すべての場所名（titleとlocationフィールド）はその国のローカル言語を使用する必要があります
            """
        case .system:
            return """
            You are a top-tier travel itinerary planner with deep understanding of city culture and rich travel experience.
            
            Your planning philosophy:
            1. Cities are not "collections of attractions", but carriers of "structure" and "memory"
            2. Itinerary design is not about filling activities, but creating "feeling transitions" and "memory anchors"
            3. Every arrangement must have "rationale" and "why", not just listing places
            4. Avoid rushed sightseeing, pursue deep experiences and city understanding
            
            Your planning style:
            - Each day has clear themes and keywords (e.g., "City Memories", "Colonial Culture", "Modern Heights")
            - Each time slot has "rationale" explanation, explaining why arranged this way
            - Provide specific, real location names (e.g., "The Bund", "Wukang Road", "Yu Garden"), not generic "sightseeing visit"
            - Consider geographic location and route logic, avoid back-and-forth
            - Arrange reasonably according to pace, not rushed
            - Include cultural background, city understanding, life aesthetics and other deep content
            
            CRITICAL: Location Name Language Requirement
            - If the destination country's primary language is not English (e.g., Brazil uses Portuguese, Spain uses Spanish, France uses French), all location names (title and location fields) MUST use that country's local language
            - For example: If destination is Brazil, use Portuguese names like "Copacabana", "Ipanema", "Cristo Redentor", not English translations
            - This ensures accuracy and searchability of location names, avoiding search failures due to translation
            - Descriptions and other text content can be in English, but location names MUST be in the destination's local language
            """
        }
    }
    
    /// 获取 JSON Schema 描述（字段定义和限制）
    private func getJSONSchemaDescription(for language: AppLanguage) -> String {
        switch language {
        case .simplifiedChinese, .traditionalChinese:
            return """
            【JSON Schema 定义】
            请严格按照以下 JSON Schema 返回数据：
            
            顶层对象：
            - destination (string, 必需): 目的地名称
            - startDate (string, 必需): 开始日期，格式 yyyy-MM-dd
            - endDate (string, 必需): 结束日期，格式 yyyy-MM-dd
            - days (array, 必需): 每天的行程数组
            - generalTips (array<string>, 必需): 总体建议数组
            
            days 数组中每个对象：
            - date (string, 必需): 日期，格式 yyyy-MM-dd
            - dayTheme (string, 可选): 当天主题
            - dayKeywords (string, 可选): 关键词
            - daySummary (string, 必需): 当天行程总结
            - activities (array, 必需): 活动数组
            - transportation (array<string>, 可选): 交通建议数组
            
            activities 数组中每个对象（必需字段）：
            - title (string): 活动名称，必须使用目的地本地语言（如果目的地语言与当前语言不同）
            - location (string): 详细地址，必须使用目的地本地语言
            - description (string): 深度描述，使用当前语言
            - category (string): 类别（景点/餐厅/购物/娱乐/文化）
            - recommendedDuration (number): 建议时长（分钟）
            
            activities 可选字段：
            - openingHours (string): 开放时间
            - tips (array<string>): 小贴士数组
            - priceLevel (string): 价格级别（免费/便宜/中等/昂贵）
            - timeSlot (string): 时间段（上午/中午/下午/晚上）
            - rationale (string): 安排思路和逻辑
            """
        case .english:
            return """
            【JSON Schema Definition】
            Please strictly follow this JSON Schema:
            
            Root object:
            - destination (string, required): Destination name
            - startDate (string, required): Start date, format yyyy-MM-dd
            - endDate (string, required): End date, format yyyy-MM-dd
            - days (array, required): Array of daily itineraries
            - generalTips (array<string>, required): General tips array
            
            Each object in days array:
            - date (string, required): Date, format yyyy-MM-dd
            - dayTheme (string, optional): Daily theme
            - dayKeywords (string, optional): Keywords
            - daySummary (string, required): Daily summary
            - activities (array, required): Activities array
            - transportation (array<string>, optional): Transportation suggestions array
            
            Each object in activities array (required fields):
            - title (string): Activity name, MUST use destination's local language if different from current language
            - location (string): Detailed address, MUST use destination's local language
            - description (string): Deep description, use current language
            - category (string): Category (Attraction/Restaurant/Shopping/Entertainment/Culture)
            - recommendedDuration (number): Recommended duration in minutes
            
            Optional fields in activities:
            - openingHours (string): Opening hours
            - tips (array<string>): Tips array
            - priceLevel (string): Price level (Free/Cheap/Moderate/Expensive)
            - timeSlot (string): Time slot (Morning/Noon/Afternoon/Evening)
            - rationale (string): Arrangement rationale and logic
            """
        case .german:
            return """
            【JSON Schema Definition】
            Bitte folgen Sie strikt diesem JSON Schema:
            
            Root-Objekt:
            - destination (string, erforderlich): Zielname
            - startDate (string, erforderlich): Startdatum, Format yyyy-MM-dd
            - endDate (string, erforderlich): Enddatum, Format yyyy-MM-dd
            - days (array, erforderlich): Array von Tagesreiserouten
            - generalTips (array<string>, erforderlich): Allgemeine Tipps-Array
            
            Jedes Objekt im days-Array:
            - date (string, erforderlich): Datum, Format yyyy-MM-dd
            - dayTheme (string, optional): Tages-Thema
            - dayKeywords (string, optional): Schlüsselwörter
            - daySummary (string, erforderlich): Tageszusammenfassung
            - activities (array, erforderlich): Aktivitäten-Array
            - transportation (array<string>, optional): Verkehrsvorschläge-Array
            
            Jedes Objekt im activities-Array (erforderliche Felder):
            - title (string): Aktivitätsname, MUSS die lokale Sprache des Ziels verwenden
            - location (string): Detaillierte Adresse, MUSS die lokale Sprache des Ziels verwenden
            - description (string): Tiefe Beschreibung, verwenden Sie die aktuelle Sprache
            - category (string): Kategorie
            - recommendedDuration (number): Empfohlene Dauer in Minuten
            """
        case .french:
            return """
            【Définition du schéma JSON】
            Veuillez suivre strictement ce schéma JSON:
            
            Objet racine:
            - destination (string, requis): Nom de la destination
            - startDate (string, requis): Date de début, format yyyy-MM-dd
            - endDate (string, requis): Date de fin, format yyyy-MM-dd
            - days (array, requis): Tableau d'itinéraires quotidiens
            - generalTips (array<string>, requis): Tableau de conseils généraux
            
            Chaque objet dans le tableau days:
            - date (string, requis): Date, format yyyy-MM-dd
            - dayTheme (string, optionnel): Thème du jour
            - dayKeywords (string, optionnel): Mots-clés
            - daySummary (string, requis): Résumé quotidien
            - activities (array, requis): Tableau d'activités
            - transportation (array<string>, optionnel): Tableau de suggestions de transport
            """
        case .spanish:
            return """
            【Definición del esquema JSON】
            Por favor siga estrictamente este esquema JSON:
            
            Objeto raíz:
            - destination (string, requerido): Nombre del destino
            - startDate (string, requerido): Fecha de inicio, formato yyyy-MM-dd
            - endDate (string, requerido): Fecha de fin, formato yyyy-MM-dd
            - days (array, requerido): Array de itinerarios diarios
            - generalTips (array<string>, requerido): Array de consejos generales
            
            Cada objeto en el array days:
            - date (string, requerido): Fecha, formato yyyy-MM-dd
            - dayTheme (string, opcional): Tema del día
            - dayKeywords (string, opcional): Palabras clave
            - daySummary (string, requerido): Resumen diario
            - activities (array, requerido): Array de actividades
            - transportation (array<string>, opcional): Array de sugerencias de transporte
            """
        case .japanese:
            return """
            【JSONスキーマ定義】
            以下のJSONスキーマに厳密に従ってください：
            
            ルートオブジェクト：
            - destination (string, 必須): 目的地名
            - startDate (string, 必須): 開始日、形式 yyyy-MM-dd
            - endDate (string, 必須): 終了日、形式 yyyy-MM-dd
            - days (array, 必須): 毎日の旅程配列
            - generalTips (array<string>, 必須): 全体的な提案配列
            
            days配列内の各オブジェクト：
            - date (string, 必須): 日付、形式 yyyy-MM-dd
            - dayTheme (string, オプション): 当日のテーマ
            - dayKeywords (string, オプション): キーワード
            - daySummary (string, 必須): 当日の旅程要約
            - activities (array, 必須): 活動配列
            - transportation (array<string>, オプション): 交通提案配列
            
            activities配列内の各オブジェクト（必須フィールド）：
            - title (string): 活動名、目的地のローカル言語を使用する必要があります
            - location (string): 詳細な住所、目的地のローカル言語を使用する必要があります
            - description (string): 深い説明、現在の言語を使用
            - category (string): カテゴリ（観光スポット/レストラン/ショッピング/エンターテイメント/文化）
            - recommendedDuration (number): 推奨時間（分）
            """
        case .system:
            return """
            【JSON Schema Definition】
            Please strictly follow this JSON Schema:
            
            Root object:
            - destination (string, required): Destination name
            - startDate (string, required): Start date, format yyyy-MM-dd
            - endDate (string, required): End date, format yyyy-MM-dd
            - days (array, required): Array of daily itineraries
            - generalTips (array<string>, required): General tips array
            
            Each object in days array:
            - date (string, required): Date, format yyyy-MM-dd
            - dayTheme (string, optional): Daily theme
            - dayKeywords (string, optional): Keywords
            - daySummary (string, required): Daily summary
            - activities (array, required): Activities array
            - transportation (array<string>, optional): Transportation suggestions array
            
            Each object in activities array (required fields):
            - title (string): Activity name, MUST use destination's local language if different from current language
            - location (string): Detailed address, MUST use destination's local language
            - description (string): Deep description, use current language
            - category (string): Category (Attraction/Restaurant/Shopping/Entertainment/Culture)
            - recommendedDuration (number): Recommended duration in minutes
            """
        }
    }
    
    /// 获取 JSON 示例
    private func getJSONExample(for language: AppLanguage) -> String {
        switch language {
        case .simplifiedChinese, .traditionalChinese:
            return """
            【JSON 示例】
            请参考以下格式返回 JSON：
            {
              "destination": "上海",
              "startDate": "2024-01-17",
              "endDate": "2024-01-19",
              "days": [
                {
                  "date": "2024-01-17",
                  "dayTheme": "经典上海·城市记忆线",
                  "dayKeywords": "历史、城市符号、夜景",
                  "daySummary": "这一天行程的深度总结，说明主题和思路",
                  "activities": [
                    {
                      "title": "外滩",
                      "location": "上海市黄浦区中山东一路",
                      "description": "外滩是城市名片，早上人少、建筑细节清楚，是理解上海历史的最佳起点",
                      "category": "景点",
                      "recommendedDuration": 90,
                      "openingHours": "全天开放",
                      "tips": ["早上人少，适合拍照", "建议步行游览"],
                      "priceLevel": "免费",
                      "timeSlot": "上午",
                      "rationale": "从外滩开始，可以理解上海的历史脉络和城市发展"
                    }
                  ],
                  "transportation": ["地铁2号线到人民广场站"]
                }
              ],
              "generalTips": ["上海不是景点城市，是结构城市", "行程设计不是塞满，而是感受转换"]
            }
            """
        case .english:
            return """
            【JSON Example】
            Please return JSON in the following format:
            {
              "destination": "Shanghai",
              "startDate": "2024-01-17",
              "endDate": "2024-01-19",
              "days": [
                {
                  "date": "2024-01-17",
                  "dayTheme": "Classic Shanghai · City Memory Line",
                  "dayKeywords": "History, City Symbols, Night View",
                  "daySummary": "Deep summary of this day's itinerary, explaining theme and rationale",
                  "activities": [
                    {
                      "title": "The Bund",
                      "location": "Zhongshan East Road, Huangpu District, Shanghai",
                      "description": "The Bund is the city's calling card, fewer people in the morning, clear architectural details, the best starting point to understand Shanghai's history",
                      "category": "Attraction",
                      "recommendedDuration": 90,
                      "openingHours": "Open 24 hours",
                      "tips": ["Fewer people in the morning, good for photography", "Recommended to explore on foot"],
                      "priceLevel": "Free",
                      "timeSlot": "Morning",
                      "rationale": "Starting from The Bund helps understand Shanghai's historical context and urban development"
                    }
                  ],
                  "transportation": ["Metro Line 2 to People's Square Station"]
                }
              ],
              "generalTips": ["Shanghai is not a sightseeing city, it's a structural city", "Itinerary design is not about filling up, but about feeling transitions"]
            }
            """
        case .german:
            return """
            【JSON-Beispiel】
            Bitte geben Sie JSON im folgenden Format zurück:
            {
              "destination": "Shanghai",
              "startDate": "2024-01-17",
              "endDate": "2024-01-19",
              "days": [
                {
                  "date": "2024-01-17",
                  "dayTheme": "Klassisches Shanghai",
                  "daySummary": "Zusammenfassung des Tages",
                  "activities": [
                    {
                      "title": "Der Bund",
                      "location": "Zhongshan East Road, Huangpu District, Shanghai",
                      "description": "Der Bund ist das Wahrzeichen der Stadt",
                      "category": "Sehenswürdigkeit",
                      "recommendedDuration": 90
                    }
                  ]
                }
              ],
              "generalTips": ["Shanghai ist eine Struktur-Stadt"]
            }
            """
        case .french:
            return """
            【Exemple JSON】
            Veuillez retourner JSON au format suivant:
            {
              "destination": "Shanghai",
              "startDate": "2024-01-17",
              "endDate": "2024-01-19",
              "days": [
                {
                  "date": "2024-01-17",
                  "dayTheme": "Shanghai classique",
                  "daySummary": "Résumé de la journée",
                  "activities": [
                    {
                      "title": "Le Bund",
                      "location": "Zhongshan East Road, Huangpu District, Shanghai",
                      "description": "Le Bund est la carte de visite de la ville",
                      "category": "Attraction",
                      "recommendedDuration": 90
                    }
                  ]
                }
              ],
              "generalTips": ["Shanghai est une ville structurelle"]
            }
            """
        case .spanish:
            return """
            【Ejemplo JSON】
            Por favor devuelva JSON en el siguiente formato:
            {
              "destination": "Shanghai",
              "startDate": "2024-01-17",
              "endDate": "2024-01-19",
              "days": [
                {
                  "date": "2024-01-17",
                  "dayTheme": "Shanghai clásico",
                  "daySummary": "Resumen del día",
                  "activities": [
                    {
                      "title": "El Bund",
                      "location": "Zhongshan East Road, Huangpu District, Shanghai",
                      "description": "El Bund es la tarjeta de visita de la ciudad",
                      "category": "Atracción",
                      "recommendedDuration": 90
                    }
                  ]
                }
              ],
              "generalTips": ["Shanghai es una ciudad estructural"]
            }
            """
        case .japanese:
            return """
            【JSON例】
            以下の形式でJSONを返してください：
            {
              "destination": "上海",
              "startDate": "2024-01-17",
              "endDate": "2024-01-19",
              "days": [
                {
                  "date": "2024-01-17",
                  "dayTheme": "クラシック上海・都市記憶線",
                  "dayKeywords": "歴史、都市シンボル、夜景",
                  "daySummary": "この日の旅程の深い要約、テーマと論理を説明",
                  "activities": [
                    {
                      "title": "外灘",
                      "location": "上海市黄浦区中山东一路",
                      "description": "外灘は都市の名刺、朝は人が少なく、建築の細部がはっきりしており、上海の歴史を理解する最良の出発点",
                      "category": "観光スポット",
                      "recommendedDuration": 90,
                      "openingHours": "24時間開放",
                      "tips": ["朝は人が少なく、写真撮影に適している", "徒歩での探索を推奨"],
                      "priceLevel": "無料",
                      "timeSlot": "午前",
                      "rationale": "外灘から始めることで、上海の歴史的文脈と都市発展を理解できる"
                    }
                  ],
                  "transportation": ["地下鉄2号線で人民広場駅へ"]
                }
              ],
              "generalTips": ["上海は観光スポット都市ではなく、構造都市", "旅程設計は詰め込むことではなく、感情の転換を感じること"]
            }
            """
        case .system:
            return """
            【JSON Example】
            Please return JSON in the following format:
            {
              "destination": "Shanghai",
              "startDate": "2024-01-17",
              "endDate": "2024-01-19",
              "days": [
                {
                  "date": "2024-01-17",
                  "dayTheme": "Classic Shanghai · City Memory Line",
                  "dayKeywords": "History, City Symbols, Night View",
                  "daySummary": "Deep summary of this day's itinerary, explaining theme and rationale",
                  "activities": [
                    {
                      "title": "The Bund",
                      "location": "Zhongshan East Road, Huangpu District, Shanghai",
                      "description": "The Bund is the city's calling card, fewer people in the morning, clear architectural details, the best starting point to understand Shanghai's history",
                      "category": "Attraction",
                      "recommendedDuration": 90,
                      "openingHours": "Open 24 hours",
                      "tips": ["Fewer people in the morning, good for photography", "Recommended to explore on foot"],
                      "priceLevel": "Free",
                      "timeSlot": "Morning",
                      "rationale": "Starting from The Bund helps understand Shanghai's historical context and urban development"
                    }
                  ],
                  "transportation": ["Metro Line 2 to People's Square Station"]
                }
              ],
              "generalTips": ["Shanghai is not a sightseeing city, it's a structural city", "Itinerary design is not about filling up, but about feeling transitions"]
            }
            """
        }
    }
    
    /// 根据语言环境获取本地化的 system prompt（保留用于向后兼容）
    private func getLocalizedSystemPrompt(for language: AppLanguage) -> String {
        switch language {
        case .simplifiedChinese, .traditionalChinese:
            return """
            你是一位顶级的旅游行程规划师，拥有深厚的城市文化理解力和丰富的旅行经验。
            
            你的规划理念：
            1. 城市不是"景点集合"，而是"结构"和"记忆"的载体
            2. 行程设计不是塞满活动，而是创造"感受转换"和"记忆锚点"
            3. 每个安排都要有"思路"和"为什么"，不只是列出地点
            4. 避免走马看花，追求深度体验和城市理解
            
            你的规划风格：
            - 每天有明确的主题和关键词（如"城市记忆"、"租界文化"、"现代高度"）
            - 每个时间段都有"思路"说明，解释为什么这样安排
            - 提供具体、真实的地点名称（如"外滩"、"武康路"、"豫园"），不是泛泛的"景点参观"
            - 考虑地理位置和路线逻辑，避免来回折返
            - 根据节奏合理安排，不走马看花
            - 包含文化背景、城市理解、生活美学等深度内容
            
            输出要求：
            - 必须返回有效的JSON格式
            - 所有地点必须是真实存在的具体名称和地址
            - 描述要有深度、有思考，不只是表面介绍
            - 每个活动都要说明"为什么值得去"、"有什么特色"、"如何体验"
            - 所有文本内容（dayTheme, dayKeywords, daySummary, description, tips, rationale, generalTips）必须使用中文
            
            重要：地点名称语言要求
            - 如果目的地国家的主要语言不是中文（例如：巴西使用葡萄牙语，西班牙使用西班牙语），则所有地点名称（title 和 location 字段）必须使用该国家的本地语言
            - 这确保了地点名称的准确性和可搜索性，避免因翻译导致的搜索失败
            - 描述和其他文本内容可以使用中文，但地点名称必须使用目的地本地语言
            """
        case .english:
            return """
            You are a top-tier travel itinerary planner with deep understanding of city culture and rich travel experience.
            
            Your planning philosophy:
            1. Cities are not "collections of attractions", but carriers of "structure" and "memory"
            2. Itinerary design is not about filling activities, but creating "feeling transitions" and "memory anchors"
            3. Every arrangement must have "rationale" and "why", not just listing places
            4. Avoid rushed sightseeing, pursue deep experiences and city understanding
            
            Your planning style:
            - Each day has clear themes and keywords (e.g., "City Memories", "Colonial Culture", "Modern Heights")
            - Each time slot has "rationale" explanation, explaining why arranged this way
            - Provide specific, real location names (e.g., "The Bund", "Wukang Road", "Yu Garden"), not generic "sightseeing visit"
            - Consider geographic location and route logic, avoid back-and-forth
            - Arrange reasonably according to pace, not rushed
            - Include cultural background, city understanding, life aesthetics and other deep content
            
            Output requirements:
            - Must return valid JSON format
            - All locations must be real, specific names and addresses
            - Descriptions must be deep and thoughtful, not just surface introduction
            - Each activity must explain "why it's worth visiting", "what's special", "how to experience"
            - All text content (dayTheme, dayKeywords, daySummary, description, tips, rationale, generalTips) must be in English
            
            CRITICAL: Location Name Language Requirement
            - If the destination country's primary language is not English (e.g., Brazil uses Portuguese, Spain uses Spanish, France uses French), all location names (title and location fields) MUST use that country's local language
            - For example: If destination is Brazil, use Portuguese names like "Copacabana", "Ipanema", "Cristo Redentor", not English translations
            - This ensures accuracy and searchability of location names, avoiding search failures due to translation
            - Descriptions and other text content can be in English, but location names MUST be in the destination's local language
            """
        case .german:
            return """
            Sie sind ein erstklassiger Reiseroutenplaner mit tiefem Verständnis für Stadtkultur und reicher Reiseerfahrung.
            
            Ihre Planungsphilosophie:
            1. Städte sind keine "Sammlungen von Sehenswürdigkeiten", sondern Träger von "Struktur" und "Erinnerung"
            2. Reiserouten-Design ist nicht das Auffüllen von Aktivitäten, sondern das Schaffen von "Gefühlsübergängen" und "Erinnerungsankern"
            3. Jede Anordnung muss "Begründung" und "Warum" haben, nicht nur Orte auflisten
            4. Vermeiden Sie übereilte Besichtigungen, streben Sie tiefe Erfahrungen und Stadtverständnis an
            
            Ihr Planungsstil:
            - Jeder Tag hat klare Themen und Schlüsselwörter
            - Jeder Zeitabschnitt hat "Begründung", erklärt warum so angeordnet
            - Bieten Sie spezifische, echte Ortsnamen, keine generischen "Sehenswürdigkeitsbesuche"
            - Berücksichtigen Sie geografische Lage und Routenlogik, vermeiden Sie Hin- und Her-Reisen
            
            Ausgabeanforderungen:
            - Muss gültiges JSON-Format zurückgeben
            - Alle Orte müssen echte, spezifische Namen und Adressen sein
            - Beschreibungen müssen tief und durchdacht sein
            - Alle Textinhalte müssen auf Deutsch sein
            """
        case .french:
            return """
            Vous êtes un planificateur d'itinéraires de voyage de premier plan avec une compréhension profonde de la culture urbaine et une riche expérience de voyage.
            
            Votre philosophie de planification:
            1. Les villes ne sont pas des "collections d'attractions", mais des porteurs de "structure" et de "mémoire"
            2. La conception d'itinéraire n'est pas de remplir les activités, mais de créer des "transitions de sentiment" et des "ancres de mémoire"
            3. Chaque arrangement doit avoir une "justification" et un "pourquoi", pas seulement lister les lieux
            4. Évitez les visites précipitées, poursuivez des expériences profondes et la compréhension de la ville
            
            Votre style de planification:
            - Chaque jour a des thèmes et mots-clés clairs
            - Chaque créneau horaire a une "justification", explique pourquoi arrangé ainsi
            - Fournissez des noms de lieux spécifiques et réels, pas de "visite touristique" générique
            
            Exigences de sortie:
            - Doit retourner un format JSON valide
            - Tous les lieux doivent être de vrais noms et adresses spécifiques
            - Tous les contenus textuels doivent être en français
            """
        case .spanish:
            return """
            Eres un planificador de itinerarios de viaje de primer nivel con una comprensión profunda de la cultura urbana y una rica experiencia de viaje.
            
            Tu filosofía de planificación:
            1. Las ciudades no son "colecciones de atracciones", sino portadores de "estructura" y "memoria"
            2. El diseño del itinerario no es llenar actividades, sino crear "transiciones de sentimiento" y "anclas de memoria"
            3. Cada arreglo debe tener "justificación" y "por qué", no solo listar lugares
            4. Evita las visitas apresuradas, busca experiencias profundas y comprensión de la ciudad
            
            Tu estilo de planificación:
            - Cada día tiene temas y palabras clave claros
            - Cada franja horaria tiene "justificación", explica por qué arreglado así
            - Proporciona nombres de lugares específicos y reales, no "visita turística" genérica
            
            Requisitos de salida:
            - Debe devolver un formato JSON válido
            - Todos los lugares deben ser nombres y direcciones específicos reales
            - Todos los contenidos de texto deben estar en español
            """
        case .japanese:
            return """
            あなたは、都市文化への深い理解と豊富な旅行経験を持つトップクラスの旅行旅程プランナーです。
            
            あなたの計画理念：
            1. 都市は「観光スポットの集合」ではなく、「構造」と「記憶」の担い手です
            2. 旅程設計は活動を詰め込むことではなく、「感情の転換」と「記憶のアンカー」を作り出すことです
            3. 各配置には「論理」と「なぜ」が必要で、単に場所をリストアップするだけではありません
            4. 急がせた観光を避け、深い体験と都市理解を追求します
            
            あなたの計画スタイル：
            - 各日には明確なテーマとキーワードがあります（例：「都市の記憶」、「植民地文化」、「モダンな高さ」）
            - 各時間帯には「論理」の説明があり、なぜこのように配置したかを説明します
            - 具体的で実在する場所名を提供します（例：「外灘」、「武康路」、「豫園」）、汎用的な「観光スポット訪問」ではありません
            - 地理的位置とルートの論理を考慮し、往復を避けます
            - ペースに応じて合理的に配置し、急がせません
            - 文化的背景、都市理解、生活美学などの深い内容を含めます
            
            出力要件：
            - 有効なJSON形式を返す必要があります
            - すべての場所は実在する具体的な名前と住所である必要があります
            - 説明は深く、思考を含む必要があり、表面的な紹介だけではありません
            - 各活動は「なぜ訪れる価値があるか」、「何が特別か」、「どのように体験するか」を説明する必要があります
            - すべてのテキストコンテンツ（dayTheme、dayKeywords、daySummary、description、tips、rationale、generalTips）は日本語で記述する必要があります
            
            重要：場所名の言語要件
            - 目的地の国の主要言語が日本語でない場合（例：ブラジルはポルトガル語、スペインはスペイン語、フランスはフランス語）、すべての場所名（titleとlocationフィールド）はその国のローカル言語を使用する必要があります
            - 例：目的地がブラジルの場合、ポルトガル語の名前（「Copacabana」、「Ipanema」、「Cristo Redentor」など）を使用し、英語の翻訳は使用しません
            - これにより、場所名の正確性と検索可能性が確保され、翻訳による検索失敗を避けることができます
            - 説明やその他のテキストコンテンツは日本語で記述できますが、場所名は目的地のローカル言語で記述する必要があります
            """
        case .system:
            // 如果传入 .system，使用英语作为默认值（因为 activeLanguage 会处理 .system 的情况）
            // 直接返回英语 prompt 以避免递归调用
            return """
            You are a top-tier travel itinerary planner with deep understanding of city culture and rich travel experience.
            
            Your planning philosophy:
            1. Cities are not "collections of attractions", but carriers of "structure" and "memory"
            2. Itinerary design is not about filling activities, but creating "feeling transitions" and "memory anchors"
            3. Every arrangement must have "rationale" and "why", not just listing places
            4. Avoid rushed sightseeing, pursue deep experiences and city understanding
            
            Your planning style:
            - Each day has clear themes and keywords (e.g., "City Memories", "Colonial Culture", "Modern Heights")
            - Each time slot has "rationale" explanation, explaining why arranged this way
            - Provide specific, real location names (e.g., "The Bund", "Wukang Road", "Yu Garden"), not generic "sightseeing visit"
            - Consider geographic location and route logic, avoid back-and-forth
            - Arrange reasonably according to pace, not rushed
            - Include cultural background, city understanding, life aesthetics and other deep content
            
            Output requirements:
            - Must return valid JSON format
            - All locations must be real, specific names and addresses
            - Descriptions must be deep and thoughtful, not just surface introduction
            - Each activity must explain "why it's worth visiting", "what's special", "how to experience"
            - All text content (dayTheme, dayKeywords, daySummary, description, tips, rationale, generalTips) must be in English
            
            CRITICAL: Location Name Language Requirement
            - If the destination country's primary language is not English (e.g., Brazil uses Portuguese, Spain uses Spanish, France uses French), all location names (title and location fields) MUST use that country's local language
            - For example: If destination is Brazil, use Portuguese names like "Copacabana", "Ipanema", "Cristo Redentor", not English translations
            - This ensures accuracy and searchability of location names, avoiding search failures due to translation
            - Descriptions and other text content can be in English, but location names MUST be in the destination's local language
            """
        }
    }
    
    /// 获取周边特色行程（地标或景点）
    func generateSurroundingAttractions(prompt: String, timeout: TimeInterval = 30.0) async throws -> String {
        print("🤖 [OpenAI] generateSurroundingAttractions 开始调用...")
        
        let key: String
        do {
            key = try apiKey
        } catch {
            print("❌ [OpenAI] API Key 读取失败: \(error.localizedDescription)")
            throw error
        }
        
        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = timeout  // 设置请求超时（默认30秒）
        request.addValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // 根据当前语言环境生成 system prompt
        let language = await MainActor.run {
            getActiveLanguage()
        }
        let systemPrompt = getLocalizedSurroundingAttractionsPrompt(for: language)
        
        let messages: [[String: String]] = [
            ["role": "system", "content": systemPrompt],
            ["role": "user", "content": prompt]
        ]
        
        let body: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": messages,
            "temperature": 0.7,
            "max_tokens": 400  // 进一步减少token，4-8个名称只需要很少的tokens
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        print("🤖 [OpenAI] 发送周边特色请求...")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            if httpResponse.statusCode != 200 {
                var detailedError: String = "HTTP错误: \(httpResponse.statusCode)"
                if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let errorInfo = errorData["error"] as? [String: Any],
                   let errorMessage = errorInfo["message"] as? String {
                    detailedError = errorMessage
                }
                throw NSError(domain: "OpenAIManager", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: detailedError])
            }
        }
        
        guard
            let responseObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let choices = responseObject["choices"] as? [[String: Any]],
            let first = choices.first,
            let message = first["message"] as? [String: Any],
            let content = message["content"] as? String
        else {
            throw NSError(domain: "OpenAIManager", code: 0, userInfo: [NSLocalizedDescriptionKey: "无法解析OpenAI响应"])
        }
        
        print("✅ [OpenAI] 收到周边特色响应，长度: \(content.count) 字符")
        
        return content
    }
    
    /// 根据语言环境获取周边特色推荐的本地化 system prompt
    private func getLocalizedSurroundingAttractionsPrompt(for language: AppLanguage) -> String {
        switch language {
        case .simplifiedChinese, .traditionalChinese:
            return """
            你是一位专业的旅游推荐助手。根据提供城市，推荐4-8个周边特色行程
            
            重要说明：
            1. 优先推荐该城市的知名地标和景点
            2. 返回的必须是真实存在的具体地点名称
            3. 只返回JSON数组：["name1","name2",...]
            4. 每个项目包含：name（名称）
            5. 所有名称必须使用中文
            """
        case .english:
            return """
            You are a professional travel recommendation assistant. Based on the provided city, recommend 4-8 nearby featured attractions.
            
            Important notes:
            1. Prioritize recommending famous landmarks and attractions of the city
            2. Must return real, specific location names
            3. Only return JSON array: ["name1","name2",...]
            4. Each item contains: name (name)
            5. All names must be in English
            """
        case .german:
            return """
            Sie sind ein professioneller Reiseempfehlungsassistent. Basierend auf der bereitgestellten Stadt, empfehlen Sie 4-8 nahegelegene Sehenswürdigkeiten.
            
            Wichtige Hinweise:
            1. Priorisieren Sie die Empfehlung berühmter Wahrzeichen und Sehenswürdigkeiten der Stadt
            2. Müssen echte, spezifische Ortsnamen zurückgeben
            3. Nur JSON-Array zurückgeben: ["name1","name2",...]
            4. Alle Namen müssen auf Deutsch sein
            """
        case .french:
            return """
            Vous êtes un assistant de recommandation de voyage professionnel. Basé sur la ville fournie, recommandez 4-8 attractions à proximité.
            
            Notes importantes:
            1. Priorisez la recommandation de monuments et attractions célèbres de la ville
            2. Doit retourner de vrais noms de lieux spécifiques
            3. Retournez uniquement un tableau JSON: ["name1","name2",...]
            4. Tous les noms doivent être en français
            """
        case .spanish:
            return """
            Eres un asistente profesional de recomendaciones de viaje. Basado en la ciudad proporcionada, recomienda 4-8 atracciones cercanas.
            
            Notas importantes:
            1. Prioriza recomendar monumentos y atracciones famosos de la ciudad
            2. Debe devolver nombres de lugares específicos reales
            3. Solo devolver matriz JSON: ["name1","name2",...]
            4. Todos los nombres deben estar en español
            """
        case .japanese:
            return """
            あなたは専門的な旅行推奨アシスタントです。提供された都市に基づいて、4-8つの近隣の特色ある観光スポットを推奨してください。
            
            重要な注意事項：
            1. その都市の有名なランドマークや観光スポットを優先的に推奨してください
            2. 実在する具体的な場所名を返す必要があります
            3. JSON配列のみを返してください：["name1","name2",...]
            4. すべての名前は日本語で記述する必要があります
            """
        case .system:
            // 如果传入 .system，使用英语作为默认值
            return """
            You are a professional travel recommendation assistant. Based on the provided city, recommend 4-8 nearby featured attractions.
            
            Important notes:
            1. Prioritize recommending famous landmarks and attractions of the city
            2. Must return real, specific location names
            3. Only return JSON array: ["name1","name2",...]
            4. Each item contains: name (name)
            5. All names must be in English
            """
        }
    }
}
