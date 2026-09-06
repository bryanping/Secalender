//
//  PlanDetailView.swift
//  Secalender
//
//  行程详情页面（统一处理单日和多日）
//

import SwiftUI
import Foundation
import CoreLocation
#if canImport(UIKit)
import UIKit
#endif

struct PlanDetailView: View {
    let plan: PlanResult
    var customTitle: String? = nil  // 用户自定义标题
    /// 生成引擎輸出；有值時顯示衝突並提供直接套用 / 存為建議 / scheduler 補時間（一律寫入 time_items）
    var generationResult: GenerationResult? = nil
    var onEdit: ((PlanResult) -> Void)? = nil
    var onPlanUpdated: ((PlanResult) -> Void)? = nil
    var onAddToCalendar: (() -> Void)? = nil
    var onSaveToTemplate: ((String?) -> Void)? = nil
    var onDismiss: (() -> Void)? = nil
    var onSave: (() -> Void)? = nil
    var onShare: (() -> Void)? = nil
    // 修改内容：Time OS — 統一安排預覽：重新生成回調＋多人協作旗標（顯示「發送給成員確認」）
    var onRegenerate: (() -> Void)? = nil
    var isCollaborative: Bool = false
    // 修改內容：預覽與套用一致性 — 套用後回傳實際結果（ApplyOutcome），來源頁只消耗真正寫入成功的項目
    var onApplied: ((ApplyOutcome) -> Void)? = nil
    // 修改內容：常用安排 — 呼叫端提供本次標準化輸入草稿；有值時「更多」選單顯示「存成常用安排」
    var presetDraft: PlanningPreset? = nil
    /// 修改内容：整體行程 — 由行事曆重新開啟時傳入原 requestId（重新套用會覆寫同批項目，不重複建立）
    var initialRequestId: String? = nil
    var initialTitle: String? = nil
    @State private var showSavePresetAlert = false
    @State private var presetName: String = ""
    @State private var presetSavedMessage: String? = nil
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var userManager: FirebaseUserManager
    @State private var isApplying = false
    @State private var applyError: String? = nil
    // 修改內容：預覽與套用一致性 — 唯一可編輯資料源
    //   有 days 的行程：planDays 為真相，套用時由 planDays 重建 candidates
    //   任務型（無 days）：editableCandidates 為真相
    @State private var editableCandidates: [TimeItemCandidate] = []
    @State private var existingItemsForConflict: [TimeItem] = []   // 供編輯後重新檢查衝突
    @State private var existingItemsLoaded = false                 // 現有行程是否已載入（未載入前沿用生成時衝突）
    @State private var liveConflicts: [ConflictInfo] = []          // 依當前資料重新計算的衝突
    @State private var applyRequestId: String = UUID().uuidString  // 本預覽的穩定 requestId（重試去重）
    @State private var applyOutcome: ApplyOutcome? = nil           // 套用結果 alert
    
    // 横向滚动相关状态
    @State private var selectedDayIndex: Int = 0  // 当前选中的日期索引
    @State private var planDays: [DayPlan] = []  // 可编辑的行程天数
    @State private var selectedBlock: TimeBlock? = nil  // 选中的 block（用于编辑）
    @State private var showBlockEditView = false  // 是否显示编辑页面
    
    // 功能菜单相关状态
    @State private var showActionSheet = false  // 显示操作菜单
    @State private var showShareSheet = false  // 显示分享菜单
    @State private var shareItems: [Any] = []  // 分享内容
    
    // GPS实时确认相关状态
    @StateObject private var locationManager = TransitLocationManager()
    @State private var gpsUpdateTask: Task<Void, Never>? = nil  // 后台GPS更新任务
    @State private var isDismissing = false  // 關閉中，避免 onPlanUpdated 在關閉時觸發重複彈出
    // 修改内容：頂部日期可修改 — 整體平移行程日期；套用時第一個行程不得在過去
    @State private var showStartDatePicker = false
    @State private var dayScrollTarget: Int? = nil        // 修改内容：點 D 按鈕的捲動目標
    @State private var isProgrammaticDayScroll = false    // 修改内容：程式捲動中，忽略滑動同步
    @State private var editedTitle: String? = nil  // 修改内容：可編輯標題（nil = 沿用預設）
    @State private var showTitleEditor = false
    @State private var titleDraft = ""
    @State private var pickedStartDate = Date()
    @State private var pastTimeAlert = false
    
    var body: some View {
        ZStack {
            // 白色背景，去除灰边
            Color.white
                .ignoresSafeArea()
            
            // 修改内容：Time OS — 統一安排預覽：依 resultType 顯示行程時間軸 / 任務清單 / 分工清單 / 待安排清單；底部固定操作列
            VStack(spacing: 0) {
                if let result = generationResult, plan.days.isEmpty, !result.candidates.isEmpty {
                    // 任務型結果（taskOnly / untimedPlan）：候選清單
                    // 修改內容：預覽與套用一致性 — 改用 editableCandidates / liveConflicts
                    if !liveConflicts.isEmpty {
                        conflictsBanner(conflicts: liveConflicts)
                    }
                    candidateListView(result)
                } else if plan.days.isEmpty {
                    // 空状态视图
                    Spacer()
                    VStack(spacing: 20) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("plan_detail.invalid_data".localized())
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                } else {
                    if generationResult != nil, !liveConflicts.isEmpty {
                        conflictsBanner(conflicts: liveConflicts)  // 修改內容：依當前 planDays 重新計算
                    }
                    headerCardView
                    if !planDays.isEmpty {
                        daySelectorBar
                    }
                    horizontalScrollContentView
                }

                // 底部固定操作列（僅生成引擎結果）
                if generationResult != nil {
                    bottomActionBar
                }
            }
        }
        .onAppear {
            planDays = plan.days
            if let rid = initialRequestId, !rid.isEmpty { applyRequestId = rid }  // 修改内容：整體行程
            if editedTitle == nil, let t = initialTitle, !t.isEmpty { editedTitle = t }
            // 修改內容：預覽與套用一致性 — 初始化可編輯資料源與衝突，並載入現有行程供編輯後重算
            if let result = generationResult {
                if editableCandidates.isEmpty { editableCandidates = result.candidates }
                if let rid = result.requestId, !rid.isEmpty { applyRequestId = rid }
                liveConflicts = result.conflicts
                loadExistingItemsForConflict()
            }
            // 启动后台GPS检查任务（每10分钟检查一次从餐厅到下一个景点的交通时间）
            startGPSUpdateTask()
        }
        .onDisappear {
            // 停止后台GPS检查任务
            stopGPSUpdateTask()
        }
        #if os(iOS)
        // 修复：使用 navigationBarBackButtonHidden 而不是 navigationBarHidden，避免 toolbar 不显示
        .navigationBarBackButtonHidden(true)
        #endif
        #if os(iOS)
        .navigationTitle("編輯行程")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    // 先停止 GPS 任務，避免關閉時 onPlanUpdated 觸發重複彈出
                    stopGPSUpdateTask()
                    isDismissing = true
                    if let onDismiss = onDismiss {
                        // 由父層控制關閉（fullScreenCover item 綁定）
                        onDismiss()
                    } else {
                        // 無 onDismiss 時使用系統 dismiss（如 TemplateDetailView）
                        dismiss()
                    }
                }) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(.primary)
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    showActionSheet = true
                }) {
                    Image(systemName: "ellipsis")
                        .foregroundColor(.primary)
                }
            }
        }
        .sheet(isPresented: $showBlockEditView) {
            if let block = selectedBlock {
                BlockEditView(
                    block: block,
                    onSave: { updatedBlock in
                        // 更新 block（不关闭编辑页面，继续编辑）
                        updateBlock(updatedBlock)
                        // 不关闭编辑页面，让用户可以继续编辑
                        // showBlockEditView = false
                        // selectedBlock = nil
                    },
                    onCancel: {
                        showBlockEditView = false
                        selectedBlock = nil
                    },
                    plan: plan,  // 传递完整行程用于地理围栏
                    interestTags: []  // 可以从plan或其他地方获取兴趣标签
                )
                .environmentObject(userManager)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
        }
        // 修改内容：功能整理 — 右上角僅留次要動作（主要動作在底部固定列，不重複）：
        // 套用/存建議移至底部；「用 scheduler 補時間」併入「套用到時間表」自動處理；「儲存」正名「存為模板」
        .confirmationDialog("更多操作", isPresented: $showActionSheet, titleVisibility: .visible) {
            if generationResult == nil {
                Button(initialRequestId != nil ? "更新到行事曆" : "加入行程") {  // 修改内容
                    addPlanToCalendar()
                }
            }
            Button("存為模板") {
                savePlan()
            }
            // 修改內容：常用安排 — 不需理解 prompt / 表單 schema，直接以本次輸入建立
            if let draft = presetDraft {
                Button("存成常用安排") {
                    presetName = draft.name
                    showSavePresetAlert = true
                }
            }
            // 修改内容：分享整併 — 生成階段不提供右上角分享（與底部「發送給成員確認」重疊）；僅模板/瀏覽情境保留
            if generationResult == nil {
                Button("分享") {
                    sharePlan()
                }
            }
            if onEdit != nil {
                Button("編輯整個行程") {
                    openPlanEditView()
                }
            }
            Button("取消", role: .cancel) {}
        }
        .sheet(isPresented: $showShareSheet) {
            ActivityViewController(activityItems: shareItems)
        }
        .overlay {
            if isApplying {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                ProgressView("寫入中…")
                    .tint(.white)
            }
        }
        .alert("套用失敗", isPresented: Binding(get: { applyError != nil }, set: { if !$0 { applyError = nil } })) {
            Button("確定", role: .cancel) { applyError = nil }
        } message: {
            if let msg = applyError { Text(msg) }
        }
        // 修改內容：常用安排 — 命名後保存（按帳號隔離）
        .alert("存成常用安排", isPresented: $showSavePresetAlert) {
            TextField("名稱", text: $presetName)
            Button("儲存") {
                guard var draft = presetDraft else { return }
                let trimmed = presetName.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { draft.name = trimmed }
                PlanningPresetStore.shared.upsert(draft, userId: userManager.userOpenId)
                presetSavedMessage = "已存成「\(draft.name)」，下次可直接沿用偏好"
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("會保存偏好與常用設定；日期等每次變動的條件下次重新確認")
        }
        .alert("已儲存", isPresented: Binding(get: { presetSavedMessage != nil }, set: { if !$0 { presetSavedMessage = nil } })) {
            Button("確定", role: .cancel) { presetSavedMessage = nil }
        } message: {
            if let m = presetSavedMessage { Text(m) }
        }
        // 修改內容：預覽與套用一致性 — 顯示實際寫入結果；有失敗可重試（同 requestId，不重複建立）
        .alert(applyOutcome?.hasAnyApplied == true ? "已加入日曆" : "未加入", isPresented: Binding(get: { applyOutcome != nil }, set: { if !$0 { applyOutcome = nil } })) {
            if let o = applyOutcome, o.failedCount > 0 {
                Button("重試失敗項目") {
                    applyOutcome = nil
                    if generationResult != nil { applyDirectToTimeItems() } else { addPlanToCalendar() }
                }
            }
            Button("確定", role: .cancel) {
                let o = applyOutcome
                applyOutcome = nil
                guard let o = o, o.hasAnyApplied else { return }
                if generationResult != nil {
                    onApplied?(o)
                } else {
                    onAddToCalendar?()
                }
                onDismiss?()  // 修改内容
                switchToCalendarTab()
            }
        } message: {
            if let o = applyOutcome { Text(o.summaryText) }
        }
        #endif
    }
    
    
    // MARK: - 修改内容：Time OS — 候選清單（任務清單 / 分工清單 / 待安排清單）
    private func candidateListView(_ result: GenerationResult) -> some View {
        // 修改內容：預覽與套用一致性 — 顯示與套用同一份 editableCandidates
        let timed = editableCandidates.filter { $0.hasTime }.sorted { ($0.startAt ?? .distantPast) < ($1.startAt ?? .distantPast) }
        let untimed = editableCandidates.filter { !$0.hasTime }
        let listTitle: String = isCollaborative ? "分工清單" : (result.resultType == .taskOnly ? "任務清單" : "待安排清單")
        let timeFormatter: DateFormatter = {
            let f = DateFormatter()
            f.dateFormat = "MM/dd HH:mm"
            return f
        }()
        return ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(editedTitle ?? customTitle ?? listTitle)  // 修改内容
                    .font(.system(size: 24, weight: .bold))
                Text(listTitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                if !timed.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("已排入時間")
                            .font(.headline)
                        ForEach(timed) { c in
                            HStack(alignment: .top, spacing: 12) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(c.startAt.map { timeFormatter.string(from: $0) } ?? "--")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(.blue)
                                    if let end = c.endAt {
                                        Text(timeFormatter.string(from: end))
                                            .font(.system(size: 11))
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .frame(width: 84, alignment: .leading)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(c.title)
                                        .font(.system(size: 15, weight: .medium))
                                    if let notes = c.notes, !notes.isEmpty {
                                        Text(notes)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .lineLimit(2)
                                    }
                                }
                                Spacer()
                            }
                            .padding(12)
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(12)
                        }
                    }
                }

                if !untimed.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("待安排")
                            .font(.headline)
                        ForEach(untimed) { c in
                            HStack(spacing: 12) {
                                Image(systemName: "circle")
                                    .foregroundColor(Color(UIColor.systemGray3))
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(c.title)
                                        .font(.system(size: 15, weight: .medium))
                                    if let d = c.durationMin {
                                        Text("約 \(d) 分鐘")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                Spacer()
                            }
                            .padding(12)
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(12)
                        }
                    }
                }
            }
            .padding()
        }
    }

    // MARK: - 修改内容：Time OS — 底部固定操作列（套用 / 存建議 / 重新生成 / 發送確認）
    private var bottomActionBar: some View {
        VStack(spacing: 10) {
            if isCollaborative {
                Button(action: sendToMembersForConfirmation) {
                    HStack {
                        Image(systemName: "paperplane.fill")
                        Text("發送給成員確認")
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.purple)
                    .cornerRadius(14)
                }
            }
            HStack(spacing: 10) {
                Button(action: { applyDirectToTimeItems() }) {
                    Text(currentCandidates.filter { $0.hasTime }.isEmpty ? "套用到時間表" : "套用到時間表・\(currentCandidates.filter { $0.hasTime }.count) 項")  // 修改內容：顯示實際會寫入的數量
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.blue)
                        .cornerRadius(14)
                }
                .disabled(isApplying)  // 修改內容：套用中停用，避免連點
                Button(action: { saveAsSuggestionToTimeItems() }) {
                    Text("暫存草稿")  // 修改内容
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.blue)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color(.systemBackground))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.blue, lineWidth: 1))
                }
                .disabled(isApplying)  // 修改內容
                if onRegenerate != nil {
                    Button(action: { onRegenerate?() }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.blue)
                            .frame(width: 46)
                            .padding(.vertical, 12)
                            .background(Color(.systemBackground))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.blue, lineWidth: 1))
                    }
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(Color(UIColor.systemBackground).ignoresSafeArea(edges: .bottom))
        .overlay(Rectangle().fill(Color(UIColor.systemGray5)).frame(height: 0.5), alignment: .top)
    }

    /// 多人協作：發送給成員確認
    /// 修改内容：分享整併 — 改為發佈公開網頁連結（shared_plans），任何平台皆可開啟閱讀；發佈失敗退回純文字
    private func sendToMembersForConfirmation() {
        guard generationResult != nil else { return }
        let title = editedTitle ?? customTitle ?? "時間安排"  // 修改内容
        let f = DateFormatter()
        f.dateFormat = "MM/dd HH:mm"
        var lines: [String] = ["【\(title)】請確認以下安排："]
        let shareCandidates = currentCandidates  // 修改內容：分享當前編輯後資料
        for c in shareCandidates {
            if let s = c.startAt {
                lines.append("・\(f.string(from: s)) \(c.title)")
            } else {
                lines.append("・\(c.title)（待安排）")
            }
        }
        let summaryText = lines.joined(separator: "\n")

        isApplying = true
        Task {
            let url = await SharedPlanService.shared.publish(
                title: title,
                candidates: shareCandidates,  // 修改內容
                creatorId: userManager.userOpenId,
                creatorName: userManager.displayName
            )
            await MainActor.run {
                isApplying = false
                if let url = url {
                    shareItems = ["【\(title)】請確認以下安排（點連結查看詳情）：\n\(url.absoluteString)"]
                } else {
                    shareItems = [summaryText]
                }
                showShareSheet = true
            }
        }
    }

    // MARK: - 衝突提示橫幅
    private func conflictsBanner(conflicts: [ConflictInfo]) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
            Text("與現有行程有 \(conflicts.count) 處時間重疊")
                .font(.subheadline)
                .foregroundColor(.primary)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.orange.opacity(0.15))
    }

    // MARK: - 修改內容：預覽與套用一致性 — 唯一資料源
    /// 套用 / 分享 / 衝突檢查一律以此為準：有 days → 由 planDays 重建；否則 editableCandidates
    private var currentCandidates: [TimeItemCandidate] {
        if !planDays.isEmpty {
            var p = plan
            p.days = planDays
            return GenerationNormalizer.shared.normalize(plan: p)
        }
        return editableCandidates
    }

    /// 載入現有行程（供編輯後重新檢查衝突）；失敗則沿用生成時的衝突
    private func loadExistingItemsForConflict() {
        guard let result = generationResult else { return }
        Task {
            let request = buildMinimalRequest(from: result)
            if let ctx = try? await ContextProvider.shared.fetchContext(for: request) {
                await MainActor.run {
                    existingItemsForConflict = ctx.existingItems
                    existingItemsLoaded = true
                    recomputeConflicts()
                }
            }
        }
    }

    /// 依當前資料重新計算衝突（未載入現有行程時不覆蓋原衝突）
    private func recomputeConflicts() {
        guard generationResult != nil, existingItemsLoaded else { return }
        liveConflicts = ConflictDetector.shared.detect(candidates: currentCandidates, existingItems: existingItemsForConflict)
    }

    // MARK: - 寫入 time_items（生成引擎套用）
    // 修改内容：功能整理 — 「套用到時間表」智能化：候選若缺時間，先用 scheduler 補齊再寫入
    // 修改內容：預覽與套用一致性 —
    //   1. 以 currentCandidates（編輯後）寫入，不用過期的 result.candidates
    //   2. 缺時間者經 scheduler 仍排不進 → 保留待安排並回報，不靜默跳過
    //   3. 同一預覽沿用 applyRequestId → 重試 / 連點不重複建立
    //   4. 回報 ApplyOutcome，由使用者確認後才回呼 onApplied
    private func applyDirectToTimeItems() {
        guard let result = generationResult, !isApplying else { return }
        if firstItemIsPast { pastTimeAlert = true; return }  // 修改内容：第一個行程不可在過去
        isApplying = true
        applyError = nil
        let snapshot = currentCandidates
        Task {
            do {
                var candidates = snapshot
                let untimed = candidates.filter { !$0.hasTime }
                if !untimed.isEmpty {
                    let context = try await ContextProvider.shared.fetchContext(for: buildMinimalRequest(from: result))
                    let scheduled = GenerationSchedulerService.shared.schedule(
                        untimedCandidates: untimed,
                        rangeStart: context.rangeStart,
                        rangeEnd: context.rangeEnd,
                        existingItems: context.existingItems
                    )
                    candidates = candidates.map { c in
                        if c.hasTime { return c }
                        return scheduled.first(where: { $0.id == c.id }) ?? c
                    }
                }
                // 不在此過濾 hasTime：交由 ApplyStrategy 回報 skippedNoTime
                let outcome = await ApplyStrategy.shared.applyDirect(
                    candidates: candidates,
                    requestId: applyRequestId,
                    themeKey: result.themeKey
                )
                await MainActor.run {
                    isApplying = false
                    // 任務型：已寫入者從可編輯清單移除，剩下仍為待安排（可重試）
                    if planDays.isEmpty {
                        editableCandidates = candidates.filter { !outcome.appliedCandidateIds.contains($0.id) }
                    }
                    // 修改内容：全部成功 → 直接回呼並關閉，不再等待 alert 確認
                    if outcome.isFullSuccess {
                        if !planDays.isEmpty { persistAppliedSnapshot(outcome: outcome, themeKey: result.themeKey) }  // 修改内容
                        onApplied?(outcome)
                        onDismiss?()
                        switchToCalendarTab()
                    } else {
                        applyOutcome = outcome
                    }
                }
            } catch {
                await MainActor.run {
                    isApplying = false
                    applyError = error.localizedDescription
                }
            }
        }
    }

    private func saveAsSuggestionToTimeItems() {
        guard let result = generationResult, !isApplying else { return }
        isApplying = true
        applyError = nil
        let snapshot = currentCandidates
        Task {
            let outcome = await ApplyStrategy.shared.saveAsSuggestion(
                candidates: snapshot,
                requestId: applyRequestId,
                themeKey: result.themeKey
            )
            await MainActor.run {
                isApplying = false
                if outcome.failedCount == 0 {
                    onDismiss?()
                } else {
                    applyError = "\(outcome.failedCount) 項未能暫存草稿：" + (outcome.failures.first?.reason ?? "")  // 修改内容
                }
            }
        }
    }

    private func buildMinimalRequest(from result: GenerationResult) -> GenerateRequest {
        let start = result.plan?.days.first?.date ?? Date()
        let end = result.plan?.days.last?.date ?? start
        var slots = ExtractedSlots()
        slots.dateRange = SlotInfo(value: DateRange(startDate: start, endDate: end), confidence: 1.0)
        return GenerateRequest(
            generateMode: .multiDay,
            themeKey: nil,
            themeMode: .generateItinerary,
            userId: nil,
            slots: slots,
            assumptions: [],
            riskFlags: [],
            npi: nil,
            customInstructions: nil,
            departureLocation: nil,
            accommodationAddress: nil,
            accommodationCoordinate: nil,
            selectedAttractionNames: [],
            customSurroundingTags: [],
            departureDateTime: nil,
            adults: 1,
            children: 0
        )
    }

    // MARK: - 头部卡片视图（参考图片）
    
    // 修改内容：排版優化 — 標題 / 日期 / 天數摘要分層；過去日期以紅字 + 警示標示
    private var headerCardView: some View {
        let isPast = firstItemIsPast
        return VStack(alignment: .leading, spacing: 10) {
            Button {  // 修改内容：標題可修改
                titleDraft = planTitle
                showTitleEditor = true
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(planTitle)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    Image(systemName: "pencil")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(PlainButtonStyle())
            .alert("修改標題", isPresented: $showTitleEditor) {
                TextField("行程標題", text: $titleDraft)
                Button("儲存") {
                    let t = titleDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !t.isEmpty { editedTitle = t }
                }
                Button("取消", role: .cancel) {}
            }

            Button {
                pickedStartDate = max(planDays.first?.date ?? Date(), Calendar.current.startOfDay(for: Date()))
                showStartDatePicker = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: isPast ? "exclamationmark.triangle.fill" : "calendar")
                        .font(.system(size: 13, weight: .semibold))
                    Text(dateRangeString)
                        .font(.system(size: 15, weight: .semibold))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                        .opacity(0.8)
                }
                .foregroundColor(isPast ? .red : .blue)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background((isPast ? Color.red : Color.blue).opacity(0.1))
                .cornerRadius(10)
            }
            .buttonStyle(PlainButtonStyle())

            if isPast {  // 修改内容：僅過期時顯示提示
                Text(firstDayIsToday ? "今天部分行程時間已過，套用時可捨去或重新安排" : "日期已過，點擊上方修改出發日")  // 修改内容
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.red)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 6)  // 修改内容：取消色塊背景，改為純文字排版
        .sheet(isPresented: $showStartDatePicker) {
            NavigationView {
                VStack {
                    DatePicker("出發日期", selection: $pickedStartDate, in: Calendar.current.startOfDay(for: Date())..., displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .padding()
                    Spacer()
                }
                .navigationTitle("修改出發日期")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("取消") { showStartDatePicker = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("套用") {
                            shiftPlan(toStart: pickedStartDate)
                            showStartDatePicker = false
                        }
                    }
                }
            }
            .presentationDetents([.medium, .large])
        }
        .confirmationDialog("行程時間已過", isPresented: $pastTimeAlert, titleVisibility: .visible) {
            if firstDayIsToday {
                Button("捨去已過的行程") { dropPastBlocks() }
                Button("從現在開始重新安排") { rescheduleFromNow() }
            }
            Button("修改出發日期") {
                pickedStartDate = Calendar.current.startOfDay(for: Date())
                showStartDatePicker = true
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text(firstDayIsToday
                 ? "今天部分行程的時間已經過了，可以捨去已過的行程，或以現在時間重新安排今天的行程"
                 : "第一個行程的時間早於現在，請先修改出發日期")
        }
    }

    // 修改内容：整體平移 — 以新出發日取代第一天，所有天/區塊保持相對間隔
    private func shiftPlan(toStart newStart: Date) {
        guard let first = planDays.first else { return }
        let cal = Calendar.current
        let oldDay = cal.startOfDay(for: first.date)
        let newDay = cal.startOfDay(for: newStart)
        let delta = cal.dateComponents([.day], from: oldDay, to: newDay).day ?? 0
        guard delta != 0 else { return }
        planDays = planDays.map { day in
            var d = day
            d.date = cal.date(byAdding: .day, value: delta, to: day.date) ?? day.date
            d.blocks = day.blocks.map { b in
                var nb = b
                nb.startTime = cal.date(byAdding: .day, value: delta, to: b.startTime) ?? b.startTime
                nb.endTime = cal.date(byAdding: .day, value: delta, to: b.endTime) ?? b.endTime
                return nb
            }
            return d
        }
        var p = plan
        p.days = planDays
        onPlanUpdated?(p)
        recomputeConflicts()
    }

    /// 第一個有時間的行程是否已在過去
    private var firstItemIsPast: Bool {
        let firstStart = currentCandidates.compactMap { $0.startAt }.min()
        guard let s = firstStart else { return false }
        return s < Date()
    }

    /// 修改内容：第一天即為今天（日期沒過，只是時間過了）
    private var firstDayIsToday: Bool {
        guard let d = planDays.first?.date else { return false }
        return Calendar.current.isDateInToday(d)
    }

    // 修改内容：捨去已過的行程 — 移除今天結束時間早於現在的區塊；整天皆過則移除該天
    private func dropPastBlocks() {
        let now = Date()
        planDays = planDays.compactMap { day in
            var d = day
            d.blocks = day.blocks.filter { $0.endTime > now }
            // 開頭若為交通/彈性，清掉直到第一個 activity
            while let f = d.blocks.first, f.type != .activity { d.blocks.removeFirst() }
            return d.blocks.contains(where: { $0.type == .activity }) ? d : nil
        }
        selectedDayIndex = 0
        commitPlanDays()
    }

    // 修改内容：從現在開始重新安排 — 今天的區塊整體後移，第一個行程從「現在（進位到 15 分）」開始，保持時長與順序
    private func rescheduleFromNow() {
        guard let first = planDays.first, let firstBlock = first.blocks.first else { return }
        let cal = Calendar.current
        let now = Date()
        let minute = cal.component(.minute, from: now)
        let rounded = cal.date(byAdding: .minute, value: (15 - minute % 15) % 15, to: now) ?? now
        let start = cal.date(bySetting: .second, value: 0, of: rounded) ?? rounded
        let delta = start.timeIntervalSince(firstBlock.startTime)
        guard delta > 0 else { return }
        let dayEnd = cal.date(bySettingHour: 23, minute: 30, second: 0, of: first.date) ?? first.date
        var d = first
        d.blocks = first.blocks.compactMap { b in
            var nb = b
            nb.startTime = b.startTime.addingTimeInterval(delta)
            nb.endTime = b.endTime.addingTimeInterval(delta)
            return nb.startTime < dayEnd ? nb : nil  // 超出當天者捨去
        }
        planDays[0] = d
        commitPlanDays()
    }

    // 修改内容：整體行程 — 套用成功後保存快照並清理已移除的項目
    private func persistAppliedSnapshot(outcome: ApplyOutcome, themeKey: String?) {
        var p = plan
        p.days = planDays
        AppliedPlanStore.shared.upsert(
            AppliedPlanSnapshot(requestId: outcome.requestId, title: planTitle, plan: p, themeKey: themeKey, appliedAt: Date()),
            userId: userManager.userOpenId
        )
        let keep = Set(outcome.writtenItemIds.values)
        Task { await TimeItemService.shared.deleteOrphans(requestId: outcome.requestId, keepIds: keep) }
    }

    private func commitPlanDays() {
        var p = plan
        p.days = planDays
        onPlanUpdated?(p)
        recomputeConflicts()
    }

    // MARK: - 日期范围字符串
    private var dateRangeString: String {
        guard let firstDay = planDays.first ?? plan.days.first,
              let lastDay = planDays.last ?? plan.days.last else {
            return ""
        }
        
        // 修改内容：同月 yyyy/MM/dd-dd；跨月 yyyy/MM/dd-MM/dd；跨年 yyyy/MM/dd-yyyy/MM/dd；單日僅 yyyy/MM/dd
        let cal = Calendar.current
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_TW")
        f.dateFormat = "yyyy/MM/dd"
        let start = f.string(from: firstDay.date)
        if cal.isDate(firstDay.date, inSameDayAs: lastDay.date) { return start }
        let sameYear = cal.component(.year, from: firstDay.date) == cal.component(.year, from: lastDay.date)
        let sameMonth = sameYear && cal.component(.month, from: firstDay.date) == cal.component(.month, from: lastDay.date)
        f.dateFormat = sameMonth ? "dd" : (sameYear ? "MM/dd" : "yyyy/MM/dd")
        return "\(start)-\(f.string(from: lastDay.date))"
    }
    
    private var backgroundColor: Color {
        #if canImport(UIKit)
        return Color(UIColor.systemBackground)
        #else
        return Color.white
        #endif
    }
    
    private var groupedBackgroundColor: Color {
        #if canImport(UIKit)
        return Color(UIColor.systemGroupedBackground)
        #else
        return Color.gray.opacity(0.1)
        #endif
    }
    
    private var gray6BackgroundColor: Color {
        #if canImport(UIKit)
        return Color(UIColor.systemGray6)
        #else
        return Color.gray.opacity(0.2)
        #endif
    }
    
    // MARK: - 日期选择栏（仅显示 D1、D2、D3）
    // 修改内容：排版優化 — 膠囊分段（D1 + 日期），移除無功能的「+」；固定尺寸避免切換時跳動
    private var daySelectorBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(0..<planDays.count, id: \.self) { index in
                    dayButton(dayIndex: index, isSelected: selectedDayIndex == index)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(Color.white)
        .overlay(Rectangle().fill(Color(UIColor.systemGray5)).frame(height: 0.5), alignment: .bottom)
    }

    private func dayButton(dayIndex: Int, isSelected: Bool) -> some View {
        return Button(action: {  // 修改内容：點擊 → 捲動到該日（與滑動同步分離）
            dayScrollTarget = dayIndex
        }) {
            Text("D\(dayIndex + 1)")  // 修改内容：只留 D1，不重複日期
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(isSelected ? .white : .primary)
                .frame(width: 46, height: 46)
                .background(Circle().fill(isSelected ? Color.blue : Color(.systemGray6)))
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - 日期格式化器
    private var dayDateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日（E）"
        formatter.locale = Locale(identifier: "zh_TW")
        return formatter
    }
    
    // MARK: - 横向滚动内容
    // 修改内容：改用 scrollPosition + paging（原 offset preference 與 scrollTo 互相覆蓋，點 D1/D2 無法換頁）
    // 修改内容：改為單頁垂直接續顯示所有天；點 D1/D2/D3 捲動到該日
    private var horizontalScrollContentView: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(0..<planDays.count, id: \.self) { index in
                        DayColumnView(
                            dayIndex: index + 1,
                            day: planDays[index],
                            onBlockTap: { block in
                                selectedBlock = block
                                showBlockEditView = true
                            }
                        )
                        .id(index)
                        .background(  // 修改内容：回報各日頂部位置，供滑動時同步 D1/D2/D3
                            GeometryReader { g in
                                Color.clear.preference(
                                    key: ScrollOffsetPreferenceKey.self,
                                    value: [ScrollOffsetData(index: index, offset: g.frame(in: .named("dayScroll")).minY)]
                                )
                            }
                        )
                    }
                    Color.clear.frame(height: 200)  // 讓最後一天也能捲到頂
                }
            }
            .coordinateSpace(name: "dayScroll")
            .onPreferenceChange(ScrollOffsetPreferenceKey.self) { data in
                guard !isProgrammaticDayScroll else { return }
                // 取「頂部已越過上緣（≤ 40pt）」的最後一天
                let passed = data.filter { $0.offset <= 40 }.map { $0.index }
                let current = passed.max() ?? 0
                if current != selectedDayIndex { selectedDayIndex = current }
            }
            .background(Color(UIColor.systemGroupedBackground))
            .onAppear {
                if planDays.isEmpty { planDays = plan.days }
            }
            .onChange(of: dayScrollTarget) { _, target in
                guard let target else { return }
                isProgrammaticDayScroll = true
                selectedDayIndex = target
                withAnimation(.easeInOut(duration: 0.3)) {
                    proxy.scrollTo(target, anchor: .top)
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                    isProgrammaticDayScroll = false
                    dayScrollTarget = nil
                }
            }
        }
    }
    
    // MARK: - 处理滚动位置变化（参考 MultiEventView）
    private func handleScrollOffsetChange(offsetData: [ScrollOffsetData], screenWidth: CGFloat) {
        // 计算当前最接近屏幕中心的日期
        let centerX = screenWidth / 2
        
        var minDistance: CGFloat = .infinity
        var closestIndex = selectedDayIndex
        
        for data in offsetData {
            let dayWidth = screenWidth
            let dayCenter = data.offset + dayWidth / 2
            let distance = abs(dayCenter - centerX)
            
            if distance < minDistance {
                minDistance = distance
                closestIndex = data.index
            }
        }
        
        // 更新选中的日期索引（避免循环更新，只在用户滚动时更新）
        if closestIndex != selectedDayIndex && closestIndex >= 0 && closestIndex < planDays.count {
            selectedDayIndex = closestIndex
        }
    }
    
    
    // MARK: - 智能重新计算时间（根据修改的行程位置采用不同策略）
    private func recalculateTimesIntelligently(
        for blocks: [TimeBlock],
        dayDate: Date,
        updatedBlockId: UUID,
        isFirst: Bool,
        isLast: Bool
    ) -> [TimeBlock] {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: dayDate)
        let visibleBlocks = blocks.filter { $0.type == .activity || $0.type == .flex || $0.type == .rest }
        
        // 找到更新的 block
        guard let updatedBlock = visibleBlocks.first(where: { $0.id == updatedBlockId }),
              let updatedIndex = visibleBlocks.firstIndex(where: { $0.id == updatedBlockId }) else {
            // 如果找不到，使用原来的方法
            return recalculateTimes(for: blocks, dayDate: dayDate)
        }
        
        if isFirst {
            // 第一个行程修改：调整出发时间，不影响后续行程时间
            return recalculateTimesForFirstActivity(
                blocks: visibleBlocks,
                updatedBlock: updatedBlock,
                updatedIndex: updatedIndex,
                dayDate: dayDate
            )
        } else if isLast {
            // 最后行程修改：修改前交通时间，并把弹性时间往后延
            return recalculateTimesForLastActivity(
                blocks: visibleBlocks,
                updatedBlock: updatedBlock,
                updatedIndex: updatedIndex,
                dayDate: dayDate
            )
        } else {
            // 中间行程修改：计算前后行程交通时间，缩短其行程持续时间
            return recalculateTimesForMiddleActivity(
                blocks: visibleBlocks,
                updatedBlock: updatedBlock,
                updatedIndex: updatedIndex,
                dayDate: dayDate
            )
        }
    }
    
    // MARK: - 重新计算时间（将 buffer 合并到 transit 中）
    private func recalculateTimes(for blocks: [TimeBlock], dayDate: Date) -> [TimeBlock] {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: dayDate)
        let dayEnd = calendar.date(bySettingHour: 22, minute: 0, second: 0, of: dayStart) ?? dayStart
        
        var currentTime = calendar.date(bySettingHour: 8, minute: 0, second: 0, of: dayStart) ?? dayStart
        var result: [TimeBlock] = []
        
        // 先提取所有 activity、flex、rest 类型的 block（按原始顺序）
        let visibleBlocks = blocks.filter { $0.type == .activity || $0.type == .flex || $0.type == .rest }
        
        for (index, block) in visibleBlocks.enumerated() {
            if block.type == .activity {
                // 如果不是第一个 activity，添加 transit（包含 buffer 时间）
                if index > 0 {
                    // 计算 transit 时间（基础时间 + buffer 时间）
                    // 基础 transit 时间：30分钟
                    // buffer 时间：根据 transit 时间动态计算（transit 越长，buffer 越多）
                    let baseTransitDuration: TimeInterval = 30 * 60  // 30分钟基础交通时间
                    
                    // 计算 buffer 时间：基础 10分钟 + transit 时间的 20%（最多 20分钟）
                    let bufferRatio: TimeInterval = 0.2  // 20%
                    let maxBufferDuration: TimeInterval = 20 * 60  // 最多 20分钟
                    let calculatedBuffer = min(baseTransitDuration * bufferRatio, maxBufferDuration)
                    let minBufferDuration: TimeInterval = 10 * 60  // 最少 10分钟
                    let bufferDuration = max(calculatedBuffer, minBufferDuration)
                    
                    // 总 transit 时间 = 基础 transit + buffer
                    let totalTransitDuration = baseTransitDuration + bufferDuration
                    let transitEnd = currentTime.addingTimeInterval(totalTransitDuration)
                    
                    if transitEnd <= dayEnd {
                        // 创建 transit block（包含 buffer 时间，但不显示 buffer）
                        result.append(TimeBlock(
                            id: UUID(),
                            type: .transit,
                            startTime: currentTime,
                            endTime: transitEnd,
                            title: "前往下一地点",
                            location: nil,
                            isAnchor: false,
                            priority: 5,
                            description: nil
                        ))
                        currentTime = transitEnd
                    }
                }
                
                // 添加 activity（保持原有时长）
                let activityDuration = block.endTime.timeIntervalSince(block.startTime)
                let activityEnd = currentTime.addingTimeInterval(activityDuration)
                
                if activityEnd <= dayEnd {
                    var updatedBlock = block
                    updatedBlock.startTime = currentTime
                    updatedBlock.endTime = activityEnd
                    result.append(updatedBlock)
                    currentTime = activityEnd
                }
            } else if block.type == .flex || block.type == .rest {
                // 对于 flex 和 rest，保持原有时长
                let duration = block.endTime.timeIntervalSince(block.startTime)
                let blockEnd = currentTime.addingTimeInterval(duration)
                
                if blockEnd <= dayEnd {
                    var updatedBlock = block
                    updatedBlock.startTime = currentTime
                    updatedBlock.endTime = blockEnd
                    result.append(updatedBlock)
                    currentTime = blockEnd
                }
            }
        }
        
        return result
    }
    
    // MARK: - 计算属性
    
    private var planTitle: String {
        if let t = editedTitle, !t.isEmpty { return t }  // 修改内容
        // 优先使用用户自定义标题（"此行的主题"）
        if let customTitle = customTitle, !customTitle.isEmpty {
            return customTitle
        }
        // 如果没有自定义标题，尝试从模板标题中提取
        // 否则使用默认标题
        let destination = extractDestination()
        return "\(destination)\(plan.days.count)日深度遊"
    }
    
    private var planDestination: String {
        let destination = extractDestination()
        if let country = extractCountry(from: destination) {
            return "\(country),\(destination)"
        }
        return destination
    }
    
    private func extractDestination() -> String {
        // 修复：扫描前 N 个 activity，找第一个有 location 的，提高成功率
        for day in plan.days {
            // 扫描该天的所有 activity blocks
            for block in day.blocks where block.type == .activity {
                if let location = block.location, !location.isEmpty {
                    // 尝试提取城市名（假设格式为 "城市" 或 "国家 - 城市"）
                    if location.contains(" - ") {
                        return String(location.split(separator: " - ").last ?? "")
                    }
                    return location
                }
            }
        }
        return "未知目的地"
    }
    
    private func extractCountry(from destination: String) -> String? {
        // 简单的国家映射
        let countryMap: [String: String] = [
            "東京": "日本",
            "京都": "日本",
            "大阪": "日本",
            "首爾": "韓國",
            "台北": "台灣",
            "曼谷": "泰國"
        ]
        
        for (city, country) in countryMap {
            if destination.contains(city) {
                return country
            }
        }
        return nil
    }
    
    // MARK: - 更新 Block
    private func updateBlock(_ updatedBlock: TimeBlock) {
        // 找到并更新对应的 block
        for dayIndex in 0..<planDays.count {
            if let blockIndex = planDays[dayIndex].blocks.firstIndex(where: { $0.id == updatedBlock.id }) {
                // 获取当前天的所有 activity blocks（用于判断位置）
                let activityBlocks = planDays[dayIndex].blocks.filter { $0.type == .activity }
                let activityIndex = activityBlocks.firstIndex(where: { $0.id == updatedBlock.id })
                
                // 判断是第一个、中间还是最后一个行程
                let isFirstActivity = activityIndex == 0
                let isLastActivity = activityIndex == activityBlocks.count - 1
                
                // 更新 block 信息
                planDays[dayIndex].blocks[blockIndex] = updatedBlock
                
                // 智能重新计算时间（根据位置采用不同策略）
                let visibleBlocks = planDays[dayIndex].blocks.filter { 
                    $0.type == .activity || $0.type == .flex || $0.type == .rest 
                }
                
                // 使用智能重算方法
                let recalculatedBlocks = recalculateTimesIntelligently(
                    for: visibleBlocks,
                    dayDate: planDays[dayIndex].date,
                    updatedBlockId: updatedBlock.id,
                    isFirst: isFirstActivity,
                    isLast: isLastActivity
                )
                planDays[dayIndex].blocks = recalculatedBlocks
                recomputeConflicts()  // 修改內容：編輯後依新時間重新檢查衝突
                
                // 同步 plan 給父層（關閉中不觸發，避免重複彈出）
                if !isDismissing {
                    var updatedPlan = plan
                    updatedPlan.days = planDays
                    onPlanUpdated?(updatedPlan)
                }
                
                break
            }
        }
    }
    
    // MARK: - 開啟整個行程編輯
    /// 用戶明確點擊「編輯整個行程」時，將目前編輯後的 plan 傳給父層並進入 PlanEditView
    private func openPlanEditView() {
        var updatedPlan = plan
        updatedPlan.days = planDays
        onEdit?(updatedPlan)
    }
    
    // MARK: - 储存行程
    private func savePlan() {
        let userId = userManager.userOpenId
        
        // 生成默认标题
        let templateTitle: String
        if let t = editedTitle, !t.isEmpty {  // 修改内容：優先使用編輯後標題
            templateTitle = t
        } else if let customTitle = customTitle, !customTitle.isEmpty {
            templateTitle = customTitle
        } else {
            let destination = extractDestination()
            if destination != "未知目的地" {
                templateTitle = "\(destination) \(planDays.count)天行程"
            } else {
                templateTitle = "行程模板 \(planDays.count)天"
            }
        }
        
        // 提取目的地
        let destination = extractDestination()
        
        // 创建模板
        var updatedPlan = plan
        updatedPlan.days = planDays
        let template = SavedTripTemplate(
            title: templateTitle,
            plan: updatedPlan,
            savedDate: Date(),
            tags: [],
            destination: destination != "未知目的地" ? destination : nil
        )
        
        // 保存模板
        TripTemplateManager.shared.saveTemplate(template, for: userId, syncToAppleCalendar: false)
        
        // 显示成功提示
        #if os(iOS)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootViewController = window.rootViewController {
            let alert = UIAlertController(title: "成功", message: "已保存到行程模板：\(templateTitle)", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "確定", style: .default))
            rootViewController.present(alert, animated: true)
        }
        #endif
        
        onSave?()
    }
    
    // MARK: - 分享行程
    private func sharePlan() {
        // 构建分享文本
        var shareText = "\(planTitle)\n\n"
        
        let destination = extractDestination()
        if destination != "未知目的地" {
            shareText += "目的地：\(destination)\n"
        }
        
        shareText += "行程天数：\(planDays.count)天\n\n"
        
        // 添加每天的行程
        for (dayIndex, day) in planDays.enumerated() {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "M月d日"
            dateFormatter.locale = Locale(identifier: "zh_TW")
            shareText += "第\(dayIndex + 1)天（\(dateFormatter.string(from: day.date))）：\n"
            
            let activities = day.blocks.filter { $0.type == .activity }
            for activity in activities {
                let timeFormatter = DateFormatter()
                timeFormatter.dateFormat = "HH:mm"
                timeFormatter.locale = Locale(identifier: "zh_TW")
                let timeString = timeFormatter.string(from: activity.startTime)
                shareText += "\(timeString) - \(activity.title)"
                if let location = activity.location {
                    shareText += " (\(location))"
                }
                shareText += "\n"
            }
            
            if dayIndex < planDays.count - 1 {
                shareText += "\n"
            }
        }
        
        shareItems = [shareText]
        showShareSheet = true
    }
    
    // MARK: - 加入行程（添加到日历）
    // 修改内容：Time OS — 套用一律寫入 time_items（ApplyStrategy），不再寫舊 EventManager
    // 修改內容：預覽與套用一致性 — 改用 ApplyOutcome 顯示實際結果；沿用 applyRequestId 去重；套用中禁止重入
    private func addPlanToCalendar() {
        guard !isApplying else { return }
        if firstItemIsPast { pastTimeAlert = true; return }  // 修改内容：第一個行程不可在過去
        var updatedPlan = plan
        updatedPlan.days = planDays

        isApplying = true
        Task {
            let outcome = await ApplyStrategy.shared.applyFromPlan(
                updatedPlan,
                requestId: applyRequestId,
                themeKey: generationResult?.themeKey
            )
            await MainActor.run {
                isApplying = false
                // 修改内容：全部成功 → 直接回呼、關閉並切到行事曆
                if outcome.isFullSuccess {
                    persistAppliedSnapshot(outcome: outcome, themeKey: generationResult?.themeKey)  // 修改内容
                    onAddToCalendar?()
                    onDismiss?()
                    switchToCalendarTab()
                } else {
                    applyOutcome = outcome
                }
            }
        }
    }

    // 修改内容：關閉後切到行事曆 Tab（ContentView 監聽）；無 onDismiss（NavigationLink 推入）時用環境 dismiss
    private func switchToCalendarTab() {
        if onDismiss == nil { dismiss() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            NotificationCenter.default.post(name: NSNotification.Name("SwitchToCalendarTab"), object: nil)
        }
    }

    // MARK: - 辅助函数
    private func combine(date: Date, time: Date) -> Date {
        let calendar = Calendar.current
        return calendar.date(
            bySettingHour: calendar.component(.hour, from: time),
            minute: calendar.component(.minute, from: time),
            second: calendar.component(.second, from: time),
            of: date
        ) ?? date
    }
    
    // MARK: - 第一个行程修改：调整出发时间，不影响后续行程时间
    private func recalculateTimesForFirstActivity(
        blocks: [TimeBlock],
        updatedBlock: TimeBlock,
        updatedIndex: Int,
        dayDate: Date
    ) -> [TimeBlock] {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: dayDate)
        let dayEnd = calendar.date(bySettingHour: 22, minute: 0, second: 0, of: dayStart) ?? dayStart
        
        var result: [TimeBlock] = []
        var currentTime = calendar.date(bySettingHour: 8, minute: 0, second: 0, of: dayStart) ?? dayStart
        
        // 第一个行程：使用更新后的时间，但保持原有时长
        let activityDuration = updatedBlock.endTime.timeIntervalSince(updatedBlock.startTime)
        let activityEnd = currentTime.addingTimeInterval(activityDuration)
        
        if activityEnd <= dayEnd {
            var firstBlock = updatedBlock
            firstBlock.startTime = currentTime
            firstBlock.endTime = activityEnd
            result.append(firstBlock)
            currentTime = activityEnd
        }
        
        // 后续行程：保持原有顺序和时间间隔
        for index in 1..<blocks.count {
            let block = blocks[index]
            
            if block.type == .activity {
                // 添加 transit 时间
                let baseTransitDuration: TimeInterval = 30 * 60
                let bufferRatio: TimeInterval = 0.2
                let maxBufferDuration: TimeInterval = 20 * 60
                let calculatedBuffer = min(baseTransitDuration * bufferRatio, maxBufferDuration)
                let minBufferDuration: TimeInterval = 10 * 60
                let bufferDuration = max(calculatedBuffer, minBufferDuration)
                let totalTransitDuration = baseTransitDuration + bufferDuration
                let transitEnd = currentTime.addingTimeInterval(totalTransitDuration)
                
                if transitEnd <= dayEnd {
                    result.append(TimeBlock(
                        id: UUID(),
                        type: .transit,
                        startTime: currentTime,
                        endTime: transitEnd,
                        title: "前往下一地点",
                        location: nil,
                        isAnchor: false,
                        priority: 5,
                        description: nil
                    ))
                    currentTime = transitEnd
                }
                
                // 添加 activity（保持原有时长）
                let activityDuration = block.endTime.timeIntervalSince(block.startTime)
                let activityEnd = currentTime.addingTimeInterval(activityDuration)
                
                if activityEnd <= dayEnd {
                    var updatedBlock = block
                    updatedBlock.startTime = currentTime
                    updatedBlock.endTime = activityEnd
                    result.append(updatedBlock)
                    currentTime = activityEnd
                }
            } else if block.type == .flex || block.type == .rest {
                // 对于 flex 和 rest，保持原有时长
                let duration = block.endTime.timeIntervalSince(block.startTime)
                let blockEnd = currentTime.addingTimeInterval(duration)
                
                if blockEnd <= dayEnd {
                    var updatedBlock = block
                    updatedBlock.startTime = currentTime
                    updatedBlock.endTime = blockEnd
                    result.append(updatedBlock)
                    currentTime = blockEnd
                }
            }
        }
        
        return result
    }
    
    // MARK: - 最后行程修改：修改前交通时间，并把弹性时间往后延
    private func recalculateTimesForLastActivity(
        blocks: [TimeBlock],
        updatedBlock: TimeBlock,
        updatedIndex: Int,
        dayDate: Date
    ) -> [TimeBlock] {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: dayDate)
        let dayEnd = calendar.date(bySettingHour: 22, minute: 0, second: 0, of: dayStart) ?? dayStart
        
        var result: [TimeBlock] = []
        var currentTime = calendar.date(bySettingHour: 8, minute: 0, second: 0, of: dayStart) ?? dayStart
        
        // 处理前面的行程（保持原有顺序）
        for index in 0..<updatedIndex {
            let block = blocks[index]
            
            if block.type == .activity {
                // 如果不是第一个 activity，添加 transit
                if index > 0 {
                    let baseTransitDuration: TimeInterval = 30 * 60
                    let bufferRatio: TimeInterval = 0.2
                    let maxBufferDuration: TimeInterval = 20 * 60
                    let calculatedBuffer = min(baseTransitDuration * bufferRatio, maxBufferDuration)
                    let minBufferDuration: TimeInterval = 10 * 60
                    let bufferDuration = max(calculatedBuffer, minBufferDuration)
                    let totalTransitDuration = baseTransitDuration + bufferDuration
                    let transitEnd = currentTime.addingTimeInterval(totalTransitDuration)
                    
                    if transitEnd <= dayEnd {
                        result.append(TimeBlock(
                            id: UUID(),
                            type: .transit,
                            startTime: currentTime,
                            endTime: transitEnd,
                            title: "前往下一地点",
                            location: nil,
                            isAnchor: false,
                            priority: 5,
                            description: nil
                        ))
                        currentTime = transitEnd
                    }
                }
                
                // 添加 activity
                let activityDuration = block.endTime.timeIntervalSince(block.startTime)
                let activityEnd = currentTime.addingTimeInterval(activityDuration)
                
                if activityEnd <= dayEnd {
                    var updatedBlock = block
                    updatedBlock.startTime = currentTime
                    updatedBlock.endTime = activityEnd
                    result.append(updatedBlock)
                    currentTime = activityEnd
                }
            } else if block.type == .flex || block.type == .rest {
                let duration = block.endTime.timeIntervalSince(block.startTime)
                let blockEnd = currentTime.addingTimeInterval(duration)
                
                if blockEnd <= dayEnd {
                    var updatedBlock = block
                    updatedBlock.startTime = currentTime
                    updatedBlock.endTime = blockEnd
                    result.append(updatedBlock)
                    currentTime = blockEnd
                }
            }
        }
        
        // 添加最后一个行程前的 transit（重新计算）
        if updatedIndex > 0 {
            _ = blocks[updatedIndex - 1]
            let baseTransitDuration: TimeInterval = 30 * 60
            let bufferRatio: TimeInterval = 0.2
            let maxBufferDuration: TimeInterval = 20 * 60
            let calculatedBuffer = min(baseTransitDuration * bufferRatio, maxBufferDuration)
            let minBufferDuration: TimeInterval = 10 * 60
            let bufferDuration = max(calculatedBuffer, minBufferDuration)
            let totalTransitDuration = baseTransitDuration + bufferDuration
            let transitEnd = currentTime.addingTimeInterval(totalTransitDuration)
            
            if transitEnd <= dayEnd {
                result.append(TimeBlock(
                    id: UUID(),
                    type: .transit,
                    startTime: currentTime,
                    endTime: transitEnd,
                    title: "前往下一地点",
                    location: nil,
                    isAnchor: false,
                    priority: 5,
                    description: nil
                ))
                currentTime = transitEnd
            }
        }
        
        // 添加最后一个行程（使用更新后的时间，但保持原有时长）
        let activityDuration = updatedBlock.endTime.timeIntervalSince(updatedBlock.startTime)
        let activityEnd = currentTime.addingTimeInterval(activityDuration)
        
        if activityEnd <= dayEnd {
            var lastBlock = updatedBlock
            lastBlock.startTime = currentTime
            lastBlock.endTime = activityEnd
            result.append(lastBlock)
            currentTime = activityEnd
        }
        
        // 如果有弹性时间，将其往后延
        if updatedIndex < blocks.count - 1 {
            let remainingBlocks = blocks[(updatedIndex + 1)...]
            for block in remainingBlocks {
                if block.type == .flex || block.type == .rest {
                    let duration = block.endTime.timeIntervalSince(block.startTime)
                    let blockEnd = currentTime.addingTimeInterval(duration)
                    
                    if blockEnd <= dayEnd {
                        var updatedBlock = block
                        updatedBlock.startTime = currentTime
                        updatedBlock.endTime = blockEnd
                        result.append(updatedBlock)
                        currentTime = blockEnd
                    }
                }
            }
        }
        
        return result
    }
    
    // MARK: - 中间行程修改：计算前后行程交通时间，缩短其行程持续时间
    private func recalculateTimesForMiddleActivity(
        blocks: [TimeBlock],
        updatedBlock: TimeBlock,
        updatedIndex: Int,
        dayDate: Date
    ) -> [TimeBlock] {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: dayDate)
        let dayEnd = calendar.date(bySettingHour: 22, minute: 0, second: 0, of: dayStart) ?? dayStart
        
        var result: [TimeBlock] = []
        var currentTime = calendar.date(bySettingHour: 8, minute: 0, second: 0, of: dayStart) ?? dayStart
        
        // 处理前面的行程（保持原有顺序）
        for index in 0..<updatedIndex {
            let block = blocks[index]
            
            if block.type == .activity {
                if index > 0 {
                    let baseTransitDuration: TimeInterval = 30 * 60
                    let bufferRatio: TimeInterval = 0.2
                    let maxBufferDuration: TimeInterval = 20 * 60
                    let calculatedBuffer = min(baseTransitDuration * bufferRatio, maxBufferDuration)
                    let minBufferDuration: TimeInterval = 10 * 60
                    let bufferDuration = max(calculatedBuffer, minBufferDuration)
                    let totalTransitDuration = baseTransitDuration + bufferDuration
                    let transitEnd = currentTime.addingTimeInterval(totalTransitDuration)
                    
                    if transitEnd <= dayEnd {
                        result.append(TimeBlock(
                            id: UUID(),
                            type: .transit,
                            startTime: currentTime,
                            endTime: transitEnd,
                            title: "前往下一地点",
                            location: nil,
                            isAnchor: false,
                            priority: 5,
                            description: nil
                        ))
                        currentTime = transitEnd
                    }
                }
                
                let activityDuration = block.endTime.timeIntervalSince(block.startTime)
                let activityEnd = currentTime.addingTimeInterval(activityDuration)
                
                if activityEnd <= dayEnd {
                    var updatedBlock = block
                    updatedBlock.startTime = currentTime
                    updatedBlock.endTime = activityEnd
                    result.append(updatedBlock)
                    currentTime = activityEnd
                }
            } else if block.type == .flex || block.type == .rest {
                let duration = block.endTime.timeIntervalSince(block.startTime)
                let blockEnd = currentTime.addingTimeInterval(duration)
                
                if blockEnd <= dayEnd {
                    var updatedBlock = block
                    updatedBlock.startTime = currentTime
                    updatedBlock.endTime = blockEnd
                    result.append(updatedBlock)
                    currentTime = blockEnd
                }
            }
        }
        
        // 添加前一个行程到当前行程的 transit（重新计算）
        if updatedIndex > 0 {
            let previousBlock = blocks[updatedIndex - 1]
            // 尝试使用实际交通时间计算
            var transitDuration: TimeInterval = 30 * 60 + 10 * 60  // 默认值
            
            // 如果两个行程都有地点，尝试计算实际交通时间
            if let fromLocation = previousBlock.location,
               let toLocation = updatedBlock.location,
               !fromLocation.isEmpty,
               !toLocation.isEmpty {
                // 使用同步方法获取默认值，实际计算在后台进行
                if let calculatedTime = calculateTransitTime(from: previousBlock, to: updatedBlock) {
                    transitDuration = calculatedTime
                }
            }
            
            let transitEnd = currentTime.addingTimeInterval(transitDuration)
            
            if transitEnd <= dayEnd {
                result.append(TimeBlock(
                    id: UUID(),
                    type: .transit,
                    startTime: currentTime,
                    endTime: transitEnd,
                    title: "前往下一地点",
                    location: nil,
                    isAnchor: false,
                    priority: 5,
                    description: nil
                ))
                currentTime = transitEnd
            }
        }
        
        // 添加当前修改的行程（缩短持续时间以适应时间限制）
        let originalDuration = updatedBlock.endTime.timeIntervalSince(updatedBlock.startTime)
        let maxAvailableTime = dayEnd.timeIntervalSince(currentTime)
        let activityDuration = min(originalDuration, maxAvailableTime * 0.8)  // 保留20%缓冲
        let activityEnd = currentTime.addingTimeInterval(activityDuration)
        
        if activityEnd <= dayEnd {
            var middleBlock = updatedBlock
            middleBlock.startTime = currentTime
            middleBlock.endTime = activityEnd
            result.append(middleBlock)
            currentTime = activityEnd
        }
        
        // 添加当前行程到下一个行程的 transit（重新计算）
        if updatedIndex < blocks.count - 1 {
            let nextBlock = blocks[updatedIndex + 1]
            if nextBlock.type == .activity {
                var transitDuration: TimeInterval = 30 * 60 + 10 * 60  // 默认值
                
                if let fromLocation = updatedBlock.location,
                   let toLocation = nextBlock.location,
                   !fromLocation.isEmpty,
                   !toLocation.isEmpty {
                    if let calculatedTime = calculateTransitTime(from: updatedBlock, to: nextBlock) {
                        transitDuration = calculatedTime
                    }
                }
                
                let transitEnd = currentTime.addingTimeInterval(transitDuration)
                
                if transitEnd <= dayEnd {
                    result.append(TimeBlock(
                        id: UUID(),
                        type: .transit,
                        startTime: currentTime,
                        endTime: transitEnd,
                        title: "前往下一地点",
                        location: nil,
                        isAnchor: false,
                        priority: 5,
                        description: nil
                    ))
                    currentTime = transitEnd
                }
            }
        }
        
        // 处理后续行程（保持原有顺序）
        for index in (updatedIndex + 1)..<blocks.count {
            let block = blocks[index]
            
            if block.type == .activity {
                let activityDuration = block.endTime.timeIntervalSince(block.startTime)
                let activityEnd = currentTime.addingTimeInterval(activityDuration)
                
                if activityEnd <= dayEnd {
                    var updatedBlock = block
                    updatedBlock.startTime = currentTime
                    updatedBlock.endTime = activityEnd
                    result.append(updatedBlock)
                    currentTime = activityEnd
                }
            } else if block.type == .flex || block.type == .rest {
                let duration = block.endTime.timeIntervalSince(block.startTime)
                let blockEnd = currentTime.addingTimeInterval(duration)
                
                if blockEnd <= dayEnd {
                    var updatedBlock = block
                    updatedBlock.startTime = currentTime
                    updatedBlock.endTime = blockEnd
                    result.append(updatedBlock)
                    currentTime = blockEnd
                }
            }
        }
        
        return result
    }
    
    // MARK: - 计算两个行程之间的交通时间
    /// 计算两个行程之间的交通时间（同步版本，返回默认值或实际计算值）
    /// 注意：由于地理编码和路线计算是异步的，这里先返回默认值，实际计算在后台进行
    private func calculateTransitTime(from: TimeBlock, to: TimeBlock) -> TimeInterval? {
        // 如果两个行程都有地点，尝试计算实际交通时间
        guard let fromLocation = from.location,
              let toLocation = to.location,
              !fromLocation.isEmpty,
              !toLocation.isEmpty else {
            return nil
        }
        
        // 使用地理编码将地址转换为坐标，然后计算交通时间
        // 由于这是同步方法，我们使用默认值，实际计算在后台异步进行
        // 这里返回 nil，让调用者使用默认时间
        // TODO: 可以改为异步方法，使用 DispatchGroup 或 async/await
        
        // 临时方案：使用默认交通时间（30分钟基础 + 10分钟缓冲）
        let defaultTransitDuration: TimeInterval = 30 * 60
        let defaultBufferDuration: TimeInterval = 10 * 60
        return defaultTransitDuration + defaultBufferDuration
    }
    
    // MARK: - 异步计算交通时间（用于实际计算）
    /// 异步计算两个行程之间的实际交通时间
    private func calculateTransitTimeAsync(
        from: TimeBlock,
        to: TimeBlock,
        completion: @escaping (TimeInterval?) -> Void
    ) {
        guard let fromLocation = from.location,
              let toLocation = to.location,
              !fromLocation.isEmpty,
              !toLocation.isEmpty else {
            completion(nil)
            return
        }
        
        // 使用地理编码将地址转换为坐标
        let geocoder = CLGeocoder()
        
        // 先编码起始地址
        geocoder.geocodeAddressString(fromLocation) { fromPlacemarks, fromError in
            guard let fromPlacemark = fromPlacemarks?.first,
                  let fromCoordinate = fromPlacemark.location else {
                // 如果编码失败，使用默认时间
                let defaultTime: TimeInterval = 30 * 60 + 10 * 60
                completion(defaultTime)
                return
            }
            
            // 再编码目标地址
            geocoder.geocodeAddressString(toLocation) { toPlacemarks, toError in
                guard let toPlacemark = toPlacemarks?.first,
                      let toCoordinate = toPlacemark.location else {
                    // 如果编码失败，使用默认时间
                    let defaultTime: TimeInterval = 30 * 60 + 10 * 60
                    completion(defaultTime)
                    return
                }
                
                // 使用 TravelTimeCalculator 计算实际交通时间
                TravelTimeCalculator.shared.calculateTravelTime(
                    from: fromCoordinate,
                    to: toCoordinate
                ) { efficientTime, taxiTime, routeInfo in
                    // 使用最有效率的时间（步行或公共交通）
                    // 如果计算失败，使用默认时间
                    if let travelTime = efficientTime {
                        completion(travelTime)
                    } else {
                        // 如果计算失败，使用默认时间
                        let defaultTime: TimeInterval = 30 * 60 + 10 * 60
                        completion(defaultTime)
                    }
                }
            }
        }
    }
    
    // MARK: - GPS实时确认功能
    
    /// 启动后台GPS更新任务（每10分钟检查一次从餐厅到下一个景点的交通时间）
    private func startGPSUpdateTask() {
        // 取消之前的任务
        stopGPSUpdateTask()
        
        // 请求位置权限
        locationManager.requestPermission()
        
        // 创建后台任务
        gpsUpdateTask = Task {
            while !Task.isCancelled {
                // 每10分钟检查一次
                try? await Task.sleep(nanoseconds: 10 * 60 * 1_000_000_000) // 10分钟
                
                // 检查是否有需要实时确认的交通块（从餐厅到下一个景点）
                await updateTransitTimesFromRestaurants()
            }
        }
    }
    
    /// 停止后台GPS更新任务
    private func stopGPSUpdateTask() {
        gpsUpdateTask?.cancel()
        gpsUpdateTask = nil
    }
    
    /// 更新从餐厅到下一个景点的交通时间
    @MainActor
    private func updateTransitTimesFromRestaurants() async {
        guard !isDismissing else { return }
        guard let currentLocation = locationManager.currentLocation else {
            print("📍 [PlanDetailView] GPS位置不可用，跳过交通时间更新")
            return
        }
        
        var hasUpdates = false
        
        // 遍历所有天的行程
        for dayIndex in 0..<planDays.count {
            var updatedBlocks = planDays[dayIndex].blocks
            
            // 查找所有"从餐厅前往下一地点"的交通块
            for blockIndex in 0..<updatedBlocks.count {
                let block = updatedBlocks[blockIndex]
                
                // 檢查可依 GPS 更新交通時間的塊：從餐廳、前往住宿、從住宿出發等
                let isUpdatableTransit = block.title.contains("从餐厅") ||
                    block.title.contains("從餐廳") ||
                    block.title.contains("前往住宿") ||
                    block.title.contains("從住宿")
                if block.type == .transit,
                   isUpdatableTransit,
                   let destinationLocation = block.location,
                   !destinationLocation.isEmpty {
                    
                    // 使用地理编码获取目标地点的坐标
                    let geocoder = CLGeocoder()
                    
                    do {
                        let placemarks = try await geocoder.geocodeAddressString(destinationLocation)
                        
                        if let placemark = placemarks.first,
                           let destinationCoordinate = placemark.location {
                            
                            // 计算实际交通时间
                            await withCheckedContinuation { continuation in
                                TravelTimeCalculator.shared.calculateTravelTime(
                                    from: currentLocation,
                                    to: destinationCoordinate
                                ) { efficientTime, taxiTime, routeInfo in
                                    // 使用最有效率的时间（步行或公共交通）
                                    if let travelTime = efficientTime {
                                        // 添加10分钟缓冲时间
                                        let totalTime = travelTime + (10 * 60)
                                        
                                        // 更新交通块的时间
                                        let newEndTime = block.startTime.addingTimeInterval(totalTime)
                                        
                                        var updatedBlock = block
                                        updatedBlock.endTime = newEndTime
                                        
                                        // 更新描述，显示实时计算的时间
                                        let minutes = Int(totalTime / 60)
                                        updatedBlock.description = "从餐厅前往下一地点（实时GPS确认：约\(minutes)分钟）\n\(routeInfo ?? "")"
                                        
                                        updatedBlocks[blockIndex] = updatedBlock
                                        hasUpdates = true
                                        
                                        print("📍 [PlanDetailView] 更新交通时间：从餐厅到\(destinationLocation)，预计\(minutes)分钟")
                                    }
                                    
                                    continuation.resume()
                                }
                            }
                        }
                    } catch {
                        print("📍 [PlanDetailView] 地理编码失败：\(error.localizedDescription)")
                    }
                }
            }
            
            // 如果有更新，保存到 planDays
            if hasUpdates {
                planDays[dayIndex].blocks = updatedBlocks
                
                // 同步 plan 給父層（關閉中不觸發，避免重複彈出）
                if !isDismissing {
                    var updatedPlan = plan
                    updatedPlan.days = planDays
                    onPlanUpdated?(updatedPlan)
                }
            }
        }
    }
}

// MARK: - 单日列视图（横向滚动）

struct DayColumnView: View {
    let dayIndex: Int
    let day: DayPlan
    let onBlockTap: ((TimeBlock) -> Void)?  // 添加 onBlockTap 参数
    
    private var dayBackgroundColor: Color {
        #if canImport(UIKit)
        return Color(UIColor.systemBackground)
        #else
        return Color.white
        #endif
    }
    
    private var dayDateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日（E）"
        formatter.locale = Locale(identifier: "zh_TW")
        return formatter
    }
    
    // 修改内容：改為區段（外層由 PlanDetailView 單一垂直 ScrollView 接續顯示）
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            dayHeaderView
            VStack(alignment: .leading, spacing: 6) {  // 連接列緊貼行程卡片
                blocksListView
            }
        }
        .padding(.bottom, 24)
        .background(Color(UIColor.systemGroupedBackground))
    }
    
    // MARK: - 日期标题视图
    // 修改内容：排版優化 — 過去日期紅字標示；移除無功能的「AI 建議路線」；顯示當日行程數
    private var dayHeaderView: some View {
        return HStack(alignment: .firstTextBaseline, spacing: 8) {  // 修改内容：只留日期
            Text(dayDateFormatter.string(from: day.date))
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.primary)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }
    
     // MARK: - 行程卡片列表视图
     private var blocksListView: some View {
         ForEach(Array(day.blocks.enumerated()), id: \.element.id) { index, block in
             // 显示 activity、transit、flex、rest，隐藏 buffer
             if block.type == .activity || block.type == .flex || block.type == .rest || block.type == .transit {
                 blockCardView(for: block, at: index)
             }
         }
     }
    
    // MARK: - 单个行程卡片视图
    private func blockCardView(for block: TimeBlock, at index: Int) -> some View {
        // 获取下一个活动的地点（用于导航）
        // 地图应用会使用GPS自动定位当前位置，所以不需要前一个地点
        var nextLocation: String? = nil
        
        // 查找后一个 activity
        for i in (index + 1)..<day.blocks.count {
            if day.blocks[i].type == .activity, let loc = day.blocks[i].location, !loc.isEmpty {
                nextLocation = loc
                break
            }
        }
        
        return BlockCardView(
            block: block,
            blockIndex: index,
            nextLocation: nextLocation,
            onTap: {
                onBlockTap?(block)
            }
        )
        .padding(.horizontal, 20)
    }
}

// MARK: - Block 卡片视图

struct BlockCardView: View {
    let block: TimeBlock
    let blockIndex: Int  // 当前 block 的索引
    var nextLocation: String? = nil  // 下一个活动的地点（用于交通导航，地图会使用GPS定位当前位置）
    var onTap: (() -> Void)? = nil  // 点击回调（可选）
    
    private var itemGray6BackgroundColor: Color {
        #if canImport(UIKit)
        return Color(UIColor.systemGray6)
        #else
        return Color.gray.opacity(0.2)
        #endif
    }
    
    var body: some View {
        // 修改内容：交通 / 彈性時間不是行程 → 改為輕量連接列，與行程卡片區分
        if block.type == .transit || block.type == .flex || block.type == .buffer {
            connectorRow
        } else {
            cardBody
        }
    }

    // 修改内容：交通 / 彈性時間的連接列（無卡片、無陰影、縮排、虛線）
    private var connectorRow: some View {
        HStack(spacing: 10) {
            Rectangle()
                .fill(Color.clear)
                .frame(width: 40)
                .overlay(
                    Rectangle()
                        .fill(Color(.systemGray4))
                        .frame(width: 1.5)
                )
            Image(systemName: iconForBlock(block))
                .font(.system(size: 13))
                .foregroundColor(iconColorForBlock(block))
            Text(block.title)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
            Text("·")
                .font(.system(size: 13))
                .foregroundColor(Color(.systemGray3))
            Text("\(durationMinutes) 分鐘")
                .font(.system(size: 13))
                .foregroundColor(Color(.systemGray))
            Spacer()
            if block.type == .transit, nextLocation != nil {
                Image(systemName: "arrow.triangle.turn.up.right.diamond")
                    .font(.system(size: 13))
                    .foregroundColor(.blue)
            }
        }
        .frame(height: 32)
        .contentShape(Rectangle())
        .onTapGesture {
            if block.type == .transit { openMapForNavigation() }
        }
    }

    private var durationMinutes: Int {
        Int(block.endTime.timeIntervalSince(block.startTime) / 60)
    }

    private var cardBody: some View {
        HStack(spacing: 12) {
            // 图标圆圈
            ZStack {
                Circle()
                    .fill(iconColorForBlock(block))
                    .frame(width: 40, height: 40)

                Image(systemName: iconForBlock(block))
                    .font(.system(size: 18))
                    .foregroundColor(.white)
            }
            
            // 中间：标题和时间信息
            VStack(alignment: .leading, spacing: 4) {
                Text(block.title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.primary)
                
                // 时间和类型标签
                HStack(spacing: 4) {
                    // 如果是餐饮类型，显示时间范围（开始时间 - 结束时间）
                    if isRestaurantType(block) {
                        Text("\(formattedTime(from: block.startTime)) - \(formattedTime(from: block.endTime))")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(iconColorForBlock(block))
                    } else {
                        // 其他类型只显示开始时间
                        Text(formattedTime(from: block.startTime))
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(iconColorForBlock(block))
                    }
                    
                    Text("·")
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                    
                    Text(typeLabelForBlock(block))
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // 编辑按钮（仅 activity 类型显示）
            if block.type == .activity {
                Button(action: {
                    onTap?()
                }) {
                    Text("編輯")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(14)
        .background(Color.white)
        .cornerRadius(14)
        .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 1)
        .contentShape(Rectangle())  // 让整个卡片可点击
        .onTapGesture {
            // 餐饮类型：跳转到地图应用搜索附近餐厅
            if isRestaurantType(block) {
                openMapForRestaurant()
            }
            // 交通类型：跳转到导航应用
            else if block.type == .transit {
                openMapForNavigation()
            }
            // 其他类型：保持原有行为（点击编辑按钮）
        }
    }
    
    // MARK: - 地图跳转功能
    
    /// 打开地图应用搜索附近餐厅
    private func openMapForRestaurant() {
        #if os(iOS)
        // 获取当前地点（如果有）或使用通用搜索
        let searchQuery: String
        if let location = block.location, !location.isEmpty {
            // 如果有地点，搜索该地点附近的餐厅
            searchQuery = "\(location) 附近餐厅"
        } else {
            // 如果没有地点，使用通用搜索
            searchQuery = "附近餐厅"
        }
        
        // 优先使用 Google Maps（如果可用），否则使用 Apple Maps
        let availableApps = MapAppManager.shared.getAvailableMapApps()
        
        if let googleMaps = availableApps.first(where: { $0 == .google }) {
            MapAppManager.shared.openMapApp(googleMaps, destination: searchQuery)
        } else if let appleMaps = availableApps.first(where: { $0 == .apple }) {
            MapAppManager.shared.openMapApp(appleMaps, destination: searchQuery)
        } else {
            // 如果都没有，使用 Apple Maps 作为默认
            MapAppManager.shared.openMapApp(.apple, destination: searchQuery)
        }
        #endif
    }
    
    /// 打开导航应用导航到下一个地点
    private func openMapForNavigation() {
        #if os(iOS)
        // 交通类型：导航到下一个地点
        guard let destination = nextLocation, !destination.isEmpty else {
            // 如果没有下一个地点，无法导航
            return
        }
        
        // 优先使用 Google Maps（如果可用），否则使用 Apple Maps
        let availableApps = MapAppManager.shared.getAvailableMapApps()
        
        if let googleMaps = availableApps.first(where: { $0 == .google }) {
            MapAppManager.shared.openMapApp(googleMaps, destination: destination, coordinate: nil, transportType: .automobile)
        } else if let appleMaps = availableApps.first(where: { $0 == .apple }) {
            MapAppManager.shared.openMapApp(appleMaps, destination: destination, coordinate: nil, transportType: .automobile)
        } else {
            MapAppManager.shared.openMapApp(.apple, destination: destination, coordinate: nil, transportType: .automobile)
        }
        #endif
    }
    
    // 根据 block 类型返回不同的颜色
    private func iconColorForBlock(_ block: TimeBlock) -> Color {
        switch block.type {
        case .activity:
            // 如果是餐饮类型，使用橙色
            let title = block.title.lowercased()
            if title.contains("餐廳") || title.contains("餐厅") || 
               title.contains("restaurant") || title.contains("美食") ||
               title.contains("午餐") || title.contains("晚餐") ||
               title.contains("早餐") || title.contains("拉麵") {
                return .orange
            }
            return .blue
        case .transit:
            return .orange
        case .buffer:
            return .gray
        case .flex:
            return .purple
        case .rest:
            return .green
        }
    }
    
    // 根据 block 类型返回标签文本
    private func typeLabelForBlock(_ block: TimeBlock) -> String {
        switch block.type {
        case .activity:
            // 如果是餐饮类型，显示"餐饮"
            let title = block.title.lowercased()
            if title.contains("餐廳") || title.contains("餐厅") || 
               title.contains("restaurant") || title.contains("美食") ||
               title.contains("午餐") || title.contains("晚餐") ||
               title.contains("早餐") || title.contains("拉麵") {
                return "餐饮"
            }
            return ""
        case .transit:
            return "交通"
        case .buffer:
            return "缓冲"
        case .flex:
            return "弹性"
        case .rest:
            return "休息"
        }
    }
    
    // 修复：基于 TimeBlockType 而不是 title 匹配，避免语言问题
    private func iconForBlock(_ block: TimeBlock) -> String {
        switch block.type {
        case .activity:
            // 对于 activity，可以根据 location 或 title 进一步细分
            let title = block.title.lowercased()
            if title.contains("餐廳") || title.contains("餐厅") || 
               title.contains("restaurant") || title.contains("美食") || 
               title.contains("拉麵") || title.contains("午餐") || 
               title.contains("晚餐") || title.contains("早餐") {
                return "fork.knife"
            } else if title.contains("寺") || title.contains("神宮") || title.contains("神社") || title.contains("廟") {
                return "building.columns.fill"
            } else if title.contains("觀景") || title.contains("展望") || title.contains("塔") {
                return "binoculars.fill"
            } else {
                return "mappin.circle.fill"
            }
        case .transit:
            return "bus.fill"
        case .buffer:
            return "clock.fill"
        case .flex:
            return "clock.arrow.circlepath"
        case .rest:
            return "bed.double.fill"
        }
    }
    
    // 修复：使用单一方案（DateFormatter）并缓存，避免性能浪费和格式不一致
    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.locale = Locale(identifier: "zh_TW")
        return formatter
    }()
    
    private func formattedTime(from date: Date) -> String {
        // 使用缓存的 formatter，统一使用 24 小时制
        return Self.timeFormatter.string(from: date)
    }
    
    // 判断是否为餐饮类型
    private func isRestaurantType(_ block: TimeBlock) -> Bool {
        guard block.type == .activity else { return false }
        let title = block.title.lowercased()
        return title.contains("餐廳") || title.contains("餐厅") || 
               title.contains("restaurant") || title.contains("美食") ||
               title.contains("午餐") || title.contains("晚餐") ||
               title.contains("早餐") || title.contains("拉麵")
    }
}

// MARK: - 交通位置管理器（用于实时GPS确认）

class TransitLocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    @Published var currentLocation: CLLocation?
    
    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 50  // 50米更新一次，节省电量
    }
    
    func requestPermission() {
        let status = manager.authorizationStatus
        if status == .notDetermined {
            manager.requestWhenInUseAuthorization()
        } else if status == .authorizedWhenInUse || status == .authorizedAlways {
            manager.startUpdatingLocation()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        currentLocation = locations.last
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("📍 [TransitLocationManager] GPS定位失败：\(error.localizedDescription)")
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways {
            manager.startUpdatingLocation()
        }
    }
}


