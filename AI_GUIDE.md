# AI 行程生成功能完整指南

本文档包含 Secalender AI 行程生成功能的完整配置、使用和故障排除指南。

---

## 📋 目录

1. [概述](#概述)
2. [時間型態與主題定位](#時間型態與主題定位)
3. [功能特性](#功能特性)
4. [配置步骤](#配置步骤)
5. [配置开关](#配置开关)
6. [使用流程](#使用流程)
7. [工作原理](#工作原理)
8. [成本与配额](#成本与配额)
9. [常见问题](#常见问题)
10. [故障排除](#故障排除)

---

## 概述

Secalender 已实现基于 OpenAI API 的智能行程生成功能，可以生成包含真实景点、餐厅和详细建议的行程。

### 核心组件

- **InputClassifier** - 输入分类和信息抽取
- **AITripGenerator** - AI 行程生成器
- **OpenAIManager** - OpenAI API 管理器
- **PlanGenerator** - 基础行程生成器（回退方案）
- **AIConfig** - AI 功能配置开关

---

## 時間型態與主題定位

### Secalender 定位

Secalender 不只是「行程產生器」，而是**時間結構引擎**。做的是「時間型態抽象」，目標成為一個**時間操作系統**。

### 時間規劃的 7 大型態

這不是功能分類，是「時間本質分類」：

| 型態 | 特徵 | 現況 | 例子 |
|------|------|------|------|
| **1. 固定型** | 明確開始/結束時間 | ✅ Event 模型 | 醫院預約、會議、餐廳訂位 |
| **2. 區間可選型** | 提供可用時間區間，由他人決定 | 規劃中 | 家教學生填可上課時間、團隊投票選開會時間 |
| **3. 彈性任務型** | 無固定時間，只有期限/優先順序 | 規劃中 | 本週完成報告、今日待辦、AI 自動塞進空白時間 |
| **4. 多階段型** | 有順序，每階段可能跨天 | ✅ 行程/itinerary | 旅行（交通→景點→晚餐）、專案開發 |
| **5. 反覆週期型** | 固定週期、可變時間 | 部分支援 | 每週家教、每月保養、每日運動 |
| **6. 協作撮合型** | 至少兩方，需條件匹配 | 規劃中 | 家教老師 vs 學生、運動搭子 |
| **7. AI 優化型** | 系統主動安排，使用者只給條件 | 部分支援 | 幫我安排今天最有效率的工作、排一週健身+學習 |

### 主題 = 時間規則模板

主題不該只是「AI 提示詞分類」，而應升級為**時間運算分類**：

| 主題 | 本質 | 對應 mode |
|------|------|-----------|
| 旅行 | 多階段型 | `generateItinerary` |
| 家教 | 區間可選 + 撮合 | `collectAvailability` + `matchingSchedule` |
| 健身 | 週期型 | `recurringSchedule` |
| 創作 | 彈性任務 | `floatingTasks` |
| 公司排班 | 多方 + 固定 + 資源 | `resourceBooking` |

**建議最終支援的 6 類主題模式**：
```
generateItinerary    → 多階段型（旅行）
collectAvailability  → 區間可選型
floatingTasks        → 彈性任務型
recurringSchedule    → 週期型
matchingSchedule     → 撮合型
resourceBooking      → 資源預約型
```

### 時間規劃的 3 個維度

頂尖產品不是增加功能，而是抽象維度。時間規劃只有三個軸：

1. **時間結構**：固定 / 彈性 / 區間
2. **參與角色**：單人 / 雙方 / 多方
3. **自動程度**：手動 / 半自動 / AI 主導

目前 Secalender 偏重：**固定 + 單人 + 半自動**。未來市場在：**彈性 + 多方 + AI 主導**。

> 詳細架構、資料模型、服務層、實作路線請參閱 [TIME_ENGINE_ARCHITECTURE.md](./TIME_ENGINE_ARCHITECTURE.md)。

---

## 功能特性

✅ **真实地点**：使用 OpenAI 生成真实存在的景点、餐厅、购物地点  
✅ **详细描述**：每个活动都有详细的游玩建议和小贴士  
✅ **智能规划**：考虑地理位置，合理规划路线  
✅ **个性化**：根据用户兴趣标签、节奏偏好定制行程  
✅ **错误回退**：如果 AI 生成失败，自动回退到基础生成器  
✅ **配置开关**：支持禁用 AI 功能以节省费用

---

## 配置步骤

### 1. 配置 OpenAI API Key

**推荐方式：通过 Secrets.xcconfig（已配置）**

项目已配置使用 `Secrets.xcconfig` 来管理 API Key，这是最安全的方式。

1. 打开 `Config/Secrets.xcconfig` 文件
2. 确保 `OPENAI_API_KEY` 已设置：
```bash
OPENAI_API_KEY = sk-你的API密钥
```

3. 确保 `Info.plist` 中包含：
```xml
<key>OPENAI_API_KEY</key>
<string>$(OPENAI_API_KEY)</string>
```

4. 确保 Xcode 项目 Build Settings 中引用了 `Secrets.xcconfig`

**备用方式：通过环境变量（仅用于调试）**

设置环境变量：
```bash
export OPENAI_API_KEY="sk-你的API密钥"
```

**重要说明**：
- `OpenAIManager.swift` 中的 `apiKey` 是一个计算属性，从 `Info.plist` 或环境变量读取
- **不要**直接在代码中硬编码 API Key
- API Key 的读取优先级：Info.plist → 环境变量

### 2. 确保文件结构

确保以下文件都在项目的同一个 target 中：

- `InputClassifier.swift` - 包含 `Pace`, `WalkingLevel`, `TransportPreference`, `ExtractedSlots` 等类型
- `PlanGenerator.swift` - 包含 `TimeBlock`, `TimeBlockType`, `PlanResult`, `DayPlan` 等类型
- `ScheduleItem.swift` - 包含 `ScheduleItem` 类型
- `OpenAIManager.swift` - OpenAI API 管理器
- `AITripGenerator.swift` - AI行程生成器
- `AIConfig.swift` - AI 配置开关

### 3. 编译和运行

1. 在 Xcode 中清理构建文件夹（`Cmd+Shift+K`）
2. 重新构建项目（`Cmd+B`）
3. 运行应用测试 AI 行程生成功能

---

## 配置开关

`AIConfig` 提供了一个简单的代码开关，用于控制是否使用 OpenAI API 生成行程。这可以在测试时节省 API 流量和费用。

### 方法 1：修改代码默认值（推荐用于测试）

编辑 `Secalender/Secalender/Core/AIgeneration/AIConfig.swift`：

```swift
private let defaultOpenAIEnabled = false  // 改为 false 禁用 OpenAI API
```

**优点**：
- 永久禁用，除非修改代码
- 适合长期测试，避免误用
- 不需要重新配置

### 方法 2：运行时修改（适合临时测试）

在代码中任何地方调用：

```swift
// 禁用 OpenAI API
AIConfig.shared.isOpenAIEnabled = false

// 启用 OpenAI API
AIConfig.shared.isOpenAIEnabled = true

// 重置为默认值
AIConfig.shared.resetToDefault()

// 查看当前状态
AIConfig.shared.printConfig()
```

**优点**：
- 不需要重新编译
- 可以在运行时动态切换
- 配置会保存到 UserDefaults

### 行为说明

#### 当 `isOpenAIEnabled = false` 时：

1. **AI行程生成会被禁用**
   - `AITripGenerator.generateAIItinerary()` 会抛出 `AITripGenerationError.openAIDisabled` 错误
   - 不会调用 OpenAI API，**不会产生任何费用**

2. **自动回退到基础生成器**
   - `AIPlannerView` 会捕获错误
   - 自动使用 `PlanGenerator.shared.generatePlan()` 生成基础行程
   - 用户会看到提示："⚠️ AI功能已禁用，已生成基础行程模板"

3. **基础行程特点**
   - 使用模板化的活动名称（如"景点参观"、"文化体验"）
   - 不包含真实地点名称
   - 时间规划仍然正确
   - 可以正常添加到日历

#### 当 `isOpenAIEnabled = true` 时：

1. **正常使用 OpenAI API**
   - 调用 OpenAI API 生成高质量行程
   - 包含真实地点和详细描述
   - **会产生 API 费用**

### 使用场景

**场景 1：日常开发测试**
```swift
// 在 AIConfig.swift 中
private let defaultOpenAIEnabled = false  // 测试时禁用
```

**场景 2：演示前临时启用**
```swift
// 在演示前临时启用
AIConfig.shared.isOpenAIEnabled = true
```

**场景 3：生产环境**
```swift
// 在 AIConfig.swift 中
private let defaultOpenAIEnabled = true  // 生产环境启用
```

---

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

---

## 工作原理

### 整体流程

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

### 1. 输入分类阶段（InputClassifier）

**文件**: `InputClassifier.swift`

**分类逻辑**:
- **A类（完整需求）**: 包含目的地、时间、意图至少2项 → 直接生成
- **B类（半需求）**: 有目的地或意图但缺少时间 → 默认值补齐后生成
- **C类（碎片输入）**: 信息不足 → 进入追问模式
- **D类（模板意图）**: 检测到模板关键词 → 切换到模板系统

**关键信息抽取（Slot Filling）**:
- 目的地（destination）
- 日期范围（dateRange）或天数（durationDays）
- 兴趣标签（interestTags）
- 节奏（pace）
- 步行强度（walkingLevel）
- 交通偏好（transportPreference）

### 2. 提示词构建阶段（AITripGenerator）

**文件**: `AITripGenerator.swift` → `buildPrompt()`

**提示词结构**:
```
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

### 3. OpenAI API 调用阶段（OpenAIManager）

**文件**: `OpenAIManager.swift` → `generateStructuredItinerary()`

**API 配置参数**:
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

**System Prompt（系统提示词）**:
```
你是一位专业的旅游行程规划师。你的任务是根据用户需求生成详细、有趣、实用的行程规划。
必须返回有效的JSON格式，包含真实存在的景点、餐厅等具体地点和详细地址。
所有地点都必须是真实存在的，描述要生动有趣，说明为什么好玩、值得去。
```

**关键控制点**:
1. **模型选择**: `gpt-4o`（高质量，支持长文本）
2. **Temperature**: `0.8`（提高创造性，让行程更有趣）
3. **Max Tokens**: `4000`（支持详细描述）
4. **System Prompt**: 明确角色和输出要求

### 4. 响应解析阶段（AITripGenerator）

**文件**: `AITripGenerator.swift` → `parseAIResponse()`

**JSON 结构要求**:
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

**解析流程**:
1. 提取 JSON（移除 markdown 代码块标记）
2. 修复常见 JSON 问题（尾随逗号等）
3. 解析为 `AITripPlan` 结构
4. 转换为 `PlanResult`（包含 TimeBlock）

### 5. 时间规划阶段（PlanGenerator）

**文件**: `PlanGenerator.swift` → `convertToPlanResult()`

**时间块转换规则**:
- **ACTIVITY**: AI 生成的活动 → 转换为 TimeBlock
- **TRANSIT**: 自动添加交通时间（30分钟）
- **BUFFER**: 自动添加缓冲时间（10分钟）
- **FLEX**: 确保每天至少1个弹性时间
- **REST**: 确保每天至少1个休息时间

**时间约束**:
- 连续活动 ≤ 2个
- 根据节奏调整活动数量
- 考虑开放时间（如果有）

### 6. 错误处理和回退机制

**错误处理流程**:
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

**回退条件**:
- API 调用失败
- JSON 解析失败
- 数据验证失败
- AI 功能被禁用

---

## 成本与配额

### 成本估算

#### gpt-4o（当前使用）
- **输入**：$2.50 / 1M tokens
- **输出**：$10.00 / 1M tokens
- 生成一个 3 天行程约消耗：
  - 输入：~1000 tokens ($0.0025)
  - 输出：~3000 tokens ($0.03)
  - **总计：约 $0.03-0.04**

#### gpt-3.5-turbo（备选）
- **输入**：$0.50 / 1M tokens
- **输出**：$1.50 / 1M tokens
- 生成一个 3 天行程约消耗：
  - 输入：~1000 tokens ($0.0005)
  - 输出：~3000 tokens ($0.0045)
  - **总计：约 $0.005**

#### gpt-4o-mini（推荐折中方案）
- **输入**：$0.15 / 1M tokens
- **输出**：$0.60 / 1M tokens
- 生成一个 3 天行程约消耗：
  - 输入：~1000 tokens ($0.00015)
  - 输出：~3000 tokens ($0.0018)
  - **总计：约 $0.002**

### 配额问题

#### 错误信息

```
❌ OpenAI API错误: You exceeded your current quota
```

这是一个 **HTTP 429** 错误，表示 API 配额已用完。

#### 问题原因

1. **API Key 的额度已用完**
   - 免费额度（$5）已用尽
   - 或付费额度已用完

2. **账户未绑定付款方式**
   - 免费额度用完后，需要绑定付款方式才能继续使用

3. **请求过于频繁**
   - 虽然这里是配额问题，但也可能是速率限制

#### 解决方案

**方案 1：检查账户余额（推荐）**

1. 访问 OpenAI 账户页面：https://platform.openai.com/account/billing
2. 查看：
   - **Usage**：查看使用量
   - **Billing**：查看账单和余额
   - **Payment methods**：检查付款方式
3. 如果余额不足，需要：
   - 绑定付款方式（信用卡）
   - 充值账户

**方案 2：更换 API Key**

1. 生成新的 API Key：https://platform.openai.com/api-keys
2. 更新 `Secrets.xcconfig` 中的 `OPENAI_API_KEY`
3. 重新构建项目

**方案 3：降低使用频率**

如果配额充足但仍遇到错误：
1. 检查是否是速率限制（Rate Limit）
2. 减少 API 调用频率
3. 使用缓存机制（暂未实现）

**方案 4：使用更便宜的模型（临时方案）**

可以临时改用 `gpt-3.5-turbo` 或 `gpt-4o-mini` 降低成本：

```swift
// 在 OpenAIManager.swift 中修改
"model": "gpt-3.5-turbo",  // 更便宜，但质量较低
// 或
"model": "gpt-4o-mini",    // gpt-4o 的轻量版，更便宜
```

**方案 5：临时禁用 AI 功能**

如果暂时无法充值，可以禁用 AI 功能，使用基础生成器：

```swift
AIConfig.shared.isOpenAIEnabled = false
```

#### 预防措施

1. **设置使用限制**：在 OpenAI 账户中设置使用限额
2. **监控使用量**：定期检查使用情况
3. **使用更便宜的模型**：对于简单场景，使用 `gpt-3.5-turbo` 或 `gpt-4o-mini`
4. **实现缓存机制**：避免重复生成相同行程
5. **测试时禁用**：开发测试时禁用 AI 功能以节省费用

---

## 常见问题

**Q: 如何确认 OpenAI API 已被禁用？**

A: 查看控制台日志，会显示 "⚠️ [AITripGenerator] OpenAI API 已禁用" 和 "⚠️ [AI生成] OpenAI 已禁用，回退到基础生成器"

**Q: 禁用后还能生成行程吗？**

A: 可以，但会使用基础生成器，生成的是模板化行程，质量较低。

**Q: 如何永久禁用（适合长期测试）？**

A: 修改 `AIConfig.swift` 中的 `defaultOpenAIEnabled = false`，并重新编译。

**Q: 如何在运行时临时启用？**

A: 在代码中调用 `AIConfig.shared.isOpenAIEnabled = true`，配置会保存到 UserDefaults。

**Q: 如何降低 API 成本？**

A: 
1. 使用更便宜的模型（`gpt-3.5-turbo` 或 `gpt-4o-mini`）
2. 测试时禁用 AI 功能
3. 实现缓存机制避免重复生成

---

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
4. 是否启用了 AI 功能（`AIConfig.shared.isOpenAIEnabled`）

### 问题：生成的行程不够详细

**调整**：
- 在 `AITripGenerator.swift` 的 `buildPrompt` 方法中增加更详细的提示词要求
- 调整 `temperature` 参数（0.8-1.0 更创造性）
- 增加 `max_tokens` 以支持更详细的描述

### 问题：配额超限

**解决**：
1. 检查账户余额和付款方式
2. 更换 API Key
3. 使用更便宜的模型
4. 临时禁用 AI 功能

---

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

---

## 优化建议

1. **主題專屬提示詞**：每個主題（如寵物餵養）擁有自己的 `aiPromptPrefix`，存 Firebase，避免偏題（如寵物主題→天安門旅遊）✅ 已實作
2. **缓存机制**: 缓存常用目的地的行程，减少 API 调用
3. **流式输出**: 使用 streaming API 提供实时反馈
4. **上下文记忆**: 在对话中保持上下文，支持"修改行程"等操作
5. **多模型支持**: 根据复杂度选择不同模型（简单用 3.5，复杂用 4o）
6. **提示词模板**: 为不同场景准备不同的提示词模板（ThemePromptService 已支援 Firebase 同步）
7. **用户反馈**: 收集用户对行程的评价，优化提示词
8. **地图集成**: 将生成的地点显示在地图上
9. **预算估算**: 根据价格级别估算行程总预算
10. **時間型態擴展**: 從「多階段型」擴展至區間可選、彈性任務、撮合等型態（見 TIME_ENGINE_ARCHITECTURE.md）

---

## 相关链接

- OpenAI 账户页面：https://platform.openai.com/account
- 账单页面：https://platform.openai.com/account/billing
- API Keys：https://platform.openai.com/api-keys
- 使用量统计：https://platform.openai.com/usage
- 错误代码文档：https://platform.openai.com/docs/guides/error-codes

---

**最后更新**: 2025-02-25  
**维护者**: Secalender 开发团队  
**相關文件**: [TIME_ENGINE_ARCHITECTURE.md](./TIME_ENGINE_ARCHITECTURE.md) - 時間引擎架構與實作路線
