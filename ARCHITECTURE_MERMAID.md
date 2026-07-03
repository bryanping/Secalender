# Secalender 時間引擎架構 — Mermaid 圖

本文件以 Mermaid 圖呈現 [TIME_ENGINE_ARCHITECTURE.md](./TIME_ENGINE_ARCHITECTURE.md) 中的架構。

---

## 1. 整體定位

```mermaid
flowchart LR
    subgraph 定位
        A[Secalender] --> B[可定義時間規則的引擎]
        B --> C[非單純行程產生器]
    end
```

---

## 2. 時間規劃的 7 大型態

```mermaid
mindmap
  root((時間規劃<br/>7 大型態))
    固定型 Fixed
      Event 模型
      會議 / 預約 / 訂位
    區間可選型 Availability
      可用時間區間
      他人決定最終時間
    彈性任務型 Floating Task
      deadline / priority
      AI 可塞空檔
    多階段型 Multi-Phase
      itinerary / PlanResult
      旅行 / 專案流程
    反覆週期型 Recurring
      RRULE
      每週家教 / 每月保養
    協作撮合型 Matching
      雙方/多方
      條件匹配
    自動優化型 AI Optimization
      系統主動安排
      高級訂閱
```

---

## 3. 時間規劃三維度

```mermaid
quadrantChart
    title 時間規劃的三個維度
    x-axis 手動 --> AI 主導
    y-axis 單人 --> 多方
    quadrant-1 彈性 + 多方 + AI
    quadrant-2 固定 + 多方
    quadrant-3 單人 + 手動
    quadrant-4 單人 + AI
    現況: [0.3, 0.2]
    目標市場: [0.9, 0.8]
```

簡化版（維度與選項）：

```mermaid
flowchart TB
    subgraph 維度
        D1[時間結構: 固定 / 彈性 / 區間]
        D2[參與角色: 單人 / 雙方 / 多方]
        D3[自動程度: 手動 / 半自動 / AI 主導]
    end
    NOW[現況: 固定、單人、半自動]
    TARGET[市場: 彈性、多方、AI 主導]
    D1 --> NOW
    D2 --> NOW
    D3 --> NOW
    D1 -.-> TARGET
    D2 -.-> TARGET
    D3 -.-> TARGET
```

---

## 4. 主題模式與本質對應

```mermaid
flowchart LR
    subgraph 主題模式
        T1[generateItinerary]
        T2[collectAvailability]
        T3[floatingTasks]
        T4[recurringSchedule]
        T5[matchingSchedule]
        T6[resourceBooking]
    end
    subgraph 本質
        N1[多階段型]
        N2[區間可選型]
        N3[彈性任務型]
        N4[週期型]
        N5[撮合型]
        N6[資源預約型]
    end
    T1 --> N1
    T2 --> N2
    T3 --> N3
    T4 --> N4
    T5 --> N5
    T6 --> N6
```

---

## 5. Firestore 資料模型

```mermaid
erDiagram
    users ||--o{ themes : has
    users ||--o{ theme_prompts : has
    users ||--o{ planning_requests : has
    users ||--o{ time_items : has

    themes {
        string title
        string desc
        string icon
        string mode
        string formSchemaId
        timestamp createdAt
        timestamp updatedAt
    }

    theme_prompts {
        string themeKey
        string mode
        map prompts
        timestamp updatedAt
    }

    planning_requests {
        string themeKey
        string mode
        map input
        array availabilityRanges
        string status
        timestamp createdAt
        timestamp updatedAt
    }

    time_items {
        string type
        timestamp startAt
        timestamp endAt
        number durationMin
        timestamp deadlineAt
        number priority
        string energyTag
        string source
        string themeKey
        string requestId
        string templateId
        string status
        timestamp updatedAt
    }
```

**集合路徑：**

```mermaid
flowchart TB
    U["users/{uid}"]
    U --> T["themes/{themeKey}"]
    U --> TP["theme_prompts/{themeKey}"]
    U --> PR["planning_requests/{requestId}"]
    U --> TI["time_items/{itemId}"]
```

**time_items type 與型態對應：**

```mermaid
flowchart LR
    event[event] --> 固定型
    task[task] --> 彈性任務型
    block[block] --> 時間保護型
    availability[availability] --> 區間可選型
    suggestion[suggestion] --> AI優化型
```

---

## 6. 服務層架構

```mermaid
flowchart TB
    subgraph 展示層
        View[View]
    end
    subgraph 狀態層
        ViewModel[ViewModel]
    end
    subgraph 服務層
        ThemeService[ThemeService]
        ThemePromptService[ThemePromptService]
        TimeItemService[TimeItemService]
        PlanningRequestService[PlanningRequestService]
        SchedulerService[SchedulerService]
    end
    subgraph 資料層
        Firestore[(Firestore)]
    end

    View --> ViewModel
    ViewModel --> ThemeService
    ViewModel --> ThemePromptService
    ViewModel --> TimeItemService
    ViewModel --> PlanningRequestService
    ViewModel --> SchedulerService

    ThemeService --> Firestore
    ThemePromptService --> Firestore
    TimeItemService --> Firestore
    PlanningRequestService --> Firestore
    SchedulerService --> Firestore
```

**原則：**

```mermaid
flowchart LR
    subgraph 正確
        V1[View] --> VM[ViewModel] --> S[Service] --> F[Firestore]
    end
    subgraph 錯誤
        V2[View] -.->|❌| F2[Firestore]
    end
```

**服務職責：**

| 服務 | 職責 |
|------|------|
| ThemeService | themes CRUD |
| ThemePromptService | promptSet CRUD |
| TimeItemService | time_items CRUD、批次更新、衝突檢測 |
| PlanningRequestService | planning_requests 流程單 |
| SchedulerService | 生成建議排程/調整，不直接寫 UI |

---

## 7. 快取與查詢策略

```mermaid
flowchart TB
    subgraph 快取策略
        A[themes / promptSet] --> B[本地快取 + 變更才同步]
        C[time_items] --> D[月範圍查詢<br/>startAt 月初～月末+7天]
    end

    subgraph 寫入策略
        E[拖曳調整時間] --> F[debounce 300~600ms]
        F --> G[batch commit]
    end

    subgraph 避免重複
        H[DataSyncCoordinator 單例]
        H --> I[同一 query 只跑一次]
        I --> J[避免 onAppear 重複 query]
    end
```

---

## 8. 實作路線圖

```mermaid
flowchart LR
    S0[階段 0<br/>現況 ✅]
    S1[階段 1<br/>Theme 模式<br/>2-4 週]
    S2[階段 2<br/>time_items<br/>4-6 週]
    S3[階段 3<br/>彈性任務+AI<br/>4-6 週]
    S4[階段 4<br/>區間+撮合<br/>6-8 週]
    S5[階段 5<br/>週期+資源<br/>4-6 週]

    S0 --> S1 --> S2 --> S3 --> S4 --> S5
```

```mermaid
gantt
    title 實作階段時程（示意）
    dateFormat X
    axisFormat %s

    section 階段 1
    Theme 模式擴充    :a1, 0, 4
    section 階段 2
    time_items 統一   :a2, 4, 10
    section 階段 3
    彈性任務 + AI     :a3, 10, 16
    section 階段 4
    區間 + 撮合       :a4, 16, 24
    section 階段 5
    週期 + 資源       :a5, 24, 30
```

---

## 9. 進階時間規劃模式（補充）

```mermaid
flowchart TB
    subgraph 進階模式
        A[時間保護型 Time Shield]
        B[能量型規劃 Energy-Based]
        C[條件觸發型 Conditional]
        D[商業資源型 Resource Booking]
    end
    A --> A1[protected / cannotOverride]
    B --> B1[精神狀態分配任務]
    C --> C1[triggerCondition / autoCancelPolicy]
    D --> D1[resourceId / capacity / conflict]
```

---

## 10. 生成引擎架構

生成引擎為「多階段型」itinerary 的統一管道：UI 只組 `GenerateRequest` 並呼叫 `GenerationOrchestrator`，唯一輸出為 `GenerationResult`；新資料一律寫入 **time_items**（event / suggestion）。

```mermaid
flowchart LR
    subgraph UI
        AIP[AIPlannerView\n輸入頁]
        Detail[PlanDetailView\n結果預覽]
    end
    subgraph 引擎
        Req[GenerateRequest]
        Orch[GenerationOrchestrator]
        Res[GenerationResult]
    end
    AIP -->|組請求| Req
    Req --> Orch
    Orch -->|唯一輸出| Res
    Res --> Detail
    Detail -->|直接套用/存建議/scheduler| TimeItems[(time_items)]
```

**Orchestrator 內部流程：**

```mermaid
flowchart TB
    Req[GenerateRequest] --> Validate{輸入合法?}
    Validate -->|否| Err1[回傳錯誤]
    Validate -->|是| Theme[ThemeResolver\n主題解析]
    Theme -->|themeMode≠itinerary| Err2[不支援行程]
    Theme -->|userId 有值| TPS[ThemePromptService\n讀取 promptPrefix]
    Theme --> Context[ContextProvider\n讀取 time_items 範圍]
    Context --> Gen[AITripGenerator\n生成]
    Gen --> Norm[GenerationNormalizer\n→ TimeItemCandidate]
    Norm --> Class{resultType}
    Class -->|untimed/taskOnly| Sched[GenerationSchedulerService\n補時間]
    Class -->|timed| Conflict[ConflictDetector]
    Sched --> Conflict
    Conflict --> Out[GenerationResult\nplan + candidates + conflicts + themeKey]
```

**與服務層對應：**

| 引擎組件 | 依賴服務 / 資料 |
|----------|------------------|
| ThemeResolver | ThemePromptService（theme_prompts）、QuickThemeManager（themeMode） |
| ContextProvider | TimeItemService.fetchFixedItems |
| ApplyStrategy | TimeItemService.upsert（寫入 event / suggestion） |
| ConflictDetector | 現有 time_items（event、block） |
| GenerationSchedulerService | 空檔計算（與 SchedulerService 邏輯一致） |

**原則：**

- 對外唯一輸出為 **GenerationResult**；`PlanResult` 僅為過渡欄位存在於 `result.plan`。
- 新生成結果一律寫入 **time_items**（直接套用 → event，存為建議 → suggestion），不寫入舊 EventManager 為主流程。
- 寫入時帶入 `requestId`、`themeKey`，便於篩選與統計。

---

**對應文件**： [TIME_ENGINE_ARCHITECTURE.md](./TIME_ENGINE_ARCHITECTURE.md)  
**最後更新**： 2025-03-07
