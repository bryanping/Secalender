# AI功能配置开关使用指南

## 概述

`AIConfig` 提供了一个简单的代码开关，用于控制是否使用 OpenAI API 生成行程。这可以在测试时节省 API 流量和费用。

## 快速开始

### 方法 1：修改代码默认值（推荐用于测试）

编辑 `Secalender/Core/AIgeneration/AIConfig.swift`：

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

## 行为说明

### 当 `isOpenAIEnabled = false` 时：

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

### 当 `isOpenAIEnabled = true` 时：

1. **正常使用 OpenAI API**
   - 调用 OpenAI API 生成高质量行程
   - 包含真实地点和详细描述
   - **会产生 API 费用**

## 使用场景

### 场景 1：日常开发测试

```swift
// 在 AIConfig.swift 中
private let defaultOpenAIEnabled = false  // 测试时禁用
```

这样可以：
- 快速测试 UI 和功能
- 不需要等待 API 响应
- 不产生任何费用
- 避免配额用尽

### 场景 2：演示前临时启用

```swift
// 在演示前临时启用
AIConfig.shared.isOpenAIEnabled = true
```

### 场景 3：生产环境

```swift
// 在 AIConfig.swift 中
private let defaultOpenAIEnabled = true  // 生产环境启用
```

## 检查配置状态

### 在代码中检查

```swift
if AIConfig.shared.isOpenAIEnabled {
    print("✅ OpenAI API 已启用")
} else {
    print("❌ OpenAI API 已禁用")
}
```

### 查看调试日志

应用启动时会在控制台打印配置状态（仅在 DEBUG 模式下）：

```
📊 [AIConfig] AI 配置状态：
- OpenAI API: ✅ 启用 / ❌ 禁用
- 默认值: 启用 / 禁用
```

## 注意事项

1. **默认值优先级**
   - 如果从未通过代码设置过 `isOpenAIEnabled`，使用 `defaultOpenAIEnabled`
   - 如果通过代码设置过，会保存在 UserDefaults 中，优先级更高

2. **重置配置**
   - 调用 `AIConfig.shared.resetToDefault()` 会清除 UserDefaults 中的设置
   - 之后会使用 `defaultOpenAIEnabled` 的值

3. **基础生成器限制**
   - 基础生成器生成的行程质量较低
   - 不包含真实地点名称
   - 仅适合功能测试

4. **错误处理**
   - 当 OpenAI 禁用时，会自动回退到基础生成器
   - 不会显示错误提示给用户
   - 仅在控制台输出警告日志

## 文件位置

- **配置文件**：`Secalender/Core/AIgeneration/AIConfig.swift`
- **使用位置**：`Secalender/Core/AIgeneration/AITripGenerator.swift`
- **错误处理**：`Secalender/Views/AIPlannerView.swift`

## 示例代码

### 完整的配置切换示例

```swift
// 在 AppDelegate 或 SceneDelegate 中
func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    
    #if DEBUG
    // 调试模式：禁用 OpenAI API
    AIConfig.shared.isOpenAIEnabled = false
    #else
    // 生产模式：启用 OpenAI API
    AIConfig.shared.isOpenAIEnabled = true
    #endif
    
    return true
}
```

### 根据环境变量配置

```swift
// 在 AIConfig.swift 中
private let defaultOpenAIEnabled: Bool = {
    // 从环境变量读取（如果有）
    if let envValue = ProcessInfo.processInfo.environment["ENABLE_OPENAI"] {
        return envValue.lowercased() == "true"
    }
    // 默认值
    return true
}()
```

## 常见问题

**Q: 如何确认 OpenAI API 已被禁用？**

A: 查看控制台日志，会显示 "⚠️ [AITripGenerator] OpenAI API 已禁用" 和 "⚠️ [AI生成] OpenAI 已禁用，回退到基础生成器"

**Q: 禁用后还能生成行程吗？**

A: 可以，但会使用基础生成器，生成的是模板化行程，质量较低。

**Q: 如何永久禁用（适合长期测试）？**

A: 修改 `AIConfig.swift` 中的 `defaultOpenAIEnabled = false`，并重新编译。

**Q: 如何在运行时临时启用？**

A: 在代码中调用 `AIConfig.shared.isOpenAIEnabled = true`，配置会保存到 UserDefaults。
