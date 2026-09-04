# 後端實作要求：活動通知（參加者收件匣）

## 背景

活動列表頁原本想加一顆「通知」icon，對齊論壇廣場頁的搜尋／收藏／通知三入口排版。
前端一開始用「`GET /api/events` 篩 `isJoined` + 逐一打 `GET /api/events/:id/reminders`」
硬湊通知清單，在 code review（[PR #53](https://github.com/willy1236/TarokoLanguageApp/pull/53)）被
標記 Blocking 退回，原因：

1. `/reminders` 是查「單一活動的提醒排程」，不是使用者維度的通知收件匣，端點語意錯位。
2. N+1 請求 + 活動筆數上限（`pageSize: 50`），已報名活動一多會漏抓通知、請求量暴增。
3. 任一活動查詢失敗會被 `catchError` 吞掉，使用者看到「沒有通知」而非「載入失敗」，是假象。

因此改請後端提供正式的使用者通知端點，設計上直接比照現有論壇通知
（`GET /api/forum/notifications`、`POST /api/forum/notifications/read`）的模式，
前端接手時不需要另外學一套新規則。

## 需求

參加者在「我報名的活動」被發起人發送提醒（`POST /api/events/:id/reminders` 建立、
排程時間到後由後端排程送出）時，應該能在一個獨立的通知列表看到這些訊息，並且：

- 可分頁瀏覽歷史通知。
- 知道目前有幾則未讀（活動列表頁通知 icon 要顯示未讀紅點，比照論壇）。
- 點開／進入清單後可標記已讀。
- 單一活動查不到資料時是整體請求失敗，而不是後端在單一活動層級各自成功/失敗、前端猜不到哪些漏了。

## API 規格

### 1. `GET /api/events/notifications`

列出目前使用者「已報名活動」收到的通知（即該活動已送出的 reminder），依時間新到舊排序。

**Query params**

| 參數 | 型別 | 說明 |
|---|---|---|
| `cursor` | number, 選填 | 分頁游標，沿用論壇通知的 cursor 分頁方式 |

**Response 200**

```json
{
  "notifications": [
    {
      "id": 123,
      "event_id": 45,
      "event_title": "部落豐年祭前置準備",
      "message": "記得帶雨具，現場備有簡易雨棚",
      "sent_at": "2026-09-01T02:00:00Z",
      "is_read": false
    }
  ],
  "unread_count": 3,
  "next_cursor": 118
}
```

欄位對應現有 `EventReminder`（`id` / `message` / `sent_at`）另外加：
- `event_id` / `event_title`：前端要能顯示是哪場活動、點下去導去該活動詳情頁。
- `is_read`：比照論壇通知的已讀狀態。

只回傳 `status == 'sent'` 的提醒；`pending` / `failed` / `cancelled` 不算通知。
使用者若已退出該活動，該活動後續產生的通知不必再回傳（已收到的歷史通知是否保留皆可，
以實作方便為準，前端不強制要求）。

### 2. `POST /api/events/notifications/read`

標記已讀，比照 `POST /api/forum/notifications/read`。

**Request body**

```json
{ "ids": [123, 124] }
```

不帶 `ids`（或傳空陣列，依論壇既有慣例擇一）代表全部標記已讀。

**Response 200**：`{}` 或 `{"marked": 2}` 皆可，前端不依賴回傳內容。

## 資料模型建議

沿用既有 `event_reminders` 表（id / event_id / message / scheduled_at / status / sent_at），
新增一張記錄「誰、對哪則提醒、何時已讀」的關聯表，例如：

```sql
CREATE TABLE event_reminder_reads (
  reminder_id INT NOT NULL REFERENCES event_reminders(id),
  user_id     INT NOT NULL REFERENCES users(id),
  read_at     TIMESTAMPTZ,
  PRIMARY KEY (reminder_id, user_id)
);
```

`GET /api/events/notifications` 的查詢邏輯大致是：

```
SELECT r.*, e.title AS event_title, (rr.read_at IS NOT NULL) AS is_read
FROM event_reminders r
JOIN event_participants p ON p.event_id = r.event_id AND p.user_id = :current_user
JOIN events e ON e.id = r.event_id
LEFT JOIN event_reminder_reads rr ON rr.reminder_id = r.id AND rr.user_id = :current_user
WHERE r.status = 'sent'
ORDER BY r.sent_at DESC
```

`unread_count` 用同樣的 join 條件加 `WHERE rr.read_at IS NULL` 算 COUNT。

## 邊界情況

- 使用者從未報名任何活動 → 回傳空陣列 + `unread_count: 0`，不是錯誤。
- 活動已被取消 → 該活動先前送出的提醒是否仍顯示為通知，由後端決定即可（建議：保留，畢竟訊息本身仍是歷史事實）。
- 未帶 JWT / 401 → 沿用既有 `ApiClient` 的 401 自動導回登入邏輯，不需特殊處理。

## 前端配合

端點就緒後，前端會：
1. 重新加回 `lib/screens/events/event_notifications_screen.dart`，改成單一分頁請求 + `unread_count` 顯示紅點（比照 [plaza_screen.dart](../lib/screens/plaza/plaza_screen.dart) 的 `_actionIcons()` 通知 icon 寫法）。
2. 在 `lib/screens/events/events_screen.dart` 的 `_actionIcons()` 補回通知 icon。
3. `EventService` 新增 `fetchEventNotifications({cursor})` / `markEventNotificationsRead({ids})`，仿照 `ForumService.notifications()` / `ForumService.markRead()`。
