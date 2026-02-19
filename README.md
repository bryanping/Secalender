# Secalender

Secalender 是一个用于管理日历和活动的 iOS 应用程序，支持个人行程管理、朋友分享、社群活动和 AI 智能规划等功能。

## 📚 文档索引

**查看完整文档索引**: [DOCUMENTATION_INDEX.md](./DOCUMENTATION_INDEX.md)

所有项目文档已整理完成，包括：
- 📖 项目概览和快速入门
- ⚙️ 配置与设置指南
- 🎯 功能说明文档
- 🏗️ 架构设计文档
- 🔧 问题解决方案
- ✅ 待办事项清单

---

## 主要功能

### 核心功能

- **日历视图**: 使用卷轴式的排列显示一整个月的行程，支持不同颜色标记不同类型的活动
  - 🔴 自己发起的活动用红色
  - 🟢 社群发起的活动用绿色
  - 🔵 朋友发起的活动用蓝色

- **活动管理**: 
  - 添加、编辑、删除活动
  - 支持活动的重复设置（如每周、每月）
  - 事件筛选功能（全部/我的行程/朋友分享/公开/附近行程）
  - 双击日期快速创建事件

- **智能规划**: 
  - AI 行程规划
  - 模板市集功能
  - 规划结果展示

- **朋友和社群**: 
  - 添加和管理好友（支持通过别名、邮箱或用户ID搜索添加）
  - 创建和管理社群
  - 查看朋友和社群的活动
  - 朋友活动分享

- **分享功能**: 
  - 事件分享
  - 分享历史记录
  - 分享通知
  - 活动邀请

- **用户功能**: 
  - 个人资料管理
  - 成就系统
  - 应用设置

- **其他功能**:
  - Apple 日历导入
  - Google 地图与 Places 地点搜索
  - 地图 App 跳转（Apple Maps、Google Maps）
  - 好友邀请链接与二维码
  - 批量分享多个事件
  - 多语言支持（含 Multilingual 资源）

## 主要导航结构

应用采用 TabView 结构，包含 5 个主要标签页：

1. **行事曆** - 查看和管理所有活动
2. **智能規劃** - AI 行程规划和模板市集
3. **新增行程** - 快速创建新行程
4. **朋友＆社群** - 管理朋友和社群
5. **功能** - 用户设置和功能入口

---

## 项目结构

```
Secalender/
├── SecalenderApp.swift          # 应用入口
├── ContentView.swift            # 主 TabView 容器
├── Core/
│   ├── RootView.swift           # 根视图（处理认证状态）
│   ├── Authentication/          # 认证相关（含 SignInEmailView、EmailVerificationView）
│   ├── AIgeneration/            # AI 功能
│   ├── Attractions/             # 景点数据
│   ├── Cache/                   # 缓存管理（事件、好友）
│   ├── Import/                  # 日历导入
│   ├── Localization/            # 多语言
│   ├── Location/                # 位置服务（含 Google Places）
│   ├── Profile/                 # 个人资料
│   ├── Settings/                # 设置
│   └── Share/                   # 分享功能（含邀请链接、QR Code）
├── Views/                       # 所有视图页面
├── Models/                      # 数据模型
├── Authentication/              # 认证管理器
├── Utilities/                   # 工具类
```

---

## 已完成的页面清单

### 主要 Tab 页面

- ✅ **行事曆页面** (`CalendarView.swift`) - 月份导航、事件列表、筛选功能、下拉刷新
- ✅ **智能規劃页面** (`AIPlannerView.swift`) - AI 规划输入、模板市集、结果展示
- ✅ **新增行程页面** (`EventCreateView.swift`) - 快速创建、成功提示、自动重置
- ✅ **朋友＆社群页面** (`FriendsAndGroupsView.swift`) - 朋友和社群管理
- ✅ **功能页面** (`MemberView.swift`) - 用户信息、功能入口

### 事件相关页面

- ✅ **事件创建/编辑**: `EventCreateView.swift`, `EventEditView.swift`, `EventDetailViewModel.swift`
- ✅ **事件展示**: `SharedEventSectionView.swift`, `EventShareView.swift`, `EventShareActionView.swift`
- ✅ **事件邀请**: `EventInvitationsView.swift`
- ✅ **事件管理**: `EventManager.swift`, `Event.swift`

### 朋友和社群功能

- ✅ **朋友管理**: `AddFriendView.swift`, `MyFriendListView.swift`, `ReceivedFriendRequestsView.swift`, `FriendDetailView.swift`
- ✅ **社群管理**: `AddGroupView.swift`, `GroupEventsView.swift`, `CommunityView.swift`
- ✅ **朋友活动**: `FriendEventsView.swift`, `FriendSelectionView.swift`, `FriendMultiSelectView.swift`

### 分享功能

- ✅ `ShareHistoryView.swift` - 分享历史
- ✅ `ShareNotificationsView.swift` - 分享通知
- ✅ `InviteFriendsView.swift` - 邀请朋友
- ✅ `BatchShareEventsView.swift` - 批量分享多个事件

### 其他功能页面

- ✅ `AchievementsView.swift` - 成就页面
- ✅ `EditProfileView.swift` - 编辑个人资料
- ✅ `LocationPickerView.swift` - 地点选择器
- ✅ `CalendarOptionsView.swift` - 日历选项
- ✅ `RepeatOptionsView.swift` - 重复选项
- ✅ `TravelTimeOptionsView.swift` - 行程时间选项
- ✅ `TemplateStoreView.swift` - 模板市集
- ✅ `TemplateDetailView.swift` - 模板详情
- ✅ `NearbyEventsView.swift` - 附近活动
- ✅ `StaticSkeletonView.swift` - 骨架屏加载视图
- ✅ `ImportAppleCalendarView.swift` - 导入 Apple 日历
- ✅ `GoogleMapView.swift` - Google 地图视图
- ✅ `MapAppSelectorView.swift` - 地图 App 选择器
- ✅ `BasicInfoView.swift` - 基本信息
- ✅ `BlockEditView.swift` - 行程区块编辑
- ✅ `EnrichTripView.swift` - 行程丰富化

### 核心功能模块

#### 认证模块 (`Core/Authentication/`、`Authentication/`)
- ✅ `AuthenticationView.swift` - 认证主视图
- ✅ `FirebaseUserManager.swift` - Firebase 用户管理
- ✅ `AuthenticationManager.swift` - 认证管理器
- ✅ `SignInAppleHelper.swift` - Apple 登录助手
- ✅ `SignInGoogleHelper.swift` - Google 登录助手
- ✅ `SignInEmailView.swift`、`EmailVerificationView.swift` - 邮箱登录与验证
- ✅ `PhoneVerificationManager.swift` - 手机验证管理器
- ✅ `AppleCalendarManager.swift` - Apple 日历管理

#### AI 功能 (`Core/AIgeneration/`)
- ✅ `OpenAIManager.swift` - OpenAI 管理器
- ✅ `ScheduleItem.swift` - 行程项模型
- ✅ `AITripGenerator.swift`、`PlanGenerator.swift`、`InputClassifier.swift` - AI 行程生成

#### 缓存和存储 (`Core/Cache/`)
- ✅ `EventCacheManager.swift` - 事件缓存管理器
- ✅ `FriendCacheManager.swift` - 好友缓存管理器

#### 位置服务 (`Core/Location/`)
- ✅ `LocationCacheManager.swift` - 位置缓存管理器
- ✅ `TravelTimeCalculator.swift` - 行程时间计算器
- ✅ `GooglePlacesManager.swift`、`GooglePlacesAutocompleteManager.swift` - Google Places 搜索
- ✅ `MapAppManager.swift` - 地图 App 跳转管理

#### 导入 (`Core/Import/`)
- ✅ `AppleCalendarImportManager.swift` - Apple 日历导入

#### 分享功能 (`Core/Share/`)
- ✅ `ContactManager.swift` - 联系人管理器
- ✅ `InviteLinkManager.swift` - 邀请链接管理器
- ✅ `FriendInviteLinkManager.swift` - 好友邀请链接
- ✅ `QRCodeGenerator.swift` - 二维码生成

#### 多语言 (`Core/Localization/`)
- ✅ `LocalizationManager.swift` - 本地化管理

#### 景点数据 (`Core/Attractions/`)
- ✅ `CityAttractionsDatabase.swift` - 城市景点数据

---

## 待完善的页面/功能

### 高优先级待完善功能

#### 事件相关
- ⚠️ **事件详情页面** - 需要创建完整的事件详情展示页面
- ⚠️ **事件删除确认** - 增强删除确认流程
- ⚠️ **事件重复规则** - 完善重复事件的创建和编辑逻辑
- ⚠️ **事件提醒设置** - 添加事件提醒功能

#### 朋友和社群
- ✅ **社群成员管理** - 完善社群成员列表和管理功能（已完成）
- ✅ **社群权限设置** - 添加社群管理员权限管理（已完成）
- ✅ **朋友活动同步** - 优化朋友活动同步机制（已完成）

#### 分享功能
- ✅ **事件分享基础功能** - 支持分享事件给好友、通过链接分享
- ✅ **分享可见性控制** - 根据观看者身份（创建者/被分享者/好友/陌生人）显示不同功能
  - 创建者：可分享、删除、编辑行程
  - 被分享者：可选择参与/不参与
  - 好友：可查看公开事件
  - 单一行程分享（非好友）：永远可见，参与状态用颜色区分（参与=蓝色，未参与=浅蓝色）
  - 陌生人：不可见
- ✅ **参与状态管理** - 支持记录和显示用户参与状态（已参与/未参与/已拒绝）
- ✅ **批量分享** - 支持批量分享多个事件（`BatchShareEventsView`）
- ✅ **分享链接生成** - 事件分享連結完整流程（InviteLinkManager + DeepLink 解析與導航）

### 中优先级待完善功能

#### UI/UX 优化
- ⚠️ **加载状态优化** - 统一加载状态展示
- ⚠️ **错误提示优化** - 统一错误提示样式和文案
- ⚠️ **空状态页面** - 为各列表页面添加空状态提示

#### 功能增强
- ⚠️ **事件搜索** - 添加事件搜索功能
- ⚠️ **事件标签** - 支持事件标签分类
- ⚠️ **事件附件** - 支持添加图片、文件等附件
- ⚠️ **事件评论** - 支持对共享事件进行评论

#### 数据同步
- ⚠️ **离线支持** - 完善离线数据缓存和同步
- ⚠️ **冲突解决** - 处理多设备数据冲突

### 低优先级/未来功能

- ⚠️ **统计报表** - 活动参与统计
- ⚠️ **导出功能** - 导出日历为 iCal 格式
- ⚠️ **主题定制** - 支持自定义主题颜色
- ⚠️ **多语言支持** - 国际化支持（已有基础结构）

---

## 安装与配置

### 安装

1. 确保已安装 CocoaPods。
2. 在项目根目录下运行 `pod install`。
3. 打开生成的 `.xcworkspace` 文件。

### 配置

1. 确保 `GoogleService-Info.plist` 文件已添加到项目中。
2. 在 Xcode 中选择正确的 Scheme。
3. 配置 Firebase 项目（如果需要使用 Firebase 功能）。

**详细配置指南**:
- [Google Maps 配置指南](./GOOGLE_MAPS_GUIDE.md)
- [AI 功能配置指南](./AI_GUIDE.md)
- [数据库架构文档](../docs/DATABASE_ARCHITECTURE.md)

---

## 技术栈

- **开发语言**: Swift
- **UI 框架**: SwiftUI
- **后端服务**: Firebase (Authentication, Firestore)
- **AI 服务**: OpenAI API
- **地图服务**: Google Maps SDK, Google Places SDK
- **依赖管理**: CocoaPods, Swift Package Manager (SPM)

---

## 数据库架构

### 架构总览

Secalender 采用「Web 服务（内容商品）+ Firebase（人/权限/私有资料）」架构：

| 资料类型 | 存放位置 | 说明 |
|---------|---------|------|
| **行程模板市集** | PostgreSQL | 可搜寻、可排序、可运营的内容商品 |
| **订单/付款** | PostgreSQL | 金流、发票、对帐 |
| **评价系统** | PostgreSQL | 公开评价、审核 |
| **用户资料** | Firebase Firestore | 个人资料、隐私设定 |
| **私有行程 (Events)** | Firebase Firestore | 用户自己建立的行程 |
| **购买记录索引** | Firebase Firestore | 快速判断授权 |
| **好友/群组** | Firebase Firestore | 社交关系、权限管理 |
| **媒体档案** | Object Storage + CDN | 图片、影片 |

### 代码对应关系

| 现有档案 | 新架构对应 |
|---------|-----------|
| `UserManager.swift` → `DBUser` | Firestore `users/{uid}` |
| `EventManager.swift` → `Event` | Firestore `users/{uid}/events/{eventId}` |
| `TripTemplateManager.swift` → `SavedTripTemplate` | Firestore `users/{uid}/library/{templateId}`（未来） |
| `FriendManager.swift` | Firestore `friends/{docId}`, `friend_requests/{docId}` |
| `GroupManager.swift` → `CommunityGroup` | Firestore `groups/{groupId}` |

### 实施阶段

#### Phase 1: 基础架构（MVP）
- [ ] Web 服务（PostgreSQL + API）
- [ ] Firebase 购买记录索引
- [ ] iOS App 整合

#### Phase 2: 进阶功能
- [ ] 评价系统
- [ ] 搜寻与筛选
- [ ] 收藏功能

#### Phase 3: 运营功能
- [ ] 作者系统
- [ ] 推荐系统
- [ ] 统计与分析

**详细架构文档**: 请参考 [docs/DATABASE_ARCHITECTURE.md](../docs/DATABASE_ARCHITECTURE.md)

---

## 使用指南

### 快速开始

- 启动应用程序后，首先需要进行登录（支持 Apple、Google、邮箱及手机验证登录）。
- 登录后可以在日历视图中查看和管理活动。
- 点击活动可以查看详情或进行编辑。
- 使用底部 Tab 栏切换不同功能模块。

### 多平台支持

#### iOS 应用
- ✅ 完整的日历和事件管理功能
- ✅ 好友管理（支持别名、邮箱、用户ID搜索）
- ✅ 事件分享与批量分享
- ✅ Apple 日历导入
- ✅ Google 地图与地点搜索

#### Web 应用 (SecalenderWeb)
- ✅ 好友管理功能
- ✅ 事件分享查看
- ✅ 支持部署到 https://huodonli.cn/
- 📝 位置：`/Users/linping/Desktop/活動歷/MyFirstProgram/SecalenderWeb/`

#### 小程序 (miniprogram)
- ✅ 好友管理功能
- ✅ 事件分享查看
- 📝 位置：`/Users/linping/Desktop/活動歷/MyFirstProgram/SecalenderWeb/miniprogram/`

---

## 开发进度

- ✅ 核心功能已实现
- ✅ 主要页面已完成
- ✅ 数据库架构设计完成
- ⚠️ 部分功能待完善（详见"待完善的页面/功能"章节）
- ⚠️ 数据库架构实施中（详见 [docs/TODO.md](../docs/TODO.md)）

---

## 下一步行动计划

1. **完善事件详情页面** - 创建完整的事件详情展示和操作界面
2. **优化分享功能** - 完善事件分享链接生成和解析
3. **UI/UX 优化** - 统一加载状态、错误提示和空状态
4. **性能优化** - 优化列表滚动和图片加载性能
5. **Web 和小程序功能完善** - 添加事件创建、编辑等功能
6. **数据库架构实施** - 完成 Phase 1 MVP 实施（详见 [docs/TODO.md](../docs/TODO.md)）

---

## 相关文档

### 配置指南
- [Google Maps 配置指南](./GOOGLE_MAPS_GUIDE.md) - Google Maps SDK 集成配置
- [AI 功能配置指南](./AI_GUIDE.md) - AI 行程生成功能配置

### 功能说明
- [页面清单](./PAGE_INVENTORY.md) - 所有已实现和待实现的页面
- [事件分享规则](./EVENT_SHARE_VISIBILITY_RULES.md) - 事件分享可见性规则

### 架构设计
- [数据库架构设计](../docs/DATABASE_ARCHITECTURE.md) - 完整的数据库架构设计
- [Firestore 安全规则](../docs/FIRESTORE_RULES.md) - Firestore Security Rules
- [Web API 整合指南](../docs/WEB_API_INTEGRATION.md) - Web API 整合指南

### 待办事项
- [实施 TODO 清单](../docs/TODO.md) - 数据库架构实施任务清单

---

## 贡献

欢迎提交问题和请求功能。请通过 GitHub 提交。

---

## 许可证

[在此添加许可证信息]
