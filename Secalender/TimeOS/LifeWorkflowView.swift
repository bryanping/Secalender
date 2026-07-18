//
//  LifeWorkflowView.swift
//  Secalender
//
//  修改内容：生活協作工作流頁 — 讓買菜/餵狗/打掃「體現為工作流」而非預填文字：
//  預設步驟清單（可勾選/編輯時長/自行新增）→ 選安排範圍（今天/3 天/7 天）→
//  一次性項目塞空檔、每日型（餵狗）每天各排一次 → PlanDetailView 統一預覽 → 套用寫 time_items。
//

import SwiftUI

struct LifeWorkflowView: View {
    let workflow: PlannerWorkflow
    @EnvironmentObject var userManager: FirebaseUserManager
    @Environment(\.dismiss) var dismiss

    @State private var items: [WorkflowPresetItem] = []
    @State private var selectedIds: Set<String> = []
    @State private var newItemTitle: String = ""
    @State private var rangeDays: Int = 3
    @State private var isScheduling = false
    @State private var previewResult: GenerationResult? = nil
    @State private var errorMessage: String? = nil

    private var selectedItems: [WorkflowPresetItem] {
        items.filter { selectedIds.contains($0.id) }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        // 標題（與其他頁一致的 28pt 樣式）
                        VStack(alignment: .leading, spacing: 8) {
                            Text(workflow.title)
                                .font(.system(size: 28, weight: .bold))
                            Text(workflow.repeatsDaily ? "勾選每天要做的事，AI 排進每日空檔" : "勾選步驟，AI 排進近期空檔")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

                        // 步驟清單（預設模板＋可編輯）
                        VStack(alignment: .leading, spacing: 10) {
                            Text("步驟清單")
                                .font(.headline)
                            ForEach($items) { $item in
                                stepRow($item)
                            }
                            // 新增步驟
                            HStack(spacing: 10) {
                                TextField("新增步驟，例：買狗糧", text: $newItemTitle)
                                    .padding(10)
                                    .background(Color(.systemBackground))
                                    .cornerRadius(10)
                                Button(action: addItem) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 26))
                                        .foregroundColor(newItemTitle.trimmingCharacters(in: .whitespaces).isEmpty ? .gray : workflow.color)
                                }
                                .disabled(newItemTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                            }
                        }

                        // 安排範圍
                        VStack(alignment: .leading, spacing: 10) {
                            Text(workflow.repeatsDaily ? "重複天數" : "安排範圍")
                                .font(.headline)
                            Picker("", selection: $rangeDays) {
                                Text(workflow.repeatsDaily ? "3 天" : "今天").tag(workflow.repeatsDaily ? 3 : 1)
                                Text(workflow.repeatsDaily ? "7 天" : "3 天內").tag(workflow.repeatsDaily ? 7 : 3)
                                if !workflow.repeatsDaily {
                                    Text("7 天內").tag(7)
                                }
                            }
                            .pickerStyle(.segmented)
                            if workflow.repeatsDaily {
                                Text("每天各排一次（如 3 項 × 7 天 = 21 筆）")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }

                        Spacer().frame(height: 12)
                    }
                    .padding()
                }
                .scrollDismissesKeyboard(.interactively)

                // 底部
                VStack(spacing: 8) {
                    Button(action: runSchedule) {
                        HStack {
                            if isScheduling { ProgressView().tint(.white) }
                            Text(selectedIds.isEmpty ? "勾選要安排的步驟" : "AI 排進空檔（\(selectedIds.count) 項）")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(selectedIds.isEmpty ? Color.gray : workflow.color)
                        .foregroundColor(.white)
                        .cornerRadius(14)
                    }
                    .disabled(selectedIds.isEmpty || isScheduling)
                }
                .padding(.horizontal)
                .padding(.vertical, 10)
                .background(Color(UIColor.systemBackground))
                .overlay(Rectangle().fill(Color(UIColor.systemGray5)).frame(height: 0.5), alignment: .top)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(workflow.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                    }
                }
            }
            .onAppear {
                if items.isEmpty {
                    items = workflow.presetItems
                    selectedIds = Set(items.map(\.id))  // 預設全選
                    rangeDays = workflow.repeatsDaily ? 7 : 3
                }
            }
            .alert("發生錯誤", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("確定", role: .cancel) { errorMessage = nil }
            } message: {
                if let msg = errorMessage { Text(msg) }
            }
            .fullScreenCover(item: $previewResult) { result in
                NavigationView {
                    PlanDetailView(
                        plan: PlanResult(days: [], assumptions: [], riskFlags: result.riskFlags),
                        customTitle: workflow.title,
                        generationResult: result,
                        onDismiss: { previewResult = nil },
                        onRegenerate: {
                            previewResult = nil
                            runSchedule()
                        },
                        onApplied: {
                            previewResult = nil
                            dismiss()
                        }
                    )
                    .environmentObject(userManager)
                }
            }
        }
    }

    // MARK: - 步驟列（勾選＋時長調整＋刪除）
    private func stepRow(_ item: Binding<WorkflowPresetItem>) -> some View {
        let id = item.wrappedValue.id
        let isSelected = selectedIds.contains(id)
        return HStack(spacing: 12) {
            Button(action: {
                if isSelected { selectedIds.remove(id) } else { selectedIds.insert(id) }
            }) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundColor(isSelected ? workflow.color : Color(UIColor.systemGray3))
            }
            .buttonStyle(PlainButtonStyle())

            Text(item.wrappedValue.title)
                .font(.system(size: 15, weight: .medium))
                .lineLimit(1)
            Spacer()
            // 時長調整
            Menu {
                ForEach([15, 30, 45, 60, 90], id: \.self) { d in
                    Button("\(d) 分鐘") { item.wrappedValue.durationMin = d }
                }
            } label: {
                Text("\(item.wrappedValue.durationMin) 分")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(workflow.color)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(workflow.color.opacity(0.1))
                    .cornerRadius(8)
            }
            Button(action: { removeItem(id) }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(Color(UIColor.systemGray3))
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(12)
        .background(isSelected ? workflow.color.opacity(0.06) : Color(.systemBackground))
        .cornerRadius(12)
    }

    private func addItem() {
        let title = newItemTitle.trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty else { return }
        let item = WorkflowPresetItem(title: title, durationMin: 30)
        items.append(item)
        selectedIds.insert(item.id)
        newItemTitle = ""
    }

    private func removeItem(_ id: String) {
        items.removeAll { $0.id == id }
        selectedIds.remove(id)
    }

    // MARK: - 排程：一次性塞空檔；每日型逐日各排一次
    private func runSchedule() {
        let steps = selectedItems
        guard !steps.isEmpty else { return }
        isScheduling = true
        Task {
            do {
                let cal = Calendar.current
                let now = Date()
                let dayStart = cal.startOfDay(for: now)
                var allScheduled: [TimeItemCandidate] = []
                var unplaced = 0

                if workflow.repeatsDaily {
                    // 每日型：逐日排（每天的空檔各排一輪）
                    for dayOffset in 0..<rangeDays {
                        guard let day = cal.date(byAdding: .day, value: dayOffset, to: dayStart) else { continue }
                        let rangeStart = dayOffset == 0 ? max(now, day) : (cal.date(bySettingHour: 7, minute: 0, second: 0, of: day) ?? day)
                        let rangeEnd = cal.date(bySettingHour: 22, minute: 0, second: 0, of: day) ?? day
                        guard rangeStart < rangeEnd else { unplaced += steps.count; continue }
                        let existing = try await TimeItemService.shared.fetchFixedItems(rangeStart: rangeStart, rangeEnd: rangeEnd)
                        let candidates = steps.map { s in
                            TimeItemCandidate(title: s.title, durationMin: s.durationMin, type: .task, dayIndex: dayOffset)
                        }
                        let scheduled = GenerationSchedulerService.shared.schedule(
                            untimedCandidates: candidates,
                            rangeStart: rangeStart,
                            rangeEnd: rangeEnd,
                            existingItems: existing
                        )
                        unplaced += candidates.count - scheduled.count
                        allScheduled.append(contentsOf: scheduled)
                    }
                } else {
                    // 一次性：塞進範圍內空檔
                    let rangeEnd = cal.date(byAdding: .day, value: rangeDays, to: dayStart)
                        .flatMap { cal.date(bySettingHour: 23, minute: 59, second: 59, of: $0) } ?? now
                    let existing = try await TimeItemService.shared.fetchFixedItems(rangeStart: now, rangeEnd: rangeEnd)
                    let candidates = steps.map { s in
                        TimeItemCandidate(title: s.title, durationMin: s.durationMin, type: .task)
                    }
                    let scheduled = GenerationSchedulerService.shared.schedule(
                        untimedCandidates: candidates,
                        rangeStart: now,
                        rangeEnd: rangeEnd,
                        existingItems: existing
                    )
                    unplaced = candidates.count - scheduled.count
                    allScheduled = scheduled
                }

                var riskFlags: [String] = []
                if unplaced > 0 {
                    riskFlags.append("空檔不足，有 \(unplaced) 筆未能排入，可縮短時長或延長範圍後重試")
                }
                let sorted = allScheduled.sorted { ($0.startAt ?? .distantPast) < ($1.startAt ?? .distantPast) }

                await MainActor.run {
                    isScheduling = false
                    guard !sorted.isEmpty else {
                        errorMessage = "範圍內找不到足夠空檔，請調整後重試"
                        return
                    }
                    previewResult = GenerationResult(
                        resultType: .taskOnly,
                        plan: PlanResult(days: [], assumptions: [], riskFlags: riskFlags),
                        candidates: sorted,
                        conflicts: [],
                        riskFlags: riskFlags,
                        themeKey: "life_\(workflow.type.rawValue)"
                    )
                }
            } catch {
                await MainActor.run {
                    isScheduling = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

#Preview {
    LifeWorkflowView(workflow: .workflow(.grocery))
        .environmentObject(MockFirebaseUserManager.shared)
}
