
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
    
    /// 生成结构化的行程JSON（用于AITripGenerator）
    func generateStructuredItinerary(prompt: String, timeout: TimeInterval = 60.0) async throws -> String {
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
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = timeout  // 设置请求超时（默认60秒）
        request.addValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let systemPrompt = """
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
        """
        
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
        print("🤖 [OpenAI] 模型: gpt-4o, Temperature: 0.8, Max Tokens: 4000, 超时: \(timeout)秒")
        
        // 发送请求（带超时处理）
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            // 检查是否是超时错误
            if let urlError = error as? URLError {
                if urlError.code == .timedOut {
                    print("❌ [OpenAI] 请求超时（\(timeout)秒）")
                    throw NSError(
                        domain: "OpenAIManager",
                        code: -408,
                        userInfo: [NSLocalizedDescriptionKey: "请求超时。OpenAI API 响应时间过长（超过\(Int(timeout))秒）。请检查网络连接或稍后重试。"]
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
            throw error
        }
        
        print("✅ [OpenAI] 收到响应")
        
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
        
        return content
    }
    
    /// 获取周边特色行程（地标或景点）
    func generateSurroundingAttractions(prompt: String, timeout: TimeInterval = 15.0) async throws -> String {
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
        request.timeoutInterval = timeout  // 设置请求超时
        request.addValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // 简化 system prompt 以减少 tokens 和响应时间
        // 只基于城市推荐，不考虑兴趣偏好和特殊需求（这些在生成行程时再考虑）
        let systemPrompt = """
        你是一位专业的旅游推荐助手。根据提供城市，推荐4-8个周边特色行程
        
        重要说明：
        1. 优先推荐该城市的知名地标和景点
        2. 返回的必须是真实存在的具体地点名称
        3. 只返回JSON数组：["name1","name2",...]
        4. 每个项目包含：name（名称）
        """
        
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
}
