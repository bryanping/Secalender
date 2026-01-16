# AI行程生成器配置说明

## 概述

已实现基于 OpenAI API 的智能行程生成功能，可以生成包含真实景点、餐厅和详细建议的行程。

## 功能特性

✅ **真实地点**：使用 OpenAI 生成真实存在的景点、餐厅、购物地点  
✅ **详细描述**：每个活动都有详细的游玩建议和小贴士  
✅ **智能规划**：考虑地理位置，合理规划路线  
✅ **个性化**：根据用户兴趣标签、节奏偏好定制行程  
✅ **错误回退**：如果 AI 生成失败，自动回退到基础生成器

## 配置步骤

### 1. 配置 OpenAI API Key

打开 `Secalender/Core/AIgeneration/OpenAIManager.swift`，在 `apiKey` 中填入您的 OpenAI API 密钥：

```swift
private let apiKey = "sk-你的API密钥"
```

**注意**：API key 已在 `AIPlanner.swift` 中配置，可以从那里复制。

### 2. 确保文件结构

确保以下文件都在项目的同一个 target 中：

- `InputClassifier.swift` - 包含 `Pace`, `WalkingLevel`, `TransportPreference`, `ExtractedSlots` 等类型
- `PlanGenerator.swift` - 包含 `TimeBlock`, `TimeBlockType`, `PlanResult`, `DayPlan` 等类型
- `ScheduleItem.swift` - 包含 `ScheduleItem` 类型
- `OpenAIManager.swift` - OpenAI API 管理器
- `AITripGenerator.swift` - AI行程生成器（新增）

### 3. 编译和运行

1. 在 Xcode 中清理构建文件夹（`Cmd+Shift+K`）
2. 重新构建项目（`Cmd+B`）
3. 运行应用测试 AI 行程生成功能

## 使用流程

1. 用户在「输入您的需求」文本框中输入需求（如："台北两天一夜，亲子，不要太累"）
2. 系统自动判别输入类型（A/B/C/D）
3. **A/B类**：调用 OpenAI API 生成包含真实地点的详细行程
4. **C类**：进入追问模式，收集必要信息后生成行程
5. 生成的结果包含：
   - 真实景点名称和地址
   - 详细的游玩建议
   - 餐厅推荐和美食说明
   - 交通建议
   - 开放时间、价格等信息
   - 实用小贴士

## API 调用说明

### 使用的模型

- **模型**：`gpt-4o`
- **温度**：0.8（提高创造性，让行程更有趣）
- **最大Token**：4000（支持详细描述）

### 提示词设计

系统提示词要求 AI：
- 提供真实存在的景点和地址
- 详细说明为什么好玩、值得去
- 考虑地理位置，合理规划路线
- 根据节奏安排活动数量
- 包含餐厅推荐和美食说明
- 提供实用建议和小贴士

## 错误处理

- 如果 API key 未配置：显示错误提示
- 如果 API 调用失败：自动回退到基础生成器
- 如果 JSON 解析失败：尝试修复常见问题（如尾随逗号）

## 成本估算

使用 `gpt-4o` 生成一个 3 天行程大约消耗：
- 输入：~1000 tokens
- 输出：~3000 tokens
- 预计成本：约 $0.03-0.05 美元

**建议**：
- 可以先用 `gpt-3.5-turbo` 测试（成本更低）
- 或者添加缓存机制，避免重复生成相同行程

## 示例输出

生成的行程包含以下信息：

```json
{
  "destination": "台北",
  "days": [
    {
      "date": "2024-01-15",
      "activities": [
        {
          "title": "台北101观景台",
          "location": "台北市信义区信义路五段7号",
          "description": "台北地标建筑，360度俯瞰台北市景...",
          "category": "景点",
          "recommendedDuration": 90,
          "openingHours": "09:00-22:00",
          "tips": ["建议傍晚时分前往，可欣赏日落和夜景"],
          "priceLevel": "中等"
        }
      ]
    }
  ]
}
```

## 故障排除

### 问题：编译错误 "Cannot find type 'X' in scope"

**解决方案**：
1. 确保所有文件都在同一个 target 中
2. 清理构建文件夹（`Cmd+Shift+K`）
3. 重新构建项目（`Cmd+B`）

### 问题：API 调用失败

**检查**：
1. API key 是否正确配置
2. 是否有网络连接
3. API key 是否有足够额度

### 问题：生成的行程不够详细

**调整**：
- 在 `AITripGenerator.swift` 的 `buildPrompt` 方法中增加更详细的提示词要求
- 调整 `temperature` 参数（0.8-1.0 更创造性）
- 增加 `max_tokens` 以支持更详细的描述

## 后续优化建议

1. **缓存机制**：缓存常用目的地的行程，减少 API 调用
2. **多语言支持**：支持英文、日文等目的地
3. **地图集成**：将生成的地点显示在地图上
4. **用户反馈**：收集用户对行程的评价，优化提示词
5. **预算估算**：根据价格级别估算行程总预算
