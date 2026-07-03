# 事件分享可見性規則

> **已整合**：本文件已與 Firestore 安全規則合併至  
> [`docs/EVENT_AND_FIRESTORE_RULES.md`](../docs/EVENT_AND_FIRESTORE_RULES.md)。  
> 下列為原內容保留，以利快速查閱。

---

## 0. 核心原則（必須統一）

### 0.1 可见性判定先于 UI 渲染
- 先判定 **"是否可见"**，再决定 **"能做什么按钮/动作"**。

### 0.2 身份优先级
- 身份可能重叠（好友+被分享者+群成员等），必须用优先级决定最终身份。

### 0.3 颜色规则统一
- 颜色只由**"来源"**决定，参与状态只影响深浅，不要在不同页面用不同颜色逻辑。
- **颜色标准**：
  - 好友 / 非好友 / 个人单一分享（direct share / link share）＝ **绿色** `.green`
  - 社群活动＝ **蓝色** `.blue`
  - 自己创建＝ **红色** `.red`（保留）
  - 已结束＝ **灰色** `.gray`（保留）

### 0.4 字段命名统一（重要）
- **问题**：当前存在 `event.isOpenChecked`（Bool）和 `event.openChecked`（Int）混用
- **修正建议**：统一成两个明确字段（强烈建议）
  - `event.visibilityFriends: Bool` - 是否对好友公开
  - `event.visibilityGroup: Bool` - 是否对社群公开（或 `visibilityGroupLevel` 未来扩展）

## 1. 观看者身份优先级（从高到低，唯一真相）

同一用户满足多个条件时，取优先级更高者。

1. **创建者 Creator**
2. **社群管理者 Group Admin/Owner**（仅当事件属于该社群且对社群公开）
3. **被分享者 Shared Recipient**（含邀请链接验证通过）
4. **社群成员 Group Member**（普通成员）（仅当事件属于该社群且对社群公开）
5. **好友 Friend**（仅当对好友公开）
6. **陌生人 Stranger**

## 2. 可见性判定（是否能看到这条事件）

### 2.1 创建者（Creator）

- **条件**: `event.creatorOpenid == currentUserId`
- **可见性**: ✅ **可见**（完全可见）

### 2.2 社群可见（Group Member / Admin / Owner）

- **条件**:
  - `event.groupId != nil`
  - 当前用户属于该社群（`groupId ∈ userGroups`）
  - 且事件对社群公开（`event.openChecked == 1` 或等价字段）
- **可见性**: ✅ **可见**

> **注**：如果你未来要支持"社群私密活动"，这里要加一层 role 或 activityType 控制。

### 2.3 被单独分享/邀请链接（Shared Recipient / Invite Link）

- **条件**（任一成立）:
  - `event_shares` 中存在记录：`receiverId == currentUserId && eventId == event.id`
  - 或通过 `event_invites`/`InviteLinkManager` 验证通过（链接有效且当前用户被授权）
- **可见性**: ✅ **可见**

> **备注**：即使不是好友、也不是社群成员，只要属于"被分享者"，在行事历中**永远可见**。

### 2.4 好友可见（Friend）

- **条件**:
  - `FriendManager.shared.isFriend(with: event.creatorOpenid) == true`
  - 且事件公开给好友：`event.isOpenChecked == true`（或等价字段）
- **可见性**: ✅ **可见**

### 2.5 陌生人（Stranger）

- **条件**: 以上都不满足
- **可见性**: ❌ **不可见**（不应出现在列表/日历；若通过链接进入则显示无权限）

## 3. 权限与功能（看到以后能做什么）

### 3.1 创建者（Creator）

- ✅ 查看详情
- ✅ 编辑事件
- ✅ 分享事件
- ✅ 删除事件（若产品允许）

### 3.2 社群管理者（Group Owner / Admin）

- ✅ 查看详情
- ✅ 编辑事件（当事件属于社群活动时）
- ✅ 删除事件（当事件属于社群活动时）
- ✅ 分享事件

> **注意**：如果事件是"个人事件但带 groupId"这种异常结构，建议以"是否为社群活动"字段再做约束，避免管理员误删私人事件。

### 3.3 被分享者（Shared Recipient / Invite Link）

- ✅ 查看详情
- ✅ 参与 / 不参与
- ❌ 编辑
- ❌ 删除
- ❌ 分享（除非你额外允许"转分享"，见 6.2）

### 3.4 社群普通成员（Group Member）

- ✅ 查看详情
- ✅ 参与 / 不参与
- ❌ 编辑（除非也是创建者）
- ❌ 删除（除非也是创建者）
- ✅ 分享（仅当创建者允许，见 6.2）

### 3.5 好友（Friend）

- ✅ 查看详情
- ✅ 参与 / 不参与（你文档需要这个按钮，所以保留）
- ❌ 编辑
- ❌ 删除
- ✅ 分享（仅当创建者允许，见 6.2）

### 3.6 陌生人（Stranger）

- ❌ 不可见
- 若通过无效链接访问：显示"无权限/链接无效"，可提供"加好友"入口（可选）

## 4. 参与状态（Participation Status）

### 4.1 状态存储（统一来源）

- **数据源**: `event_shares.status`
- **允许值**:
  - `"shared"`：已分享但未表态（初始态）
  - `"joined"`：参与
  - `"declined"`：不参与

### 4.2 查询逻辑（避免公开事件查不到记录）

- 若查询不到 `event_shares` 记录：视为 **未表态**（等价 `"shared"`）

> **重点**：好友公开/社群公开的事件，初次可能没有 `event_shares` 记录。UI 仍然要能显示"参与"按钮，点击后再写入/更新 `event_shares`。

### 4.3 写入逻辑（必须 Upsert）

当用户点击"参与/不参与"，必须 upsert 一条 `event_shares`：

- `eventId`
- `receiverId`
- `creatorId`（建议存，便于索引/审计）
- `status` = `joined`/`declined`
- `source` = `friend` | `group` | `direct` | `link`（建议存，便于颜色来源与统计）
- `updatedAt`

## 5. UI 显示规则

### 5.1 EventShareView 底部按钮栏（按身份渲染）

#### Creator
```
[分享]
```
- 分享按钮：主要按钮样式（`.borderedProminent`）

#### Group Owner/Admin
```
[🗑️ 删除] [✏️ 编辑] [分享]
```
- 删除按钮：使用 `trash` icon，样式较不显眼
- 编辑按钮：使用 `pencil` icon
- 分享按钮：主要按钮样式

#### Shared Recipient / Friend / Group Member
```
[参与] [不参与]
```
- 参与按钮：主要按钮样式（`.borderedProminent`）
- 不参与按钮：次要按钮样式（`.bordered`）
- 或做成一个切换按钮（推荐）

#### Stranger
```
（显示"无权限"提示）
```
- 不显示操作按钮
- 可提供"添加创建者为好友"入口（可选）

> **注意**：分享按钮绝不能全员显示。只有 Creator /（允许的）Group Admin/Owner /（创建者允许转分享的）Friend/Group Member 才能显示。

## 6. 行事历显示颜色规则

### 6.1 颜色来源（唯一标准）

1. **自己创建的事件**：红色 `.red`
2. **社群活动**（group 可见）：蓝色 `.blue`
3. **好友可见 / 非好友单一分享 / 邀请链接 / 个人单一分享**：绿色 `.green`
4. **已结束**：灰色 `.gray`（覆盖以上颜色）

### 6.2 参与状态只影响深浅（建议）

- `"joined"`：正常不透明（`opacity: 1.0`）
- `"shared"` 或无记录：半透明（`opacity: 0.5`）
- `"declined"`：更淡（`opacity: 0.25`）或灰阶（由你决定）

> **这样你不会再出现"同类事件不同页面颜色冲突"**。

## 7. 数据查询需求（按判定顺序，最省能耗）

1. **当前用户**: `currentUserId = userManager.userOpenId`
2. **创建者判断**: `isCreator = event.creatorOpenid == currentUserId`
3. **group 判断**（若 `event.groupId != nil`）:
   ```swift
   let userGroups = try await GroupManager.shared.getUserGroups(userId: currentUserId)
   let groupIds = Set(userGroups.compactMap { $0.id })
   let isGroupMember = event.groupId != nil && groupIds.contains(event.groupId!)
   
   // 若需角色
   if let groupId = event.groupId {
       let group = try await GroupManager.shared.getGroup(groupId: groupId)
       let isOwner = group.isOwner(userId: currentUserId)
       let isAdmin = group.isAdmin(userId: currentUserId)
   }
   ```
4. **好友判断**: `isFriend = FriendManager.shared.isFriend(with: event.creatorOpenid)`
5. **share 记录**:
   ```swift
   db.collection("event_shares")
     .whereField("eventId", isEqualTo: event.id)
     .whereField("receiverId", isEqualTo: currentUserId)
     .getDocuments()
   ```
6. **邀请链接验证**（仅当通过链接进入时才做）:
   - `InviteLinkManager` / `event_invites` 验证

## 8. 实现注意事项（防止"按钮/颜色乱"再发生）

1. **先算身份 `viewerRole`，再渲染底部按钮**（按钮逻辑只看 `viewerRole`）
2. **颜色只看 `accessSource`，不看 `viewerRole`**（`source=group→蓝`，其他分享→绿）
3. **公开事件没有 share 记录时，状态默认 `shared`/未表态**
4. **所有写入参与状态都走 upsert，避免重复文档与状态错乱**
5. **异步查询**: 所有数据库查询都应该是异步的
6. **状态管理**: 使用 `@State` 管理观看者类型和参与状态
7. **权限检查**: 在显示 UI 之前先检查权限
8. **错误处理**: 处理网络错误和权限错误
9. **缓存优化**: 考虑缓存好友关系和分享记录以提高性能

## 9. 字段命名建议

### 当前问题
- `event.isOpenChecked`（Bool）和 `event.openChecked`（Int）混用
- 在不同页面可能写出两套判断逻辑

### 建议修正
```swift
struct Event {
    // 替换 openChecked/isOpenChecked
    var visibilityFriends: Bool = false  // 是否对好友公开
    var visibilityGroup: Bool = false   // 是否对社群公开
    
    // 或未来扩展
    // var visibilityGroupLevel: VisibilityLevel = .none
    // enum VisibilityLevel {
    //     case none, members, admins, owner
    // }
}
```

这样可以：
- 统一判断逻辑
- 避免在不同 View/ViewModel 里写两套判断
- 未来扩展更容易（如支持"仅管理员可见"）
