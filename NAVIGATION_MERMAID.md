# Secalender 頁面跳轉 — Mermaid 圖

本文件以 Mermaid 圖呈現 App 內所有頁面與跳轉關係，對應 [页面导航树状图.md](./页面导航树状图.md)。

---

## 1. 應用入口與主架構

```mermaid
flowchart TB
    RootView[RootView 根視圖]
    Auth[AuthenticationView 認證]
    Content[ContentView 主容器]
    Tab1[Tab1: 行事曆<br/>CalendarView]
    Tab2[Tab2: 智能規劃<br/>TravelTemplateView]
    Tab3[Tab3: 朋友＆社群<br/>FriendsAndGroupsView]
    Tab4[Tab4: 功能<br/>MemberView]

    RootView -->|未登入| Auth
    RootView -->|已登入| Content
    Auth --> SignIn[SignInEmailView]
    Auth --> BasicInfo[BasicInfoView]
    SignIn --> EmailVerify[EmailVerificationView]

    Content --> Tab1
    Content --> Tab2
    Content --> Tab3
    Content --> Tab4
```

---

## 2. 中間按鈕觸發（ContentView Sheet）

```mermaid
flowchart LR
    subgraph Tab1_中鍵[Tab1 行事曆]
        M1[中間按鈕] --> E1[EventCreateView]
    end
    subgraph Tab2_中鍵[Tab2 智能規劃]
        M2[中間按鈕] --> A1[AIConversationView]
    end
    subgraph Tab3_中鍵[Tab3 朋友＆社群]
        M3[中間按鈕] --> F1[FriendsActionBottomSheet]
        F1 --> AddF[AddFriendView]
        F1 --> AddG[AddGroupView]
    end
    subgraph Tab4_中鍵[Tab4 功能]
        M4[中間按鈕] --> E2[EventCreateView]
    end
```

---

## 3. Tab 1 — 行事曆（CalendarView）

```mermaid
flowchart TB
    Cal[CalendarView 行事曆]
    Create[EventCreateView 建立行程]
    Share[EventShareView 事件詳情]
    Multi[MultiEventView 多行程檢視]
    Batch[BatchShareEventsView 批量分享]
    Import[ImportAppleCalendarView 導入 Apple 日曆]
    Loc[LocationPickerView]
    Repeat[RepeatOptionsView]
    CalOpt[CalendarOptionsView]
    Travel[TravelTimeOptionsView]
    GroupSel[GroupSelectorView]
    Edit[EventEditView]
    Invite[InviteFriendsView]
    MapSel[MapAppSelectorView]

    Cal -->|中間按鈕 / 雙擊日期| Create
    Cal -->|點擊事件| Share
    Cal -->|多選 → 編輯| Multi
    Cal -->|多選 → 分享| Batch
    Cal -->|導入按鈕| Import

    Create --> Loc
    Create --> Repeat
    Create --> CalOpt
    Create --> Travel
    Create --> GroupSel

    Share --> Edit
    Share --> Invite
    Share --> MapSel
    Edit --> Loc
    Edit --> Repeat
    Edit --> CalOpt
    Edit --> Travel

    Multi --> Edit
    Multi --> Share
```

---

## 4. Tab 2 — 智能規劃（TravelTemplateView）

```mermaid
flowchart TB
    TravelTab[TravelTemplateView]
    Welcome[AIPlanningWelcomeView]
    Planner[AIPlannerView]
    MyTpl[MyTemplatesView]
    Store[TemplateStoreView]
    PlanDetail[PlanDetailView]
    BlockEdit[BlockEditView]
    TemplateDetail[TemplateDetailView]
    StoreDetail[TemplateDetailView 模板詳情]
    Creator[CreatorProfileView]
    Loc2[LocationPickerView]

    TravelTab --> Welcome
    TravelTab --> MyTpl
    TravelTab --> Store

    Welcome -->|開始規劃| Planner
    Planner -->|生成結果| PlanDetail
    Planner -->|模板市集| Store
    Store --> StoreDetail
    Store --> Creator
    Creator --> StoreDetail

    PlanDetail -->|點擊行程塊| BlockEdit
    PlanDetail -->|加入行程| MultiEventView
    BlockEdit --> Loc2

    MyTpl -->|點擊模板| PlanDetail
    MyTpl -->|fullScreenCover| PlanDetail
    MyTpl -->|加入行程後| MultiEventView
    StoreDetail --> PlanDetail
```

**AIPlanningWelcomeView 主題 Sheet 一覽：**

```mermaid
flowchart LR
    Welcome2[AIPlanningWelcomeView]
    Welcome2 --> W1[WeekendFlashView]
    Welcome2 --> D1[DeepCultureView]
    Welcome2 --> E1[EnrichTripView]
    Welcome2 --> T1[TravelPlanningView]
    Welcome2 --> C1[CreateTripTemplateView]
    Welcome2 --> M1[ThemeManagementView]
    Welcome2 --> Custom[自訂主題]
    W1 --> PlanDetail
    D1 --> PlanDetail
    E1 --> PlanDetail
    T1 --> PlanDetail
```

---

## 5. Tab 3 — 朋友＆社群（FriendsAndGroupsView）

```mermaid
flowchart TB
    FAG[FriendsAndGroupsView]
    AddFriend[AddFriendView]
    AddGroup[AddGroupView]
    FriendDetail[FriendDetailView]
    GroupDetail[GroupDetailView]
    FriendEvents[FriendEventsView]
    GroupEvents[GroupEventsView]
    EventShare[EventShareView]
    InviteMembers[InviteMembersToGroupView]
    Admin[AdminManagementView]

    FAG -->|添加好友| AddFriend
    FAG -->|創建社群| AddGroup
    FAG -->|點擊朋友| FriendDetail
    FAG -->|點擊社群| GroupDetail

    FriendDetail --> FriendEvents
    FriendEvents --> EventShare

    GroupDetail --> GroupEvents
    GroupDetail --> InviteMembers
    GroupDetail --> Admin
    GroupEvents --> EventShare
```

---

## 6. Tab 4 — 功能（MemberView）

```mermaid
flowchart TB
    Member[MemberView]
    Profile[ProfileHeaderView]
    Settings[SettingsView]
    EditProfile[EditProfileView]
    AddF[AddFriendView]
    FriendList[MyFriendListView]
    Requests[ReceivedFriendRequestsView]
    ShareHist[ShareHistoryView]
    EventInv[EventInvitationsView]
    ContentBatch[ContentBatchManagementView]
    Achieve[AchievementsContentView]
    ShareSheet[ShareProfileSheetView]
    QR[QRCodeSheetView]

    Member -->|用戶資訊| Profile
    Member -->|設定| Settings
    Member -->|分享按鈕| ShareSheet
    Member -->|內容批量管理| ContentBatch
    Member -->|添加好友| AddF
    Member -->|好友列表| FriendList
    Member -->|收到的好友請求| Requests
    Member -->|分享歷史| ShareHist
    Member -->|活動邀請| EventInv
    FriendList --> FriendDetailView
    ShareHist --> EventShareView
```

---

## 7. 設定頁（SettingsView）子頁面

```mermaid
flowchart TB
    Settings[SettingsView]
    Settings --> EditProfile[EditProfileView]
    Settings --> AccountSec[AccountSecurityView]
    Settings --> Visibility[VisibilityPrivacyView]
    Settings --> Notif[NotificationsView]
    Settings --> AIPref[AIAssistantPreferencesView]
    Settings --> DarkMode[DarkModeSelectionView]
    Settings --> Lang[LanguageSelectionView]
    Settings --> ContentPref[ContentPreferencesView]
    Settings --> Wallet[WalletPaymentView]
    Settings --> Feedback[FeedbackView]
    Settings --> Cache[CachePerformanceView]
    Settings --> About[AboutView]
    Settings --> Privacy[PrivacyPolicyView]
    AccountSec --> Phone[PhoneBindingView]
    AccountSec --> Pwd[PasswordManageView]
    AccountSec --> RealName[RealNameVerifyPlaceholderView]
    Settings --> ThemePref[ThemePreferencePickerView]
    Settings --> PayPwd[PaymentPasswordPlaceholderView]
    Settings --> Business[BusinessCenterDetailView]
    Settings --> Bills[BillsPlaceholderView]
    Settings -->|登出| AuthenticationView
```

---

## 8. 編輯個人資料（EditProfileView）子頁

```mermaid
flowchart LR
    EditProfile[EditProfileView]
    EditProfile --> EditUserCode[EditUserCodeView]
    EditProfile --> EditAlias[EditAliasView]
    EditProfile --> EditDisplayName[EditDisplayNameView]
    EditProfile --> EditGender[EditGenderView]
    EditProfile --> EditPhone[EditPhoneView]
    EditProfile --> EditRegion[EditRegionView]
    EditProfile --> EditSignature[EditSignatureView]
    EditProfile --> EditFavoriteTags[EditFavoriteTagsView]
    EditProfile --> ShareProfile[ShareProfileSheetView]
```

---

## 9. 導航方式圖例

```mermaid
flowchart LR
    subgraph 導航方式
        L[NavigationLink<br/>推入堆疊]
        S[.sheet<br/>模態]
        F[.fullScreenCover<br/>全屏]
    end
```

| 方式 | 說明 | 範例 |
|------|------|------|
| NavigationLink | 推入導航堆疊，可返回 | MemberView → SettingsView |
| .sheet | 底部彈出模態 | CalendarView → EventCreateView |
| .fullScreenCover | 全屏覆蓋 | MyTemplatesView → PlanDetailView |

---

## 10. Deep Link 與 RootView Sheet

```mermaid
flowchart TB
    Root[RootView]
    Root -->|pendingLink| Sheet[Sheet]
    Sheet --> AddFriendDL[AddFriendView 預填邀請碼]
    Sheet --> EventShareDL[EventShareView 分享連結]
    Sheet --> EventShareError[錯誤提示視圖]
```

---

## 11. 頁面與檔案對照（精簡）

| 頁面 | 檔案路徑 |
|------|----------|
| RootView | Secalender/Core/RootView.swift |
| ContentView | Secalender/ContentView.swift |
| CalendarView | Secalender/Views/CalendarView.swift |
| TravelTemplateView | Secalender/Views/Template/TravelTemplateView.swift |
| FriendsAndGroupsView | Secalender/Views/FriendsAndGroupsView.swift |
| MemberView | Secalender/Views/Member/MemberView.swift |
| EventCreateView / EventEditView / EventShareView | Secalender/Views/Event*.swift |
| PlanDetailView / BlockEditView / PlanEditView | Secalender/Views/Plan*.swift, BlockEditView.swift |
| AIPlannerView / AIPlanningWelcomeView | Secalender/Views/Template/AIPlannerView.swift, AIPlanningWelcomeView.swift |
| MyTemplatesView / TemplateStoreView / TemplateDetailView | Secalender/Views/Template/*.swift, TemplateDetailView.swift |
| SettingsView 及子頁 | Secalender/Core/Settings/SettingsView.swift |
| EditProfileView 及子頁 | Secalender/Views/EditProfileView.swift |

---

**對應文件**：[页面导航树状图.md](./页面导航树状图.md)  
**最後更新**：2025-03-07
