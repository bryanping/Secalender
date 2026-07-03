# Google Maps 集成配置完整指南

本文档包含 Google Maps SDK 和 Google Places SDK 的完整配置指南，包括安装、配置、常见问题和故障排除。

---

## 📋 目录

1. [概述](#概述)
2. [安装依赖](#安装依赖)
3. [配置 API Key](#配置-api-key)
4. [主要改动](#主要改动)
5. [常见问题](#常见问题)
6. [字体警告说明](#字体警告说明)
7. [SPM 配置说明](#spm-配置说明)

---

## 概述

`LocationPickerView` 已从 MapKit 迁移到 Google Maps，以支持国外定位和搜索功能。

### 使用的 SDK

- **Google Maps SDK for iOS** - 地图显示和交互
- **Google Places SDK for iOS** - 地点搜索和自动完成
- **Geocoding API** - 地址解析和反向地理编码

### 安装方式

项目使用 **Swift Package Manager (SPM)** 安装 Google Maps 和 Google Places SDK，这是官方推荐的方式。

---

## 安装依赖

### 1. SPM 配置（推荐）

项目已通过 SPM 安装以下依赖：

- ✅ `GoogleMaps` - 来自 `ios-maps-sdk`（官方仓库）
- ✅ `GooglePlaces` - 来自 `ios-places-sdk`（官方仓库）

**优势**:
- 官方支持，直接来自 Google 官方仓库
- 最新版本，可以获取最新功能和修复
- 统一管理，与 `ios-maps-sdk` 使用相同的安装方式
- 减少依赖，不需要通过 CocoaPods 安装

### 2. CocoaPods 配置（已弃用）

`Podfile` 中的 Google Maps 和 Google Places 已注释掉，现在通过 SPM 安装。

### 3. 版本要求

- ✅ Xcode 16.0 或更高版本
- ✅ iOS 16.0 或更高版本（项目当前为 iOS 17.5，满足要求）

### 4. 验证安装

安装完成后，检查：
1. Xcode 项目中的 **Package Dependencies** 应显示 `ios-maps-sdk` 和 `ios-places-sdk`
2. 代码中的 `import GoogleMaps` 和 `import GooglePlaces` 应该能正常编译
3. 运行项目，测试地图显示和地点搜索功能

---

## 配置 API Key

### 1. 获取 Google Maps API Key

1. 访问 [Google Cloud Console](https://console.cloud.google.com/)
2. 创建新项目或选择现有项目
3. 启用以下 API：
   - **Maps SDK for iOS** ✅ 必需
   - **Places API (New)** ✅ 必需（用于搜索和自动完成）
   - **Geocoding API** ✅ 必需（用于反向地理编码）
4. 创建 API Key：
   - 进入 "APIs & Services" > "Credentials"
   - 点击 "Create Credentials" > "API Key"
   - **重要**：配置应用限制为 **iOS 应用**
     - 选择 "iOS apps"
     - 添加你的 Bundle ID（例如：`com.yourcompany.Secalender`）
   - 或者暂时移除限制（仅用于测试，不推荐用于生产环境）

### 2. 配置 API Key

**推荐方式：通过 Secrets.xcconfig（已配置）**

项目已配置使用 `Secrets.xcconfig` 来管理 API Key，这是最安全的方式。

1. 打开 `Config/Secrets.xcconfig` 文件
2. 确保 `GOOGLE_MAPS_API_KEY` 已设置：
```bash
GOOGLE_MAPS_API_KEY = YOUR_GOOGLE_MAPS_API_KEY
```

3. 确保 `Info.plist` 中包含：
```xml
<key>GOOGLE_MAPS_API_KEY</key>
<string>$(GOOGLE_MAPS_API_KEY)</string>
```

4. 确保 Xcode 项目 Build Settings 中引用了 `Secrets.xcconfig`

**备用方式：通过 GoogleService-Info.plist**

如果 `Secrets.xcconfig` 未正确配置，系统会尝试从 `GoogleService-Info.plist` 读取：
```xml
<key>API_KEY</key>
<string>YOUR_GOOGLE_MAPS_API_KEY</string>
```

**调试方式：通过环境变量**

设置环境变量（仅用于调试）：
```bash
export GOOGLE_MAPS_API_KEY="YOUR_GOOGLE_MAPS_API_KEY"
```

### 3. 初始化

API Key 会在 `AppDelegate` 的 `application(_:didFinishLaunchingWithOptions:)` 中自动初始化。

**优先级顺序：**
1. Info.plist（从 Secrets.xcconfig 传递）✅ **推荐**
2. GoogleService-Info.plist（备用）
3. 环境变量（调试用）

---

## 主要改动

### 地图组件
- 从 `MapKit.Map` 替换为 `GoogleMapView`（自定义 SwiftUI 包装器）
- 使用 `GMSCameraPosition` 控制地图位置和缩放

### 搜索功能
- 从 `MKLocalSearch` 替换为 `GooglePlacesManager`
- 从 `MKLocalSearchCompleter` 替换为 `GooglePlacesAutocompleteManager`
- 支持全球搜索，不再局限于特定地区

### 地理编码
- 从 `CLGeocoder` 替换为 Google Geocoding API
- 支持全球地址解析

### 数据类型
- `MKMapItem` → `GooglePlaceResult`
- `MKLocalSearchCompletion` → `GooglePlaceAutocomplete`
- `MKCoordinateRegion` → `CLLocationCoordinate2D` + `GMSCameraPosition`

---

## 常见问题

### REQUEST_DENIED 错误

如果遇到 `REQUEST_DENIED` 错误，表示 API Key 未正确配置应用限制。

**错误信息示例：**
```
REQUEST_DENIED: This IP, site or mobile application is not authorized to use this API key.
```

**解决方法：**

1. **检查 API Key 的应用限制设置**
   - 进入 Google Cloud Console > APIs & Services > Credentials
   - 找到你的 API Key，点击编辑
   - 在 "Application restrictions" 中选择 "iOS apps"
   - 添加你的 Bundle ID（例如：`com.yourcompany.Secalender`）
   - 保存更改

2. **检查是否启用了必要的 API**
   - Maps SDK for iOS
   - Places API (New)
   - Geocoding API

3. **等待配置生效**
   - API Key 配置更改可能需要几分钟才能生效
   - 如果问题持续，尝试重新启动应用

4. **临时解决方案（仅用于测试）**
   - 在 API Key 设置中，将 "Application restrictions" 改为 "None"
   - ⚠️ **警告**：这会使 API Key 不安全，仅用于测试，不要用于生产环境

### 功能限制

由于 API Key 授权问题，以下功能已暂时禁用或简化：

- **附近POI搜索**：已暂时禁用，避免授权错误
- **反向地理编码**：使用 Geocoding API，需要正确配置 API Key

---

## 字体警告说明

### 警告信息

```
GSFont: file already registered - " file:///.../GoogleMaps.bundle/GMSCoreResources.bundle/Tharlon-Regular.ttf "
GSFont: file already registered - " file:///.../GoogleMaps.bundle/GMSCoreResources.bundle/DroidSansMerged-Regular.ttf "
```

### 原因

这个警告出现是因为：
1. 项目同时使用了 **Swift Package Manager (SPM)** 的 `GoogleMaps` 和 `GooglePlaces`
2. 这两个 SDK 都包含了相同的字体资源文件
3. iOS 系统检测到字体文件被重复注册

### 影响

⚠️ **这个警告不影响应用功能**，只是控制台输出信息。字体仍然可以正常使用。

### 解决方案

**方案 1: 忽略警告（推荐）**

这是最安全的方案，因为：
- 警告不影响功能
- 字体资源是 Google Maps SDK 正常工作所需的
- 移除或修改可能导致 SDK 功能异常

**方案 2: 在 Info.plist 中抑制警告（不推荐）**

如果确实需要抑制警告，可以在 `Info.plist` 中添加：

```xml
<key>UIAppFonts</key>
<array>
    <!-- 不推荐：可能导致字体加载问题 -->
</array>
```

⚠️ **不推荐此方案**，因为可能影响 Google Maps SDK 的正常工作。

**方案 3: 检查依赖配置**

确保没有重复的依赖：
- ✅ 使用 SPM 的 `GoogleMaps` 和 `GooglePlaces`（官方仓库）
- ❌ 不要同时使用 CocoaPods 的 `GoogleMaps` 和 `GooglePlaces`

当前配置：
- ✅ `GoogleMaps` 通过 SPM 安装（官方仓库）
- ✅ `GooglePlaces` 通过 SPM 安装（官方仓库 `ios-places-sdk`）
- ✅ `Podfile` 中已注释掉 CocoaPods 的 GoogleMaps 和 GooglePlaces

### 结论

**建议忽略此警告**，它不会影响应用功能。如果警告信息过多，可以在 Xcode 的 Scheme 设置中过滤掉这些日志。

---

## SPM 配置说明

### 使用官方 Google Places SDK (SPM)

项目已配置使用 Google 官方的 [ios-places-sdk](https://github.com/googlemaps/ios-places-sdk) 仓库，通过 Swift Package Manager (SPM) 安装，替代 CocoaPods 的 `GooglePlaces`。

### 已完成的配置

1. ✅ **Package Reference** - 已添加 `ios-places-sdk` 仓库引用
   - 仓库 URL: `https://github.com/googlemaps/ios-places-sdk`
   - 版本要求: `9.2.0` 或更高

2. ✅ **Product Dependency** - 已添加 `GooglePlaces` 产品依赖
   - 已添加到 target 的 `packageProductDependencies`
   - 已添加到 Frameworks build phase

3. ✅ **Podfile 更新** - 已注释掉 `pod 'GooglePlaces'`
   - 现在通过 SPM 安装，不再需要 CocoaPods

### 代码兼容性

代码完全兼容，无需修改：
- `GMSPlacesClient` ✅
- `GMSAutocompleteFilter` ✅
- `GMSPlaceField` ✅
- 所有现有 API 调用 ✅

### 注意事项

1. **混合使用 CocoaPods 和 SPM** - 项目同时使用两种依赖管理方式，这是正常的
2. **版本同步** - 确保 SPM 的 `GooglePlaces` 版本与 `GoogleMaps` 兼容
3. **API Key** - 仍然需要配置 Google Maps API Key（已在 `Secrets.xcconfig` 中配置）

---

## 注意事项

1. **API 配额**：Google Maps API 有使用配额限制，请注意控制调用频率
2. **费用**：Google Maps API 按使用量收费，请查看 [定价页面](https://cloud.google.com/maps-platform/pricing)
3. **API Key 安全**：确保 API Key 设置了 iOS 应用限制（Bundle ID），避免被滥用
4. **HTTP 请求限制**：直接使用 HTTP 请求调用 Google APIs 需要 API Key 配置为允许 iOS 应用使用

---

## 测试

配置完成后，测试以下功能：
- ✅ 地图显示和拖动
- ✅ 搜索地点（国内外）
- ✅ 自动建议功能
- ✅ 反向地理编码（坐标转地址）
- ✅ 附近POI推荐

---

## 相关文档

- [Google Maps Platform iOS SDK](https://developers.google.com/maps/documentation/ios-sdk)
- [Google Places SDK for iOS](https://developers.google.com/maps/documentation/places/ios-sdk)
- [Google Maps Platform 定价](https://cloud.google.com/maps-platform/pricing)

---

**最后更新**: 2025-01-XX  
**维护者**: Secalender 开发团队
