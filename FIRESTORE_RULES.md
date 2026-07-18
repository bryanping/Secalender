# Firestore Security Rules

> **已整合**：完整規則與事件分享可見性邏輯已合併至 [`EVENT_AND_FIRESTORE_RULES.md`](./EVENT_AND_FIRESTORE_RULES.md)。  
> 本文件保留規則總覽與快速參考。

---

## 📋 規則總覽

### 資料結構

```
users/{uid}
  ├── events/{eventId}
  ├── purchases/{templateId}
  ├── favorites/{templateId}
  └── library/{templateId}

friends/{docId}
friend_requests/{docId}
event_shares/{docId}
event_invites/{docId}

groups/{groupId}
  └── groupEvents/{eventId}
```

---

## 🔒 完整 Rules

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // ==================== Helper Functions ====================
    
    // 判斷是否為本人
    function isOwner(userId) {
      return request.auth != null && request.auth.uid == userId;
    }
    
    // 判斷是否為好友
    function isFriend(userId) {
      return request.auth != null && 
        exists(/databases/$(database)/documents/friends/$(request.auth.uid)) &&
        get(/databases/$(database)/documents/friends/$(request.auth.uid))
          .data.friendIds.hasAny([userId]);
    }
    
    // 判斷是否為群組成員
    function isGroupMember(groupId) {
      return request.auth != null && 
        exists(/databases/$(database)/documents/groups/$(groupId)) &&
        get(/databases/$(database)/documents/groups/$(groupId))
          .data.members.hasAny([request.auth.uid]);
    }
    
    // 判斷是否為群組管理員
    function isGroupAdmin(groupId) {
      return request.auth != null && 
        exists(/databases/$(database)/documents/groups/$(groupId)) &&
        (get(/databases/$(database)/documents/groups/$(groupId)).data.owner == request.auth.uid ||
         get(/databases/$(database)/documents/groups/$(groupId)).data.admins.hasAny([request.auth.uid]));
    }
    
    // ==================== Users ====================
    
    match /users/{uid} {
      // 本人可讀寫
      allow read, write: if isOwner(uid);
      
      // 好友可讀（僅公開資訊）
      allow read: if isFriend(uid);
      
      // ==================== User Events ====================
      
      match /events/{eventId} {
        // 本人可讀寫
        allow read, write: if isOwner(uid);
        
        // 好友可讀（若 openChecked == 1）
        allow read: if isFriend(uid) && 
          resource.data.openChecked == 1;
        
        // 群組成員可讀（若為群組活動）
        allow read: if request.auth != null && 
          resource.data.groupId != null &&
          isGroupMember(resource.data.groupId);
      }
      
      // ==================== Purchases ====================
      
      match /purchases/{templateId} {
        // 本人只能讀取（不能寫入，由 Admin SDK 寫入）
        allow read: if isOwner(uid);
        allow write: if false;  // 禁止用戶直接寫入
      }
      
      // ==================== Favorites ====================
      
      match /favorites/{templateId} {
        // 本人可讀寫
        allow read, write: if isOwner(uid);
      }
      
      // ==================== Library ====================
      
      match /library/{templateId} {
        // 本人可讀寫
        allow read, write: if isOwner(uid);
      }
    }
    
    // ==================== Friends ====================
    
    match /friends/{docId} {
      // 本人可讀自己的好友關係
      allow read: if request.auth != null && 
        (resource.data.owner == request.auth.uid || 
         resource.data.friend == request.auth.uid);
      
      // 本人可建立好友關係
      allow create: if request.auth != null && 
        request.resource.data.owner == request.auth.uid;
      
      // 本人可刪除自己的好友關係
      allow delete: if request.auth != null && 
        resource.data.owner == request.auth.uid;
      
      // 禁止更新（需透過刪除+新增）
      allow update: if false;
    }
    
    // ==================== Friend Requests ====================
    
    match /friend_requests/{docId} {
      // 發送者或接收者可讀
      allow read: if request.auth != null && 
        (resource.data.from == request.auth.uid || 
         resource.data.to == request.auth.uid);
      
      // 本人可發送請求
      allow create: if request.auth != null && 
        request.resource.data.from == request.auth.uid;
      
      // 接收者可更新（接受/拒絕）
      allow update: if request.auth != null && 
        resource.data.to == request.auth.uid &&
        request.resource.data.from == resource.data.from &&
        request.resource.data.to == resource.data.to;
      
      // 發送者可取消請求
      allow delete: if request.auth != null && 
        resource.data.from == request.auth.uid;
    }
    
    // ==================== Groups ====================
    
    match /groups/{groupId} {
      // 公開群組：所有人可讀
      allow read: if resource.data.privacy == 'public';
      
      // 審核群組：所有人可讀
      allow read: if resource.data.privacy == 'approval';
      
      // 私人群組：僅成員可讀
      allow read: if resource.data.privacy == 'private' && 
        isGroupMember(groupId);
      
      // 建立群組：需登入
      allow create: if request.auth != null && 
        request.resource.data.owner == request.auth.uid;
      
      // 更新群組：僅管理員可更新
      allow update: if isGroupAdmin(groupId);
      
      // 刪除群組：僅擁有者可刪除
      allow delete: if request.auth != null && 
        resource.data.owner == request.auth.uid;
      
      // ==================== Group Events ====================
      
      match /groupEvents/{eventId} {
        // 群組成員可讀寫
        allow read, write: if isGroupMember(groupId);
      }
    }
  }
}
```

---

## 🔍 規則說明

### 1. Users / Events

- **本人**：可讀寫自己的所有活動
- **好友**：可讀取好友的公開活動（`openChecked == 1`）
- **群組成員**：可讀取群組活動（`groupId != null`）

### 2. Purchases

- **本人**：只能讀取（不能寫入）
- **寫入**：僅透過 Firebase Admin SDK（Web 端）寫入

### 3. Friends

- **讀取**：只能讀取自己作為 `owner` 或 `friend` 的記錄
- **建立**：只能建立自己作為 `owner` 的記錄
- **刪除**：只能刪除自己作為 `owner` 的記錄
- **更新**：禁止（需透過刪除+新增）

### 4. Friend Requests

- **讀取**：發送者或接收者可讀取
- **建立**：只能建立自己作為 `from` 的請求
- **更新**：僅接收者可更新（接受/拒絕）
- **刪除**：僅發送者可刪除（取消請求）

### 5. Groups

- **公開群組**：所有人可讀取
- **審核群組**：所有人可讀取（但加入需審核）
- **私人群組**：僅成員可讀取
- **更新**：僅管理員可更新
- **刪除**：僅擁有者可刪除

---

## ⚠️ 注意事項

### 1. 效能考量

- **避免深度查詢**：`isFriend()` 函數會讀取 `friends` 文檔，建議在客戶端快取好友列表
- **索引需求**：針對常用查詢建立 Firestore 索引

### 2. 安全性

- **Purchases 寫入**：嚴格禁止用戶直接寫入，僅允許 Admin SDK 寫入
- **群組權限**：區分「成員」與「管理員」，避免權限提升

### 3. 測試建議

- 使用 Firebase Emulator Suite 測試 Rules
- 編寫單元測試覆蓋各種情境

---

## 📝 索引需求

在 `firestore.indexes.json` 中建立以下索引：

```json
{
  "indexes": [
    {
      "collectionGroup": "events",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "groupId", "order": "ASCENDING" },
        { "fieldPath": "createTime", "order": "DESCENDING" }
      ]
    },
    {
      "collectionGroup": "friend_requests",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "to", "order": "ASCENDING" },
        { "fieldPath": "status", "order": "ASCENDING" },
        { "fieldPath": "createdAt", "order": "DESCENDING" }
      ]
    },
    {
      "collectionGroup": "friends",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "owner", "order": "ASCENDING" },
        { "fieldPath": "since", "order": "DESCENDING" }
      ]
    }
  ]
}
```

---

### event_shares / event_invites

`event_shares`（分享記錄與參與狀態）與 `event_invites`（邀請連結）的完整 Rules 已納入  
[`EVENT_AND_FIRESTORE_RULES.md`](./EVENT_AND_FIRESTORE_RULES.md)，部署時請以該文件的 Rules 為準。

---

**最後更新**：2025-02  
**維護者**：Secalender 開發團隊

---

## 🆕 2026-07 新增集合（已合併至 infra/firebase/firestore.rules，以該檔為部署真源）

```javascript
// users 子集合（本人可讀寫）
match /time_items/{itemId}    { allow read, write: if isOwner(uid); }  // Time OS 主儲存
match /theme_prompts/{key}    { allow read, write: if isOwner(uid); }  // 主題提示詞
match /quick_themes/{themeId} { allow read, write: if isOwner(uid); }  // 自訂主題雲端同步

// users/{uid}/events：新增好友公開活動可讀
allow read: if signedIn() && resource.data.openChecked == 1;

// 頂層集合
match /shared_plans/{shareId} {          // 跨平台安排確認網頁（plan.html）
  allow read: if true;
  allow create: if signedIn();
  allow update, delete: if signedIn() && resource.data.creatorId == request.auth.uid;
}
match /public_events/{eventId} {         // 時事活動（世界盃等，Admin/seed 寫入）
  allow read: if true;
  allow write: if isAdmin();
}
match /shared_quick_themes/{themeId} {   // 公開主題（模板市集）
  allow read: if true;
  allow create: if signedIn();
  allow update, delete: if signedIn() && resource.data.creatorId == request.auth.uid;
}
```

**部署**：`cd infra/firebase && ./deploy_rules.sh`（首次先 `npm i -g firebase-tools && firebase login`）
