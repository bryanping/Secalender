# Secalender 時間引擎架構

Secalender 定位為**可定義時間規則的引擎**，而非單純的行程產生器。本文件描述時間型態、資料模型、服務層、快取策略與實作路線。

---

## 📋 目錄

1. [時間規劃的 7 大型態](#一時間規劃的-7-大型態)
2. [進階時間規劃模式](#二進階時間規劃模式)
3. [時間規劃的三個維度](#三時間規劃的三個維度)
4. [主題 = 時間規則模板](#四主題--時間規則模板)
5. [資料模型（Firestore）](#五資料模型firestore)
6. [服務層拆分](#六服務層拆分)
7. [快取與查詢策略](#七快取與查詢策略)
8. [實作路線圖](#八實作路線圖)

---

## 一、時間規劃的 7 大型態

這不是功能分類，是「時間本質分類」。

### 1️⃣ 固定型（Fixed Slot Planning）

| 項目 | 說明 |
|------|------|
| **特徵** | 明確開始時間 + 結束時間，像 Apple 日曆事件 |
| **現況** | ✅ `Event` 模型即為此型 |
| **例子** | 醫院預約、家教上門、會議、餐廳訂位 |

### 2️⃣ 區間可選型（Availability Planning）

| 項目 | 說明 |
|------|------|
| **特徵** | 提供「可用時間區間」，最終時間由他人決定 |
| **現況** | 規劃中 |
| **例子** | 家教學生填可上課時間、客戶填諮詢時段、團隊投票選開會時間 |
| **需要模型** | `availabilityRanges[]`、`status: pending / selected / confirmed` |

### 3️⃣ 彈性任務型（Floating Task）

| 項目 | 說明 |
|------|------|
| **特徵** | 沒有固定時間，只有期限或優先順序 |
| **現況** | 規劃中 |
| **例子** | 本週完成報告、三天內回覆、今日待辦 |
| **需要模型** | `deadline`、`estimatedDuration`、`priority`、`auto-scheduler flag` |
| **潛力** | AI 可自動塞進空白時間 |

### 4️⃣ 多階段型（Multi-Phase Planning）

| 項目 | 說明 |
|------|------|
| **特徵** | 有順序，每階段可能跨天 |
| **現況** | ✅ `itinerary` / `PlanResult` 屬於此型 |
| **例子** | 旅行（交通 → 景點 → 晚餐）、手術流程、專案開發 |
| **需要模型** | `phaseIndex`、`dependencyIds` |

### 5️⃣ 反覆週期型（Recurring System）

| 項目 | 說明 |
|------|------|
| **特徵** | 固定週期、可變時間 |
| **現況** | 部分支援 |
| **例子** | 每週家教、每月保養、每日運動 |
| **需要** | `recurrenceRule` (RRULE)、`auto-adjust mode` |

### 6️⃣ 協作撮合型（Matching Planning）

| 項目 | 說明 |
|------|------|
| **特徵** | 至少兩方，需要條件匹配 |
| **現況** | 規劃中 |
| **例子** | 家教老師 vs 學生、運動搭子、商業會面 |
| **需要模型** | `role`、`constraints`、`matching algorithm` |
| **潛力** | 社群變現核心 |

### 7️⃣ 自動優化型（AI Optimization）

| 項目 | 說明 |
|------|------|
| **特徵** | 系統主動安排，使用者只給條件 |
| **現況** | 部分支援 |
| **例子** | 幫我安排今天最有效率的工作、排一週健身+學習 |
| **需要** | `free time detection`、`priority weighting`、`fatigue model` |
| **潛力** | 高級訂閱功能 |

---

## 二、進階時間規劃模式

### A. 時間保護型（Time Shield）

- **用途**：封鎖不可被安排時間（如陪孩子時間）
- **模型**：`protected: true`、`cannotOverride: true`

### B. 能量型時間規劃（Energy-Based Planning）

- **概念**：用精神狀態而非時間排程
- **例子**：早上高專注、下午低能量，AI 依能量分配任務

### C. 條件觸發型（Conditional Planning）

- **例子**：下雨才安排室內、孩子生病取消家教
- **模型**：`triggerCondition`、`autoCancelPolicy`

### D. 商業資源型時間（Resource Booking）

- **例子**：教室、攝影棚、會議室
- **模型**：`resourceId`、`capacity`、`conflict detection`
- **潛力**：可變 SaaS

---

## 三、時間規劃的三個維度

頂尖產品不是增加功能，而是抽象維度。時間規劃只有三個軸：

| 維度 | 選項 | 現況 |
|------|------|------|
| **時間結構** | 固定 / 彈性 / 區間 | 固定 |
| **參與角色** | 單人 / 雙方 / 多方 | 單人 |
| **自動程度** | 手動 / 半自動 / AI 主導 | 半自動 |

**真正的市場在**：彈性 + 多方 + AI 主導

---

## 四、主題 = 時間規則模板

主題從「AI 提示詞分類」升級為「時間運算分類」。

### 建議支援的 6 類主題模式

```
generateItinerary    → 多階段型（旅行）
collectAvailability  → 區間可選型
floatingTasks        → 彈性任務型
recurringSchedule    → 週期型
matchingSchedule     → 撮合型
resourceBooking      → 資源預約型
```

### 主題與本質對應

| 主題 | 本質 |
|------|------|
| 旅行 | 多階段型 |
| 家教 | 區間可選 + 撮合 |
| 健身 | 週期型 |
| 創作 | 彈性任務 |
| 公司排班 | 多方 + 固定 + 資源 |

---

## 五、資料模型（Firestore）

### 核心原則

> 時間世界只保留 1 個時間物件集合（`time_items`），所有功能都只是不同視圖/流程在讀寫它。避免到處同步、到處 bug。

### 1. themes（主題）

```text
users/{uid}/themes/{themeKey}
```

| 欄位 | 類型 | 說明 |
|------|------|------|
| title | string | 主題名稱 |
| desc | string | 描述 |
| icon | string | 圖示 |
| mode | string | 見下方 mode 枚舉 |
| formSchemaId | string? | 可選，表單 schema |
| createdAt | timestamp | |
| updatedAt | timestamp | |

**mode 枚舉**：`generateItinerary` | `collectAvailability` | `floatingTasks` | `recurringSchedule` | `matchingSchedule` | `resourceBooking`

### 2. theme_prompts（提示詞集合）

```text
users/{uid}/theme_prompts/{themeKey}
```

| 欄位 | 類型 | 說明 |
|------|------|------|
| themeKey | string | 主題 key |
| mode | string | 對應模式 |
| prompts | map | 不同用途的 prompt |
| updatedAt | timestamp | |

**prompts map 結構**：
- `itinerary_prefix` - 行程生成用
- `form_generator_prefix` - 表單生成用
- `assistant_reply_prefix` - 助理回覆用
- `scheduler_policy_prefix` - AI 排程策略用

> 現有 `ThemePromptService` 已實作 `promptPrefix` 儲存，可逐步擴展為完整 prompts map。

### 3. planning_requests（流程型輸入單）

```text
users/{uid}/planning_requests/{requestId}
```

| 欄位 | 類型 | 說明 |
|------|------|------|
| themeKey | string | 主題 key |
| mode | string | 對應模式 |
| input | map | 表單輸入 |
| availabilityRanges | array? | 若為 collectAvailability |
| status | string | draft | submitted | scheduled | closed |
| createdAt | timestamp | |
| updatedAt | timestamp | |

### 4. time_items（統一時間物件）

```text
users/{uid}/time_items/{itemId}
```

| 欄位 | 類型 | 說明 |
|------|------|------|
| type | string | event | task | block | availability | suggestion |
| startAt | timestamp? | task 可空 |
| endAt | timestamp? | task 可空 |
| durationMin | number? | task 必填 |
| deadlineAt | timestamp? | task 可選 |
| priority | number | 1-5 |
| energyTag | string? | deepWork / light / admin |
| source | string | user | ai | imported |
| themeKey | string? | 可追溯 |
| requestId | string? | 可追溯 |
| templateId | string? | 可追溯 |
| status | string | active | done | canceled |
| updatedAt | timestamp | |

**type 與型態對應**：
- `event` → 固定型
- `task` → 彈性任務型
- `block` → 時間保護型
- `availability` → 區間可選型
- `suggestion` → AI 優化型

---

## 六、服務層拆分

### 原則

- **View**：只做展示/互動
- **ViewModel**：只做狀態與呼叫 Service
- **Service**：做 Firestore 與快取，避免 View 直接呼叫

### 服務清單

| 服務 | 職責 |
|------|------|
| **ThemeService** | themes CRUD |
| **ThemePromptService** | promptSet CRUD（✅ 已實作） |
| **TimeItemService** | time_items CRUD、批次更新、衝突檢測 |
| **PlanningRequestService** | planning_requests 流程單 |
| **SchedulerService** | 只負責「生成建議排程/調整」，不直接寫 UI |

### 避免 View 直接呼叫

```text
❌ View → Firestore
✅ View → ViewModel → Service → Firestore
```

---

## 七、快取與查詢策略

### 快取策略

| 資料類型 | 策略 |
|----------|------|
| themes / promptSet | 本地快取 + 變更才同步（UserDefaults / local file / Firestore listener） |
| time_items | 用**月範圍**查詢（startAt between 月初～月末+7天） |

### 避免重複 query

- 使用單例 `DataSyncCoordinator` 控制「同一個 query 只跑一次」
- 避免 `.onAppear` 重複 query

### 寫入策略

- **拖曳調整時間**：debounce 300~600ms → batch commit
- 減少 Firestore 寫入次數，降低能耗

---

## 八、實作路線圖

### 階段 0：現況（已完成）

- ✅ Event 模型（固定型）
- ✅ 行程/itinerary（多階段型）
- ✅ 主題專屬提示詞（ThemePromptService、aiPromptPrefix）
- ✅ QuickTheme + UserDefaults

### 階段 1：擴充 Theme 模式（約 2–4 週）

**目標**：主題從「僅提示詞」升級為「時間運算分類」

| 任務 | 說明 |
|------|------|
| 1.1 擴充 QuickTheme 模型 | 新增 `mode` 欄位（enum: generateItinerary | collectAvailability | floatingTasks | recurringSchedule | matchingSchedule | resourceBooking） |
| 1.2 擴充 theme_prompts | 從單一 `promptPrefix` 擴展為 `prompts` map（itinerary_prefix, form_generator_prefix 等） |
| 1.3 建立 ThemeService | 將 themes CRUD 從 QuickThemeManager 抽離，支援 Firestore 同步 |
| 1.4 內建主題對應 | 將 weekend_flash、deep_culture、enrich_trip、travel_planning 對應到正確 mode |

**產出**：主題可宣告其「時間型態」，為後續流程鋪路。

### 階段 2：引入 time_items 統一模型（約 4–6 週）

**目標**：單一時間物件集合，取代多處分散的 Event / Plan / Task

| 任務 | 說明 |
|------|------|
| 2.1 定義 TimeItem 模型 | type: event | task | block | availability | suggestion，支援 startAt/endAt/durationMin/deadlineAt |
| 2.2 建立 TimeItemService | CRUD、批次更新、衝突檢測 |
| 2.3 建立 Event ↔ TimeItem 轉換 | 現有 Event 寫入/讀取經由 TimeItemService，保持向後相容 |
| 2.4 建立 PlanResult ↔ TimeItem 轉換 | 行程生成結果寫入 time_items |
| 2.5 月範圍查詢 | 實作「startAt between 月初～月末+7天」查詢 |

**產出**：所有時間相關資料統一由 time_items 管理。

### 階段 3：彈性任務型 + AI 優化（約 4–6 週）

**目標**：支援待辦、deadline、AI 自動塞空檔

| 任務 | 說明 |
|------|------|
| 3.1 彈性任務 UI | 新增「待辦」列表，支援 deadline、priority、estimatedDuration |
| 3.2 空白時間檢測 | 從 time_items 計算使用者可用時間區間 |
| 3.3 SchedulerService | AI 根據 priority、deadline、energyTag 建議排程 |
| 3.4 一鍵塞入 | 使用者點「幫我安排」→ AI 將待辦塞進空檔 |

**產出**：支援 floatingTasks 與 AI 優化型。

### 階段 4：區間可選型 + 撮合型（約 6–8 週）

**目標**：家教、諮詢、團隊投票等場景

| 任務 | 說明 |
|------|------|
| 4.1 collectAvailability 流程 | 使用者填寫可用時間區間，存 planning_requests |
| 4.2 區間匹配 UI | 顯示「可選時間」與「已選時間」 |
| 4.3 matchingSchedule 流程 | 雙方/多方條件匹配（role、constraints） |
| 4.4 PlanningRequestService | 流程單 CRUD、狀態流轉 |

**產出**：支援區間可選型與協作撮合型。

### 階段 5：週期型強化 + 資源預約（約 4–6 週）

**目標**：RRULE 完整支援、教室/會議室預約

| 任務 | 說明 |
|------|------|
| 5.1 RRULE 完整支援 | 支援複雜週期規則（每週二四、每月第一週等） |
| 5.2 resourceBooking 流程 | resourceId、capacity、衝突檢測 |
| 5.3 資源管理 UI | 教室、攝影棚等資源的建立與預約 |

**產出**：支援 recurringSchedule 與 resourceBooking。

---

## 路線圖總覽

```
階段 0（現況）     → 階段 1（Theme 模式） → 階段 2（time_items）
       ✅                    2-4 週                    4-6 週
                                                              ↓
階段 5（資源預約） ← 階段 4（撮合型）   ← 階段 3（彈性任務）
    4-6 週                  6-8 週                    4-6 週
```

**預估總時程**：約 20–30 週（視資源與優先級調整）

---

## 相關文件

- [AI_GUIDE.md](./AI_GUIDE.md) - AI 行程生成配置與使用
- [页面导航树状图.md](./页面导航树状图.md) - 應用導航結構

---

**最後更新**: 2025-02-25  
**維護者**: Secalender 開發團隊
