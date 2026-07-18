# Secalender（活動曆）

Secalender 是一款 iOS 行事曆與活動管理 App：個人行程、朋友/社群分享、AI 智能規劃、模板市集、Time OS 時間管理。本 README 於 2026-07-18 依全量程式碼審查（iOS 152 檔 + Core 子模組 73 檔 + Web + infra）重寫，取代舊版過期內容。

---

## 1. 實際導航結構

TabView 為 **4 個 Tab + 中央動作鈕**（ContentView.swift），非舊文件所稱 5 Tab：

1. **行事曆** `CalendarView`
2. **智能規劃** `TravelTemplateView`（3 分頁：AI 規劃 `AIPlanningWelcomeView` / 我的模板 `MyTemplatesView` / 模板市集 `TemplateStoreView`；另可進 `TimeOSHomeView`）
3. （中央 + 鈕）動作選單：新增行程 `EventCreateView`、AI 對話 `AIConversationView`、加好友、建社群
4. **朋友＆社群** `FriendsAndGroupsView`
5. **會員中心** `MemberView`（→ 設定 `SettingsView`、影響力中心、商業中心、資產）

深鏈：`secalender://`（friend / invite / event / addevent / addcalendar）→ `DeepLinkCoordinator` → `RootView` 分派。

---

## 2. 實際專案結構

```
活動曆/
├── Secalender/                  # iOS App（CocoaPods + SPM）
│   ├── Secalender/
│   │   ├── SecalenderApp.swift / ContentView.swift
│   │   ├── Core/
│   │   │   ├── AIgeneration/    # OpenAIManager、AITripGenerator、InputClassifier、TripTemplateManager…（11 檔）
│   │   │   ├── GenerationEngine/# GenerationOrchestrator、PlannerIntentClassifier、ConflictDetector…（12 檔）
│   │   │   ├── Attractions/     # CityAttractionsDatabase（75 城硬編碼景點庫，無座標）
│   │   │   ├── Cache/           # EventCache、FriendCache、SyncQueueService、圖片/頭像快取（7 檔）
│   │   │   ├── Share/           # DeepLinkCoordinator、邀請連結、QRCode、SharedPlanService（8 檔）
│   │   │   ├── Location/        # GooglePlaces、TravelTimeCalculator、MapAppManager（6 檔）
│   │   │   ├── Influence/       # 埋點、XP、遊戲化、關係提醒（8 檔）
│   │   │   ├── Settings/ Profile/ Networking/ Localization/
│   │   │   └── RootView、TimeItemService、SchedulerService、QuickThemeManager、NPI、EntitlementService…
│   │   ├── Authentication/      # Auth 管理、SSO、Apple 日曆（12 檔）
│   │   ├── Models/（+ Coordination/ Planning/）
│   │   ├── TimeOS/              # TimeOSHomeView、SuggestionInbox、TodayWorkspace、LifeWorkflow
│   │   ├── Views/（+ Group/ Loginview/ Member/ Template/）
│   │   ├── Engines/Coordination/# 多人時間交集引擎
│   │   └── Utilities/
│   └── Multilingual/            # 7 語言 Localizable.strings
├── SecalenderWeb/               # 靜態站：index / events / plan / worldcup.html
└── infra/
    ├── firebase/                # firestore.rules、functions（awardXP、social 埋點）
    └── db/                      # PostgreSQL schema（已標註停用）
```

註：舊 README 所列 `Core/Import/`、`docs/` 目錄、`miniprogram/` 均不存在。

---

## 3. 功能模組現況（審查結論）

| 模組 | 完成度 | 狀態摘要 |
|---|---|---|
| 登入/註冊（Email/Google/Apple/匿名/手機） | 85% | 可用；但 users 唯一性查詢被 Firestore rules 阻斷（見 P0） |
| 行事曆月檢視 + 篩選/搜尋/標籤 | 85% | 可用；跨月多日事件漏顯示、「+」建立鈕被註解只剩雙擊 |
| 事件建立/編輯/刪除 + Local-First 同步佇列 | 75% | 可用；座標不落庫、離線重試產生重複事件、樂觀儲存吞錯 |
| 重複事件 | 15% | 只有 UI 與欄位，**無展開/顯示/編輯語意**（空殼） |
| 事件提醒/通知 | 0% | 無任何 UNUserNotification 排程（僅關係提醒有本地推播） |
| Apple 日曆匯入/寫出 | 60% | iOS 17+ 權限判斷 bug 導致讀寫失敗；匯入紀錄僅存本地 |
| 好友（搜尋/QR/邀請連結/請求） | 80% | 可用；快取未按用戶隔離會互相污染、刪好友單向、錯誤無 UI 回饋 |
| 社群 | 70% | 審核制/私密社群可被繞過直接加入；一般成員看不到社群活動列表 |
| 事件分享/邀請/參與狀態 | 70% | client 邏輯大致齊；**rules 缺 event_shares/event_invitations/notifications 集合**（部署即全斷）；accepted/joined 雙軌狀態 |
| AI 規劃（統一規劃器 + 旅遊四步驟） | 75% | 真 OpenAI（gpt-4o/4o-mini），但 key 打包在 App 內；生成進度為 16 秒假動畫；JSON 修復邏輯會越修越壞 |
| Time OS（建議收件匣/今日工作台/生活工作流） | 80% | 可用；套用時未排入項目也被標 done（資料遺失） |
| 多人時間協調 | 60% | 5 模式僅 3 種真實作；未回覆者被當不存在 |
| 模板市集 | 55% | 讀取走 APIClient；**購買為假流程**（無金流、僅本地標記）；發布/上架流程不存在 |
| 會員中心/影響力/XP | 65% | 埋點+Cloud Function awardXP 真實；商業中心/等級權益/分析數字全部寫死 |
| 設定 | 80% | 14 個子頁多數可用；快取資訊/意見反饋/2FA/錢包為假或空殼 |
| 多語言（7 語） | 60% | zh-Hant 最全 1117 key；de/es/fr/ja 缺約 44%、zh-Hans 缺 31% |
| Web（4 頁） | 80% | worldcup 最完整；plan.html 只能看不能確認、無深鏈按鈕 |
| 金流/IAP | 0% | 無 StoreKit；EntitlementService 無人呼叫、isProUser 恆 false |

---

## 4. 審查發現的問題

### P0 — 阻斷性（部署/上架前必修）

1. **Firestore rules 與 client 嚴重脫節**（infra/firebase/firestore.rules）
   - 缺 `event_shares`、`event_invitations`、`notifications` 三個集合規則 → 部署後分享/邀請/通知全部 permission-denied。
   - `users` 只許本人讀，但註冊要做 userCode/alias 唯一性 where 查詢 → **新用戶註冊流程被 rules 擋死**；userCode 搜好友亦同。
   - `groups/{gid}/groupEvents` 任何登入者可讀寫；`shared_plans`/`shared_quick_themes` create 未驗 creatorId；users create 未限欄位可自帶 XP。
   - 兩份 FIRESTORE_RULES.md 指向不存在的 `EVENT_AND_FIRESTORE_RULES.md`，且彼此不一致 → 收斂為單一真實來源。
2. **OpenAI API Key 打包進 App**（Info.plist/Secrets.xcconfig，OpenAIManager/PlannerIntentClassifier/CreateTripTemplateView 三處直連）→ 改後端代理。
3. **事件 ID 體系不穩定**：`abs(UUID().hashValue)`、缺 id 時 fallback `documentID.hashValue`（每次啟動隨機化）→ 去重/參與狀態/多選全不穩定；離線重試會產生新 id 造成重複事件。改用 documentID 字串。
4. **假購買流程**：TemplateDetailView 無扣款即「購買成功」，僅存本地 → 上架審核風險；接 StoreKit 2 或先下架價格顯示。
5. **iOS 17 日曆權限 bug**：AppleCalendarManager 多處只判 `.authorized` 未判 `.fullAccess` → 匯入/寫出在 iOS 17+ 失效。
6. Cloud Functions：`recordMetric` 無白名單可灌任意 metric 刷成就；awardXP 帶 metricKey 路徑 transaction 讀在寫後**必拋錯**（functions/src/index.ts:269）。

### P1 — 嚴重功能缺陷

- DateFormatter 全域未設 `en_US_POSIX`/timeZone；日期以裸字串存儲無時區 → 佛曆/和曆裝置寫壞資料、跨時區時間全錯。
- 跨區間查詢缺陷：TimeItemService 只查 startAt 落在範圍內 → 月曆漏顯示、衝突偵測漏判；CalendarView 月過濾同病。
- FriendManager 快取污染（getMutualFriendsCount 以對方 id 覆蓋自己的好友集）→ 全 app isFriend 判斷錯誤。
- EventShareView：管理員刪除按鈕無對應 alert（deleteEvent 永不執行）；分享「+」對非創建者也顯示（違反可見性規則 5.1）。
- 社群：joinGroupPublicly 不驗 privacy；getGroupMembers `in` 查詢 >10 人直接拋錯。
- AI 解析：fixJSON 把所有 `'`→`"`、換行→字面 `\n`（越修越壞）；同日重複活動標題 `Dictionary(uniqueKeysWithValues:)` **runtime crash**；GenerationSchedulerService `sorted >=` 未定義行為；排不進空檔的任務被靜默丟棄。
- 樂觀儲存吞錯：建立/編輯先 dismiss、背景失敗只 print → 幽靈事件；update 找不到文件靜默 no-op。
- EventCreateView 多日項「結束日期」Binding 寫回開始日期（明確 bug）；多日儲存中途失敗無回滾。
- ImageCacheService 用 Hasher 當快取鍵（跨啟動失效且垃圾堆積）。
- PhoneVerificationManager 把 17025（號碼已綁他人）當驗證成功。
- 錯誤處理普遍 `try?`/print 吞錯，登入失敗、AI 失敗（AIConversationView 無 .alert）用戶無感。

### P2 — 未完成/假資料/斷頭

- **確認孤兒頁 25 個**（有程式無入口，含約 120KB legacy）：CommunityView、NearbyEventsView*、FriendEventsView*、ShareNotificationsView、EventShareActionView（且與他檔重複宣告）、FriendMultiSelectView、TravelTimeOptionsView、DaySectionView、PlanDaySectionView、StaticSkeletonView、TimeSecretaryView(TimeOSV1)、WeekendFlashView、DeepCultureView、EnrichTripView、TravelPlanningView、CustomThemePlannerView、AchievementsView、AIPlanResultView、FavoritesDetailView、RecentViewsDetailView、SocialAssetsManagementView、PublishingHistoryView、CreatorPublicHubView、Core/Profile/ProfileView、ReviewView（*經由孤兒 CommunityView 連帶斷頭）。→ 接上導航或刪除。
- 無人呼叫的服務：EntitlementService、TimeItemMigration、CalendarEventRealtimeListener、OpenAIManager.generateSchedule、AIPlanner.generatePlan/suggestEvents（endpoint 早已下線）。
- 寫死假資料：商業中心全部數字、LevelBenefits、影響力分析卡、TemplateStore mock 創作者、FriendCard 統計、SettingsView 快取資訊/錢包、CreatorPublicHub 樣本卡、QR 佔位圖。
- 空殼/斷頭按鈕：MyPlansDetail/MyThemesDetail/Drafts（空殼）、PersonalProfileView 4 顆按鈕、ContentBatchManagement 4 卡、MyFriendListView 3 鈕、EventShareView 陌生人加好友、市集「創作者」分類、SettingsView 設密碼鈕未掛載、切換帳號空實作、AIConversationView「查看詳情/添加到日曆」無 sheet、MultiEventView 拖拽排序未綁定、轉存模板 stub。
- 其他：CalendarView「+」被註解、CityAttractionsDatabase 全庫無座標（距離排序失效）、聊天記錄只存不載、seed_worldcup.js 缺資料檔、plan.html 無法確認參與、域名三分裂（secalender.app / secalender.com / huodonli.cn）。

---

## 5. 多語言現況

| 語言 | 唯一 key | 相對 zh-Hant 缺漏 |
|---|---|---|
| zh-Hant | 1117 | 基準（另缺 en 的 24 個深鏈/repeat key） |
| en | 1014 | 缺 127（徽章牆、AI 規劃、行程豐富化） |
| zh-Hans | 773 | 缺 347 |
| es / de / fr | ~625 | 各缺 ~492（44%） |
| ja | 613 | 缺 525 |

另：程式內仍有大量硬編碼中文（EventCreate/Edit、CalendarView、EventUIStyle 等）與 `zh_TW` 寫死 locale；Web 支援 ar 而 iOS 不支援。建議建 CI 腳本比對 key 差集與重複 key（現 64 處重複）。

---

## 6. 上線前檢查清單（依審查重排）

- [ ] 修 firestore.rules 四項（P0-1）並用 Emulator 實測後部署
- [ ] OpenAI 改後端代理，移除 client key（P0-2）
- [ ] 事件 ID 改 documentID 字串（P0-3）
- [ ] 假購買下架或接 StoreKit 2（P0-4）
- [ ] iOS 17 日曆權限修復（P0-5）
- [ ] Cloud Functions：metric 白名單 + transaction 讀寫順序（P0-6）
- [ ] DateFormatter/時區統一工具
- [ ] 跨區間查詢修復（月曆 + 衝突偵測）
- [ ] EventShareView 刪除 alert、分享鈕權限 gating、accepted/joined 統一
- [ ] 孤兒頁與 legacy（~120KB）清理決策
- [ ] 多語言 key 補齊 + CI 校驗
- [ ] 重複事件引擎與本地通知提醒（核心行事曆期待功能）
- [ ] 補單元測試：NPI、SchedulerService、EventAccessManager、AvailabilityIntersectionEngine、fixJSON

---

## 7. 安裝與配置

1. 安裝 CocoaPods，專案根目錄執行 `pod install`，開啟 `.xcworkspace`。
2. 確認 `GoogleService-Info.plist` 已加入。
3. `Config/Secrets.xcconfig` 提供 API Key（GOOGLE_MAPS / OPENAI；OPENAI 將移往後端）。
4. Firebase：`infra/firebase/` 內 `deploy_rules.sh` 部署 rules 與索引（**先完成 P0-1 修復**）；functions 為 XP/埋點引擎。
5. `infra/db/` PostgreSQL schema 目前停用，模板市集讀取走 `APIClient`（GET /api/templates）。

技術棧：Swift / SwiftUI、Firebase（Auth、Firestore、Functions、Storage）、OpenAI（gpt-4o / gpt-4o-mini）、Google Maps & Places、CocoaPods + SPM。

---

## 8. 相關文件

- [EVENT_SHARE_VISIBILITY_RULES.md](./EVENT_SHARE_VISIBILITY_RULES.md) — 分享可見性規則（client 實作與此有偏差，見 P1）
- [TIME_ENGINE_ARCHITECTURE.md](./TIME_ENGINE_ARCHITECTURE.md) — Time OS / time_items 架構
- [AI_GUIDE.md](./AI_GUIDE.md)、[PAGE_INVENTORY.md](./PAGE_INVENTORY.md)、[NAVIGATION_MERMAID.md](./NAVIGATION_MERMAID.md) — ⚠️ 內容過期（引用 19+ 個不存在檔案、5 Tab 舊結構），待依本 README 第 2、3 節更新
- `docs/` 目錄（TODO.md、DATABASE_ARCHITECTURE.md、OFFLINE_SYNC_DESIGN.md 等）**不存在**，舊連結已全部移除
