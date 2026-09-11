# 語見太魯閣 (Taroko Language App)

一個以太魯閣族語 (Truku) 為共同語言的社群 App。核心是讓族語在人跟人之間用起來：年輕人跟族語耆老直接視訊對話，族人在論壇交流、加好友聊天，一起報名部落活動。

課程、測驗和文化影音是輔助，讓使用者有足夠的基礎開口。

後端是另一個 repo `Truku_backend`（Node.js + Typescript，部署在 Google Cloud Run），本 repo 只放行動端前端。

## 互動功能

| 功能         | 內容                                                                                                                 |
| ------------ | -------------------------------------------------------------------------------------------------------------------- |
| 視訊互動     | 隨機配對族人進行 1 對 1 視訊 (Agora RTC)，配對成功會推播通知                                                         |
| 好友通話     | 直接撥視訊給好友，有來電畫面與等待接聽流程                                                                           |
| 好友與聊天   | 好友邀請、即時一對一聊天 (WebSocket)                                                                                 |
| 論壇         | 發文、回覆、收藏貼文，有人回覆時推播通知                                                                             |
| 活動廣場     | 部落與社群活動列表、報名、活動前提醒與取消通知                                                                       |
| 公開身分     | 公開暱稱、自訂頭像，用小米幣兌換頭像框，在社群裡展示                                                                 |
| 長者精簡模式 | 為耆老準備的介面：放大字級與版面，並用密度常數 (`AppDensity`) 限制每張卡片的欄位數與首頁區塊數，讓畫面資訊量保持精簡 |

推播通知（視訊配對、好友來電、論壇回覆、活動提醒）走 Firebase Cloud Messaging，點通知會直接導到對應畫面。

## 輔助學習

| 功能       | 內容                                                                 |
| ---------- | -------------------------------------------------------------------- |
| 課程與測驗 | 分級課程、字卡、單字與聽力測驗、分級測驗 (placement)，可回報答案錯誤 |
| 文化影音   | 族語影片 (HLS 串流)、文化文章 (Markdown)，可按讚與收藏               |
| 小米幣     | 每日簽到、完成測驗獲得小米幣，到商店兌換頭像與頭像框                 |

## 技術架構

- **Flutter** 3.44 / Dart SDK `^3.10.7`
- **登入**：Google Sign-In → Firebase Auth 取得 ID token → 後端換發 JWT，存在 `flutter_secure_storage`
- **網路**：`http` + 自訂 `ApiClient`；聊天用 `web_socket_channel`
- **影音**：`better_player_plus` (HLS)、`audioplayers` (測驗音檔)
- **視訊**：`agora_rtc_engine`（App ID 和 token 由後端依通話 session 下發，前端不寫死）
- **通知**：`firebase_messaging` + `flutter_local_notifications`
- **字型與樣式**：`google_fonts` (Noto Sans TC)，設計代幣集中在 `lib/core/constants/`

## 目錄結構

```
lib/
├── main.dart               # 進入點、路由、FCM 通知導頁
├── firebase_options.dart   # FlutterFire 產生的 Firebase 設定
├── core/
│   ├── constants/          # api.dart（端點）、app_colors / typography / spacing / radius / density
│   ├── network/            # api_client.dart
│   └── utils/
├── models/                 # 資料模型與 fromJson
├── services/               # 各模組的 API 呼叫（auth、learn、forum、video_call…）
├── screens/                # 依功能分資料夾，子元件放在各自的 widgets/
└── shared/                 # 共用元件（底部導覽、painter、reward overlay…）
test/                       # 單元與 widget 測試
integration_test/           # API Inspector、需要真機的整合測試
claude-design-src/          # 設計稿 (JSX / HTML prototype)，Flutter UI 的對照來源
docs/                       # 開發文件
```

## 開始開發

### 需求

- Flutter 3.44 以上（stable channel）
- Android Studio 或 Xcode（視目標平台）
- 能連到後端 API 的網路

### 安裝與執行

```bash
flutter pub get
flutter devices
flutter run -d <device_id>
```

後端網址設定在 [lib/core/constants/api.dart](lib/core/constants/api.dart) 的 `ApiConfig.baseUrl`，預設指向正式環境的 Cloud Run。要接本機後端就改這個值。

Firebase 設定檔（`lib/firebase_options.dart`、`android/app/google-services.json`）已經在 repo 裡。Google 登入失敗時，多半是本機 debug keystore 的 SHA-1 沒登記到 Firebase 專案，排查步驟見 [docs/google-signin-troubleshooting.md](docs/google-signin-troubleshooting.md)。

### 測試

```bash
flutter analyze
flutter test
```

整合測試要在真機或模擬器上跑，而且裝置上的 App 要先登入：

```bash
flutter test integration_test/api_inspector_test.dart -d <device_id>
```
