# Secalender 页面清单文档

本文档详细列出了 Secalender 项目中所有已实现和待实现的页面，包括文件路径、功能描述和实现状态。

## 目录

- [主要 Tab 页面](#主要-tab-页面)
- [事件相关页面](#事件相关页面)
- [朋友和社群功能页面](#朋友和社群功能页面)
- [分享功能页面](#分享功能页面)
- [用户功能页面](#用户功能页面)
- [核心功能模块](#核心功能模块)
- [待实现页面](#待实现页面)

---

## 主要 Tab 页面

### 1. 行事曆页面

**文件路径**: `Secalender/Views/CalendarView.swift`

**功能描述**:
- 月份导航（上一月/下一月）
- 事件列表展示（按日期分组）
- 事件筛选功能（全部/我的行程/朋友分享/公开/附近行程）
- 双击日期快速创建事件
- 下拉刷新功能
- 事件颜色标记（红色-自己发起，绿色-社群发起，蓝色-朋友发起）
- 位置筛选（基于用户位置）

**实现状态**: ✅ 已完成

**依赖组件**:
- `SharedEventSectionView.swift` - 事件区块视图
- `EventCreateView.swift` - 事件创建视图
- `EventManager.swift` - 事件管理器
- `LocationManager` - 位置管理器（内嵌）

---

### 2. 智能規劃页面

**文件路径**: `Secalender/Views/AIPlannerView.swift`

**功能描述**:
- AI 行程规划输入界面
- 模板市集功能
- 规划结果展示
- 错误处理和加载状态

**实现状态**: ✅ 已完成

**相关页面**:
- `AIPlanResultView.swift` - 规划结果展示
- `TemplateStoreView.swift` - 模板市集
- `TemplateDetailView.swift` - 模板详情

**依赖模块**:
- `Core/AIgeneration/OpenAIManager.swift` - OpenAI 管理器
- `Core/AIgeneration/ScheduleItem.swift` - 行程项模型

---

### 3. 新增行程页面

**功能描述**:
- 快速创建新行程
- 使用 `EventCreateView` 作为核心组件
- 创建成功提示
- 自动重置表单

**实现状态**: ✅ 已完成

**依赖组件**:
- `EventCreateView.swift` - 事件创建表单
- `EventDetailViewModel.swift` - 事件详情视图模型

---

### 4. 朋友＆社群页面

**文件路径**: `Secalender/Views/FriendsAndGroupsView.swift`

**功能描述**:
- 朋友和社群管理 Tab 切换
- 朋友列表展示
- 社群列表展示
- 社群详情页面

**实现状态**: ✅ 已完成

**子组件**:
- `FriendRowView` - 朋友行视图（内嵌）
- `GroupRowView` - 社群行视图（内嵌）
- `GroupDetailView` - 社群详情视图（内嵌）

**相关页面**:
- `AddFriendView.swift` - 添加好友
- `AddGroupView.swift` - 添加社群
- `CommunityView.swift` - 社群互动

---

### 5. 功能页面

**文件路径**: `Secalender/Views/MemberView.swift`

**功能描述**:
- 用户信息展示
- 好友功能入口
- 分享功能入口
- 任务成就入口
- 设定入口

**实现状态**: ✅ 已完成

**子组件**:
- `AchievementsContentView` - 成就内容视图（内嵌）

**导航目标**:
- `AddFriendView.swift` - 添加好友
- `MyFriendListView.swift` - 好友清单
- `ReceivedFriendRequestsView.swift` - 收到的请求
- `ShareHistoryView.swift` - 分享历史
- `ShareNotificationsView.swift` - 分享通知
- `EventInvitationsView.swift` - 活动邀请
- `SettingsView.swift` - 设置页面

---

## 事件相关页面

### 事件创建和编辑

#### EventCreateView.swift
**路径**: `Secalender/Views/EventCreateView.swift`

**功能**: 事件创建表单，包含所有必要字段的输入

**实现状态**: ✅ 已完成

**依赖**:
- `EventDetailViewModel.swift` - 视图模型
- `EventManager.swift` - 事件管理器
- `LocationPickerView.swift` - 地点选择器
- `RepeatOptionsView.swift` - 重复选项
- `TravelTimeOptionsView.swift` - 行程时间选项

---

#### EventEditView.swift
**路径**: `Secalender/Views/EventEditView.swift`

**功能**: 事件编辑页面

**实现状态**: ✅ 已完成

---

#### EventDetailViewModel.swift
**路径**: `Secalender/Views/EventDetailViewModel.swift`

**功能**: 事件详情视图模型，处理事件数据的业务逻辑

**实现状态**: ✅ 已完成

---

### 事件展示和操作

#### SharedEventSectionView.swift
**路径**: `Secalender/Views/SharedEventSectionView.swift`

**功能**: 共享事件区块视图，按日期分组显示事件

**实现状态**: ✅ 已完成

---

#### EventShareView.swift
**路径**: `Secalender/Views/EventShareView.swift`

**功能**: 事件分享页面

**实现状态**: ✅ 已完成

---

#### EventShareActionView.swift
**路径**: `Secalender/Views/EventShareActionView.swift`

**功能**: 事件分享操作，包含分享选项和操作

**实现状态**: ✅ 已完成

**子组件**:
- `ActivityViewController` - iOS 分享控制器（内嵌）
- `FriendSelectionView` - 朋友选择视图（内嵌）

---

#### EventInvitationsView.swift
**路径**: `Secalender/Views/EventInvitationsView.swift`

**功能**: 活动邀请列表，显示收到的活动邀请

**实现状态**: ✅ 已完成

---

### 事件数据模型和管理

#### Event.swift
**路径**: `Secalender/Views/Event.swift`

**功能**: 事件数据模型

**实现状态**: ✅ 已完成

---

#### EventManager.swift
**路径**: `Secalender/Views/EventManager.swift`

**功能**: 事件管理逻辑，处理事件的 CRUD 操作

**实现状态**: ✅ 已完成

---

## 朋友和社群功能页面

### 朋友管理

#### AddFriendView.swift
**路径**: `Secalender/Views/AddFriendView.swift`

**功能**: 添加好友页面，支持搜索和添加好友

**实现状态**: ✅ 已完成

---

#### MyFriendListView.swift
**路径**: `Secalender/Views/MyFriendListView.swift`

**功能**: 好友清单，显示所有好友列表

**实现状态**: ✅ 已完成

---

#### ReceivedFriendRequestsView.swift
**路径**: `Secalender/Views/ReceivedFriendRequestsView.swift`

**功能**: 收到的请求，显示收到的好友请求

**实现状态**: ✅ 已完成

---

#### FriendEventsView.swift
**路径**: `Secalender/Views/FriendEventsView.swift`

**功能**: 朋友活动列表，显示特定朋友的活动

**实现状态**: ✅ 已完成

---

#### FriendSelectionView.swift
**路径**: `Secalender/Views/FriendSelectionView.swift`

**功能**: 朋友选择视图，用于选择要分享的朋友

**实现状态**: ✅ 已完成

---

#### FriendMultiSelectView.swift
**路径**: `Secalender/Views/FriendMultiSelectView.swift`

**功能**: 多选朋友视图，支持多选朋友

**实现状态**: ✅ 已完成

---

#### FriendSelectionRow.swift
**路径**: `Secalender/Views/FriendSelectionRow.swift`

**功能**: 朋友选择行组件，用于显示单个朋友选择项

**实现状态**: ✅ 已完成

---

#### FriendManager.swift
**路径**: `Secalender/Views/FriendManager.swift`

**功能**: 朋友管理逻辑，处理好友关系的 CRUD 操作

**实现状态**: ✅ 已完成

---

### 社群管理

#### AddGroupView.swift
**路径**: `Secalender/Views/AddGroupView.swift`

**功能**: 添加社群页面，创建新社群

**实现状态**: ✅ 已完成

---

#### GroupEventsView.swift
**路径**: `Secalender/Views/GroupEventsView.swift`

**功能**: 社群活动列表，显示社群的所有活动

**实现状态**: ✅ 已完成

---

#### CommunityView.swift
**路径**: `Secalender/Views/CommunityView.swift`

**功能**: 社群互动页面，包含三个 Tab：
- 朋友分享
- 社群分享
- 附近活动

**实现状态**: ✅ 已完成

**子页面**:
- `GroupEventsView` - 社群活动
- `NearbyEventsView` - 附近活动

---

## 分享功能页面

#### ShareHistoryView.swift
**路径**: `Secalender/Views/ShareHistoryView.swift`

**功能**: 分享历史，显示所有分享记录

**实现状态**: ✅ 已完成

---

#### ShareNotificationsView.swift
**路径**: `Secalender/Views/ShareNotificationsView.swift`

**功能**: 分享通知，显示分享相关的通知

**实现状态**: ✅ 已完成

---

#### InviteFriendsView.swift
**路径**: `Secalender/Views/InviteFriendsView.swift`

**功能**: 邀请朋友页面，邀请朋友加入活动

**实现状态**: ✅ 已完成

---

## 用户功能页面

#### EditProfileView.swift
**路径**: `Secalender/Views/EditProfileView.swift`

**功能**: 编辑个人资料

**实现状态**: ✅ 已完成

---

#### AchievementsView.swift
**路径**: `Secalender/Views/AchievementsView.swift`

**功能**: 成就页面，显示用户成就和任务进度

**实现状态**: ✅ 已完成

---

#### SettingsView.swift
**路径**: `Secalender/Core/Settings/SettingsView.swift`

**功能**: 设置页面，包含账户设定、偏好设定、缓存管理等

**实现状态**: ✅ 已完成

**相关模块**:
- `SettingsViewModel.swift` - 设置视图模型
- `UserPreferencesManager.swift` - 用户偏好管理器

---

## 辅助功能页面

#### LocationPickerView.swift
**路径**: `Secalender/Views/LocationPickerView.swift`

**功能**: 地点选择器，用于选择事件地点

**实现状态**: ✅ 已完成

---

#### CalendarOptionsView.swift
**路径**: `Secalender/Views/CalendarOptionsView.swift`

**功能**: 日历选项，设置日历相关选项

**实现状态**: ✅ 已完成

---

#### RepeatOptionsView.swift
**路径**: `Secalender/Views/RepeatOptionsView.swift`

**功能**: 重复选项，设置事件的重复规则

**实现状态**: ✅ 已完成

---

#### TravelTimeOptionsView.swift
**路径**: `Secalender/Views/TravelTimeOptionsView.swift`

**功能**: 行程时间选项，设置行程时间相关选项

**实现状态**: ✅ 已完成

---

#### TemplateStoreView.swift
**路径**: `Secalender/Views/TemplateStoreView.swift`

**功能**: 模板市集，浏览和购买行程模板

**实现状态**: ✅ 已完成

---

#### TemplateDetailView.swift
**路径**: `Secalender/Views/TemplateDetailView.swift`

**功能**: 模板详情，查看模板的详细信息

**实现状态**: ✅ 已完成

---

#### NearbyEventsView.swift
**路径**: `Secalender/Views/NearbyEventsView.swift`

**功能**: 附近活动，显示附近的活动

**实现状态**: ✅ 已完成

---

#### StaticSkeletonView.swift
**路径**: `Secalender/Views/StaticSkeletonView.swift`

**功能**: 骨架屏加载视图，用于显示加载状态

**实现状态**: ✅ 已完成

**子组件**:
- `SkeletonEventView` - 事件骨架视图（内嵌）
- `FastSkeletonView` - 快速骨架视图（内嵌）

---

#### ActivityViewController.swift
**路径**: `Secalender/Views/ActivityViewController.swift`

**功能**: iOS 分享控制器包装器

**实现状态**: ✅ 已完成

---

## 核心功能模块

### 认证模块

**路径**: `Secalender/Core/Authentication/`

#### AuthenticationView.swift
**功能**: 认证主视图，处理用户登录和注册

**实现状态**: ✅ 已完成

---

#### AuthenticationViewModel.swift
**功能**: 认证视图模型，处理认证业务逻辑

**实现状态**: ✅ 已完成

---

#### FirebaseUserManager.swift
**功能**: Firebase 用户管理，管理用户数据和状态

**实现状态**: ✅ 已完成

---

#### SignInEmailView.swift
**功能**: 邮箱登录视图

**实现状态**: ✅ 已完成

---

#### SignInEmailViewModel.swift
**功能**: 邮箱登录视图模型

**实现状态**: ✅ 已完成

---

**路径**: `Secalender/Authentication/`

#### AuthenticationManager.swift
**功能**: 认证管理器，统一管理认证逻辑

**实现状态**: ✅ 已完成

---

#### SignInAppleHelper.swift
**功能**: Apple 登录助手

**实现状态**: ✅ 已完成

---

#### SignInGoogleHelper.swift
**功能**: Google 登录助手

**实现状态**: ✅ 已完成

---

#### UserManager.swift
**功能**: 用户管理器

**实现状态**: ✅ 已完成

---

#### EventAccessManager.swift
**功能**: 事件访问管理器，管理事件访问权限

**实现状态**: ✅ 已完成

---

#### AppleCalendarManager.swift
**功能**: Apple 日历管理器，集成系统日历

**实现状态**: ✅ 已完成

---

### AI 功能模块

**路径**: `Secalender/Core/AIgeneration/`

#### OpenAIManager.swift
**功能**: OpenAI 管理器，处理 AI 相关请求

**实现状态**: ✅ 已完成

---

#### ScheduleItem.swift
**功能**: 行程项模型，定义行程项数据结构

**实现状态**: ✅ 已完成

---

### 缓存和存储模块

**路径**: `Secalender/Core/Cache/`

#### EventCacheManager.swift
**功能**: 事件缓存管理器，管理事件的本地缓存

**实现状态**: ✅ 已完成

---

### 位置服务模块

**路径**: `Secalender/Core/Location/`

#### LocationCacheManager.swift
**功能**: 位置缓存管理器，缓存位置信息

**实现状态**: ✅ 已完成

---

#### TravelTimeCalculator.swift
**功能**: 行程时间计算器，计算行程所需时间

**实现状态**: ✅ 已完成

---

### 设置模块

**路径**: `Secalender/Core/Settings/`

#### SettingsView.swift
**功能**: 设置页面（已在用户功能页面中列出）

**实现状态**: ✅ 已完成

---

#### SettingsViewModel.swift
**功能**: 设置视图模型

**实现状态**: ✅ 已完成

---

#### UserPreferencesManager.swift
**功能**: 用户偏好管理器，管理用户偏好设置

**实现状态**: ✅ 已完成

---

### 分享功能模块

**路径**: `Secalender/Core/Share/`

#### ContactManager.swift
**功能**: 联系人管理器，管理联系人信息

**实现状态**: ✅ 已完成

---

#### InviteLinkManager.swift
**功能**: 邀请链接管理器，生成和管理邀请链接

**实现状态**: ✅ 已完成

---

### 其他核心组件

#### RootView.swift
**路径**: `Secalender/Core/RootView.swift`

**功能**: 根视图，处理认证状态和路由

**实现状态**: ✅ 已完成

---

#### ContentView.swift
**路径**: `Secalender/ContentView.swift`

**功能**: 主 TabView 容器，包含所有主要标签页

**实现状态**: ✅ 已完成

---

#### SecalenderApp.swift
**路径**: `Secalender/SecalenderApp.swift`

**功能**: 应用入口，初始化应用和配置

**实现状态**: ✅ 已完成

---

## 待实现页面

### 高优先级

#### 事件详情页面
**功能**: 完整的事件详情展示页面，包含事件的所有信息和操作选项

**状态**: ⚠️ 待实现

**建议路径**: `Secalender/Views/EventDetailView.swift`

**功能需求**:
- 显示事件完整信息
- 编辑和删除操作
- 分享功能
- 邀请朋友
- 查看参与者

---

#### 社群成员管理页面
**功能**: 社群成员列表和管理功能

**状态**: ⚠️ 待实现

**建议路径**: `Secalender/Views/GroupMembersView.swift`

**功能需求**:
- 显示所有成员
- 添加/移除成员
- 成员权限管理
- 成员活动统计

---

#### 事件搜索页面
**功能**: 事件搜索功能

**状态**: ⚠️ 待实现

**建议路径**: `Secalender/Views/EventSearchView.swift`

**功能需求**:
- 关键词搜索
- 日期范围筛选
- 标签筛选
- 高级搜索选项

---

### 中优先级

#### 事件标签管理页面
**功能**: 管理事件标签

**状态**: ⚠️ 待实现

**建议路径**: `Secalender/Views/EventTagsView.swift`

---

#### 事件附件管理页面
**功能**: 管理事件的附件（图片、文件等）

**状态**: ⚠️ 待实现

**建议路径**: `Secalender/Views/EventAttachmentsView.swift`

---

#### 事件评论页面
**功能**: 对共享事件进行评论

**状态**: ⚠️ 待实现

**建议路径**: `Secalender/Views/EventCommentsView.swift`

---

#### 统计报表页面
**功能**: 活动参与统计

**状态**: ⚠️ 待实现

**建议路径**: `Secalender/Views/StatisticsView.swift`

---

### 低优先级

#### 导出功能页面
**功能**: 导出日历为 iCal 格式

**状态**: ⚠️ 待实现

**建议路径**: `Secalender/Views/ExportView.swift`

---

#### 主题定制页面
**功能**: 自定义主题颜色

**状态**: ⚠️ 待实现

**建议路径**: `Secalender/Views/ThemeSettingsView.swift`

---

## 页面统计

### 已完成页面
- **主要 Tab 页面**: 5 个
- **事件相关页面**: 9 个
- **朋友和社群页面**: 9 个
- **分享功能页面**: 3 个
- **用户功能页面**: 3 个
- **辅助功能页面**: 8 个
- **核心功能模块**: 20+ 个文件

**总计**: 约 60+ 个已实现的页面和组件

### 待实现页面
- **高优先级**: 3 个
- **中优先级**: 4 个
- **低优先级**: 2 个

**总计**: 9 个待实现的页面

---

## 更新记录

- **2025-01-XX**: 创建页面清单文档
- 持续更新中...

---

## 备注

- 所有页面路径均相对于项目根目录
- 实现状态标记：
  - ✅ 已完成
  - ⚠️ 待实现
  - 🔄 进行中
