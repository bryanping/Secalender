# Secalender 文档索引

本文档是 Secalender 项目所有说明文档和待办文档的完整索引，帮助快速定位所需信息。

---

## 📋 目录

1. [快速导航](#快速导航)
2. [项目概览文档](#项目概览文档)
3. [配置与设置文档](#配置与设置文档)
4. [功能说明文档](#功能说明文档)
5. [架构设计文档](#架构设计文档)
6. [问题解决文档](#问题解决文档)
7. [测试与调试文档](#测试与调试文档)
8. [待办事项文档](#待办事项文档)
9. [多语言支持](#多语言支持)

---

## 🚀 快速导航

### 新手入门
- **[README.md](./README.md)** - 项目主文档，包含功能概览、安装配置、使用说明、数据库架构概览

### 配置指南
- **[GOOGLE_MAPS_GUIDE.md](./GOOGLE_MAPS_GUIDE.md)** - Google Maps 和 Google Places SDK 完整配置指南
- **[AI_GUIDE.md](./AI_GUIDE.md)** - AI 行程生成功能完整指南（配置、使用、成本、故障排除）

### 遇到问题？
- **[test_event_creation.md](./test_event_creation.md)** - 事件创建测试指南

---

## 📖 项目概览文档

### README.md
**路径**: `Secalender/README.md`

**内容**:
- 项目简介和主要功能
- 主要导航结构
- 已完成的页面清单
- 待完善的功能
- 项目结构
- 安装和配置步骤
- 技术栈说明
- 开发进度

**适用场景**: 
- 新成员了解项目
- 查看项目整体功能
- 了解开发进度

---

## ⚙️ 配置与设置文档

### 1. GOOGLE_MAPS_GUIDE.md
**路径**: `Secalender/GOOGLE_MAPS_GUIDE.md`

**内容**:
- Google Maps SDK 和 Google Places SDK 完整配置指南
- SPM 安装方式说明
- API Key 配置方法
- 地图组件迁移说明
- 搜索功能迁移说明
- 字体警告说明和解决方案
- 常见问题（REQUEST_DENIED 错误等）

**适用场景**:
- 首次配置 Google Maps
- 迁移到 Google Maps
- 解决 API Key 授权问题
- 了解字体警告和处理方法

---

### 2. AI_GUIDE.md
**路径**: `Secalender/AI_GUIDE.md`

**内容**:
- AI 行程生成功能完整指南
- 配置步骤和 API Key 设置
- AI 功能配置开关使用方法
- 使用流程和工作原理
- 成本估算和配额管理
- 常见问题和故障排除

**适用场景**:
- 配置 AI 行程生成功能
- 了解 AI 生成机制
- 解决配额和成本问题
- 测试时禁用 AI 功能

---

### 3. GOOGLE_SIGNIN_VERSION.md
**路径**: `Secalender/GOOGLE_SIGNIN_VERSION.md`

**内容**:
- GoogleSignIn 5.x vs 6.x 版本差异
- 当前配置说明
- 升级指南

**适用场景**:
- 选择 GoogleSignIn 版本
- 升级到新版本

---

### 4. AI_CONFIG_GUIDE.md
**路径**: `Secalender/AI_CONFIG_GUIDE.md`

**内容**:
- AI 功能配置开关使用方法
- 禁用/启用 OpenAI API 的方法
- 运行时配置和代码配置
- 行为说明和使用场景

**适用场景**:
- 测试时禁用 AI 功能节省费用
- 配置 AI 功能开关

---

## 🎯 功能说明文档


### 3. PAGE_INVENTORY.md
**路径**: `Secalender/PAGE_INVENTORY.md`

**内容**:
- 所有已实现页面的详细清单
- 主要 Tab 页面说明
- 事件相关页面
- 朋友和社群功能页面
- 分享功能页面
- 用户功能页面
- 核心功能模块
- 待实现页面

**适用场景**:
- 查找特定页面实现
- 了解项目页面结构
- 规划新功能开发

---

### 4. EVENT_SHARE_VISIBILITY_RULES.md
**路径**: `Secalender/EVENT_SHARE_VISIBILITY_RULES.md`

**内容**:
- 事件分享可见性规则
- 观看者身份优先级
- 可见性判定逻辑
- 权限与功能说明
- 参与状态管理
- UI 显示规则
- 颜色规则统一标准

**适用场景**:
- 实现事件分享功能
- 理解分享权限逻辑
- 修复分享相关问题

---

### 5. MODEL_ARCHITECTURE_ANALYSIS.md
**路径**: `Secalender/MODEL_ARCHITECTURE_ANALYSIS.md`

**内容**:
- 数据模型架构分析
- Template vs SavedTripTemplate vs Event 的区别
- 潜在问题和建议方案
- 当前状态说明

**适用场景**:
- 理解数据模型设计
- 解决模型命名混淆
- 规划数据转换逻辑

---

## 🏗️ 架构设计文档

### 1. DATABASE_ARCHITECTURE.md
**路径**: `docs/DATABASE_ARCHITECTURE.md`

**内容**:
- 数据库架构总览
- Web 服务数据库（PostgreSQL）表结构
- Firebase（Firestore）集合结构
- 数据所有权矩阵
- 整合流程
- 迁移计划

**适用场景**:
- 了解数据库架构设计
- 实施新功能时参考数据结构
- 规划数据迁移

---

### 2. FIRESTORE_RULES.md
**路径**: `docs/FIRESTORE_RULES.md`

**内容**:
- Firestore Security Rules 完整规则
- 规则说明和索引需求
- 安全性最佳实践

**适用场景**:
- 配置 Firestore 安全规则
- 理解数据访问权限
- 部署安全规则

---

### 3. WEB_API_INTEGRATION.md
**路径**: `docs/WEB_API_INTEGRATION.md`

**内容**:
- Web API 整合指南
- Firebase Admin SDK 设定
- 认证中间件
- API 端点范例（Node.js / Python）
- 购买流程整合

**适用场景**:
- 开发 Web API
- 整合 Firebase Auth
- 实现购买流程

---

## 🔧 问题解决文档

> **注意**: OpenAI 配额问题和 Google Maps 字体警告已整合到对应的配置指南中：
> - OpenAI 配额问题 → 见 [AI_GUIDE.md](./AI_GUIDE.md) 的"成本与配额"章节
> - Google Maps 字体警告 → 见 [GOOGLE_MAPS_GUIDE.md](./GOOGLE_MAPS_GUIDE.md) 的"字体警告说明"章节

---

### 3. test_event_creation.md
**路径**: `Secalender/test_event_creation.md`

**内容**:
- 事件创建功能测试指南
- 问题诊断和修复
- 测试步骤
- 预期结果

**适用场景**:
- 测试事件创建功能
- 调试事件创建问题

---

## ✅ 待办事项文档

### TODO.md
**路径**: `docs/TODO.md`

**内容**:
- 数据库架构实施 TODO 清单
- Phase 1: 基础架构（MVP）
- Phase 2: 进阶功能
- Phase 3: 运营功能
- 技术债务与优化
- 里程碑规划

**适用场景**:
- 查看待办任务
- 规划开发进度
- 跟踪实施状态

---

## 🌍 多语言支持

### Multilingual 目录
**路径**: `Secalender/Multilingual/`

**结构**:
```
Multilingual/
├── de.lproj/          # 德语
├── en.lproj/          # 英语
├── es.lproj/          # 西班牙语
├── fr.lproj/          # 法语
├── ja.lproj/          # 日语
├── zh-Hans.lproj/     # 简体中文
└── zh-Hant.lproj/     # 繁体中文
```

**内容**:
- 所有 UI 文本的本地化字符串
- 按功能模块组织（Tab Bar、AI Planner、Settings 等）
- 支持 7 种语言

**适用场景**:
- 添加新的本地化字符串
- 修改现有翻译
- 添加新语言支持

---

## 📚 文档分类总结

### 按用途分类

| 用途 | 文档 |
|------|------|
| **新手入门** | README.md, AI_TRIP_GENERATOR_SETUP.md |
| **配置指南** | GOOGLE_MAPS_SETUP.md, SPM_GOOGLE_PLACES_SETUP.md, AI_CONFIG_GUIDE.md |
| **功能说明** | PAGE_INVENTORY.md, EVENT_SHARE_VISIBILITY_RULES.md, OPENAI_TRIP_PLANNING_MECHANISM.md |
| **架构设计** | DATABASE_ARCHITECTURE.md, FIRESTORE_RULES.md, WEB_API_INTEGRATION.md |
| **问题解决** | OPENAI_QUOTA_ISSUE.md, GOOGLE_MAPS_FONT_WARNING.md, test_event_creation.md |
| **待办事项** | TODO.md |

### 按优先级分类

| 优先级 | 文档 |
|--------|------|
| **必读** | README.md, DATABASE_ARCHITECTURE.md |
| **重要** | GOOGLE_MAPS_GUIDE.md, AI_GUIDE.md, EVENT_SHARE_VISIBILITY_RULES.md |
| **参考** | PAGE_INVENTORY.md, MODEL_ARCHITECTURE_ANALYSIS.md |
| **问题排查** | AI_GUIDE.md（配额问题）, GOOGLE_MAPS_GUIDE.md（字体警告）, test_event_creation.md |

---

## 🔍 快速查找指南

### 我想...

- **了解项目整体情况** → 阅读 `README.md`
- **配置 Google Maps** → 阅读 `GOOGLE_MAPS_GUIDE.md`
- **配置 AI 功能** → 阅读 `AI_GUIDE.md`
- **理解数据库架构** → 阅读 `docs/DATABASE_ARCHITECTURE.md`
- **查看所有页面清单** → 阅读 `PAGE_INVENTORY.md`
- **理解事件分享规则** → 阅读 `EVENT_SHARE_VISIBILITY_RULES.md`
- **解决 OpenAI 配额问题** → 阅读 `AI_GUIDE.md` 的"成本与配额"章节
- **查看待办任务** → 阅读 `docs/TODO.md`
- **开发 Web API** → 阅读 `docs/WEB_API_INTEGRATION.md`
- **配置 Firestore 规则** → 阅读 `docs/FIRESTORE_RULES.md`

---

## 📝 文档维护说明

### 文档更新原则

1. **及时更新**: 功能变更时同步更新相关文档
2. **保持准确**: 确保文档内容与实际代码一致
3. **分类清晰**: 按用途和优先级分类
4. **易于查找**: 提供快速导航和索引

### 文档位置规范

- **项目级文档**: 放在 `Secalender/` 根目录
- **架构设计文档**: 放在 `docs/` 目录
- **多语言资源**: 放在 `Secalender/Multilingual/` 目录

---

## 🔗 相关资源

### 外部文档链接

- [Firebase 文档](https://firebase.google.com/docs)
- [Google Maps Platform](https://developers.google.com/maps/documentation)
- [OpenAI API 文档](https://platform.openai.com/docs)
- [PostgreSQL 文档](https://www.postgresql.org/docs/)

---

**最后更新**: 2025-01-XX  
**维护者**: Secalender 开发团队
