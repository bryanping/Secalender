//
//  TimeOSHomeView.swift
//  Secalender
//
//  修改内容：Time OS = AI 時間工作流入口（AI Time Workspace）
//  進入路徑：時間秘書 Tab → 智能規劃主按鈕 → 本頁。
//  結構：① 一句話 AI 輸入框 ② 快速開始 ③ 生活協作 ④ 最近使用。
//  所有入口導向同一 AIPlannerView，僅帶不同 plannerModelType / workflow / 預設輸入；
//  本頁只負責入口，真正生成在 AIPlannerView → GenerationOrchestrator → PlanDetailView。
//

import SwiftUI

struct TimeOSHomeView: View {
    @EnvironmentObject var userManager: FirebaseUserManager
    @Environment(\.dismiss) var dismiss

    @State private var aiInput: String = ""
    @FocusState private var isInputFocused: Bool
    @State private var activeWorkflow: PlannerWorkflow? = nil
    @State private var showFreeInputPlanner = false
    @State private var showTravelPlanner = false  // 修改内容：Step A — 規劃行程直導旅遊四步驟
    // 修改内容：Step B — 建議收件匣（消費「存為建議」與未排任務）
    @State private var showSuggestionInbox = false
    @State private var pendingCount = 0
    // 修改内容：Step C — 今日工作台
    @State private var showTodayWorkspace = false
    // 修改内容：生活協作 — 帶步驟模板的工作流頁
    @State private var activeLifeWorkflow: PlannerWorkflow? = nil
    @State private var recents: [PlannerWorkflowRecents.Entry] = []

    private let gridColumns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    // ① 頂部一句話 AI 輸入框
                    aiInputSection

                    // ② 快速開始
                    sectionView(title: "快速開始") {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            ForEach(PlannerWorkflow.quickStart) { wf in
                                quickStartCard(wf)
                            }
                        }
                    }

                    // ③ 生活協作
                    sectionView(title: "生活協作") {
                        LazyVGrid(columns: gridColumns, spacing: 12) {
                            ForEach(PlannerWorkflow.lifeCollaboration) { wf in
                                lifeCard(wf)
                            }
                        }
                    }

                    // 修改内容：Step B — 待安排（建議收件匣入口，有內容才顯示）
                    if pendingCount > 0 {
                        Button(action: { showSuggestionInbox = true }) {
                            HStack(spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color.orange.opacity(0.12))
                                        .frame(width: 40, height: 40)
                                    Image(systemName: "tray.full.fill")
                                        .foregroundColor(.orange)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("待安排（\(pendingCount)）")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.primary)
                                    Text("已存的建議與未排任務，一鍵排進空檔")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(14)
                            .background(Color(.systemBackground))
                            .cornerRadius(16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }

                    // ④ 最近使用
                    if !recents.isEmpty {
                        sectionView(title: "最近使用") {
                            VStack(spacing: 10) {
                                ForEach(recents) { entry in
                                    if let wf = entry.workflow {
                                        recentRow(wf, usedAt: entry.usedAt)
                                    }
                                }
                            }
                        }
                    }

                    Spacer().frame(height: 24)
                }
                .padding()
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Time OS")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                    }
                }
            }
            .onAppear { recents = PlannerWorkflowRecents.load() }
            // 修改内容：Step B — 載入待安排數量（建議＋未排任務）
            .task { await loadPendingCount() }
            // 工作流入口 → 同一 AIPlannerView（帶 workflow 預設）
            .fullScreenCover(item: $activeWorkflow) { wf in
                AIPlannerView(workflow: wf)
                    .environmentObject(userManager)
            }
            // 自由輸入 → AIPlannerView（帶一句話，AI 判斷型態）
            .fullScreenCover(isPresented: $showFreeInputPlanner) {
                AIPlannerView(initialInput: aiInput)
                    .environmentObject(userManager)
            }
            // 修改内容：Step A — 規劃行程 → TravelPlannerContent 四步驟（自帶 NavigationView）
            .fullScreenCover(isPresented: $showTravelPlanner) {
                TravelPlannerContent()
                    .environmentObject(userManager)
            }
            // 修改内容：Step B — 建議收件匣；關閉後刷新待安排數量
            .fullScreenCover(isPresented: $showSuggestionInbox, onDismiss: {
                Task { await loadPendingCount() }
            }) {
                SuggestionInboxView()
                    .environmentObject(userManager)
            }
            // 修改内容：Step C — 今日工作台；關閉後刷新待安排數量（可能已消化建議）
            .fullScreenCover(isPresented: $showTodayWorkspace, onDismiss: {
                Task { await loadPendingCount() }
            }) {
                TodayWorkspaceView()
                    .environmentObject(userManager)
            }
            // 修改内容：生活協作 — 步驟模板工作流（買菜/餵狗/打掃）
            .fullScreenCover(item: $activeLifeWorkflow) { wf in
                LifeWorkflowView(workflow: wf)
                    .environmentObject(userManager)
            }
        }
    }

    // MARK: - ① AI 輸入框
    private var aiInputSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("今天想安排什麼？")
                .font(.system(size: 28, weight: .bold))
            Text("一句話描述，AI 幫你排好時間")
                .font(.subheadline)
                .foregroundColor(.secondary)

            HStack(spacing: 10) {
                Image(systemName: "sparkles")
                    .foregroundColor(.blue)
                TextField("例：幫我安排今天下午、規劃兩日遊、安排買菜", text: $aiInput, axis: .vertical)
                    .lineLimit(1...3)
                    .focused($isInputFocused)
                    .onSubmit { submitFreeInput() }
                if !aiInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Button(action: submitFreeInput) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 26))
                            .foregroundColor(.blue)
                    }
                }
            }
            .padding(14)
            .background(Color(.systemBackground))
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color(UIColor.systemGray4), lineWidth: 1)
            )
        }
    }

    private func submitFreeInput() {
        guard !aiInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        isInputFocused = false
        showFreeInputPlanner = true
    }

    // MARK: - 區塊容器
    private func sectionView<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 18, weight: .semibold))
            content()
        }
    }

    // MARK: - ② 快速開始卡片（2 欄大卡）
    private func quickStartCard(_ wf: PlannerWorkflow) -> some View {
        Button(action: { open(wf) }) {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: wf.icon)
                    .font(.system(size: 24))
                    .foregroundColor(wf.color)
                Text(wf.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                Text(wf.subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color(UIColor.systemGray5), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - ③ 生活協作卡片（3 欄小卡）
    private func lifeCard(_ wf: PlannerWorkflow) -> some View {
        Button(action: { open(wf) }) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(wf.color.opacity(0.12))
                        .frame(width: 48, height: 48)
                    Image(systemName: wf.icon)
                        .font(.system(size: 20))
                        .foregroundColor(wf.color)
                }
                Text(wf.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)
                if wf.isCollaborative {
                    Text("多人")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(UIColor.systemGray6))
                        .cornerRadius(6)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color(UIColor.systemGray5), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - ④ 最近使用列
    private func recentRow(_ wf: PlannerWorkflow, usedAt: Date) -> some View {
        Button(action: { open(wf) }) {
            HStack(spacing: 12) {
                Image(systemName: wf.icon)
                    .font(.system(size: 16))
                    .foregroundColor(wf.color)
                    .frame(width: 32, height: 32)
                    .background(wf.color.opacity(0.12))
                    .cornerRadius(8)
                VStack(alignment: .leading, spacing: 2) {
                    Text(wf.title)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.primary)
                    Text(relativeTime(usedAt))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(12)
            .background(Color(.systemBackground))
            .cornerRadius(14)
        }
        .buttonStyle(PlainButtonStyle())
    }

    // 修改内容：Step B — 待安排數量（建議＋未排任務；未登入或失敗時靜默為 0）
    private func loadPendingCount() async {
        let suggestions = (try? await TimeItemService.shared.fetchSuggestions()) ?? []
        let tasks = (try? await TimeItemService.shared.fetchFloatingTasks()) ?? []
        await MainActor.run { pendingCount = suggestions.count + tasks.count }
    }

    private func open(_ wf: PlannerWorkflow) {
        PlannerWorkflowRecents.record(wf)
        recents = PlannerWorkflowRecents.load()
        // 修改内容：Step A/C＋生活協作 — 旅遊走四步驟、安排今天走今日工作台、帶步驟模板走 LifeWorkflowView，其餘走 AIPlannerView
        if wf.usesTravelFlow {
            showTravelPlanner = true
        } else if wf.usesTodayWorkspace {
            showTodayWorkspace = true
        } else if wf.usesLifeFlow {
            activeLifeWorkflow = wf
        } else {
            activeWorkflow = wf
        }
    }

    private func relativeTime(_ date: Date) -> String {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        return f.localizedString(for: date, relativeTo: Date())
    }
}

#Preview {
    TimeOSHomeView()
        .environmentObject(MockFirebaseUserManager.shared)
}
