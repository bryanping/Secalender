//
//  AIConversationView.swift
//  Secalender
//
//  Created by 林平 on 2025/8/8.
//  原 AIPlannerView 代码，保留对话式AI规划功能
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

//enum PlannerTab {
//    case aiPlanning      // AI 規劃
//    case myTemplates     // 行程模板（保存的行程建议）
//    case templateStore   // 模板市集（付费模板）
//}

/// 模板排序选项


struct AIConversationView: View {
    @EnvironmentObject var userManager: FirebaseUserManager
    
    @State private var inputText: String = ""
    @State private var isLoading = false
    
    // 错误提示
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    
    // 需求判别和追问状态
    @State private var followUpState: FollowUpState?
    @State private var followUpAnswer: String = ""
    @State private var classificationResult: ClassificationResult?
    @State private var planResult: PlanResult?
    
    // 对话和行程卡片状态
    @State private var chatMessages: [ChatMessage] = []
    @State private var generatedPlans: [PlanResult] = []  // 所有生成的行程
    @State private var selectedPlanForDetails: PlanResult? = nil  // 选中的行程（单日或多日）
    
    // 键盘相关状态
    @State private var keyboardHeight: CGFloat = 0
    @FocusState private var isInputFieldFocused: Bool
    
    // 行程编辑状态
    @State private var editingPlan: PlanResult? = nil
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                // 主内容区域：对话界面（全屏）
                chatView
                    .padding(.bottom, keyboardHeight > 0 ? keyboardHeight + 80 : 100) // 为输入框和TabBar预留空间
                
                // 浮动输入框（固定在底部，跟随键盘）
                floatingInputView
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        // 移除 safeAreaInset，改用输入框的 padding 来控制位置
        .simultaneousGesture(
            TapGesture()
                .onEnded { _ in
                    // 点击页面收起键盘（但不要阻止输入框的点击）
                    if isInputFieldFocused {
                        hideKeyboard()
                    }
                }
        )
    }
    
    // 对话界面
    private var chatView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    if chatMessages.isEmpty {
                        // 欢迎消息
                        HStack {
                            Image(systemName: "sparkles")
                                .foregroundColor(.orange)
                            Text("您好！我可以帮您规划行程，请告诉我您的需求")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    ForEach(chatMessages) { message in
                        VStack(alignment: .leading, spacing: 8) {
                            // 消息气泡
                            MessageBubble(message: message)
                            
                            // 如果消息包含行程，显示行程卡片
                            if let plan = message.planResult {
                                TripPlanCard(
                                    plan: plan,
                                    onAddToCalendar: {
                                        // 单日行程：跳转到详情页
                                        selectedPlanForDetails = plan
                                    },
                                    onViewDetails: {
                                        // 多日行程：查看详情
                                        selectedPlanForDetails = plan
                                    },
                                    onSaveToTemplate: {
                                        // 保存到模板（虽然已经自动保存，但允许重新保存）
                                        savePlanToTemplate(plan)
                                    }
                                )
                                .padding(.horizontal, 4)
                                .padding(.top, 4)
                            }
                        }
                        .id(message.id)
                    }
                    
                    if isLoading {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("正在生成行程...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                    }
                }
                .padding()
                .padding(.bottom, 20) // 为输入框预留空间
            }
            .onChange(of: chatMessages.count) { _ in
                // 当有新消息时，立即滚动到底部
                if let lastMessage = chatMessages.last {
                    // 使用更短的延迟，确保消息已渲染
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        withAnimation(.easeOut(duration: 0.3)) {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }
            .onChange(of: isLoading) { loading in
                // 当加载状态改变时，也滚动到底部
                if !loading, let lastMessage = chatMessages.last {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation(.easeOut(duration: 0.3)) {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }
            .onAppear {
                // 视图出现时，滚动到最新消息
                if let lastMessage = chatMessages.last {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }
        }
    }
    
    // 浮动输入框（参考 ChatGPT 风格）
    private var floatingInputView: some View {
        VStack(spacing: 0) {
            // 输入框容器
            VStack(spacing: 8) {
                // 如果有追问状态，显示追问UI
                if let followUpState = followUpState, let currentQuestion = followUpState.currentQuestion {
                    followUpInputView(state: followUpState, question: currentQuestion)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                } else {
                    // 正常输入框（ChatGPT 风格）
                    HStack(alignment: .bottom, spacing: 12) {
                        // 输入框
                        TextField("输入您的需求...", text: $inputText, axis: .vertical)
                            .textFieldStyle(.plain)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 24)
                                    .fill(Color(.systemGray6))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 24)
                                    .stroke(isInputFieldFocused ? Color.orange : Color.clear, lineWidth: 1.5)
                            )
                            .lineLimit(1...6)
                            .focused($isInputFieldFocused)
                            .onSubmit {
                                if !inputText.isEmpty && !isLoading {
                                    Task { await sendMessage() }
                                }
                            }
                        
                        // 发送按钮（与输入框底部对齐）
                        Button(action: {
                            Task { await sendMessage() }
                        }) {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 32))
                                .foregroundColor(inputText.isEmpty || isLoading ? Color(.systemGray3) : .orange)
                        }
                        .disabled(inputText.isEmpty || isLoading)
                        .padding(.bottom, 4) // 微调对齐
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
            // 去除外层底色，只保留阴影
            .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: -2) // 保留阴影
        }
        .padding(.bottom, keyboardHeight > 0 ? 30 : 70) // 键盘弹起时没有TabBar，不需要padding；键盘收起时在TabBar上方（100是TabBar高度）
        .animation(.easeOut(duration: 0.25), value: keyboardHeight)
    }
    
    // 追问输入视图（简化版）
    private func followUpInputView(state: FollowUpState, question: FollowUpQuestionType) -> some View {
        VStack(spacing: 8) {
            HStack {
                Text(FollowUpManager.shared.getQuestionText(question))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
            }
            
            HStack(spacing: 8) {
                // 快捷选项按钮
                ForEach(FollowUpManager.shared.getQuickOptions(question), id: \.self) { option in
                    Button(option) {
                        handleQuickOption(option, for: question)
                    }
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.orange.opacity(0.1))
                    .foregroundColor(.orange)
                    .cornerRadius(16)
                }
                
                Spacer()
            }
        }
    }
    
    // 追问UI视图
    @ViewBuilder
    private func followUpView(state: FollowUpState, question: FollowUpQuestionType) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(FollowUpManager.shared.getQuestionText(question))
                .font(.headline)
                .padding(.bottom, 8)
            
            // 快捷选项
            let quickOptions = FollowUpManager.shared.getQuickOptions(question)
            if !quickOptions.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(quickOptions, id: \.self) { option in
                        Button(action: {
                            handleQuickOption(option, for: question)
                        }) {
                            HStack {
                                Text(option)
                                    .foregroundColor(.primary)
                                Spacer()
                            }
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                        }
                    }
                }
            }
            
            // 手动输入
            Text("或手动输入：")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.top, 8)
            
            TextField("请输入", text: $followUpAnswer)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.bottom, 8)
            
            Button(action: {
                handleFollowUpAnswer(question: question)
            }) {
                Text("确定")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .padding()
            .background(followUpAnswer.isEmpty ? Color.gray : Color.orange)
            .foregroundColor(.white)
            .cornerRadius(8)
            .disabled(followUpAnswer.isEmpty)
            
            // 返回按钮
            Button(action: {
                followUpState = nil
                followUpAnswer = ""
                classificationResult = nil
            }) {
                Text("返回")
                    .foregroundColor(.secondary)
            }
            .padding(.top, 8)
        }
    }
    
    // MARK: - 消息处理
    
    /// 发送消息（持续对话）
    private func sendMessage() async {
        guard !inputText.isEmpty else { return }
        
        // 添加用户消息到对话历史
        let userMessage = ChatMessage(role: .user, content: inputText)
        chatMessages.append(userMessage)
        let currentInput = inputText
        inputText = ""  // 清空输入框
        
        // 保存聊天记录
        onMessageChanged()
        
        // 收起键盘
        hideKeyboard()
        
        isLoading = true
        
        // 1. 文本预处理（在 InputClassifier 内部完成）
        // 2. 输入类型判别（A/B/C/D）
        let result = InputClassifier.shared.classify(currentInput)
        self.classificationResult = result
        
        // 3. 根据类型处理
        switch result.inputType {
        case .typeA:
            // A类：直接生成
            await generatePlanDirect(from: result)
            
        case .typeB:
            // B类：使用默认值补齐后生成
            await generatePlanWithDefaults(from: result)
            
        case .typeC:
            // C类：进入最少追问模式
            enterFollowUpMode()
            // 添加AI追问消息
            if let followUpState = followUpState, let question = followUpState.currentQuestion {
                let aiMessage = ChatMessage(role: .assistant, content: FollowUpManager.shared.getQuestionText(question))
                chatMessages.append(aiMessage)
                onMessageChanged()
            }
            
        case .typeD:
            // D类：提示用户使用模板市集
            let aiMessage = ChatMessage(role: .assistant, content: "建议您前往模板市集浏览并选择模板。")
            chatMessages.append(aiMessage)
            onMessageChanged()
        }
        
        isLoading = false
    }
    
    // MARK: - 行程生成
    
    /// A类：直接生成行程（使用AI增强）
    private func generatePlanDirect(from result: ClassificationResult) async {
        print("🤖 [AI生成] 开始生成行程，使用 OpenAI API...")
        do {
            // 使用AI生成包含真实地点的行程
            print("🤖 [AI生成] 调用 AITripGenerator.generateAIItinerary()...")
            let plan = try await generateAIPoweredPlan(from: result)
            print("✅ [AI生成] OpenAI 成功生成行程，天数: \(plan.days.count)")
            
            self.planResult = plan
            
            // 添加到生成的行程列表
            generatedPlans.append(plan)
            
            // ✨ 自动保存到行程模板
            autoSavePlanToTemplate(plan)
            
            // 添加AI回复消息到对话历史（包含行程数据）
            let responseText = plan.days.count > 1
            ? "✅ 已为您生成 \(plan.days.count) 天行程（使用AI生成），已自动保存到行程模板。"
            : "✅ 已为您生成行程（使用AI生成），已自动保存到行程模板。"
            let aiMessage = ChatMessage(role: .assistant, content: responseText, planResult: plan)
            chatMessages.append(aiMessage)
            onMessageChanged()
            
        } catch {
            // 如果AI生成失败，根据错误类型处理
            print("❌ [AI生成] OpenAI 生成失败: \(error.localizedDescription)")
            print("❌ [AI生成] 错误详情: \(error)")
            
            // 检查是否是 OpenAI 禁用错误
            if let aiError = error as? AITripGenerationError,
               case .openAIDisabled = aiError {
                // OpenAI 已禁用，回退到基础生成器
                print("⚠️ [AI生成] OpenAI 已禁用，回退到基础生成器")
                do {
                    let plan = try PlanGenerator.shared.generatePlan(
                        from: result.slots,
                        assumptions: result.assumptions + ["AI功能已禁用，使用基础行程模板"],
                        riskFlags: result.riskFlags + ["⚠️ 注意：当前使用的是基础行程模板，非AI生成"]
                    )
                    self.planResult = plan
                    
                    // 添加到生成的行程列表
                    generatedPlans.append(plan)
                    
                    // ✨ 自动保存到行程模板
                    autoSavePlanToTemplate(plan)
                    
                    // 添加提示消息
                    let aiMessage = ChatMessage(role: .assistant, content: "⚠️ AI功能已禁用，已生成基础行程模板，已自动保存到行程模板。请在 AIConfig.swift 中启用 OpenAI API 以获得更好的行程建议。", planResult: plan)
                    chatMessages.append(aiMessage)
                    onMessageChanged()
                    
                    return  // 成功生成基础行程，直接返回
                } catch {
                    // 基础生成器也失败
                    self.errorMessage = "行程生成失败：\(error.localizedDescription)"
                    self.showErrorAlert = true
                    let errorMessage = ChatMessage(role: .system, content: "❌ 行程生成失败：\(error.localizedDescription)")
                    chatMessages.append(errorMessage)
                    onMessageChanged()
                    return
                }
            }
            
            // 检查是否是配额错误
            let nsError = error as NSError
            var errorMessageText = "AI行程生成失败"
            var chatErrorMessage = "❌ AI行程生成失败"
            
            if nsError.code == -429 || nsError.code == 429 {
                // 配额错误
                errorMessageText = error.localizedDescription
                chatErrorMessage = """
                ❌ OpenAI API 配额已用完
                
                无法生成AI行程，因为：
                • API Key 的额度已用完
                • 或账户未绑定付款方式
                
                解决方案：
                1. 访问 OpenAI 账户查看余额
                https://platform.openai.com/account/billing
                
                2. 绑定付款方式或充值
                
                3. 使用其他 API Key
                
                如需帮助，请联系技术支持。
                """
            } else {
                // 其他错误
                errorMessageText = "AI行程生成失败：\(error.localizedDescription)\n\n请检查：\n1. OpenAI API Key 是否正确配置\n2. 网络连接是否正常\n3. API 额度是否充足"
                chatErrorMessage = "❌ AI行程生成失败：\(error.localizedDescription)\n\n提示：请检查 API Key 配置和网络连接。"
            }
            
            self.errorMessage = errorMessageText
            self.showErrorAlert = true
            
            // 添加错误消息到对话
            let errorMessage = ChatMessage(role: .system, content: chatErrorMessage)
            chatMessages.append(errorMessage)
            onMessageChanged()
        }
    }
    
    /// 使用AI生成增强的行程（必须使用OpenAI）
    private func generateAIPoweredPlan(from result: ClassificationResult) async throws -> PlanResult {
        print("🤖 [AI生成] generateAIPoweredPlan 开始...")
        guard let destination = result.slots.destination.value else {
            print("❌ [AI生成] 缺少目的地")
            throw PlanGenerationError.missingDestination
        }
        
        print("🤖 [AI生成] 目的地: \(destination)")
        
        // 确定日期范围
        let dateRange: DateRange
        if let range = result.slots.dateRange.value {
            dateRange = range
        } else if let days = result.slots.durationDays.value {
            let calendar = Calendar.current
            let startDate = calendar.date(byAdding: .day, value: 1, to: Date()) ?? Date()
            let endDate = calendar.date(byAdding: .day, value: days - 1, to: startDate) ?? startDate
            dateRange = DateRange(startDate: startDate, endDate: endDate)
        } else {
            print("❌ [AI生成] 缺少日期信息")
            throw PlanGenerationError.missingDateInfo
        }
        
        // 获取天数
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: dateRange.startDate, to: dateRange.endDate).day ?? 1
        let numberOfDays = max(1, days + 1)
        
        print("🤖 [AI生成] 天数: \(numberOfDays), 日期范围: \(dateRange.startDate) 到 \(dateRange.endDate)")
        print("🤖 [AI生成] 兴趣标签: \(result.slots.interestTags)")
        print("🤖 [AI生成] 节奏: \(result.slots.pace.value?.rawValue ?? "中")")
        
        // 使用AITripGenerator生成包含真实地点的行程（调用OpenAI API）
        print("🤖 [AI生成] 调用 AITripGenerator.shared.generateAIItinerary()...")
        let aiPlan = try await AITripGenerator.shared.generateAIItinerary(
            destination: destination,
            startDate: dateRange.startDate,
            endDate: dateRange.endDate,
            durationDays: numberOfDays,
            interestTags: result.slots.interestTags,
            pace: result.slots.pace.value ?? .moderate,
            walkingLevel: result.slots.walkingLevel.value,
            transportPreference: result.slots.transportPreference.value
        )
        
        print("✅ [AI生成] OpenAI 返回了 \(aiPlan.days.count) 天的行程")
        
        // 转换为PlanResult
        var plan = try AITripGenerator.shared.convertToPlanResult(aiPlan, slots: result.slots)
        plan.assumptions = result.assumptions
        
        // 添加AI生成的一般建议
        if !aiPlan.generalTips.isEmpty {
            plan.riskFlags.append(contentsOf: result.riskFlags)
        }
        
        print("✅ [AI生成] 行程转换完成，共 \(plan.days.count) 天")
        return plan
    }
    
    /// B类：使用默认值补齐后生成
    private func generatePlanWithDefaults(from result: ClassificationResult) async {
        // 默认值已在 InputClassifier.fillDefaults 中补齐
        await generatePlanDirect(from: result)
    }
    
    /// C类：进入追问模式
    private func enterFollowUpMode() {
        followUpState = FollowUpManager.shared.createFollowUpState()
        followUpAnswer = ""
    }
    
    /// 处理追问快捷选项
    private func handleQuickOption(_ option: String, for question: FollowUpQuestionType) {
        if question == .destination && option == "使用当前定位" {
            // TODO: 获取当前位置
            // 这里可以使用 LocationManager 获取当前位置
            followUpAnswer = "当前位置"  // 临时值，实际应获取真实位置
        } else {
            followUpAnswer = option
        }
        handleFollowUpAnswer(question: question)
    }
    
    /// 处理追问答案
    private func handleFollowUpAnswer(question: FollowUpQuestionType) {
        guard var state = followUpState else { return }
        
        // 保存答案
        state = FollowUpManager.shared.answerQuestion(state, question: question, answer: followUpAnswer)
        followUpState = state
        followUpAnswer = ""
        
        // 如果追问完成，生成行程
        if state.isComplete {
            Task {
                await generatePlanFromFollowUp(state)
            }
        } else {
            // 继续追问
            if let nextQuestion = state.currentQuestion {
                let aiMessage = ChatMessage(role: .assistant, content: FollowUpManager.shared.getQuestionText(nextQuestion))
                chatMessages.append(aiMessage)
                onMessageChanged()
            }
        }
    }
    
    /// 从追问状态生成行程（使用AI增强）
    private func generatePlanFromFollowUp(_ state: FollowUpState) async {
        isLoading = true
        
        // 从追问状态构建 Slots
        let slots = FollowUpManager.shared.buildSlotsFromFollowUp(state)
        
        // 生成行程（使用AI增强）
        do {
            guard let destination = slots.destination.value else {
                throw PlanGenerationError.missingDestination
            }
            
            // 确定日期范围
            let dateRange: DateRange
            if let range = slots.dateRange.value {
                dateRange = range
            } else if let days = slots.durationDays.value {
                let calendar = Calendar.current
                let startDate = calendar.date(byAdding: .day, value: 1, to: Date()) ?? Date()
                let endDate = calendar.date(byAdding: .day, value: days - 1, to: startDate) ?? startDate
                dateRange = DateRange(startDate: startDate, endDate: endDate)
            } else {
                throw PlanGenerationError.missingDateInfo
            }
            
            let calendar = Calendar.current
            let days = calendar.dateComponents([.day], from: dateRange.startDate, to: dateRange.endDate).day ?? 1
            let numberOfDays = max(1, days + 1)
            
            // 使用AI生成
            let aiPlan = try await AITripGenerator.shared.generateAIItinerary(
                destination: destination,
                startDate: dateRange.startDate,
                endDate: dateRange.endDate,
                durationDays: numberOfDays,
                interestTags: slots.interestTags,
                pace: slots.pace.value ?? .moderate,
                walkingLevel: slots.walkingLevel.value,
                transportPreference: slots.transportPreference.value
            )
            
            print("✅ [追问生成] OpenAI 成功生成行程")
            var plan = try AITripGenerator.shared.convertToPlanResult(aiPlan, slots: slots)
            plan.assumptions = ["基于追问信息生成"]
            
            self.planResult = plan
            
            // 添加到生成的行程列表
            generatedPlans.append(plan)
            
            // ✨ 自动保存到行程模板
            autoSavePlanToTemplate(plan)
            
            // 添加AI回复消息（包含行程数据）
            let responseText = plan.days.count > 1
            ? "✅ 已为您生成 \(plan.days.count) 天行程（使用AI生成），已自动保存到行程模板。"
            : "✅ 已为您生成行程（使用AI生成），已自动保存到行程模板。"
            let aiMessage = ChatMessage(role: .assistant, content: responseText, planResult: plan)
            chatMessages.append(aiMessage)
            onMessageChanged()
            
            self.followUpState = nil
        } catch {
            // 不再回退到基础生成器，直接显示错误
            print("❌ [追问生成] OpenAI 生成失败: \(error.localizedDescription)")
            
            // 检查是否是配额错误
            let nsError = error as NSError
            var errorMessageText = "AI行程生成失败"
            var chatErrorMessage = "❌ AI行程生成失败"
            
            if nsError.code == -429 || nsError.code == 429 {
                // 配额错误
                errorMessageText = error.localizedDescription
                chatErrorMessage = """
                ❌ OpenAI API 配额已用完
                
                无法生成AI行程，请检查：
                • API Key 的额度是否用完
                • 账户是否已绑定付款方式
                
                访问账户：https://platform.openai.com/account/billing
                """
            } else {
                // 其他错误
                errorMessageText = "AI行程生成失败：\(error.localizedDescription)\n\n请检查 API Key 配置和网络连接。"
                chatErrorMessage = "❌ AI行程生成失败：\(error.localizedDescription)"
            }
            
            self.errorMessage = errorMessageText
            self.showErrorAlert = true
            
            // 添加错误消息
            let errorMessage = ChatMessage(role: .system, content: chatErrorMessage)
            chatMessages.append(errorMessage)
            onMessageChanged()
            
            self.followUpState = nil
        }
        
        isLoading = false
    }
    
    // MARK: - 保存功能
    
    /// 保存行程到日历（从PlanResult）
    private func savePlanToCalendar(_ plan: PlanResult?) {
        guard let plan = plan else { return }
        
        Task {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "HH:mm:ss"  // Event 期望的時間字串格式
            
            // 将PlanResult转换为ScheduleItem
            let items = PlanGenerator.shared.convertToScheduleItems(plan)
            
            for item in items {
                // 組合日期與時間（Date -> String）
                let startDate = combine(date: item.date, time: item.startTime)
                let endDate = combine(date: item.date, time: item.endTime)
                
                let dateString = dateFormatter.string(from: item.date)
                let startString = timeFormatter.string(from: startDate)
                let endString = timeFormatter.string(from: endDate)
                
                // 建立符合 Event 結構（date, startTime 等為 String）
                var event = Event()
                event.title = item.title
                event.creatorOpenid = userManager.userOpenId
                event.color = "#4285F4"
                event.date = dateString
                event.startTime = startString
                event.endTime = endString
                event.endDate = dateString
                event.destination = item.location
                event.mapObj = ""
                event.openChecked = 0
                event.personChecked = 0
                event.createTime = ""
                event.information = item.description
                event.groupId = nil
                
                do {
                    try await EventManager.shared.addEvent(event: event)
                } catch {
                    print("添加事件失敗：\(error)")
                }
            }
            
            // 添加成功消息
            await MainActor.run {
                let successMessage = ChatMessage(role: .system, content: "✅ 已成功将行程添加到日历中")
                self.chatMessages.append(successMessage)
                self.onMessageChanged()
            }
        }
    }
    
    /// 組合日期與時間，回傳帶時間的 Date
    private func combine(date: Date, time: Date) -> Date {
        let calendar = Calendar.current
        return calendar.date(
            bySettingHour: calendar.component(.hour, from: time),
            minute: calendar.component(.minute, from: time),
            second: calendar.component(.second, from: time),
            of: date
        ) ?? date
    }
    
    // MARK: - 键盘管理
    
    /// 设置键盘监听
    private func setupKeyboardObservers() {
        NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillShowNotification,
            object: nil,
            queue: .main
        ) { notification in
            if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                withAnimation {
                    self.keyboardHeight = keyboardFrame.height
                }
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillHideNotification,
            object: nil,
            queue: .main
        ) { _ in
            withAnimation {
                self.keyboardHeight = 0
            }
        }
    }
    
    /// 移除键盘监听
    private func removeKeyboardObservers() {
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
    }
    
    /// 收起键盘
    private func hideKeyboard() {
        isInputFieldFocused = false
        #if canImport(UIKit)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        #endif
    }
    
    // MARK: - 聊天记录管理
    
    /// 加载聊天记录
    private func loadChatHistory() {
        let userId = userManager.userOpenId
        let loadedMessages = ChatMessageManager.shared.loadChatHistory(for: userId)
        chatMessages = loadedMessages
    }
    
    /// 保存聊天记录
    private func saveChatHistory() {
        let userId = userManager.userOpenId
        ChatMessageManager.shared.saveChatHistory(chatMessages, for: userId)
    }
    
    /// 消息变化时自动保存
    private func onMessageChanged() {
        let userId = userManager.userOpenId
        ChatMessageManager.shared.saveChatHistory(chatMessages, for: userId)
    }
    
    // MARK: - 模板保存功能（仅保留自动保存和手动保存）
    
    /// 自动保存行程到模板（生成时自动调用）
    private func autoSavePlanToTemplate(_ plan: PlanResult) {
        let userId = userManager.userOpenId
        
        // 生成默认标题
        let defaultTitle: String
        if let destination = SavedTripTemplate.extractDestination(from: plan) {
            defaultTitle = "\(destination) \(plan.days.count)天行程"
        } else {
            defaultTitle = "行程模板 \(plan.days.count)天"
        }
        
        // 提取目的地
        let destination = SavedTripTemplate.extractDestination(from: plan)
        
        // 创建模板
        let template = SavedTripTemplate(
            title: defaultTitle,
            plan: plan,
            savedDate: Date(),
            tags: [],
            destination: destination
        )
        
        print("🔄 [自动保存] 开始保存行程到模板: \(defaultTitle)")
        
        // 保存模板
        TripTemplateManager.shared.saveTemplate(template, for: userId)
        
        print("✅ [自动保存] 行程已自动保存到模板: \(defaultTitle)")
    }
    
    /// 保存行程到模板（从详情页调用，可自定义标题）
    private func savePlanToTemplate(_ plan: PlanResult, withTitle title: String? = nil) {
        let userId = userManager.userOpenId
        
        // 生成默认标题或使用提供的标题
        let templateTitle: String
        if let customTitle = title, !customTitle.isEmpty {
            templateTitle = customTitle
        } else if let destination = SavedTripTemplate.extractDestination(from: plan) {
            templateTitle = "\(destination) \(plan.days.count)天行程"
        } else {
            templateTitle = "行程模板 \(plan.days.count)天"
        }
        
        // 提取目的地
        let destination = SavedTripTemplate.extractDestination(from: plan)
        
        // 创建模板
        let template = SavedTripTemplate(
            title: templateTitle,
            plan: plan,
            savedDate: Date(),
            tags: [], // 可以后续添加标签功能
            destination: destination
        )
        
        // 保存模板
        TripTemplateManager.shared.saveTemplate(template, for: userId)
        
        // 显示成功提示
        let successMessage = ChatMessage(role: .system, content: "✅ 已保存到行程模板：\(templateTitle)")
        chatMessages.append(successMessage)
        onMessageChanged()
    }
    
    /// 保存行程到模板（从卡片调用）
    private func savePlanToTemplate(_ plan: PlanResult) {
        savePlanToTemplate(plan, withTitle: nil)
    }
}

