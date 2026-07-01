# API Inspector

直接用裝置上的登入狀態（JWT token）打所有後端端點，在 terminal 印出原始 JSON 回應。用來確認端點格式，不需要手動複製 token 或架設額外工具。

## 使用方式

**前提：先在裝置上開 app 並完成 Google 登入（token 會存在 secure storage）**

```bash
# 列出可用裝置
flutter devices

# 執行
flutter test integration_test/api_inspector_test.dart -d <device_id>
```

Terminal 會印出每個端點的 HTTP status code 和 pretty-printed JSON。

### 未登入時

所有測試會顯示 `Skipped`，不會失敗。先在裝置上登入再重跑即可。

---

## 開發工作流：串接新端點前必做

每次要串接後端新端點，**必須先在這裡確認原始格式，再寫 model 和 service**：

1. 在 `integration_test/api_inspector_test.dart` 的 `group` 裡加一個 `test()`

   ```dart
   test('GET /api/new-endpoint', () => _inspect('GET', '/api/new-endpoint'));
   ```

2. 執行測試，看 terminal 輸出的原始 JSON

3. 根據**實際欄位名稱**撰寫 `fromJson()`，不要猜測

4. 確認 model 欄位名稱與原始回應完全一致後，才開始寫 service 和 UI

> 過去的 bug（`option_id` vs `id`、`available_words` vs `word_count`）都是因為沒看原始格式就直接寫 model 造成的。

---

## 測試涵蓋的端點

| 端點 | Method | 說明 |
|------|--------|------|
| `/api/health` | GET | 後端健康狀態 |
| `/api/me` | GET | 當前登入用戶資料 |
| `/api/levels` | GET | 所有課程級別列表 |
| `/api/quiz/start` | POST | 開始測驗 session |
| `/api/quiz/submit` | POST | 提交測驗答案（空資料測錯誤格式）|
| `/api/listening/start` | POST | 開始聆聽 session |
| `/api/listening/submit` | POST | 提交聆聽答案（空資料測錯誤格式）|

## 檔案位置

- 測試檔：`integration_test/api_inspector_test.dart`
- API 端點常數：`lib/core/constants/api.dart`
