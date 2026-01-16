# Secalender

Secalender 是一个用于管理日历和活动的 iOS 应用程序，支持个人行程管理、朋友分享、社群活动和 AI 智能规划等功能。

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

## 主要导航结构

应用采用 TabView 结构，包含 5 个主要标签页：

1. **行事曆** - 查看和管理所有活动
2. **智能規劃** - AI 行程规划和模板市集
3. **新增行程** - 快速创建新行程
4. **朋友＆社群** - 管理朋友和社群
5. **功能** - 用户设置和功能入口

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

- ✅ **朋友管理**: `AddFriendView.swift`, `MyFriendListView.swift`, `ReceivedFriendRequestsView.swift`
- ✅ **社群管理**: `AddGroupView.swift`, `GroupEventsView.swift`, `CommunityView.swift`
- ✅ **朋友活动**: `FriendEventsView.swift`, `FriendSelectionView.swift`, `FriendMultiSelectView.swift`

### 分享功能

- ✅ `ShareHistoryView.swift` - 分享历史
- ✅ `ShareNotificationsView.swift` - 分享通知
- ✅ `InviteFriendsView.swift` - 邀请朋友

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

### 核心功能模块

#### 认证模块 (`Core/Authentication/`)
- ✅ `AuthenticationView.swift` - 认证主视图
- ✅ `FirebaseUserManager.swift` - Firebase 用户管理
- ✅ `AuthenticationManager.swift` - 认证管理器
- ✅ `SignInAppleHelper.swift` - Apple 登录助手
- ✅ `SignInGoogleHelper.swift` - Google 登录助手

#### AI 功能 (`Core/AIgeneration/`)
- ✅ `OpenAIManager.swift` - OpenAI 管理器
- ✅ `ScheduleItem.swift` - 行程项模型

#### 缓存和存储 (`Core/Cache/`)
- ✅ `EventCacheManager.swift` - 事件缓存管理器

#### 位置服务 (`Core/Location/`)
- ✅ `LocationCacheManager.swift` - 位置缓存管理器
- ✅ `TravelTimeCalculator.swift` - 行程时间计算器

#### 设置 (`Core/Settings/`)
- ✅ `SettingsView.swift` - 设置页面
- ✅ `UserPreferencesManager.swift` - 用户偏好管理器

#### 分享功能 (`Core/Share/`)
- ✅ `ContactManager.swift` - 联系人管理器
- ✅ `InviteLinkManager.swift` - 邀请链接管理器

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
- ⚠️ **分享链接生成** - 完善事件分享链接生成和解析（部分完成，需优化）
- ⚠️ **批量分享** - 支持批量分享多个事件

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
- ⚠️ **多语言支持** - 国际化支持

## 项目结构

```
Secalender/
├── SecalenderApp.swift          # 应用入口
├── ContentView.swift            # 主 TabView 容器
├── Core/
│   ├── RootView.swift           # 根视图（处理认证状态）
│   ├── Authentication/          # 认证相关
│   ├── AIgeneration/            # AI 功能
│   ├── Cache/                   # 缓存管理
│   ├── Location/                # 位置服务
│   ├── Profile/                 # 个人资料
│   ├── Settings/                # 设置
│   └── Share/                   # 分享功能
├── Views/                       # 所有视图页面
├── Models/                      # 数据模型
├── Authentication/              # 认证管理器
├── Components/                  # 可复用组件
└── Utilities/                   # 工具类
```

## 安装

1. 确保已安装 CocoaPods。
2. 在项目根目录下运行 `pod install`。
3. 打开生成的 `.xcworkspace` 文件。

## 配置

1. 确保 `GoogleService-Info.plist` 文件已添加到项目中。
2. 在 Xcode 中选择正确的 Scheme。
3. 配置 Firebase 项目（如果需要使用 Firebase 功能）。

## 使用

- 启动应用程序后，首先需要进行登录（支持 Apple、Google 和邮箱登录）。
- 登录后可以在日历视图中查看和管理活动。
- 点击活动可以查看详情或进行编辑。
- 使用底部 Tab 栏切换不同功能模块。

## 技术栈

- **开发语言**: Swift
- **UI 框架**: SwiftUI
- **后端服务**: Firebase (Authentication, Firestore)
- **AI 服务**: OpenAI API
- **依赖管理**: CocoaPods

## 开发进度

- ✅ 核心功能已实现
- ✅ 主要页面已完成
- ⚠️ 部分功能待完善（详见"待完善的页面/功能"章节）

## 多平台支持

### iOS 应用
- ✅ 完整的日历和事件管理功能
- ✅ 好友管理（支持别名、邮箱、用户ID搜索）
- ✅ 事件分享功能

### Web 应用 (SecalenderWeb)
- ✅ 好友管理功能
- ✅ 事件分享查看
- ✅ 支持部署到 https://huodonli.cn/
- 📝 位置：`/Users/linping/Desktop/活動歷/MyFirstProgram/SecalenderWeb/`

### 小程序 (miniprogram)
- ✅ 好友管理功能
- ✅ 事件分享查看
- 📝 位置：`/Users/linping/Desktop/活動歷/MyFirstProgram/SecalenderWeb/miniprogram/`

## 下一步行动计划

1. **完善事件详情页面** - 创建完整的事件详情展示和操作界面
2. **优化分享功能** - 完善事件分享链接和批量分享
3. **增强社群功能** - 完善社群成员管理和权限设置
4. **UI/UX 优化** - 统一加载状态、错误提示和空状态
5. **性能优化** - 优化列表滚动和图片加载性能
6. **Web 和小程序功能完善** - 添加事件创建、编辑等功能

## 贡献

欢迎提交问题和请求功能。请通过 GitHub 提交。

## 许可证

[在此添加许可证信息]
