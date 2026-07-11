# 頭像商店後端規格文件

> **版本**：1.0  
> **日期**：2026-07-11  
> **對應 Issue**：#12 頭像兌換與更換功能  
> **前端參考**：`lib/services/shop_service.dart`（Task 5）

---

## 1. `users` 表新增欄位

在現有 `users` 表新增以下欄位：

```sql
ALTER TABLE users ADD COLUMN avatar_id TEXT NULL;
```

**欄位說明**：
- `avatar_id`: 目前配戴的內建頭像 ID，對應 `avatar_catalog` 表的 `id` 欄位
  - 類型：`TEXT NULL`
  - 預設值：`NULL`（使用者初始無配戴頭像）
  - FK 參考：`avatar_catalog(id)` （軟參考，允許刪除 catalog 時無須級聯）
  - 更新邏輯：用戶透過 `/api/me` PATCH 端點修改

---

## 2. 新增資料表

### 2.1 `avatar_catalog` 表

存放全部頭像素材的目錄及定價、稀有度、解鎖條件等後設資料。對應前端 `lib/core/constants/avatar_catalog.dart` 的 `kAvatarCatalog` 常數（40 筆資料）。

```sql
CREATE TABLE avatar_catalog (
  id               TEXT PRIMARY KEY,                        -- 例："avatar_general_01"
  name             TEXT NOT NULL,                           -- 顯示用名稱，例："頭像 1"
  price            INT NOT NULL,                            -- 小米幣價格
  rarity           TEXT NOT NULL,                           -- 'common' | 'rare' | 'gold'
  unlock_condition TEXT,                                    -- 解鎖條件描述；NULL 表示無條件
  created_at       TIMESTAMPTZ DEFAULT NOW(),
  
  CHECK (price >= 0),
  CHECK (rarity IN ('common', 'rare', 'gold')),
  CHECK (unlock_condition IS NOT NULL OR rarity IN ('common', 'rare'))
);

-- 便利查詢
CREATE INDEX idx_avatar_rarity ON avatar_catalog(rarity);
CREATE INDEX idx_avatar_price ON avatar_catalog(price);
```

**種子資料**（40 筆）：

根據 `_buildAvatar()` 演算法生成。以下為完整 SQL INSERT 語句：

```sql
INSERT INTO avatar_catalog (id, name, price, rarity, unlock_condition) VALUES
('avatar_general_01', '頭像 1', 50, 'common', NULL),
('avatar_general_02', '頭像 2', 50, 'common', NULL),
('avatar_general_03', '頭像 3', 50, 'common', NULL),
('avatar_general_04', '頭像 4', 50, 'common', NULL),
('avatar_general_05', '頭像 5', 200, 'rare', NULL),
('avatar_general_06', '頭像 6', 50, 'common', NULL),
('avatar_general_07', '頭像 7', 50, 'common', NULL),
('avatar_general_08', '頭像 8', 50, 'common', NULL),
('avatar_general_09', '頭像 9', 50, 'common', NULL),
('avatar_general_10', '頭像 10', 500, 'gold', '完成每日任務累積 30 天'),
('avatar_general_11', '頭像 11', 50, 'common', NULL),
('avatar_general_12', '頭像 12', 50, 'common', NULL),
('avatar_general_13', '頭像 13', 50, 'common', NULL),
('avatar_general_14', '頭像 14', 50, 'common', NULL),
('avatar_general_15', '頭像 15', 200, 'rare', NULL),
('avatar_general_16', '頭像 16', 50, 'common', NULL),
('avatar_general_17', '頭像 17', 50, 'common', NULL),
('avatar_general_18', '頭像 18', 50, 'common', NULL),
('avatar_general_19', '頭像 19', 50, 'common', NULL),
('avatar_general_20', '頭像 20', 500, 'gold', '完成每日任務累積 30 天'),
('avatar_general_21', '頭像 21', 50, 'common', NULL),
('avatar_general_22', '頭像 22', 50, 'common', NULL),
('avatar_general_23', '頭像 23', 50, 'common', NULL),
('avatar_general_24', '頭像 24', 50, 'common', NULL),
('avatar_general_25', '頭像 25', 200, 'rare', NULL),
('avatar_general_26', '頭像 26', 50, 'common', NULL),
('avatar_general_27', '頭像 27', 50, 'common', NULL),
('avatar_general_28', '頭像 28', 50, 'common', NULL),
('avatar_general_29', '頭像 29', 50, 'common', NULL),
('avatar_general_30', '頭像 30', 500, 'gold', '完成每日任務累積 30 天'),
('avatar_general_31', '頭像 31', 50, 'common', NULL),
('avatar_general_32', '頭像 32', 50, 'common', NULL),
('avatar_general_33', '頭像 33', 50, 'common', NULL),
('avatar_general_34', '頭像 34', 50, 'common', NULL),
('avatar_general_35', '頭像 35', 200, 'rare', NULL),
('avatar_general_36', '頭像 36', 50, 'common', NULL),
('avatar_general_37', '頭像 37', 50, 'common', NULL),
('avatar_general_38', '頭像 38', 50, 'common', NULL),
('avatar_general_39', '頭像 39', 50, 'common', NULL),
('avatar_general_40', '頭像 40', 500, 'gold', '完成每日任務累積 30 天');
```

**稀有度與價格分布**：
- **Common**（32 筆）：price=50
  - 所有編號除 5, 10, 15, 20, 25, 30, 35, 40
- **Rare**（4 筆）：price=200，unlock_condition=NULL
  - 編號 5, 15, 25, 35
- **Gold**（4 筆）：price=500，unlock_condition='完成每日任務累積 30 天'
  - 編號 10, 20, 30, 40

### 2.2 `user_owned_avatars` 表

記錄用戶已經擁有的頭像（曾購買者）及購買時間。

```sql
CREATE TABLE user_owned_avatars (
  uid            INT NOT NULL,                             -- FK → users.uid
  avatar_id      TEXT NOT NULL,                            -- FK → avatar_catalog.id
  obtained_at    TIMESTAMPTZ DEFAULT NOW(),                -- 購買/取得時間
  
  PRIMARY KEY (uid, avatar_id),
  FOREIGN KEY (uid) REFERENCES users(uid) ON DELETE CASCADE,
  FOREIGN KEY (avatar_id) REFERENCES avatar_catalog(id)
);

-- 便利查詢使用者已擁有的全部頭像
CREATE INDEX idx_user_owned_avatars_uid ON user_owned_avatars(uid);
-- 便利查詢某頭像的擁有者
CREATE INDEX idx_user_owned_avatars_avatar_id ON user_owned_avatars(avatar_id);
```

**應用場景**：
- 用戶購買頭像時：`INSERT INTO user_owned_avatars (uid, avatar_id) VALUES (...)`
- 個人資料頁查詢已擁有清單：`SELECT avatar_id FROM user_owned_avatars WHERE uid = ?`
- 更換頭像前驗證擁有權：`SELECT 1 FROM user_owned_avatars WHERE uid = ? AND avatar_id = ?`

---

## 3. API 合約

### 3.1 `GET /api/me`

**功能**：取得目前登入使用者的個人資料（擴充欄位）。

**請求**：
```http
GET /api/me HTTP/1.1
Authorization: Bearer <JWT token>
Content-Type: application/json
```

**回應格式**（200 OK）：
```json
{
  "uid": 1,
  "display_name": "王小明",
  "avatar_url": "https://...",
  "avatar_id": "avatar_general_05",
  "owned_avatar_ids": [
    "avatar_general_01",
    "avatar_general_02",
    "avatar_general_05"
  ],
  "coins": 250
}
```

**回應欄位說明**：
- `uid` (int)：使用者 ID（SERIAL PK）
- `display_name` (string | null)：暱稱
- `avatar_url` (string | null)：原 Google/Apple 大頭貼 URL
- `avatar_id` (string | null)：目前配戴的內建頭像 ID；初始為 null
- `owned_avatar_ids` (string[])：已購買/已擁有的頭像 ID 陣列（可為空）
- `coins` (int)：小米幣餘額

**錯誤**：
- `401 Unauthorized`：JWT 無效或已撤銷
- `403 Forbidden`：其他權限錯誤

---

### 3.2 `POST /api/shop/avatars/{id}/purchase`

**功能**：購買一個頭像，扣款並記錄擁有權。

**請求**：
```http
POST /api/shop/avatars/avatar_general_05/purchase HTTP/1.1
Authorization: Bearer <JWT token>
Content-Type: application/json

(無 body)
```

**回應格式**（200 OK）：
```json
{
  "uid": 1,
  "display_name": "王小明",
  "avatar_url": "https://...",
  "avatar_id": "avatar_general_05",
  "owned_avatar_ids": [
    "avatar_general_01",
    "avatar_general_02",
    "avatar_general_05"
  ],
  "coins": 50
}
```

**回應內容**：更新後的完整 UserModel（同 `GET /api/me`）。

**後端流程**：
1. 驗證 JWT → 取得 `uid`
2. 查詢 `avatar_catalog` 取得頭像信息（price、rarity、unlock_condition）
3. 驗證用戶餘額：`users.coins >= avatar_catalog.price`
4. 驗證用戶尚未擁有此頭像：`NOT EXISTS (SELECT 1 FROM user_owned_avatars WHERE uid=? AND avatar_id=?)`
5. 驗證解鎖條件（如有）：依 `unlock_condition` 內容檢查是否滿足
6. 執行購買：
   - `UPDATE users SET coins = coins - ? WHERE uid = ?`
   - `INSERT INTO user_owned_avatars (uid, avatar_id) VALUES (?, ?)`
7. 回傳更新後的 UserModel

**錯誤處理**：

| 錯誤情況 | HTTP Status | Response 格式 |
|---------|------------|-------------|
| JWT 無效 | 401 | `{"error":{"message":"Unauthorized"}}` |
| 頭像不存在 | 404 | `{"error":{"message":"Avatar not found"}}` |
| 小米幣不足 | 402 或 400 | `{"error":{"code":"INSUFFICIENT_BALANCE","message":"小米幣不足"}}` |
| 已擁有此頭像 | 409 或 400 | `{"error":{"code":"ALREADY_OWNED","message":"已擁有此頭像"}}` |
| 解鎖條件未滿足 | 403 或 400 | `{"error":{"code":"UNLOCK_CONDITION_NOT_MET","message":"不符合解鎖條件"}}` |

**冪等性**：同一使用者重複購買同頭像應回傳 ALREADY_OWNED 錯誤，不應扣款兩次。

---

### 3.3 `PATCH /api/me`

**功能**：更新使用者個人資料（暱稱或配戴中頭像）。

**請求**：
```http
PATCH /api/me HTTP/1.1
Authorization: Bearer <JWT token>
Content-Type: application/json

{
  "avatarId": "avatar_general_05"
}
```

或

```json
{
  "display_name": "新暱稱",
  "avatarId": "avatar_general_02"
}
```

**請求欄位**（均可選）：
- `display_name` (string)：新暱稱（選擇性）
- `avatarId` (string)：要配戴的頭像 ID（選擇性；若為 null 則清除配戴）

**回應格式**（200 OK）：
```json
{
  "uid": 1,
  "display_name": "新暱稱",
  "avatar_url": "https://...",
  "avatar_id": "avatar_general_05",
  "owned_avatar_ids": [
    "avatar_general_01",
    "avatar_general_02",
    "avatar_general_05"
  ],
  "coins": 50
}
```

**回應內容**：更新後的完整 UserModel（同 `GET /api/me`）。

**後端流程**：
1. 驗證 JWT → 取得 `uid`
2. 若 body 含 `display_name`：
   - `UPDATE users SET display_name = ? WHERE uid = ?`
3. 若 body 含 `avatarId`：
   - 驗證 `avatarId` 非 null 時：`SELECT 1 FROM user_owned_avatars WHERE uid = ? AND avatar_id = ?`
   - 若查詢無結果 → 回傳 403 AVATAR_NOT_OWNED
   - `UPDATE users SET avatar_id = ? WHERE uid = ?`
4. 回傳更新後的 UserModel

**錯誤處理**：

| 錯誤情況 | HTTP Status | Response 格式 |
|---------|------------|-------------|
| JWT 無效 | 401 | `{"error":{"message":"Unauthorized"}}` |
| 頭像不在已擁有清單中 | 403 | `{"error":{"code":"AVATAR_NOT_OWNED","message":"此頭像尚未擁有"}}` |
| 其他驗證失敗 | 400 | `{"error":{"message":"Invalid request"}}` |

**特殊情況**：
- 若 `avatarId` 為 null 或空字串，應清除當前配戴（`UPDATE users SET avatar_id = NULL`）
- 若只更新 `display_name` 不涉及 `avatarId`，不需額外驗證
- 若既有欄位無異動，仍應回 200（幂等）

---

## 4. 架構設計與未來擴充

### 4.1 平行表結構設計

本次 avatar 系統的表結構（`avatar_catalog` + `user_owned_avatars`）刻意採用**可複製擴充**的設計，便於未來實作類似的裝飾品功能（如 Issue #11 頭像框）。

預期未來 Issue #11 的實作模式：
```sql
-- Issue #11：頭像框系統
ALTER TABLE users ADD COLUMN avatar_frame_id TEXT NULL;

CREATE TABLE avatar_frame_catalog (
  id               TEXT PRIMARY KEY,
  name             TEXT NOT NULL,
  price            INT NOT NULL,
  rarity           TEXT NOT NULL,
  unlock_condition TEXT,
  created_at       TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE user_owned_avatar_frames (
  uid            INT NOT NULL,
  avatar_frame_id TEXT NOT NULL,
  obtained_at    TIMESTAMPTZ DEFAULT NOW(),
  
  PRIMARY KEY (uid, avatar_frame_id),
  FOREIGN KEY (uid) REFERENCES users(uid) ON DELETE CASCADE,
  FOREIGN KEY (avatar_frame_id) REFERENCES avatar_frame_catalog(id)
);

-- API 端點同上
-- GET /api/me (新增 avatarFrameId, ownedFrameIds)
-- POST /api/shop/frames/{id}/purchase
-- PATCH /api/me (新增 avatarFrameId)
```

此設計允許後端在實作 #11 時直接複製 avatar 的邏輯分支，確保一致性。

### 4.2 小米幣與價格策略

本規格未涵蓋小米幣的來源端點（獲取方式、任務獎勵等），該部分由獨立的經濟系統管理。購買端點僅負責驗證與扣款。

---

## 5. 集成前檢查清單

**重要提醒**：本規格文件是基於前端 `shop_service.dart`（Task 5）與前端常數設計而產出。後端團隊實作時務必執行下列步驟，確保前後端資料契約一致：

### 5.1 API 形狀對齐（必須）

1. **端點路徑** ✓
   - `GET /api/me` ← 既有端點，新增回傳欄位 `avatar_id`、`owned_avatar_ids`、`coins`
   - `POST /api/shop/avatars/{id}/purchase` ← 新增端點
   - `PATCH /api/me` ← 既有端點，新增可選欄位 `avatarId`

2. **JSON 欄位命名** ✓
   - 前端期待的 snake_case 鍵名（來自 `lib/models/user_model.dart`）：
     - `avatar_id`
     - `owned_avatar_ids`
     - `coins`
   - 確認後端回應使用相同鍵名（勿用 camelCase）

3. **錯誤回應格式** ✓
   - 預期格式（見 `shop_service.dart` L110）：`{"error":{"message":"..."}}`
   - 確認實作時保持此結構

### 5.2 Integration 測試流程（建議）

建議後端在實作後執行以下 integration test 驗証形狀一致：

```typescript
// 偽代碼
describe('Avatar Shop API', () => {
  test('GET /api/me 回傳 avatar_id, owned_avatar_ids, coins', async () => {
    const response = await getMe(validToken);
    expect(response).toHaveProperty('avatar_id');
    expect(response).toHaveProperty('owned_avatar_ids');
    expect(Array.isArray(response.owned_avatar_ids)).toBe(true);
    expect(response).toHaveProperty('coins');
    expect(typeof response.coins).toBe('number');
  });

  test('POST /api/shop/avatars/{id}/purchase 扣款並更新 owned_avatar_ids', async () => {
    const before = await getMe(token);
    const coinsBeforeStr = before.coins;
    
    const response = await purchaseAvatar(token, 'avatar_general_05');
    expect(response.owned_avatar_ids).toContain('avatar_general_05');
    expect(response.coins).toBe(coinsBeforeStr - 200);
  });

  test('PATCH /api/me 可更新 avatarId', async () => {
    // 先確保已擁有
    await purchaseAvatar(token, 'avatar_general_02');
    
    const response = await equipAvatar(token, 'avatar_general_02');
    expect(response.avatar_id).toBe('avatar_general_02');
  });

  test('PATCH /api/me 驗證 avatarId 在已擁有清單中', async () => {
    // 嘗試配戴未擁有的頭像
    const response = await equipAvatar(token, 'avatar_general_99');
    expect(response.status).toBe(403);
    expect(response.body).toHaveProperty('error.code', 'AVATAR_NOT_OWNED');
  });

  test('POST /api/shop/avatars/{id}/purchase 餘額不足時回傳 402', async () => {
    // 清空用戶餘額至 < 500 的金額
    // 嘗試購買 gold 頭像
    const response = await purchaseAvatar(token, 'avatar_general_10');
    expect(response.status).toBeOneOf([400, 402]);
    expect(response.body).toHaveProperty('error.code', 'INSUFFICIENT_BALANCE');
  });
});
```

### 5.3 前端驗證

前端 Flutter 團隊在後端完成後執行：

1. 執行 `flutter test test/services/shop_service_test.dart` 確認 mock 呼叫
2. 執行 `flutter run` 並走過完整個人資料 → 商店 → 購買 → 配戴流程
3. 檢查 Network 標籤確認 HTTP 路徑與 body 格式正確

### 5.4 共同 Checkpoint

後端實作完成後，前端與後端共同檢查清單：

- [ ] `GET /api/me` 回傳 `avatar_id`、`owned_avatar_ids`、`coins`
- [ ] `POST /api/shop/avatars/{id}/purchase` 存在且支援路徑參數
- [ ] `PATCH /api/me` 支援 body 內 `avatarId` 欄位
- [ ] 所有回應均使用 snake_case 鍵名
- [ ] 錯誤回應統一格式 `{"error":{"message":"...", "code":"..."}}`
- [ ] 小米幣扣款邏輯正確（購買時實時扣款）
- [ ] 無產權頭像的配戴操作被拒 (403)
- [ ] 餘額不足的購買操作被拒 (402 或 400)
- [ ] 無重複計費問題（冪等性）

---

## 附錄：字段對應參考

### 前端 → 後端欄位映射

| 前端 Dart | 前端 JSON 鍵 | 後端 DB 欄 | 後端 JSON 鍵 |
|---------|-----------|---------|----------|
| `UserModel.avatarId` | `avatar_id` | `users.avatar_id` | `avatar_id` |
| `UserModel.ownedAvatarIds` | `owned_avatar_ids` | `user_owned_avatars.avatar_id[]` | `owned_avatar_ids` |
| `UserModel.coins` | `coins` | `users.coins` | `coins` |

### 頭像目錄對應

| 前端 | 後端 |
|---|---|
| `AvatarCatalogItem.id` | `avatar_catalog.id` |
| `AvatarCatalogItem.name` | `avatar_catalog.name` |
| `AvatarCatalogItem.price` | `avatar_catalog.price` |
| `AvatarCatalogItem.rarity` | `avatar_catalog.rarity` |
| `AvatarCatalogItem.unlockCondition` | `avatar_catalog.unlock_condition` |

---

**文件版本** | **日期** | **作者** | **更新內容**
---|---|---|---
1.0 | 2026-07-11 | Frontend Spec | 初版發佈，對應 Task 1-5 產出物

