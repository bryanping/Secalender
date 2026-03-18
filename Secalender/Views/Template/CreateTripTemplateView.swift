//
//  CreateTripTemplateView.swift
//  Secalender
//
//  創建行程模版：第一步驟（圖示、主題、AI指令）＋ 第二步驟（AI補全進階參數）
//

import SwiftUI

enum CreateTemplateStep: Int {
    case step1 = 1  // 圖示、主題、AI指令
    case step2 = 2  // 進階參數（AI思考）
}

struct CreateTripTemplateView: View {
    @EnvironmentObject var userManager: FirebaseUserManager
    @Environment(\.dismiss) var dismiss
    @ObservedObject var themeManager = QuickThemeManager.shared
    
    @State private var currentStep: CreateTemplateStep = .step1
    
    // Step 1
    @State private var selectedIcon: String = "pawprint.fill"
    @State private var selectedColorHex: String = "#007AFF"
    @State private var themeTitle: String = ""
    @State private var themeMode: ThemeMode = .generateItinerary
    @State private var aiPromptPrefix: String = ""  // 主題專屬提示詞：約束 AI 生成符合主題的行程，存 Firebase（generateItinerary 時顯示）
    @State private var isAIGeneratingPromptPrefix = false
    @State private var aiInstruction: String = ""
    @State private var isAICompletingInstruction = false
    
    // Step 2：表單問題（可編輯、新增、刪除）
    @State private var formQuestions: [ThemeFormQuestion] = []
    @State private var isGeneratingQuestions = false
    @State private var generatingQuestionIndex: Int? = nil  // 正在根據說明生成選項的索引
    
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showIconPicker = false
    
    private let iconOptions = [
        "pawprint.fill", "star.fill", "heart.fill", "bolt.fill", "flame.fill",
        "building.columns.fill", "map.fill", "fork.knife",
        "camera.fill", "leaf.fill", "airplane", "figure.walk",
        "gift.fill", "ticket.fill", "cup.and.saucer.fill"
    ]
    
    private let colorOptions: [(String, String)] = [
        ("#FF9500", "orange"),
        ("#AF52DE", "purple"),
        ("#34C759", "green"),
        ("#007AFF", "blue"),
        ("#FF3B30", "red"),
        ("#FF2D55", "pink"),
        ("#5AC8FA", "teal"),
        ("#5856D6", "indigo")
    ]
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // 步驟指示
                    stepIndicator
                    
                    ScrollView {
                        VStack(spacing: 24) {
                            switch currentStep {
                            case .step1:
                                step1Content
                            case .step2:
                                step2Content
                            }
                        }
                        .padding()
                    }
                    .scrollDismissesKeyboard(.interactively)
                    
                    bottomButtons
                }
            }
            .dismissKeyboardOnTap()
            .navigationTitle("quick_theme.create_template".localized())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("quick_theme.cancel".localized()) {
                        hideKeyboard()
                        dismiss()
                    }
                }
            }
            .alert("quick_theme.error".localized(), isPresented: $showError) {
                Button("OK") {}
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    // MARK: - 步驟指示
    private var stepIndicator: some View {
        HStack(spacing: 8) {
            HStack(spacing: 4) {
                Circle()
                    .fill(currentStep == .step1 ? Color.blue : Color.gray.opacity(0.3))
                    .frame(width: 8, height: 8)
                Text("quick_theme.step".localized() + " 1")
                    .font(.caption)
                    .foregroundColor(currentStep == .step1 ? .primary : .secondary)
            }
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(height: 1)
            HStack(spacing: 4) {
                Circle()
                    .fill(currentStep == .step2 ? Color.blue : Color.gray.opacity(0.3))
                    .frame(width: 8, height: 8)
                Text("quick_theme.step".localized() + " 2")
                    .font(.caption)
                    .foregroundColor(currentStep == .step2 ? .primary : .secondary)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
    }
    
    // MARK: - Step 1 內容
    private var step1Content: some View {
        VStack(alignment: .leading, spacing: 24) {
            // 基礎設定
            sectionHeader(title: "quick_theme.basic_settings".localized())
            
            // 圖示：虛線圓框 + 更換圖示按鈕
            VStack(spacing: 12) {
                Button {
                    showIconPicker = true
                } label: {
                    ZStack {
                        Circle()
                            .stroke(style: StrokeStyle(lineWidth: 2, dash: [6]))
                            .foregroundColor(.gray.opacity(0.5))
                            .frame(width: 80, height: 80)
                        
                        Image(systemName: selectedIcon)
                            .font(.system(size: 36))
                            .foregroundColor(Color(hex: selectedColorHex) ?? .blue)
                    }
                }
                
                Button {
                    showIconPicker = true
                } label: {
                    Text("quick_theme.change_icon".localized())
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            
            // 主題名稱
            VStack(alignment: .leading, spacing: 8) {
                Text("quick_theme.theme_title".localized())
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                
                TextField("quick_theme.theme_title_placeholder".localized(), text: $themeTitle)
                    .textFieldStyle(.roundedBorder)
            }
            
            // 主題用途（themeMode）
            VStack(alignment: .leading, spacing: 8) {
                Text("quick_theme.theme_mode".localized())
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                
                Picker("", selection: $themeMode) {
                    Text("theme_mode.generateItinerary".localized()).tag(ThemeMode.generateItinerary)
                    Text("theme_mode.floatingTasks".localized()).tag(ThemeMode.floatingTasks)
                    Text("theme_mode.collectAvailability".localized()).tag(ThemeMode.collectAvailability)
                    Text("theme_mode.collectInfoOnly".localized()).tag(ThemeMode.collectInfoOnly)
                }
                .pickerStyle(.menu)
            }
            
            // 主題專屬提示詞（僅 generateItinerary 時顯示）
            if themeMode == .generateItinerary {
                sectionHeader(title: "quick_theme.ai_prompt_prefix".localized(), showSparkle: true)
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Spacer()
                        Button {
                            generatePromptPrefixWithAI()
                        } label: {
                            if isAIGeneratingPromptPrefix {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Text("quick_theme.ai_generate".localized())
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                        }
                        .disabled(isAIGeneratingPromptPrefix || themeTitle.isEmpty)
                    }
                    
                    ZStack(alignment: .topLeading) {
                        if aiPromptPrefix.isEmpty {
                            Text("quick_theme.ai_prompt_prefix_placeholder".localized())
                                .font(.body)
                                .foregroundColor(Color(.placeholderText))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 16)
                                .allowsHitTesting(false)
                        }
                        TextEditor(text: $aiPromptPrefix)
                            .frame(minHeight: 80)
                            .padding(8)
                            .scrollContentBackground(.hidden)
                    }
                    .background(Color(.systemBackground))
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
                
                Text("quick_theme.ai_prompt_prefix_hint".localized())
                    .font(.caption2)
                    .foregroundColor(.secondary)
                }
            }
            
            // AI 指令定義
            sectionHeader(title: "quick_theme.ai_instruction".localized(), showSparkle: true)
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Spacer()
                    Button {
                        aiCompleteInstruction()
                    } label: {
                        if isAICompletingInstruction {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Text("quick_theme.ai_complete".localized())
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }
                    .disabled(isAICompletingInstruction || themeTitle.isEmpty)
                }
                
                ZStack(alignment: .topLeading) {
                    if aiInstruction.isEmpty {
                        Text("quick_theme.ai_instruction_placeholder".localized())
                            .font(.body)
                            .foregroundColor(Color(.placeholderText))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 16)
                            .allowsHitTesting(false)
                    }
                    TextEditor(text: $aiInstruction)
                        .frame(minHeight: 120)
                        .padding(8)
                        .scrollContentBackground(.hidden)
                }
                .background(Color(.systemBackground))
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
                
                Text("quick_theme.ai_instruction_hint".localized())
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .sheet(isPresented: $showIconPicker) {
            iconPickerSheet
        }
    }
    
    private func sectionHeader(title: String, showSparkle: Bool = false) -> some View {
        HStack(spacing: 8) {
            Rectangle()
                .fill(Color.blue)
                .frame(width: 4, height: 18)
            
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            
            if showSparkle {
                Image(systemName: "sparkles")
                    .font(.caption)
                    .foregroundColor(.blue)
            }
        }
    }
    
    private var iconPickerSheet: some View {
        NavigationView {
            VStack(spacing: 20) {
                // 顏色選擇
                VStack(alignment: .leading, spacing: 8) {
                    Text("quick_theme.color".localized())
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 12) {
                        ForEach(colorOptions, id: \.0) { hex, _ in
                            Button {
                                selectedColorHex = hex
                            } label: {
                                Circle()
                                    .fill(Color(hex: hex) ?? .blue)
                                    .frame(width: 32, height: 32)
                                    .overlay(
                                        Circle()
                                            .stroke(selectedColorHex == hex ? Color.primary : Color.clear, lineWidth: 3)
                                    )
                            }
                        }
                    }
                }
                
                // 圖示網格
                VStack(alignment: .leading, spacing: 8) {
                    Text("quick_theme.icon".localized())
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 12) {
                        ForEach(iconOptions, id: \.self) { icon in
                            Button {
                                selectedIcon = icon
                            } label: {
                                Image(systemName: icon)
                                    .font(.system(size: 24))
                                    .foregroundColor(selectedIcon == icon ? (Color(hex: selectedColorHex) ?? .blue) : .gray)
                                    .frame(width: 44, height: 44)
                                    .background(selectedIcon == icon ? (Color(hex: selectedColorHex) ?? .blue).opacity(0.2) : Color.clear)
                                    .cornerRadius(10)
                            }
                        }
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("quick_theme.change_icon".localized())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("quick_theme.done".localized()) {
                        showIconPicker = false
                    }
                }
            }
        }
    }
    
    // MARK: - Step 2 內容：表單問題卡片（EventEditView 風格，每卡含說明＋重新 AI 生成）
    private var step2Content: some View {
        VStack(alignment: .leading, spacing: 16) {
            if isGeneratingQuestions {
                HStack(spacing: 12) {
                    ProgressView()
                    Text("quick_theme.ai_thinking".localized())
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(24)
            } else {
                ForEach(Array(formQuestions.enumerated()), id: \.element.id) { index, question in
                    formQuestionCardEventStyle(index: index, question: question)
                }
                
                Button(action: addNewQuestion) {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 20))
                        Text("quick_theme.add_question".localized())
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.blue)
                    .frame(maxWidth: .infinity)
                    .padding(16)
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(style: StrokeStyle(lineWidth: 2, dash: [6]))
                            .foregroundColor(.blue.opacity(0.5))
                    )
                }
            }
        }
    }
    
    private func iconForQuestionType(_ type: ThemeFormQuestionType) -> String {
        switch type {
        case .text: return "textformat"
        case .number: return "number"
        case .select: return "list.bullet"
        case .multiSelect: return "list.bullet.rectangle"
        case .date: return "calendar"
        }
    }
    
    @ViewBuilder
    private func formQuestionCardEventStyle(index: Int, question: ThemeFormQuestion) -> some View {
        let label = formQuestions[safe: index]?.label ?? question.label
        
        EventFormCard(icon: iconForQuestionType(question.type), title: label.isEmpty ? "quick_theme.question_label_placeholder".localized() : label, iconColor: .blue) {
            VStack(alignment: .leading, spacing: 16) {
                // 問題標籤（可編輯）
                VStack(alignment: .leading, spacing: 4) {
                    Text("quick_theme.question_label".localized())
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                    TextField("quick_theme.question_label_placeholder".localized(), text: Binding(
                        get: { formQuestions[safe: index]?.label ?? question.label },
                        set: { if formQuestions.indices.contains(index) { formQuestions[index].label = $0 } }
                    ))
                    .lineLimit(1)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color(UIColor.systemGray6)))
                }
                
                // 說明（可直接看到，可編輯）
                VStack(alignment: .leading, spacing: 4) {
                    Text("quick_theme.question_description".localized())
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                    TextField("quick_theme.description_placeholder".localized(), text: Binding(
                        get: { formQuestions[safe: index]?.description ?? question.description ?? "" },
                        set: { if formQuestions.indices.contains(index) { formQuestions[index].description = $0.isEmpty ? nil : $0 } }
                    ), axis: .vertical)
                    .lineLimit(2...4)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color(UIColor.systemGray6)))
                }
                
                // 選項區（select / multiSelect）
                formQuestionCardOptionsSection(index: index, question: question)
                
                // 數字區（number）
                formQuestionCardNumberSection(index: index, question: question)
                
                // 底部：類型標籤、刪除、重新 AI 生成
                HStack {
                    Text(question.type.rawValue)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(.systemGray6))
                        .cornerRadius(6)
                    
                    Button(action: { deleteQuestion(at: index) }) {
                        HStack(spacing: 4) {
                            Image(systemName: "trash")
                            Text("quick_theme.delete".localized())
                                .font(.caption)
                        }
                        .foregroundColor(.red)
                    }
                    
                    Spacer()
                    
                    Button(action: { regenerateQuestionWithAI(at: index) }) {
                        if generatingQuestionIndex == index {
                            ProgressView().scaleEffect(0.8)
                        } else {
                            HStack(spacing: 4) {
                                Image(systemName: "sparkles")
                                Text("quick_theme.regenerate_ai".localized())
                                    .font(.caption)
                            }
                            .foregroundColor(.blue)
                        }
                    }
                    .disabled(generatingQuestionIndex == index)
                }
            }
        }
    }
    
    @ViewBuilder
    private func formQuestionCardOptionsSection(index: Int, question: ThemeFormQuestion) -> some View {
        if question.type == .select || question.type == .multiSelect, let options = formQuestions[safe: index]?.options ?? question.options {
            VStack(alignment: .leading, spacing: 8) {
                Text("quick_theme.options".localized())
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                
                ForEach(Array(options.enumerated()), id: \.offset) { optIndex, opt in
                    HStack(spacing: 8) {
                        TextField("", text: Binding(
                            get: { formQuestions[safe: index]?.options?[safe: optIndex] ?? opt },
                            set: { newVal in
                                if formQuestions.indices.contains(index),
                                   var opts = formQuestions[index].options,
                                   opts.indices.contains(optIndex) {
                                    opts[optIndex] = newVal
                                    formQuestions[index].options = opts
                                }
                            }
                        ))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color(UIColor.systemGray6)))
                        
                        Button(action: { removeOption(at: index, optionIndex: optIndex) }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Button(action: { addOption(at: index) }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                        Text("quick_theme.add_option".localized())
                            .font(.caption)
                    }
                    .foregroundColor(.blue)
                }
            }
        }
    }
    
    @ViewBuilder
    private func formQuestionCardNumberSection(index: Int, question: ThemeFormQuestion) -> some View {
        if question.type == .number {
            VStack(alignment: .leading, spacing: 8) {
                Text("quick_theme.unit_and_range".localized())
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                HStack(spacing: 12) {
                    TextField("quick_theme.unit_placeholder".localized(), text: Binding(
                        get: { formQuestions[safe: index]?.unit ?? question.unit ?? "" },
                        set: { if formQuestions.indices.contains(index) { formQuestions[index].unit = $0.isEmpty ? nil : $0 } }
                    ))
                    .frame(width: 60)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color(UIColor.systemGray6)))
                    Text("quick_theme.range".localized())
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("min", value: Binding(
                        get: { formQuestions[safe: index]?.minValue ?? question.minValue ?? 0 },
                        set: { if formQuestions.indices.contains(index) { formQuestions[index].minValue = $0 } }
                    ), format: .number)
                    .frame(width: 50)
                    .keyboardType(.numberPad)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color(UIColor.systemGray6)))
                    Text("~")
                    TextField("max", value: Binding(
                        get: { formQuestions[safe: index]?.maxValue ?? question.maxValue ?? 999 },
                        set: { if formQuestions.indices.contains(index) { formQuestions[index].maxValue = $0 } }
                    ), format: .number)
                    .frame(width: 50)
                    .keyboardType(.numberPad)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color(UIColor.systemGray6)))
                }
            }
        }
    }
    
    // MARK: - 底部按鈕
    private var bottomButtons: some View {
        VStack(spacing: 12) {
            Button {
                hideKeyboard()
                if currentStep == .step1 {
                    currentStep = .step2
                    if formQuestions.isEmpty {
                        generateFormQuestionsForStep2()
                    }
                } else {
                    saveTemplate()
                }
            } label: {
                Text(currentStep == .step1 ? "quick_theme.next".localized() : "quick_theme.save".localized())
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(canProceed ? Color.blue : Color.gray)
                    .cornerRadius(12)
            }
            .disabled(!canProceed)
        }
        .padding()
        .background(Color(.systemBackground))
    }
    
    private var canProceed: Bool {
        switch currentStep {
        case .step1:
            return !themeTitle.trimmingCharacters(in: .whitespaces).isEmpty
        case .step2:
            return true
        }
    }
    
    // MARK: - AI 生成主題專屬提示詞
    private func generatePromptPrefixWithAI() {
        guard !themeTitle.isEmpty else { return }
        isAIGeneratingPromptPrefix = true
        
        Task {
            do {
                let suggestion = try await AITemplateHelper.shared.generateThemePromptPrefix(
                    themeTitle: themeTitle.trimmingCharacters(in: .whitespaces)
                )
                await MainActor.run {
                    aiPromptPrefix = suggestion
                    isAIGeneratingPromptPrefix = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                    isAIGeneratingPromptPrefix = false
                }
            }
        }
    }
    
    // MARK: - AI 補全指令
    private func aiCompleteInstruction() {
        guard !themeTitle.isEmpty else { return }
        isAICompletingInstruction = true
        
        Task {
            do {
                let suggestion = try await AITemplateHelper.shared.completeAIInstruction(
                    themeTitle: themeTitle,
                    partialInstruction: aiInstruction
                )
                await MainActor.run {
                    aiInstruction = suggestion
                    isAICompletingInstruction = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                    isAICompletingInstruction = false
                }
            }
        }
    }
    
    // MARK: - Step 2：進入時生成表單問題
    private func generateFormQuestionsForStep2() {
        isGeneratingQuestions = true
        Task {
            do {
                let questions = try await AITemplateHelper.shared.generateFormQuestions(
                    themeTitle: themeTitle.trimmingCharacters(in: .whitespaces),
                    aiInstruction: aiInstruction
                )
                await MainActor.run {
                    formQuestions = questions
                    isGeneratingQuestions = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                    isGeneratingQuestions = false
                }
            }
        }
    }
    
    private func regenerateQuestionWithAI(at index: Int) {
        guard formQuestions.indices.contains(index) else { return }
        let q = formQuestions[index]
        if q.type == .select || q.type == .multiSelect {
            generateOptionsForQuestion(at: index)
        } else {
            regenerateWholeQuestion(at: index)
        }
    }
    
    private func regenerateWholeQuestion(at index: Int) {
        guard formQuestions.indices.contains(index) else { return }
        let current = formQuestions[index]
        generatingQuestionIndex = index
        Task {
            do {
                let replacement = try await AITemplateHelper.shared.regenerateSingleQuestion(
                    themeTitle: themeTitle.trimmingCharacters(in: .whitespaces),
                    aiInstruction: aiInstruction,
                    currentQuestion: current
                )
                await MainActor.run {
                    if formQuestions.indices.contains(index) {
                        let existingId = formQuestions[index].id
                        formQuestions[index] = ThemeFormQuestion(
                            id: existingId,
                            label: replacement.label,
                            type: replacement.type,
                            options: replacement.options,
                            unit: replacement.unit,
                            placeholder: replacement.placeholder,
                            defaultValue: replacement.defaultValue,
                            minValue: replacement.minValue,
                            maxValue: replacement.maxValue,
                            description: replacement.description
                        )
                    }
                    generatingQuestionIndex = nil
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                    generatingQuestionIndex = nil
                }
            }
        }
    }
    
    private func generateOptionsForQuestion(at index: Int) {
        guard formQuestions.indices.contains(index) else { return }
        let q = formQuestions[index]
        let desc = q.description ?? q.label
        generatingQuestionIndex = index
        Task {
            do {
                let opts = try await AITemplateHelper.shared.generateOptionsFromDescription(
                    questionLabel: q.label,
                    description: desc
                )
                await MainActor.run {
                    if formQuestions.indices.contains(index) {
                        formQuestions[index].options = opts
                    }
                    generatingQuestionIndex = nil
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                    generatingQuestionIndex = nil
                }
            }
        }
    }
    
    private func addNewQuestion() {
        let newId = "q_\(UUID().uuidString.prefix(6))"
        formQuestions.append(ThemeFormQuestion(
            id: newId,
            label: "",
            type: .text,
            options: nil,
            unit: nil,
            placeholder: nil,
            defaultValue: nil,
            minValue: nil,
            maxValue: nil,
            description: nil
        ))
    }
    
    private func deleteQuestion(at index: Int) {
        guard formQuestions.indices.contains(index) else { return }
        formQuestions.remove(at: index)
    }
    
    private func addOption(at questionIndex: Int) {
        guard formQuestions.indices.contains(questionIndex) else { return }
        var opts = formQuestions[questionIndex].options ?? []
        opts.append("")
        formQuestions[questionIndex].options = opts
    }
    
    private func removeOption(at questionIndex: Int, optionIndex: Int) {
        guard formQuestions.indices.contains(questionIndex),
              var opts = formQuestions[questionIndex].options,
              opts.indices.contains(optionIndex) else { return }
        opts.remove(at: optionIndex)
        formQuestions[questionIndex].options = opts.isEmpty ? nil : opts
    }
    
    // MARK: - 儲存
    private func saveTemplate() {
        let questionsToSave = formQuestions.filter { !$0.label.trimmingCharacters(in: .whitespaces).isEmpty }
        let key = "custom_\(UUID().uuidString.prefix(8))"
        let theme = QuickTheme(
            key: key,
            icon: selectedIcon,
            iconColorHex: selectedColorHex,
            title: themeTitle.trimmingCharacters(in: .whitespaces),
            aiPromptPrefix: aiPromptPrefix.isEmpty ? nil : aiPromptPrefix.trimmingCharacters(in: .whitespaces),
            themeMode: themeMode,
            aiInstruction: aiInstruction.isEmpty ? nil : aiInstruction,
            advancedParams: nil,
            formQuestions: questionsToSave.isEmpty ? nil : questionsToSave,
            isBuiltIn: false
        )
        themeManager.addCustomTheme(theme, userId: userManager.userOpenId)
        // 同步主題專屬提示詞到 Firebase
        if let prefix = theme.aiPromptPrefix, !prefix.isEmpty {
            Task {
                await ThemePromptService.shared.savePrompt(themeKey: key, promptPrefix: prefix, userId: userManager.userOpenId)
            }
        }
        dismiss()
    }
}

// MARK: - AI 輔助
final class AITemplateHelper {
    static let shared = AITemplateHelper()
    
    /// 生成主題專屬提示詞：約束 AI 只生成符合主題的行程，避免偏題（如寵物餵養→天安門旅遊）
    func generateThemePromptPrefix(themeTitle: String) async throws -> String {
        let prompt = """
        請為「\(themeTitle)」主題生成一段「主題專屬提示詞」，用於約束 AI 行程生成。
        
        要求：
        1. 明確說明行程必須圍繞的主題內容（如寵物餵養→寵物餐廳、寵物公園、寵物友善景點）
        2. 明確禁止的內容（如禁止安排一般旅遊景點、歷史古蹟等與主題無關的地點）
        3. 格式：【主題：xxx】開頭，3-5 行，每行以「-」開頭
        4. 直接輸出提示詞，不要加引號或額外說明
        
        範例（寵物餵養）：
        【主題：寵物餵養】
        - 行程必須圍繞寵物相關活動：寵物餐廳、寵物咖啡館、寵物公園、寵物友善景點、寵物用品店等
        - 禁止安排一般旅遊景點（如天安門、故宮、博物館等與寵物無關的地點）
        - 所有景點必須為寵物友善或與寵物相關
        """
        return try await callOpenAI(prompt: prompt, maxTokens: 400)
    }
    
    func completeAIInstruction(themeTitle: String, partialInstruction: String) async throws -> String {
        let prompt = """
        請根據以下行程主題，補全或完善 AI 的行程規劃指令。要求簡潔、具體，可指導 AI 生成符合該主題的行程。
        
        主題：\(themeTitle)
        用戶已填寫（可在此基礎上擴充）：\(partialInstruction.isEmpty ? "（無）" : partialInstruction)
        
        請直接輸出完善後的指令（不要加引號或說明），約 50-150 字。
        """
        return try await callOpenAI(prompt: prompt, maxTokens: 500)
    }
    
    func suggestAdvancedParams(themeTitle: String, aiInstruction: String) async throws -> String {
        let prompt = """
        請根據以下行程模版，思考還缺少哪些重要資訊，以便規劃更適合的行程。列出 3-5 項建議的進階參數或補充問題。
        
        主題：\(themeTitle)
        AI 指令：\(aiInstruction.isEmpty ? "（無）" : aiInstruction)
        
        請直接輸出建議列表（每項一行，簡潔），格式如：
        - 建議考慮的交通方式
        - 預算範圍
        - 同行人數
        """
        return try await callOpenAI(prompt: prompt, maxTokens: 500)
    }
    
    /// 根據說明由 AI 生成選項（用於 select/multiSelect 類型）
    func generateOptionsFromDescription(questionLabel: String, description: String) async throws -> [String] {
        let prompt = """
        根據以下問題與說明，生成 3-8 個選項。請輸出「純 JSON」陣列，不要加 markdown 或說明。
        
        問題：\(questionLabel)
        說明：\(description.isEmpty ? "（無）" : description)
        
        範例輸出：["選項1","選項2","選項3"]
        """
        let raw = try await callOpenAI(prompt: prompt, maxTokens: 300)
        let jsonStr = raw
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = jsonStr.data(using: .utf8),
              let arr = try? JSONDecoder().decode([String].self, from: data) else {
            throw NSError(domain: "AITemplateHelper", code: -2, userInfo: [NSLocalizedDescriptionKey: "無法解析選項 JSON"])
        }
        return arr
    }
    
    /// 重新生成單一問題（替換現有問題）
    func regenerateSingleQuestion(themeTitle: String, aiInstruction: String, currentQuestion: ThemeFormQuestion) async throws -> ThemeFormQuestion {
        let prompt = """
        根據以下主題與指令，重新生成「一個」表單問題，用於取代現有問題。保持相同類型(\(currentQuestion.type.rawValue))，但可優化 label、description、options 等。
        
        主題：\(themeTitle)
        AI 指令：\(aiInstruction.isEmpty ? "（無）" : aiInstruction)
        現有問題：\(currentQuestion.label)，說明：\(currentQuestion.description ?? "（無）")
        
        請輸出「純 JSON」物件，不要加 markdown 或說明。格式：
        {"id":"\(currentQuestion.id)","label":"新標籤","type":"\(currentQuestion.type.rawValue)","description":"說明","options":["選項1","選項2"]}
        - number 型可加 unit, minValue, maxValue
        - select/multiSelect 必須有 options
        """
        let raw = try await callOpenAI(prompt: prompt, maxTokens: 400)
        let jsonStr = raw
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        struct QuestionDTO: Codable {
            let id: String
            let label: String
            let type: String
            var options: [String]?
            var unit: String?
            var placeholder: String?
            var defaultValue: String?
            var minValue: Int?
            var maxValue: Int?
            var description: String?
        }
        
        guard let data = jsonStr.data(using: .utf8),
              let dto = try? JSONDecoder().decode(QuestionDTO.self, from: data),
              let qType = ThemeFormQuestionType(rawValue: dto.type) else {
            throw NSError(domain: "AITemplateHelper", code: -2, userInfo: [NSLocalizedDescriptionKey: "無法解析 JSON"])
        }
        return ThemeFormQuestion(
            id: dto.id,
            label: dto.label,
            type: qType,
            options: dto.options,
            unit: dto.unit,
            placeholder: dto.placeholder,
            defaultValue: dto.defaultValue,
            minValue: dto.minValue,
            maxValue: dto.maxValue,
            description: dto.description
        )
    }
    
    /// 根據主題內容由 AI 生成結構化表單問題，用於 AIPlannerView 動態收集所需資訊
    /// 不同主題應產生截然不同的問題結構（學習→週數/科目、運動→頻率/類型、旅行→目的地/天數等）
    func generateFormQuestions(themeTitle: String, aiInstruction: String) async throws -> [ThemeFormQuestion] {
        let prompt = """
        根據以下主題，生成 3-6 個表單問題，用於收集規劃時間安排所需的資訊。
        
        【重要】不同主題必須有完全不同的問題類型與結構，切勿套用同一套模板。
        - 學習類：用 duration_weeks（持續週數）、session_minutes（每次時長）、subjects（科目）
        - 運動/健身類：用 sessions_per_week（每週次數）、sport_type（運動類型）、goal（目標）
        - 旅行類：用 plan_start_date（開始日期）、duration_days（天數）、destination（目的地）
        - 工作/專案類：用 deadline（截止日）、priority（優先級）、milestones（里程碑）
        
        主題：\(themeTitle)
        AI 指令：\(aiInstruction.isEmpty ? "（無）" : aiInstruction)
        
        【保留欄位 ID】若主題需要「開始日期」或「時長」，請使用以下 id 以取代系統預設區塊：
        - 開始日期：id 用 "plan_start_date" 或 "start_date"，type 用 "date"
        - 時長（天）：id 用 "duration_days" 或 "plan_duration_days"，type 用 "number"，unit 用 "天"
        - 時長（週）：id 用 "duration_weeks" 或 "plan_duration_weeks"，type 用 "number"，unit 用 "週"
        
        請輸出「純 JSON」陣列，不要加 markdown 或說明。格式範例（學習主題）：
        [
          {"id":"plan_start_date","label":"計劃開始日期","type":"date","description":"學習計畫的起始日"},
          {"id":"duration_weeks","label":"持續週數","type":"number","unit":"週","minValue":1,"maxValue":52,"description":"規劃學習計畫的總週數"},
          {"id":"session_minutes","label":"每次學習多久","type":"number","unit":"分鐘","minValue":15,"maxValue":180,"description":"單次學習時長"},
          {"id":"subjects","label":"科目選擇","type":"multiSelect","options":["數學","英文","程式"],"description":"欲加強的科目"}
        ]
        
        運動主題範例（完全不同結構）：
        [
          {"id":"plan_start_date","label":"計劃開始日期","type":"date","description":"運動計畫起始日"},
          {"id":"duration_weeks","label":"計劃週數","type":"number","unit":"週","minValue":1,"maxValue":24,"description":"運動計畫總週數"},
          {"id":"sport_type","label":"運動類型","type":"select","options":["跑步","游泳","重訓","瑜伽"],"description":"主要運動項目"},
          {"id":"sessions_per_week","label":"每週幾次","type":"number","unit":"次","minValue":1,"maxValue":7,"description":"每週運動頻率"},
          {"id":"goal","label":"目標","type":"text","placeholder":"例如：減重 5kg、跑半馬","description":"個人目標"}
        ]
        
        每個問題需有 description 欄位。支援的 type：text, number, select, multiSelect, date
        - number 可加 unit, minValue, maxValue
        - select/multiSelect 必須有 options 陣列，且選項數量限制 2-8 條
        - 每個問題必須有 id（英文、全小寫、snake_case）和 label（顯示文字）
        - 每主題問題數量上限 6 條
        
        【ID 詞典】請盡量使用以下 id：plan_start_date, duration_days, duration_weeks, goal, must_do, avoid, pace, budget_level | travel_destination, travel_areas, travel_transport_preference | learn_subjects, learn_daily_minutes, learn_sessions_per_week, learn_level | fit_goal, fit_sport_type, fit_sessions_per_week, fit_session_minutes | meet_participants, meet_location, meet_agenda_items | home_tasks_scope
        """
        let raw = try await callOpenAI(prompt: prompt, maxTokens: 800)
        let jsonStr = raw
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard let data = jsonStr.data(using: .utf8) else {
            throw NSError(domain: "AITemplateHelper", code: -2, userInfo: [NSLocalizedDescriptionKey: "無法解析 JSON"])
        }
        
        struct QuestionDTO: Codable {
            let id: String
            let label: String
            let type: String
            var options: [String]?
            var unit: String?
            var placeholder: String?
            var defaultValue: String?
            var minValue: Int?
            var maxValue: Int?
            var description: String?
        }
        
        let dtos = try JSONDecoder().decode([QuestionDTO].self, from: data)
        let mapped = dtos.prefix(6).compactMap { dto -> ThemeFormQuestion? in
            guard let qType = ThemeFormQuestionType(rawValue: dto.type) else { return nil }
            var opts = dto.options
            if let o = opts, (o.count < 2 || o.count > 8) {
                opts = Array(o.prefix(8))
                if opts!.count < 2 { opts = nil }
            }
            let id = dto.id.lowercased().replacingOccurrences(of: " ", with: "_")
            return ThemeFormQuestion(
                id: id,
                label: dto.label,
                type: qType,
                options: opts,
                unit: dto.unit,
                placeholder: dto.placeholder,
                defaultValue: dto.defaultValue,
                minValue: dto.minValue,
                maxValue: dto.maxValue,
                description: dto.description
            )
        }
        return Array(mapped)
    }
    
    private func callOpenAI(prompt: String, maxTokens: Int) async throws -> String {
        guard AIConfig.shared.isOpenAIEnabled else {
            throw NSError(domain: "AITemplateHelper", code: -1, userInfo: [NSLocalizedDescriptionKey: "OpenAI API 已禁用"])
        }
        
        let key: String
        if let k = Bundle.main.infoDictionary?["OPENAI_API_KEY"] as? String, !k.isEmpty, k != "$(OPENAI_API_KEY)" {
            key = k
        } else if let envKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"], !envKey.isEmpty {
            key = envKey
        } else {
            throw NSError(domain: "AITemplateHelper", code: -1, userInfo: [NSLocalizedDescriptionKey: "API Key 未配置"])
        }
        
        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": [
                ["role": "system", "content": "You are a helpful assistant. Respond in 繁體中文."],
                ["role": "user", "content": prompt]
            ],
            "temperature": 0.7,
            "max_tokens": maxTokens
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let first = choices.first,
              let message = first["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw NSError(domain: "AITemplateHelper", code: 0, userInfo: [NSLocalizedDescriptionKey: "解析回應失敗"])
        }
        
        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

#Preview {
    CreateTripTemplateView()
        .environmentObject(FirebaseUserManager.shared)
}
