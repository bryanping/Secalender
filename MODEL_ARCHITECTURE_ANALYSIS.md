# 数据模型架构分析

## 问题分析

经过检查，发现以下数据模型存在概念重叠但用途不同：

### 1. Template (模板市集的付费模板)
- **文件**: `Models/StoreTemplate.swift`
- **用途**: 模板市集中展示和购买的付费模板
- **存储**: PostgreSQL `templates` 表（通过 SecalenderWeb API）
- **数据结构**: 
  ```swift
  struct Template {
      let id: UUID
      let title: String
      let description: String
      let tags: [String]
      let price: Double
  }
  ```
- **特点**: 只有基本信息，不包含实际行程数据

### 2. SavedTripTemplate (用户保存的AI行程模板)
- **文件**: `Core/AIgeneration/TripTemplateManager.swift`
- **用途**: 保存用户通过AI生成的行程计划
- **存储**: 本地 UserDefaults
- **数据结构**: 
  ```swift
  struct SavedTripTemplate {
      let id: UUID
      var title: String
      var plan: PlanResult  // 完整的行程计划
      var savedDate: Date
      var tags: [String]
      // ...
  }
  ```
- **特点**: 包含完整的 PlanResult，可以转换为 Event

### 3. Event (实际的行程事件)
- **文件**: `Views/Event.swift`
- **用途**: 实际的行程事件，显示在日历上
- **存储**: Firebase Firestore (`users/{userId}/events` 或 `groups/{groupId}/groupEvents`)
- **数据结构**: 包含完整的行程信息（日期、时间、地点、备注等）

### 4. MultiDayEventItem (多日行程的临时数据)
- **文件**: `Views/EventCreateView.swift`
- **用途**: 创建多日行程时的临时UI状态
- **存储**: 不存储，只是UI状态
- **最终转换**: 转换为多个 Event

## 潜在问题

1. **命名混淆**: `Template` 和 `SavedTripTemplate` 都叫"模板"，但用途不同
2. **数据转换缺失**: `Template` (付费模板) 目前没有转换为 `Event` 的逻辑
3. **存储位置不同**: 
   - `Template` → PostgreSQL
   - `SavedTripTemplate` → UserDefaults
   - `Event` → Firebase Firestore

## 建议

### 方案1: 重命名 Template 为 StoreTemplate
- 将 `Template` 重命名为 `StoreTemplate` 或 `PaidTemplate`
- 明确表示这是模板市集的付费模板

### 方案2: 统一数据模型
- 考虑将 `Template` 扩展，包含实际的行程数据（PlanResult）
- 购买后可以转换为 `SavedTripTemplate` 或直接转换为 `Event`

### 方案3: 保持现状但添加注释
- 保持现有命名，但添加清晰的文档注释
- 确保每个模型都有明确的用途说明

## 当前状态

✅ **没有直接冲突**: 
- `Template` 和 `Event` 存储在不同的数据库
- `Template` 目前只是展示，没有转换为 `Event` 的逻辑
- `EventCreateView` 中不使用 `Template` 类型

⚠️ **需要注意**:
- `TemplateDetailView` 中的"套用至行事曆"按钮需要实现转换逻辑
- 如果将来要实现模板购买后转换为行程，需要明确转换路径
