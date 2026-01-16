# OpenAI 行程规划回应控制机制

## 整体流程

```
用户输入
    ↓
InputClassifier（输入分类：A/B/C/D）
    ↓
A/B类 → AITripGenerator（构建提示词）
    ↓
OpenAIManager（调用 OpenAI API）
    ↓
解析 JSON 响应
    ↓
转换为 PlanResult
    ↓
显示在 UI
```

## 1. 输入分类阶段（InputClassifier）

**文件**: `InputClassifier.swift`

### 分类逻辑
- **A类（完整需求）**: 包含目的地、时间、意图至少2项 → 直接生成
- **B类（半需求）**: 有目的地或意图但缺少时间 → 默认值补齐后生成
- **C类（碎片输入）**: 信息不足 → 进入追问模式
- **D类（模板意图）**: 检测到模板关键词 → 切换到模板系统

### 关键信息抽取（Slot Filling）
- 目的地（destination）
- 日期范围（dateRange）或天数（durationDays）
- 兴趣标签（interestTags）
- 节奏（pace）
- 步行强度（walkingLevel）
- 交通偏好（transportPreference）

## 2. 提示词构建阶段（AITripGenerator）

**文件**: `AITripGenerator.swift` → `buildPrompt()`

### 提示词结构

```swift
请为{目的地}规划一个{天数}天的详细行程（从{开始日期}到{结束日期}）。

【需求】
- 兴趣标签：{标签列表}
- 节奏：{松/中/紧}
- 步行强度：{少走路/正常/可多走}
- 交通偏好：{公共交通/出租车/步行/混合}

【要求】
1. 必须提供真实存在的景点、餐厅、购物地点等具体名称和地址
2. 每个活动都要有详细描述，说明为什么好玩、值得去
3. 考虑地理位置，合理规划路线，减少往返
4. 根据节奏安排每天的活动数量（轻松：3-4个，中等：4-5个，紧凑：5-6个）
5. 包含餐厅推荐，说明特色美食
6. 提供实用的游玩建议和小贴士

【输出格式】
{详细的JSON格式说明}
```

### 控制参数
- **目的地**: 从用户输入或追问中提取
- **天数**: 从日期范围计算或用户指定
- **兴趣标签**: 从输入中提取（美食、博物馆、自然、购物、亲子等）
- **节奏**: 从输入中提取（不要太累→松，紧凑→紧，默认→中）
- **步行强度**: 从输入中提取（少走路、不想走路等）
- **交通偏好**: 从输入中提取（地铁、捷运、出租车等）

## 3. OpenAI API 调用阶段（OpenAIManager）

**文件**: `OpenAIManager.swift` → `generateStructuredItinerary()`

### API 配置参数

```swift
{
  "model": "gpt-4o",           // 使用的模型
  "temperature": 0.8,          // 创造性（0.0-2.0，越高越有创造性）
  "max_tokens": 4000,          // 最大输出token数
  "messages": [
    {
      "role": "system",
      "content": "你是一位专业的旅游行程规划师..."
    },
    {
      "role": "user",
      "content": "{构建的提示词}"
    }
  ]
}
```

### System Prompt（系统提示词）

```
你是一位专业的旅游行程规划师。你的任务是根据用户需求生成详细、有趣、实用的行程规划。
必须返回有效的JSON格式，包含真实存在的景点、餐厅等具体地点和详细地址。
所有地点都必须是真实存在的，描述要生动有趣，说明为什么好玩、值得去。
```

### 关键控制点

1. **模型选择**: `gpt-4o`（高质量，支持长文本）
2. **Temperature**: `0.8`（提高创造性，让行程更有趣）
3. **Max Tokens**: `4000`（支持详细描述）
4. **System Prompt**: 明确角色和输出要求

## 4. 响应解析阶段（AITripGenerator）

**文件**: `AITripGenerator.swift` → `parseAIResponse()`

### JSON 结构要求

```json
{
  "destination": "台北",
  "startDate": "2024-01-15",
  "endDate": "2024-01-17",
  "days": [
    {
      "date": "2024-01-15",
      "daySummary": "第一天行程总结",
      "activities": [
        {
          "title": "台北101观景台",
          "location": "台北市信义区信义路五段7号",
          "description": "详细描述...",
          "category": "景点",
          "recommendedDuration": 90,
          "openingHours": "09:00-22:00",
          "tips": ["小贴士1", "小贴士2"],
          "priceLevel": "中等"
        }
      ],
      "transportation": ["交通建议"]
    }
  ],
  "generalTips": ["总体建议"]
}
```

### 解析流程
1. 提取 JSON（移除 markdown 代码块标记）
2. 修复常见 JSON 问题（尾随逗号等）
3. 解析为 `AITripPlan` 结构
4. 转换为 `PlanResult`（包含 TimeBlock）

## 5. 时间规划阶段（PlanGenerator）

**文件**: `PlanGenerator.swift` → `convertToPlanResult()`

### 时间块转换规则

- **ACTIVITY**: AI 生成的活动 → 转换为 TimeBlock
- **TRANSIT**: 自动添加交通时间（30分钟）
- **BUFFER**: 自动添加缓冲时间（10分钟）
- **FLEX**: 确保每天至少1个弹性时间
- **REST**: 确保每天至少1个休息时间

### 时间约束
- 连续活动 ≤ 2个
- 根据节奏调整活动数量
- 考虑开放时间（如果有）

## 6. 错误处理和回退机制

### 错误处理流程

```
AI 生成失败
    ↓
捕获错误
    ↓
回退到基础生成器（PlanGenerator）
    ↓
生成基础行程模板
    ↓
显示给用户（带提示）
```

### 回退条件
- API 调用失败
- JSON 解析失败
- 数据验证失败

## 控制机制总结

### 1. 输入控制
- **InputClassifier**: 智能分类和抽取关键信息
- **FollowUpManager**: C类输入的追问机制

### 2. 提示词控制
- **buildPrompt()**: 动态构建详细提示词
- 包含用户偏好、约束条件、输出格式要求

### 3. API 控制
- **模型**: gpt-4o（高质量）
- **Temperature**: 0.8（创造性）
- **Max Tokens**: 4000（详细描述）
- **System Prompt**: 明确角色和输出要求

### 4. 输出控制
- **JSON 格式**: 严格的结构化输出
- **数据验证**: 确保所有字段完整
- **时间规划**: 自动添加交通、缓冲时间

### 5. 质量保证
- **真实地点**: System Prompt 要求真实存在的地点
- **详细描述**: 要求说明为什么好玩、值得去
- **路线优化**: 要求考虑地理位置，减少往返
- **个性化**: 根据节奏、步行强度、交通偏好定制

## 可调整的参数

### 在 `AITripGenerator.swift` 中
- **提示词内容**: 修改 `buildPrompt()` 方法
- **要求列表**: 修改【要求】部分
- **输出格式**: 修改【输出格式】部分

### 在 `OpenAIManager.swift` 中
- **模型**: 修改 `model` 参数（如改为 `gpt-3.5-turbo` 降低成本）
- **Temperature**: 修改 `temperature` 参数（0.0-2.0）
- **Max Tokens**: 修改 `max_tokens` 参数
- **System Prompt**: 修改 `systemPrompt` 变量

### 在 `InputClassifier.swift` 中
- **分类规则**: 修改 `determineInputType()` 方法
- **Slot 抽取**: 修改各种 `extract*()` 方法
- **默认值**: 修改 `fillDefaults()` 方法

## 优化建议

1. **缓存机制**: 缓存常用目的地的行程，减少 API 调用
2. **流式输出**: 使用 streaming API 提供实时反馈
3. **上下文记忆**: 在对话中保持上下文，支持"修改行程"等操作
4. **多模型支持**: 根据复杂度选择不同模型（简单用 3.5，复杂用 4o）
5. **提示词模板**: 为不同场景准备不同的提示词模板
