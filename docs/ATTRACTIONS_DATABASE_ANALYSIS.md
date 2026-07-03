# 周边景点数据库方案分析

## 📋 目录

1. [需求分析](#需求分析)
2. [现有可做线上数据库的内容](#现有可做线上数据库的内容)
3. [技术方案对比](#技术方案对比)
4. [推荐方案](#推荐方案)
5. [数据结构设计](#数据结构设计)
6. [实施步骤](#实施步骤)

---

## 🎯 需求分析

### 核心需求
1. **用户搜索周边景点**：用户可以通过搜索找到周边景点
2. **用户添加新景点**：用户可以选择或添加新的周边景点到数据库
3. **数据共享**：用户添加的景点可以被其他用户搜索和使用
4. **数据验证**：确保添加的景点数据质量
5. **数据去重**：避免重复添加相同景点

### 使用场景
- **BlockEditView**：用户在编辑行程时，搜索并选择周边特色
- **AIPlannerView**：AI生成行程时，从数据库获取周边景点
- **用户贡献**：用户发现新景点后，可以添加到数据库供他人使用

---

## 📦 现有可做线上数据库的内容

### 1. 城市景点数据（CityAttractionsDatabase）

**当前状态**：
- 本地硬编码数据（75个热门城市，每个城市8个景点）
- 存储在 `CityAttractionsDatabase.swift` 中
- 数据结构：`CityAttraction`

**可迁移内容**：
```swift
public struct CityAttraction: Codable, Identifiable, Hashable {
    public let id: String
    public let name: String
    public let category: String  // 分类：地标、景点、美食、文化等
    public let icon: String
    public let coordinate: CLLocationCoordinate2D?
    public let popularity: Int  // 热门程度（0-100）
    public let tags: [String]  // 标签：美食、历史、自然、购物、艺术等
}
```

**数据量**：
- 约 600 个景点（75个城市 × 8个景点）
- 每个景点包含：名称、分类、图标、坐标、热门度、标签

### 2. 用户搜索/选择的景点（SurroundingAttraction）

**当前状态**：
- 从 OpenAI API 动态获取
- 用户选择后用于替换行程中的 Block
- 数据结构：`SurroundingAttraction`

**可存储内容**：
```swift
struct SurroundingAttraction: Identifiable, Hashable {
    let id: String
    let name: String
    let category: String
    let icon: String
}
```

**数据特点**：
- 用户搜索频率高
- 可能包含用户自定义位置（通过地图选择器）
- 需要与城市关联

### 3. 用户自定义位置

**当前状态**：
- 通过 `LocationPickerView` 选择
- 存储地址字符串和坐标
- 用户可编辑标题和描述

**可存储内容**：
- 地址（String）
- 坐标（CLLocationCoordinate2D）
- 用户自定义标题
- 用户自定义描述

### 4. 城市-景点关联数据

**当前状态**：
- 硬编码在 `CityAttractionsDatabase` 中
- 通过 `attractionsByCity` 字典存储

**可存储内容**：
- 城市名称（标准化）
- 国家名称（可选）
- 景点列表
- 关联关系

---

## ⚖️ 技术方案对比

### 方案一：Firebase Firestore

#### ✅ 优点
1. **已集成**：项目已使用 Firebase（用户数据、事件、好友等）
2. **实时同步**：支持实时数据同步，用户体验好
3. **离线支持**：Firestore 支持离线缓存
4. **权限控制**：Firestore Security Rules 可以精细控制读写权限
5. **扩展性**：自动扩展，无需管理服务器
6. **成本**：免费额度充足（50K 读/天，20K 写/天）
7. **开发速度**：无需搭建后端，快速上线

#### ❌ 缺点
1. **查询限制**：复杂查询能力有限（如全文搜索需要额外服务）
2. **成本增长**：数据量大时成本可能较高
3. **数据迁移**：如果未来需要迁移，可能较复杂
4. **全文搜索**：需要集成 Algolia 或 Elasticsearch

#### 适用场景
- ✅ 用户贡献内容（UGC）
- ✅ 实时数据同步
- ✅ 快速迭代开发
- ✅ 中小型数据量（< 100万条）

### 方案二：自建服务器（PostgreSQL + REST API）

#### ✅ 优点
1. **查询能力**：强大的 SQL 查询和全文搜索
2. **数据控制**：完全控制数据存储和访问
3. **成本可控**：长期使用成本可能更低
4. **灵活性**：可以自定义复杂的业务逻辑
5. **数据迁移**：更容易迁移和备份

#### ❌ 缺点
1. **开发成本**：需要开发后端 API
2. **运维成本**：需要维护服务器、数据库、备份等
3. **扩展性**：需要手动处理扩展问题
4. **实时性**：需要额外开发 WebSocket 或轮询机制
5. **离线支持**：需要额外开发离线缓存机制

#### 适用场景
- ✅ 复杂查询需求
- ✅ 大数据量（> 100万条）
- ✅ 需要全文搜索
- ✅ 有后端开发团队

### 方案三：混合方案（Firebase + 自建服务器）

#### 架构
- **Firebase Firestore**：存储用户贡献的景点（UGC）
- **PostgreSQL（Web服务）**：存储官方景点数据（PGC）
- **同步机制**：定期将高质量 UGC 同步到 PostgreSQL

#### ✅ 优点
1. **最佳实践**：结合两者优势
2. **数据分层**：官方数据与用户数据分离
3. **性能优化**：官方数据用 PostgreSQL 支持复杂查询
4. **用户贡献**：UGC 用 Firebase 快速上线

#### ❌ 缺点
1. **复杂度**：需要维护两套系统
2. **同步成本**：需要开发数据同步机制
3. **开发成本**：需要开发后端 API

---

## 🏆 推荐方案

### 推荐：**Firebase Firestore（方案一）**

#### 推荐理由

1. **项目现状匹配**
   - ✅ 已使用 Firebase（用户、事件、好友等）
   - ✅ 无需引入新技术栈
   - ✅ 团队已熟悉 Firebase

2. **需求匹配**
   - ✅ 用户贡献内容（UGC）适合 Firestore
   - ✅ 实时同步提升用户体验
   - ✅ 数据量适中（预计 < 10万条）

3. **开发效率**
   - ✅ 无需开发后端 API
   - ✅ 快速上线验证
   - ✅ 降低开发成本

4. **成本考虑**
   - ✅ Firebase 免费额度充足
   - ✅ 初期成本低
   - ✅ 按需付费，可预测

5. **扩展性**
   - ✅ 未来如需复杂查询，可集成 Algolia
   - ✅ 如需迁移，数据可导出

#### 实施建议

**阶段一：MVP（最小可行产品）**
- 使用 Firebase Firestore 存储用户贡献的景点
- 保留本地 `CityAttractionsDatabase` 作为默认数据
- 实现基本的搜索和添加功能

**阶段二：优化**
- 将本地数据迁移到 Firestore
- 实现数据去重和验证机制
- 添加数据质量评分

**阶段三：扩展（如需要）**
- 集成 Algolia 实现全文搜索
- 添加数据审核机制
- 实现数据同步到 PostgreSQL（如需要）

---

## 🗄️ 数据结构设计

### Firestore 集合结构

#### 1. `attractions` 集合（景点主表）

```typescript
{
  id: string,  // 自动生成
  name: string,  // 景点名称
  nameNormalized: string,  // 标准化名称（用于搜索）
  category: string,  // 分类：地标、景点、美食、文化等
  icon: string,  // SF Symbol 图标名称
  coordinate: {
    latitude: number,
    longitude: number
  } | null,
  popularity: number,  // 热门程度（0-100）
  tags: string[],  // 标签数组
  city: string,  // 城市名称（标准化）
  country: string | null,  // 国家名称
  address: string | null,  // 地址
  description: string | null,  // 描述
  
  // 数据来源
  source: 'official' | 'user',  // 官方数据或用户贡献
  contributorId: string | null,  // 贡献者用户ID（如果是用户贡献）
  contributorName: string | null,  // 贡献者名称（快取）
  
  // 数据质量
  verified: boolean,  // 是否已验证
  verificationScore: number,  // 验证分数（0-100）
  usageCount: number,  // 使用次数（被选择的次数）
  
  // 时间戳
  createdAt: Timestamp,
  updatedAt: Timestamp,
  verifiedAt: Timestamp | null,
  
  // 去重相关
  duplicateOf: string | null,  // 如果是重复数据，指向主数据ID
  isDuplicate: boolean,  // 是否为重复数据
}
```

**索引**：
- `city` (Ascending)
- `popularity` (Descending)
- `createdAt` (Descending)
- `verified` (Ascending), `popularity` (Descending)
- `tags` (Array)

#### 2. `user_attractions` 集合（用户贡献记录）

```typescript
{
  id: string,
  userId: string,  // 贡献者用户ID
  attractionId: string,  // 关联的景点ID
  city: string,
  country: string | null,
  
  // 用户输入的数据
  name: string,
  location: string,
  coordinate: {
    latitude: number,
    longitude: number
  } | null,
  description: string | null,
  
  // 状态
  status: 'pending' | 'approved' | 'rejected' | 'merged',  // 待审核、已批准、已拒绝、已合并
  rejectionReason: string | null,
  
  // 时间戳
  createdAt: Timestamp,
  reviewedAt: Timestamp | null,
  reviewerId: string | null,
}
```

**索引**：
- `userId` (Ascending), `createdAt` (Descending)
- `status` (Ascending), `createdAt` (Descending)

#### 3. `attraction_usage` 集合（使用统计）

```typescript
{
  id: string,
  attractionId: string,
  userId: string,
  city: string,
  usedAt: Timestamp,
  context: 'block_edit' | 'ai_planner' | 'other',  // 使用场景
}
```

**索引**：
- `attractionId` (Ascending), `usedAt` (Descending)
- `city` (Ascending), `usedAt` (Descending)

#### 4. `city_attractions_cache` 集合（城市景点缓存）

```typescript
{
  id: string,  // 城市名称（标准化）
  city: string,
  country: string | null,
  attractionIds: string[],  // 关联的景点ID列表
  lastUpdated: Timestamp,
  count: number,  // 景点数量
}
```

**用途**：快速获取某个城市的所有景点，避免每次查询

---

## 🔐 Firestore Security Rules

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // =====================
    // Attractions（景点主表）
    // =====================
    match /attractions/{attractionId} {
      // 所有人可读
      allow read: if true;
      
      // 只有管理员可写（通过 Cloud Functions）
      allow write: if false;
      
      // 用户可以通过 Cloud Functions 添加（通过调用函数）
    }
    
    // =====================
    // User Attractions（用户贡献）
    // =====================
    match /user_attractions/{userAttractionId} {
      // 用户可读自己的贡献
      allow read: if request.auth != null && 
                     (resource == null || resource.data.userId == request.auth.uid);
      
      // 用户可创建自己的贡献
      allow create: if request.auth != null && 
                       request.resource.data.userId == request.auth.uid;
      
      // 用户可更新自己的待审核贡献
      allow update: if request.auth != null && 
                       resource.data.userId == request.auth.uid &&
                       resource.data.status == 'pending';
      
      // 只有管理员可审核（通过 Cloud Functions）
      allow delete: if false;
    }
    
    // =====================
    // Attraction Usage（使用统计）
    // =====================
    match /attraction_usage/{usageId} {
      // 用户可读自己的使用记录
      allow read: if request.auth != null && 
                     resource.data.userId == request.auth.uid;
      
      // 用户可创建自己的使用记录
      allow create: if request.auth != null && 
                       request.resource.data.userId == request.auth.uid;
      
      // 不允许更新和删除
      allow update, delete: if false;
    }
    
    // =====================
    // City Attractions Cache（城市缓存）
    // =====================
    match /city_attractions_cache/{cityId} {
      // 所有人可读
      allow read: if true;
      
      // 只有 Cloud Functions 可写
      allow write: if false;
    }
  }
}
```

---

## 📝 实施步骤

### 阶段一：基础功能（1-2周）

1. **创建 Firestore 集合结构**
   - 创建 `attractions` 集合
   - 创建 `user_attractions` 集合
   - 设置 Security Rules

2. **迁移本地数据到 Firestore**
   - 编写脚本将 `CityAttractionsDatabase` 中的数据迁移到 Firestore
   - 标记为 `source: 'official'`

3. **修改 `CityAttractionsDatabase`**
   - 添加从 Firestore 读取数据的方法
   - 保留本地数据作为 fallback

4. **实现基础搜索功能**
   - 在 `BlockEditView` 中实现 Firestore 搜索
   - 支持按城市、名称、标签搜索

### 阶段二：用户贡献功能（2-3周）

1. **实现添加景点功能**
   - 在 `BlockEditView` 中添加"添加新景点"按钮
   - 创建 `UserAttraction` 提交表单
   - 提交到 `user_attractions` 集合

2. **实现数据去重**
   - 在提交前检查是否已存在相似景点
   - 使用名称相似度和坐标距离判断

3. **实现使用统计**
   - 当用户选择景点时，记录到 `attraction_usage`
   - 更新景点的 `usageCount`

### 阶段三：数据质量优化（2-3周）

1. **实现数据验证机制**
   - 自动验证：坐标有效性、名称格式等
   - 人工审核：管理员审核用户贡献

2. **实现数据合并**
   - 合并重复的景点数据
   - 保留最完整的数据

3. **实现数据评分**
   - 根据使用次数、验证状态等计算 `verificationScore`
   - 优先显示高质量数据

### 阶段四：性能优化（1-2周）

1. **实现缓存机制**
   - 使用 `city_attractions_cache` 缓存城市景点列表
   - 实现本地缓存（UserDefaults 或 Core Data）

2. **优化查询性能**
   - 添加必要的索引
   - 实现分页加载

3. **集成全文搜索（可选）**
   - 如需要，集成 Algolia 实现全文搜索

---

## 💰 成本估算

### Firebase Firestore 成本

**免费额度**：
- 读取：50,000 次/天
- 写入：20,000 次/天
- 删除：20,000 次/天
- 存储：1 GB

**预计使用量**（初期）：
- 景点数据：约 1,000 条（600 官方 + 400 用户贡献）
- 每日读取：约 5,000 次（用户搜索）
- 每日写入：约 100 次（用户贡献）
- 存储：约 10 MB

**结论**：初期完全在免费额度内，无需付费。

**未来扩展**（10万条数据）：
- 存储：约 100 MB（仍在免费额度内）
- 读取：如超过 50K/天，约 $0.06/10万次读取
- 写入：如超过 20K/天，约 $0.18/10万次写入

---

## 🔄 未来扩展方案

### 如果数据量增长到 100万条以上

1. **迁移到 PostgreSQL**
   - 将 Firestore 数据导出
   - 导入到 PostgreSQL
   - 开发 REST API

2. **混合方案**
   - 官方数据存储在 PostgreSQL
   - 用户贡献数据存储在 Firestore
   - 定期同步高质量 UGC 到 PostgreSQL

3. **集成搜索服务**
   - 集成 Algolia 或 Elasticsearch
   - 实现全文搜索和高级筛选

---

## ✅ 总结

**推荐方案**：Firebase Firestore

**理由**：
1. ✅ 已集成，无需引入新技术
2. ✅ 开发速度快，成本低
3. ✅ 满足当前需求
4. ✅ 未来可扩展

**下一步**：
1. 创建 Firestore 集合结构
2. 迁移本地数据
3. 实现基础搜索功能
4. 逐步添加用户贡献功能
