# 語見太魯閣 (Taroko Language App)

一個以太魯閣族語 (Truku) 為共同語言的社群 App。核心是讓族語在人跟人之間用起來：年輕人跟族語耆老直接視訊對話，族人在論壇交流、加好友聊天，一起報名部落活動。

課程、測驗和文化影音是輔助，讓使用者有足夠的基礎開口。

後端是另一個 repo `Truku_backend`（Node.js + TypeScript，部署在 Google Cloud Run），本 repo 只放前端。主力平台是 Android 與 iOS，另有功能降級的 Web 版。

## 互動功能

| 功能         | 內容                                                                                                                 |
| ------------ | -------------------------------------------------------------------------------------------------------------------- |
| 視訊互動     | 隨機配對族人進行 1 對 1 視訊 (Agora RTC)，限滿 18 歲，首次配對前顯示通話須知，配對成功會推播通知                    |
| 好友通話     | 直接撥視訊給好友，有來電畫面（鈴聲加震動）與等待接聽流程                                                             |
| 好友與聊天   | 好友碼加好友、好友邀請、封鎖、即時一對一聊天 (WebSocket)                                                             |
| 論壇         | 發文附圖、回覆、按讚、收藏、搜尋、檢舉，有人回覆時推播通知                                                           |
| 活動廣場     | 活動列表、報名、按讚、收藏、搜尋；發起人與管理員角色可發起活動（多張照片、Google 地圖選點）、推播提醒、匯出報名名單 CSV，活動取消或刪除會推播通知報名者 |
| 收件匣       | 論壇回覆、活動、審核結果與官方公告，底部導覽顯示未讀紅點；可關閉部落新活動推播                                       |
| 公開身分     | 公開暱稱、自訂頭像（裁切後上傳），用小米幣兌換頭像與頭像框，在社群裡展示                                               |
| 精簡模式     | 為耆老準備的介面：放大字級與版面，首頁只留最重要的幾個區塊                                                           |

推播通知走 Firebase Cloud Messaging，點通知會直接導到對應畫面。

## 輔助學習

| 功能       | 內容                                                                       |
| ---------- | -------------------------------------------------------------------------- |
| 課程與測驗 | 分級課程、字卡、單字與聽力測驗、分級測驗 (placement)，可回報題目錯誤        |
| 測驗紀錄   | 回顧過去的單字與聽力測驗作答                                               |
| 文化影音   | 族語影片（HLS 串流、YouTube）、文化文章 (Markdown)，可按讚、收藏與搜尋     |
| 小米幣     | 每日簽到獲得小米幣（一週集滿 7 天另有獎勵），有收支明細，到商店兌換頭像與頭像框，收在背包裡使用 |

## 帳號與治理

- **登入**：Google 或 Apple 登入；首次登入要補個人資料、出生日期，並同意最新版服務條款。
- **帳號管理**：通知信箱驗證、匯出個人資料、登出所有裝置、刪除帳號（45 天緩衝期內可復原）。
- **檢舉與處分**：使用者可檢舉貼文、留言、活動、私訊、通話與其他使用者；被處分時會進入唯讀狀態，可查看案件並提出申訴。
- **管理員後台**：只有管理員角色看得到，處理檢舉、處分案件、申訴、禁言、禁用詞、題目回報、公告、文化文章、條款發布、角色管理，更正使用者的出生日期與族群部落，並可唯讀查核小米幣帳目。
- **版本控管**：冷啟動時比對 Firebase Remote Config 的版本號，提示更新或強制更新。

## 技術架構

- **Flutter** 3.44 / Dart SDK `^3.11.0`
- **登入**：Google Sign-In／Apple → Firebase Auth 取得 ID token → `POST /api/auth/login` 換發後端 JWT，存在 `flutter_secure_storage`
- **網路**：`http` + 自訂 `ApiClient`；聊天用 `web_socket_channel`
- **影音**：`better_player_plus`（行動版 HLS）、Web 版用 `<video>` + hls.js、`youtube_player_iframe`、`audioplayers`（測驗音檔）
- **視訊**：`agora_rtc_engine`（App ID 和 token 由後端依通話 session 下發，前端不寫死）
- **通知**：`firebase_messaging` + `flutter_local_notifications`；App 圖示未讀數由後端推播帶入，`app_badge_plus` 只負責 iOS 回前景時歸零
- **地圖**：`google_maps_flutter` + `flutter_google_places_sdk` + `geocoding`，金鑰集中在 [lib/core/constants/maps_config.dart](lib/core/constants/maps_config.dart)
- **遠端設定**：`firebase_remote_config`（版本提示），範本在 [remoteconfig.template.json](remoteconfig.template.json)
- **字型與樣式**：`google_fonts`（Noto Serif TC、Noto Sans TC，拉丁字用 Crimson Pro），精簡模式的版面上限在 `AppDensity`，設計代幣集中在 `lib/core/constants/`，文字樣式一律用 `AppTypography`

### 平台差異

Web 與桌面版有些套件沒有實作，是否啟用由 [lib/core/platform/platform_features.dart](lib/core/platform/platform_features.dart) 集中判斷，新程式一律查 `PlatformFeatures`，不要自己判斷 `kIsWeb`。

| 功能           | Android／iOS | Web                    |
| -------------- | ------------ | ---------------------- |
| 視訊通話       | 支援         | 不支援，顯示提示       |
| 推播通知       | 支援         | 不支援                 |
| HLS 影片       | 原生播放器   | `<video>` + hls.js     |
| YouTube 影片   | 內嵌播放     | 另開 YouTube 網頁      |
| 活動地圖選點   | 支援         | 支援                   |

## 目錄結構

```
lib/
├── main.dart               # 進入點、路由、底部導覽容器
├── firebase_options.dart   # FlutterFire 產生的 Firebase 設定
├── core/
│   ├── constants/          # api.dart（端點）、色彩／字型／間距／圓角／密度代幣、maps_config
│   ├── navigation/         # 路由堆疊追蹤
│   ├── network/            # api_client.dart
│   ├── platform/           # platform_features.dart（平台功能判斷）
│   └── utils/
├── models/                 # 資料模型與 fromJson
├── services/               # 各模組的 API 呼叫與全域狀態（auth、fcm、forum、event、video_call、app_update…）
├── screens/                # 依功能分資料夾，子元件放在各自的 widgets/；admin/ 是管理員後台
└── shared/                 # 共用元件與工具（底部導覽、返回鍵、painter、Web HLS 播放器…）
test/
├── contract/               # 用錄下來的後端回應驗證 model 解析
├── fixtures/               # api/ 是錄製檔，api_spec/ 是規格範例
├── flows/                  # 跨畫面流程（導頁、返回、分頁狀態）
├── models/ services/ screens/ widgets/ core/
└── web/                    # Hosting 標頭、外部腳本 SRI 等 Web 設定檢查
integration_test/           # API Inspector、需要真機的整合測試
tool/                       # fixture 抽取與重新遮罩腳本
web/                        # Web 版入口、隱私權政策、刪除帳號說明、支援頁
docs/                       # 開發文件；tickets/ 是任務卡
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

後端網址設定在 [lib/core/constants/api.dart](lib/core/constants/api.dart) 的 `ApiConfig.baseUrl`，預設指向正式環境的 Cloud Run。要接本機後端就改這個值；跑 Web 版時，[firebase.json](firebase.json) 的 CSP `connect-src` 要同時放行該網址的 `https://` 與 `wss://`。聊天 WebSocket 只會把 `https` 換成 `wss`，接 `http://` 的本機後端時聊天連不上。

Firebase 設定檔（`lib/firebase_options.dart`、`android/app/google-services.json`、`ios/Runner/GoogleService-Info.plist`）已經在 repo 裡。Google 登入失敗時，多半是本機 debug keystore 的 SHA-1 沒登記到 Firebase 專案，排查步驟見 [docs/google-signin-troubleshooting.md](docs/google-signin-troubleshooting.md)。

### 測試

```bash
flutter analyze
flutter test
```

部分測試跟日期有關，CI 固定用台灣時區跑（`TZ=Asia/Taipei`），本機時區不同時可能出現差異。

整合測試要在真機或模擬器上跑，裝置上的 App 要先用 Google 登入過。API Inspector 會用登入中的帳號對**正式後端**發出寫入請求，部分會自動還原，請用測試帳號：

```bash
flutter test integration_test/api_inspector_test.dart -d <device_id>
```

串接新端點前，先用 API Inspector 確認後端原始格式，再寫 model 與 service。錄製 fixture 供 `test/contract/` 使用的方式見 [docs/api-inspector.md](docs/api-inspector.md)。

## 建置與發布

| 目標    | 方式                                                                                                       |
| ------- | ---------------------------------------------------------------------------------------------------------- |
| Android | `flutter build appbundle --release`，上傳 Google Play 封閉測試。需要 `android/key.properties`（未進版控）指向正式金鑰，沒有時退回 debug 簽章 |
| iOS     | Codemagic 的 `ios-testflight` workflow 建置並上傳 TestFlight；`ios-check` 只做未簽章建置檢查，見 [codemagic.yaml](codemagic.yaml) |
| Web     | GitHub Actions：PR 跑 analyze、test、build，合進 `master` 後部署到 Firebase Hosting；只在 App 相關路徑有變動時觸發 |

升版時三件事一起做：

1. 改 `pubspec.yaml` 的 `version`（名稱+build 號，Android 與 iOS 共用 build 號）。
2. 改 `remoteconfig.template.json` 的 `latest_version_*`，要強制更新時一併調 `min_version_*`。合進 `master` 後 GitHub Actions 會比對線上設定，經核准才發布。
3. 編出新的 release AAB。
