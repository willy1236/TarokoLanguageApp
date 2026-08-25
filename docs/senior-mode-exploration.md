# 長者精簡介面模式 — 技術現況探索報告

日期：2026-08-24（含當日 4 個 commit 的異動追蹤更新）

## 背景

評估 App 若要新增「給老人的精簡介面」模式，除了 UI 排版調整外還需要處理哪些技術層面。以下為對現有程式碼庫的探索結果，作為後續規格與規劃的依據。

## 1. 設計系統架構

- **無獨立 `theme.dart`，也沒有 design tokens 檔案系統。**
- 唯一色票來源：`lib/core/constants/app_colors.dart`（`abstract class AppColors`），註解標示對應 `design-tokens.jsx` 的 `TRUKU_COLORS`，但尚未在 Flutter 端做成完整 `ThemeExtension`。
- `ThemeData` 直接寫死在 `lib/main.dart`（約 80–93 行），只設了 `brightness: dark`、`colorScheme`、`textTheme`（`GoogleFonts.notoSansTcTextTheme`），沒有拆出獨立 theme provider 或 light/dark 切換機制。
- `lib/screens/forum/forum_theme.dart` 是論壇模組局部樣式常數，非全域主題。
- 字型全域用 Noto Sans TC（`google_fonts`），無自訂字級 tokens（如 `AppTypography`）。

## 2. 字體大小處理方式

- 專案中 `fontSize:` 出現約 **524 次**（原 452 次，8/24 新增按讚收藏/搜尋等畫面後增加），全部是各畫面內散落的 `TextStyle(fontSize: 14)` 這類寫死數值，**沒有集中管理**。
- **[2026-08-24 更新]** `lib/main.dart`（`MaterialApp.builder`）已加入全域 `textScaler` 防護：用 `mediaQuery.textScaler.clamp(minScaleFactor: 0.85, maxScaleFactor: 1.15)` 限制系統字體縮放範圍，防止極端放大導致的破版。**但這是「限制」不是「放大」**——精簡模式若要主動放大字級，仍需另外的機制（此 clamp 的 `maxScaleFactor: 1.15` 上限反而會擋住精簡模式想要的更大字級，需評估是否要為精簡模式另開路徑或調整此上限）。
- 大量固定像素排版（尤其論壇卡片、測驗題目 UI）在系統字體放大或精簡模式強制放大字級時，破版風險依然存在（未見 `FittedBox`/`AutoSizeText` 等），現有 clamp 只做了防護下限保護，未解決排版彈性問題。

## 3. 導航架構

- **Navigator 1.0**，非 go_router（`pubspec.yaml` 無此依賴）。
- `MaterialApp.routes`（`lib/main.dart`）定義少數具名路由（`/splash /login /complete-profile /terms-consent /home /shop /backpack`，8/24 新增 `/terms-consent` 服務條款同意流程），其餘畫面靠 `Navigator.push(MaterialPageRoute(...))` 直接跳轉。
- App Shell 是 `MainContainer`（`lib/main.dart`），用 `IndexedStack` + 自製 `TrukuBottomTab`（`lib/shared/widgets/truku_bottom_tab.dart`）做 7 個分頁（首頁/學習/文化/社群/廣場/活動/個人資料）。
- 手勢返回：用 `PopScope(canPop: false)` 攔截返回鍵，自訂 `_handleBack` 邏輯（分頁優先跳回首頁，首頁才彈出確認退出對話框）。精簡模式若要簡化導航需同步改這段邏輯。
- 無抽屜選單（Drawer），但個別功能（活動、論壇、學習）內部各自有多層 push 導航。

## 4. 無障礙支援現況

- `Semantics` widget 僅出現 **4 處**，全部集中在 `lib/screens/learn/`（`lesson_card_screen.dart`、`listening_placement_screen.dart`、`listening_quiz_screen.dart`、`quiz_placement_screen.dart`）。
- `Tooltip(` **完全沒有使用**。
- 整體無障礙支援程度很低，其餘大量畫面（首頁、社群、論壇、活動、商店等）未見任何無障礙標註。**此為需要大量補強的部分。**

## 5. 使用者設定/偏好儲存機制

- `pubspec.yaml` 中沒有 `shared_preferences` 依賴，專案內也搜不到任何 `SharedPreferences` 使用。
- 唯一本機儲存機制是 `flutter_secure_storage`（僅用於 `lib/services/auth_service.dart` 存 token），屬安全性儲存，非一般偏好設定用途。
- 目前無語言/主題模式等使用者偏好持久化的既有模式可沿用。若要加「精簡模式」開關，需**從零導入 `shared_preferences`（或類似方案）**。
- 專案未使用任何狀態管理框架（無 Provider/Riverpod/Bloc），畫面間全靠 `setState` + 建構子傳參，需自行設計全域狀態讓 `MainContainer` 及各 screen 讀取套用。

## 6. 主要功能頁面清單（`lib/screens/`）

- **Auth**：`login_screen.dart`、`complete_profile_screen.dart`
- **Home**：`home_screen.dart`
- **Learn（互動較複雜）**：`lesson_card_screen.dart`、`listening_mode_screen.dart`、`listening_quiz_screen.dart`（667 行）、`listening_correction_screen.dart`、`listening_placement_screen.dart`、`quiz_placement_screen.dart`、`placement_result_screen.dart`、`vocab_level_screen.dart`
- **Culture**：`culture_screen.dart`、`article_detail_screen.dart`（Markdown 渲染）、`video_detail_screen.dart`（HLS 影音播放，`better_player_plus`）
- **Community（互動最複雜）**：`community_screen.dart`、`video_call_screen.dart`（699 行，即時視訊通話）、`video_waiting_screen.dart`（263 行，含 AnimationController）
- **Events**：`events_screen.dart`、`event_detail_screen.dart`、`event_compose_screen.dart`（475 行，複雜表單）、`my_events_screen.dart`、`reminder_compose_screen.dart`
- **Forum**：`forum_board_view.dart`、`forum_detail_screen.dart`、`forum_compose_screen.dart`、`forum_bookmarks_screen.dart`、`forum_notifications_screen.dart`、`forum_search_screen.dart`、`forum_liked_posts_list.dart`、`forum_liked_comments_list.dart`（後兩者為 8/24 新增）及相關 widgets（貼文卡、留言、圖片格線、檢舉表單）
- **History**：`history_screen.dart`、`listening_history_detail_screen.dart`、`quiz_history_detail_screen.dart`、`report_question_dialog.dart`
- **Profile**：`profile_screen.dart`、`avatar_crop_screen.dart`（圖片裁切拖曳，`crop_your_image`）、`my_bookmarks_screen.dart`、`my_likes_screen.dart`（8/24 新增，全模組收藏/按讚清單彙整頁）
- **Terms**：`terms_consent_screen.dart`（8/24 新增，服務條款/隱私權政策同意流程，303 行複雜度不低）
- **其他**：`backpack_screen.dart`、`plaza_screen.dart`、`shop_screen.dart`、`millet_ledger_screen.dart`、`splash_screen.dart`

**[2026-08-24 新增功能]** 「按讚/收藏」與「搜尋」功能已擴及影音、文章、活動、論壇四模組，各自新增獨立搜尋頁與按讚/收藏清單頁（共 8 個新畫面：`article_search_screen.dart`、`article_liked_bookmarked_list.dart`、`video_search_screen.dart`、`video_liked_bookmarked_list.dart`、`event_search_screen.dart`、`event_liked_bookmarked_list.dart`、`forum_liked_posts_list.dart`、`forum_liked_comments_list.dart`），畫面規模與互動密度快速增加，精簡模式規劃需一併涵蓋，避免規格落後於現有功能面。

**精簡模式最需要優先處理**：
1. `video_call_screen.dart` — 即時視訊，UI 密度與操作複雜度最高
2. `avatar_crop_screen.dart` — 拖曳裁切手勢對長者不友善
3. `event_compose_screen.dart` / `forum_compose_screen.dart` — 複雜表單
4. `listening_quiz_screen.dart` 系列 — 多步驟測驗互動

## 7. 動畫使用情況

- `AnimationController` 僅出現在 2 個檔案：`video_waiting_screen.dart`、`reward_overlay.dart`（獎勵彈出動畫）。
- Implicit animations（`AnimatedContainer`/`AnimatedOpacity`/`AnimatedSwitcher`/`TweenAnimationBuilder`/`AnimatedBuilder`）同樣只出現在這兩個檔案。
- `Hero(` 動畫用於 6 個畫面轉場：`backpack_screen.dart`、`culture_screen.dart`、`event_detail_screen.dart`、`learn_screen.dart`、`profile_screen.dart`、`shop_screen.dart`。
- 整體動畫使用量不高、集中度低，若要「降低動效」，改動範圍可控，主要調整這 8 個檔案即可。

## 8. 產品面補充考量

以下為技術探索之外，規劃精簡模式時需一併納入的產品/架構原則：

1. **資訊密度也是精簡的一環，不只放大字體/按鈕**：精簡畫面應減少單一畫面同時呈現的資料量（如列表卡片欄位數、首頁區塊數），而非僅將現有版面等比放大。任務 6 的精簡版流程設計需包含「砍資訊」而非只做「放大版」。
2. **精簡模式是正常模式的附加層，非平行架構**：目前規劃以正常模式為主體，精簡模式開啟後，凡未特製精簡版的頁面，一律 fallback 回正常模式畫面（差異只在任務1–3的 tokens/縮放/密度層生效），而非每頁都要做兩份。維護架構上需把「精簡專屬邏輯」與「共用邏輯」明確拆開（例如透過 `SeniorModeController` 開關 + 精簡版 widget 覆寫，而非在既有 widget 內大量 `if (seniorMode)` 分支），避免精簡邏輯滲透污染既有畫面程式碼。
3. **採用深模組（deep module）原則**：精簡模式的核心邏輯（tokens 換算、密度規則、精簡版 widget）應封裝成介面簡單、內部實作完整的模組，讓呼叫端（各 screen）改動量小；避免淺模組式的到處加參數、到處判斷開關，否則後續維護成本會隨頁面數量線性上升。
4. **依長者實際使用情境重新排序優先級**：長者較常使用互動性高、情感連結強的功能（社群、視訊通話、活動、文化影音），學習功能（Learn 模組的測驗/聽力/課程卡）對長者族群實用性較低，規劃精簡版時優先級應調降。任務 6 的處理順序建議改為：**視訊通話／社群互動 → 活動／文化影音 → 個人資料／收藏清單 → 表單（活動報名、論壇發文） → 學習測驗系列（最低優先）**。

## 技術面總結與建議落地順序

1. **無設計 tokens 抽象層**：字型/間距/圓角完全寫死在各畫面，需先建立 `AppTypography`/`AppSpacing` 等 tokens，才能做到「精簡模式一鍵放大」。
2. **textScaler 已有基礎防護，但方向與精簡模式相反**：8/24 起 `main.dart` 已用 `MediaQuery.textScaler.clamp(0.85–1.15)` 限制系統字體縮放範圍，防止過度放大破版；但精簡模式的需求通常是「主動放大」，現有上限 1.15 反而可能不夠用，需評估另開精簡模式專屬的縮放路徑（例如依開關切換不同 clamp 範圍）。524 處固定 fontSize 本身仍未做相對單位化，排版彈性問題未解決。
3. **無偏好儲存機制**：需新增 `shared_preferences` 依賴 + 全域狀態（用 `ChangeNotifier` 即可，不必上 Provider）存精簡模式開關。
4. **無障礙覆蓋率極低**（僅 4 處 Semantics，0 個 Tooltip），此塊工作量最大，需補齊 Semantics 標籤與觸控熱區。
5. **導航是自訂 IndexedStack + PopScope**，若精簡模式要簡化操作路徑（減少分頁、加大按鈕熱區），需修改 `main.dart` 與 `truku_bottom_tab.dart`，改動集中、風險可控。
6. **動畫集中在少數檔案**，關閉/簡化動效的改動範圍小。
7. 最複雜的互動畫面（視訊通話、頭像裁切拖曳、多個複雜表單）將是精簡模式體驗與工程投入的重點瓶頸。

建議落地順序：
① 建立 `AppTypography`/`AppSpacing` tokens 取代寫死數值 →
② 加 `shared_preferences` + 簡單全域狀態存精簡模式開關 →
③ 補 Semantics/加大觸控熱區 →
④ 針對視訊通話、頭像裁切、複雜表單、多步驟測驗另做精簡版流程。

## 落地任務清單（依序執行）

1. **建立設計 tokens 層**（`AppTypography`/`AppSpacing`/`AppRadius`）— 取代散落的 524 處 `fontSize:` 寫死值，讓後續放大有統一開關。無此層，精簡模式無法一鍵套用。

   **[2026-08-24 已完成第一步]**
   - 新增 `lib/core/constants/app_typography.dart`：`abstract class AppTypography`，語意命名字級 `caption(11) / body(13) / bodyLarge(14) / subtitle(16) / title(18) / headline(22)`，依現有畫面 fontSize 分布擬定。
   - 新增 `lib/core/constants/app_spacing.dart`：`abstract class AppSpacing`，4/8 倍數階梯 `xs(4) / sm(8) / md(16) / lg(24) / xl(32)`。
   - 新增 `lib/core/constants/app_radius.dart`：`abstract class AppRadius`，依現有畫面 `BorderRadius.circular(` 常見值擬定 `sm(8) / md(12) / lg(16) / xl(24)`。
   - `lib/main.dart`：新增 `import 'core/constants/app_typography.dart';`，`ThemeData.textTheme`（原約第 91–93 行）由只覆寫 `bodyMedium` 顏色，改為套用 `AppTypography` 補齊 `bodySmall/bodyMedium/bodyLarge/titleSmall/titleMedium/titleLarge` 六個層級的 `fontSize`。
   - `flutter analyze` 對新檔案與 `main.dart` 無警告/錯誤。
   - **範圍限制**：本次僅建立 tokens 並套用全域 `ThemeData`，**未**逐一替換既有 524 處畫面內寫死的 `fontSize:`——那些值仍會覆蓋全域 `TextTheme`，維持原有視覺不受影響，屬於後續各畫面精簡化/重構時再漸進替換。
   - **與探索推測的差異**：`BorderRadius.circular(` 實際使用點約 190 處，分布未逐一統計精確頻率，`AppRadius` 數值採常見慣例值（8/12/16/24）而非統計眾數，未來若發現與實際主流值落差大可再調整。

2. **偏好儲存 + 全域狀態（深模組設計）** — 導入 `shared_preferences` 存精簡模式開關，寫一個 `ChangeNotifier`（如 `SeniorModeController`）讓 `MainContainer` 及各 screen 讀取套用。介面對外只需暴露「開關狀態 + 是否有精簡版可用」，內部的 tokens 換算、密度規則、fallback 判斷都封裝在模組內，避免各 screen 內部散落 `if (seniorMode)` 判斷。這是模式能「打開/記住/生效」的基礎設施，也是後續「精簡為輔、正常為主」架構的落點。

   **[2026-08-24 已完成第二步]**
   - `pubspec.yaml`：新增 `shared_preferences: ^2.3.3` 依賴。
   - 新增 `lib/services/senior_mode_controller.dart`：`class SeniorModeController extends ChangeNotifier`，本專案首個具實例、非 static-only 的 service。對外只暴露 `enabled`（getter）與 `setEnabled(bool)`；`load()` 於啟動時從 `SharedPreferences` 還原狀態，`setEnabled` 寫入並 `notifyListeners()`。同檔案提供 top-level 單例 `final seniorModeController = SeniorModeController();`，比照 `lib/main.dart` 既有 `navigatorKey`/`scaffoldMessengerKey` 的宣告方式。
   - `lib/main.dart`：`main()`（`runApp` 前）新增 `await seniorModeController.load()`，比照 `FcmService.init()` 的 try/catch 保護，讀取失敗不阻斷啟動、維持預設關閉。`KariTrukuApp.build()` 改為用 `ListenableBuilder` 監聽 `seniorModeController` 包住原本的 `MaterialApp`（原 build 內容搬到新增的 `_buildApp()`），開關狀態變化時觸發全域 rebuild——這是任務3（textScaler 依開關切換 clamp 範圍）會用到的掛點，本次僅接好骨架，`builder:` 內部縮放邏輯尚未依開關分支。
   - `flutter pub get` 成功解析；`flutter analyze` 對 `lib/main.dart`、`lib/services/senior_mode_controller.dart` 無警告/錯誤。
   - **範圍限制**：本次未加任何 UI 開關（如個人資料頁的 Switch），純粹狀態骨架；也未實作探索報告提到的 `hasCustomLayout(routeName)` 之類任務4查詢介面，僅預留擴充點。尚未做「重啟 App 驗證還原」的手動測試（因無 UI 可觸發 `setEnabled`），留待接上任務3/4/或最小測試開關時一併驗證。

3. **調整 textScaler 策略** — 現有 `main.dart` 的 `clamp(0.85–1.15)` 上限會擋住精簡模式想要的放大字級，需改成依精簡模式開關切換不同 clamp 範圍（例如一般 0.85–1.15、精簡模式 1.0–1.5），並讓 tokens 層（任務1）感知這個縮放。

   **[2026-08-24 已完成第三步]**
   - `lib/main.dart`：`_buildApp` 的 `MaterialApp.builder`（原第 136–147 行）新增 `final seniorMode = seniorModeController.enabled;`，`textScaler.clamp` 的 `minScaleFactor`/`maxScaleFactor` 改依 `seniorMode` 三元分支：一般模式維持 `0.85–1.15` 不變，精簡模式改為 `1.0–1.5`。因 `_buildApp` 已包在外層 `ListenableBuilder(listenable: seniorModeController, ...)` 內，`builder:` 內直接讀 `enabled` 即可拿到即時值，不需額外監聽。
   - `AppTypography` 字級 tokens 本身未改值——放大交給 `textScaler` 處理（Flutter 全域文字縮放機制本意），tokens 只負責提供基準字級。
   - `flutter analyze` 對 `lib/main.dart` 無警告/錯誤。
   - **範圍限制**：目前沒有 UI 開關可觸發 `setEnabled(true)`（任務 2 已知限制），本次僅完成邏輯分支，尚未做「精簡模式下文字實際放大超過 1.15 倍」的肉眼驗證，留待接上 UI 開關（個人資料頁 Switch，屬後續任務）時一併驗證。

4. **制定資訊密度規則 + fallback 機制** — 定義精簡模式下的密度上限（如列表卡片最多顯示幾個欄位、首頁區塊數量上限），並確立「未特製精簡版頁面一律 fallback 回正常模式畫面」的規則與程式碼路徑（例如 `SeniorModeController.hasCustomLayout(routeName)` 之類的查詢介面）。此任務決定後續任務 6 每個頁面「要不要做精簡版」的判斷依據，需在任務 6 之前定案。

   **[2026-08-24 已完成第四步]**
   - 新增 `lib/core/constants/app_density.dart`：`abstract class AppDensity`，定義精簡模式下的顯示上限，目前先訂 `maxListCardFields(3)`（列表卡片最多欄位數）、`maxHomeSections(4)`（首頁最多區塊數）——先給合理預設值，後續頁面客製化（任務 6/7）時可依實際內容調整,不追求本次精確。
   - `lib/services/senior_mode_controller.dart`：新增 `hasCustomLayout(String routeName)`，內部用 `static const Set<String> _customLayoutRoutes = {}`（目前為空）查表回傳該路由是否有精簡版畫面。未來任務 6/7 做完某頁精簡版時把路由名加進這個 Set 即可，呼叫端邏輯不用改。
   - `flutter analyze` 對 `lib/services/senior_mode_controller.dart`、`lib/core/constants/app_density.dart` 無警告/錯誤。
   - **範圍限制**：本次未改動任何既有 screen——`hasCustomLayout` 目前沒有呼叫方（尚無任何精簡版頁面），純粹搭好任務 5–8 會用到的查詢介面，避免任務 4 滲透去改各畫面。`AppDensity` 的數值也還沒有任何畫面實際引用，屬預留 tokens。

5. **導航簡化** — 修改 `main.dart`（`MainContainer`）與 `truku_bottom_tab.dart`：精簡模式下減少分頁數量、放大 `TrukuBottomTab` 觸控熱區，範圍集中、風險可控。

   **[2026-08-24 已完成第五步]**
   - `lib/shared/widgets/truku_bottom_tab.dart`：`TrukuBottomTab` 新增 `seniorMode`（預設 `false`）建構子參數。新增 `_seniorHiddenKeys = {'learn'}`，依此在精簡模式下從 `_keys`/`_labels` 過濾出 `visibleIndices`（僅隱藏「學習」分頁，依探索報告 8.4 節長者使用情境優先級，學習模組實用性最低），但 `onTap` 回傳的仍是原始 index（0–5），`MainContainer` 端不需改 `IndexedStack` 對應關係。精簡模式下圖示 22×22→30×30、文字 10px→13px、水平 padding 4→8，並用 `ConstrainedBox(minWidth/minHeight: 56)` 確保熱區達標；一般模式視覺與熱區完全不變。
   - `lib/main.dart`：`MainContainer.build()` 改用 `ListenableBuilder(listenable: seniorModeController, ...)` 包住原本的 `PopScope`/`Scaffold`，讀取即時 `seniorMode`；新增 `_seniorHiddenIndex = 1`（LearnScreen），當精簡模式開啟且 `_currentIndex` 停在被隱藏的學習分頁時，透過 `addPostFrameCallback` 呼叫 `_navigate(0)` 導回首頁，避免使用者卡在消失的分頁上。`TrukuBottomTab` 呼叫處新增 `seniorMode: seniorMode` 傳入。
   - `flutter analyze` 對 `lib/main.dart`、`lib/shared/widgets/truku_bottom_tab.dart` 無警告/錯誤。
   - **範圍限制**：`IndexedStack` children 順序/數量、`_profileIndex`、`_openProfile`/`_closeProfile`、`PopScope`/`_handleBack`（返回鍵邏輯）皆未改動，僅動了底部分頁顯示與熱區——範圍嚴格限定在探索報告任務 5 的敘述內，避免蔓延到導航殼層其他邏輯。因目前仍無 UI 開關可觸發 `setEnabled(true)`（任務 2/3 已知限制延續），本次未做「精簡模式下分頁確實消失、熱區確實放大」的肉眼驗證，留待接上個人資料頁 Switch 時一併驗證。

6. **無障礙補強** — 目前僅 4 處 `Semantics`、0 個 `Tooltip`，覆蓋率最低但工作量最大。建議先從長者實際會用的核心頁（社群/視訊通話、活動、文化影音、個人資料）補起，學習模組排在後面，而非一次全站覆蓋。

7. **高複雜度互動畫面另開精簡版流程** — 依「長者實際使用情境」重新排序優先級（互動性高、情感連結強的功能優先，學習功能因長者實用性較低而調降）：
   1. `video_call_screen.dart` / 社群互動相關畫面（視訊通話，長者高頻使用、UI 密度最高）
   2. `events_screen.dart` / `event_detail_screen.dart`、文化影音（`video_detail_screen.dart`/`article_detail_screen.dart`）
   3. `profile_screen.dart`、`my_bookmarks_screen.dart`/`my_likes_screen.dart`（個人資料與收藏清單，8/24 新增）
   4. 表單類：`event_compose_screen.dart`、`forum_compose_screen.dart`（複雜表單，8/24 後 event_compose 又新增 429 行改動，複雜度更高）、`avatar_crop_screen.dart`（拖曳裁切手勢對長者不友善）
   5. 新增的 4 組搜尋頁（`article_search_screen.dart` 等，8/24 新增，互動密度高但目前文件未評估，需一併納入評估範圍）
   6. `listening_quiz_screen.dart` 系列等 Learn 模組（多步驟測驗，長者實用性較低，**優先級最低**）

   **[2026-08-24 已完成部分實作：個人資料頁 + 精簡模式開關 UI]**
   - 優先做了「開關 UI」而非完全照順序 1→2→3，因為前 5 步完成後**沒有任何 UI 能觸發 `seniorModeController.setEnabled(true)`**，開關本身必須放在個人資料頁，所以先接通這個入口，讓後續任務 7 其他頁面能被實際測試到。
   - `lib/screens/profile/profile_screen.dart`：
     - `build()` 改為 `ListenableBuilder(listenable: seniorModeController, ...)` 包住原本內容（比照 `main.dart` 既有慣例），讀取即時 `seniorModeController.enabled` 並分支組出不同的 section 清單餵給同一個 `ListView`（未在各 helper 內部散落 `if (seniorMode)`）。
     - `_buildPreferencesSection()` 新增「精簡模式」開關列，重用既有 `_switchRow(label, on, {required onChanged})`（原本唯一可互動的自製 pill switch，用於「是否原住民」鎖定列），呼叫 `seniorModeController.setEnabled(v)`。
     - 精簡模式開啟時，`ListView` 只保留：`_buildHero`（精簡掉已學詞彙/通話次數/發文 3 個統計 cell，只留頭像/姓名/部落）、`_buildMyLikesBookmarksSection`（我的收藏／我按讚的內容）、`_buildPreferencesSection`（含開關本身）、`_buildOtherSection`（含「聯絡我們」）、`_buildLogout`。**隱藏**：`_buildInventorySection`（小米/背包/商店）、`_buildMyEventsSection`（我發起的活動）、`_buildAccountSection`（姓名/族語名字/部落等可編輯低頻欄位）。
     - `_navRow`（我的收藏/我按讚的內容）、`_buildOtherSection` 條列項目、`_switchRow`（含精簡模式開關本身）新增 `seniorMode` 參數，精簡模式下字級改用 `AppTypography.headline`（22px，原 14px）、垂直 padding 改用 `AppSpacing.lg`（24px，原 14px）、icon 放大至 24–30px（原 16–18px）、開關滑塊放大至 52×30px（原 36×22px）。首次套用後覺得一般模式本身字級偏小，精簡模式若只小幅放大不夠明顯，故加大到接近 2 倍字級的幅度，而非僅套用相鄰一級 tokens（如 `subtitle` 16px）。這是任務 1 tokens 第一次真正接進實際畫面（先前只套用在全域 `ThemeData`）。
     - Hero 姓名字級精簡模式下為 28px（一般模式 22px），同樣是「明顯放大」而非沿用 `AppTypography.headline`（22px，與一般模式打平、放大幅度不夠）的教訓後改用自訂值。
     - import 新增 `app_spacing.dart`、`app_typography.dart`、`senior_mode_controller.dart`。
   - `lib/services/senior_mode_controller.dart`：`_customLayoutRoutes` 從空集合加入 `'profile'`，並經由既有 `hasCustomLayout('profile')` 查詢介面走通（個人資料頁不是具名路由，用固定字串 key 代表，供後續頁面照樣造句）。
   - `flutter analyze` 對 `lib/screens/profile/profile_screen.dart`、`lib/services/senior_mode_controller.dart` 無警告/錯誤。
   - **範圍限制**：本次僅完成個人資料頁；`video_call_screen.dart`、活動、文化影音、表單、搜尋頁、學習測驗系列仍待後續任務 7 步驟。尚未做手動實機驗證（開關持久化重啟還原、底部導覽學習分頁消失/熱區放大、textScaler 實際放大超過 1.15 倍）——這些是前 5 步報告中反覆提到「留待接上 UI 開關時一併驗證」的項目，本次已接上開關但尚未執行手動驗證，留待下次操作 App 時確認。
   - **與探索推測的差異**：無重大差異；`hasCustomLayout` 的路由 key 命名採用畫面語意（`'profile'`）而非具名路由字串（因個人資料頁本來就不是 `MaterialApp.routes` 具名路由，只能靠 `IndexedStack` tab 切換），與探索報告任務 4 段落預期的用法一致。

   **[2026-08-25 已完成部分實作：論壇模組（貼文卡片 + 列表空/錯誤狀態）]**
   - 這次跳過原訂順序（1 視訊通話 → 2 活動/文化影音），改做論壇模組——依使用者本次指示直接指定，非重新排序建議。論壇貼文卡片（`ForumPostCard`）是全模組共用元件，`ForumBoardView` 又被看板、我的收藏、搜尋結果等 4+ 處呼叫，一次改動即覆蓋論壇多數瀏覽情境，槓桿較高。
   - **元件改為自行監聽全域開關，呼叫端零改動**：`ForumPostCard`、`ForumBoardView` 內部各自用 `ListenableBuilder(listenable: seniorModeController, ...)` 包住 build，直接讀 `seniorModeController.enabled`，而不是新增建構子參數要求呼叫端傳入。因為這兩個元件的呼叫點分散在 `forum_board_view.dart`、`forum_bookmarks_screen.dart`、`forum_search_screen.dart`、`my_bookmarks_screen.dart`、`plaza_screen.dart` 五個檔案，若採 `truku_bottom_tab.dart`（任務5）那種「呼叫端傳參數」模式，需要逐一改五處呼叫；改為元件自行監聽全域單例，這五個呼叫點完全不用動，符合探索報告 8.3 節「深模組」原則——呼叫端改動量趨近於零。這是比先前任務（2/3/5/6 皆走參數注入）更進一步的落地模式，往後其他共用元件（如 `forum_comment_tile.dart`）若要做精簡版，可比照此法。
   - `lib/screens/forum/widgets/forum_post_card.dart`：
     - 標題字級 15→`AppTypography.headline`（22px）、內文摘要 14→`AppTypography.title`（18px）、作者名 14→`AppTypography.subtitle`（16px）、看板名/時間 11→`AppTypography.body`（13px）、置頂標記 11→`AppTypography.body`。
     - 頭像 38→52px（含無圖時的姓名縮寫圓形頭像同步放大）。
     - 讚/留言 icon 16→30px、收藏 icon 18→34px（使用者反饋原本 24/28px 還不夠明顯後再加大一輪），讚數/留言數文字 12→`AppTypography.subtitle`（16px）；三個互動熱區的垂直 padding 6→12，比照任務6無障礙補強精神加大觸控範圍，避免長者手指誤觸鄰近按鈕。
     - **資訊密度砍除**（探索報告 8.1 節）：精簡模式下標題從最多 2 行砍到 1 行（放大後 2 行標題常把卡片撐得比內文摘要還高，且長者掃視卡片主要靠標題判斷是否點開）；內文摘要維持顯示但砍到 2 行（原 3 行）；標籤列（`#tag`）整段隱藏——對「要不要點進去」判斷幫助小，卻在字級放大後占用可觀垂直空間。
   - `lib/screens/forum/forum_board_view.dart`：空狀態標題 18→22px、說明文字與錯誤訊息文字加大到 16px、「重試」按鈕加大到最小 140×52 觸控尺寸。`_ForumEmptyState`/`_ForumErrorState` 新增必填 `seniorMode` 參數（皆為 private class，呼叫方僅限同檔案的 `_buildBody`，改動範圍可控）。
   - `lib/services/senior_mode_controller.dart`：`_customLayoutRoutes` 加入 `'forum'`。論壇非具名路由（靠廣場頁分頁/看板切換進入），與任務6個人資料頁一致，用畫面語意字串代表。
   - `flutter analyze` 對改動的三個檔案無新增警告/錯誤（`forum_board_view.dart` 有 1 處既有的 `use_null_aware_elements` info，與本次改動無關、非本次新增）。既有 `test/widgets/forum_post_card_test.dart`（5 個測試）與 `test/widgets/forum_board_view_test.dart`（12 個測試）共 17 個測試全數通過，未被本次改動破壞。
   - **範圍限制**：本次僅涵蓋論壇列表側（貼文卡片、看板/收藏/搜尋列表的空/錯誤狀態）。**未涵蓋**：`forum_detail_screen.dart`（貼文詳情 + 留言串，含 `forum_comment_tile.dart`）、`forum_compose_screen.dart`（發文表單，探索報告已列為表單類優先處理對象）、`forum_notifications_screen.dart`、`forum_search_screen.dart`/`forum_liked_posts_list.dart`/`forum_liked_comments_list.dart` 這幾個獨立畫面本身的版面（非共用元件的部分，如 AppBar、搜尋框、篩選 UI）、以及 `forum_report_sheet.dart`（檢舉表單）。`forum_theme.dart` 的淺色底色票未受影響，精簡模式不改變論壇配色，只調字級/間距/密度。未做手動實機驗證（開關持久化後論壇列表實際顯示效果），留待接上更多頁面或下次操作 App 時一併確認。
   - **與探索推測的差異**：無重大差異；`hasCustomLayout('forum')` 的粒度是「整個論壇模組的共用瀏覽元件」，比任務6 `'profile'` 對應單一畫面的粒度更粗——因為論壇沒有單一入口畫面可掛精簡版判斷，是靠元件自我監聽達成跨畫面一致，這點與探索報告任務4原先設想「以路由名查表」的用法略有出入，但介面本身（`hasCustomLayout(routeName)`）不用改，只是這次的呼叫語意從「畫面級」變成「模組級」的代表字串。

   **[2026-08-25 已完成部分實作：文化影音/文章模組]**
   - 依探索報告任務 7 排序（第 2 順位：活動／文化影音），且依使用者本次指示直接指定做「影音與文章模組頁」，涵蓋 `culture_screen.dart`（影音/文章共用清單首頁）、`video_detail_screen.dart`、`article_detail_screen.dart` 三個檔案。
   - **改用「呼叫端傳參數」模式，而非任務7論壇段落的「元件自行監聽」模式**：`CultureScreen`/`VideoDetailScreen`/`ArticleDetailScreen` 三者 build() 各自獨立 `ListenableBuilder(listenable: seniorModeController, ...)` 包住 `_buildScaffold(seniorMode)`，再把 `seniorMode` 當一般參數往下傳給所有私有 helper 方法與 `_VideoCard`/`_ArticleCard`/`_PlayButton`/`_ArrowIcon` 等子 widget。原因：這三個檔案彼此互不共用元件（`_VideoCard`/`_ArticleCard` 只在 `culture_screen.dart` 內部被呼叫，不像 `ForumPostCard` 有 5 個外部呼叫點），沒有「呼叫端分散難以逐一改」的問題，用參數傳遞比讓每個小 widget 各自監聽全域單例更直接、也更容易在同一個 build 週期內保持三個畫面各自不同區塊的 seniorMode 值一致。
   - `video_detail_screen.dart` / `article_detail_screen.dart`（結構幾乎相同，共用同一套字級/間距對應表）：
     - 標題 fontSize 20→26（未用 `AppTypography.headline` 22，因與 forum/profile 段落相同的教訓——相鄰 tokens 放大幅度不夠明顯，改用自訂值）；分類標籤 `_tag()` 10→`AppTypography.body`(13)；觀看數 icon 14→22、文字 12→`AppTypography.subtitle`(16)；`_engagementButton()` icon 18→30、文字 12→16、tap padding 6/4→12/8（比照論壇卡片熱區加大手法）；內文/描述 14→`AppTypography.title`(18)；錯誤狀態 icon 40→56、文字 15→`AppTypography.title`(18)。
     - **一般模式排版完全不變的做法**：原本 `Row`（分類標籤＋觀看數＋Spacer＋讚/收藏）在精簡模式因字級放大後容易溢出，改成 `seniorMode ? Wrap(...) : Row(...)` 兩條分支——一般模式維持原本單行 `Row` 結構逐字不動，精簡模式才改用可換行的 `Wrap`。初版曾寫成不分模式一律用 `Wrap`+兩個 `Row`，會連帶改變一般模式視覺（多一行），與規劃時「一般模式不受影響」的原則衝突，後續已修正為條件分支。
     - `article_detail_screen.dart` 額外處理 `MarkdownStyleSheet`：p 14→18、h1 20→26、h2 18→22、h3 16→20，blockquote 底色 box 與 strong/a 樣式不變。
   - `culture_screen.dart`：
     - Hero 標題 26→32、小標籤 11→`AppTypography.body`、副說明 12→`AppTypography.subtitle`、`_PlayButton` 加大 padding/icon/文字。
     - Tab 文字 16→`AppTypography.headline`(22)、族語小字 10→`AppTypography.body`；分類 chips 文字 13→`AppTypography.subtitle`，垂直 padding 8→12；影音/文章排序標籤 12→`AppTypography.subtitle`。
     - **影音 Grid 精簡模式下 2 欄→1 欄**（`crossAxisCount`、`childAspectRatio` 依 `seniorMode` 分支），避免字級/縮圖放大後 2 欄版位過擠——這是探索報告 8.1 節「資訊密度也是精簡的一環」在本次唯一動到版面欄數的地方。`_VideoCard` 精簡模式下縮圖高度 100→180、標題 14→`AppTypography.title` 且 `maxLines` 1→2（欄寬變寬後可容納 2 行仍不擠）。
     - `_buildFeaturedArticle`（精選文章卡）精簡模式下標題 19→24 且 `maxLines` 2→1，並**隱藏摘要文字**（比照論壇貼文卡密度砍除手法，標題放大後單行已足夠判斷是否點開）；`_ArticleCard`（一般清單項）精簡模式下縮圖 64→84px、分類標籤/標題放大，**隱藏「閱讀數/本週熱門」統計列**。`_ArrowIcon` 新增可選 `size` 參數供各處放大使用（一般模式維持 16px 預設值不變）。
   - `lib/services/senior_mode_controller.dart`：`_customLayoutRoutes` 加入 `'culture'`（影音/文章共用同一入口分頁，非具名路由，粒度比照任務7 `'forum'` 的模組級用法）。
   - `flutter analyze` 對 `video_detail_screen.dart`、`article_detail_screen.dart`、`culture_screen.dart`、`senior_mode_controller.dart` 四個檔案無警告/錯誤。專案內 `test/` 目前沒有 video/article/culture 相關的既有 widget test 可供回歸驗證（僅論壇模組有），故本次無測試套件可跑。
   - **範圍限制**：`video_search_screen.dart`、`article_search_screen.dart`、`video_liked_bookmarked_list.dart`、`article_liked_bookmarked_list.dart` 四個獨立清單/搜尋畫面本次**未涵蓋**（規劃時已列為後續任務範圍外）；`better_player_plus` 播放器原生控制列（播放/暫停/音量 UI）非本次可控範圍，僅調整播放器外層的標題/互動資訊卡。未做手動實機驗證（開關持久化後三畫面實際顯示效果、Grid 改 1 欄後的實際滾動體驗），留待接上更多頁面或下次操作 App 時一併確認。
   - **與探索推測的差異**：規劃階段原預期沿用論壇段落「元件自監聽、呼叫端零改動」的深模組模式，實作時改採「呼叫端傳參數」模式（見上），原因是本次三個檔案的 widget 樹沒有論壇那種多入口共用元件的情境，強行套用自監聽模式反而會讓 `_VideoCard`/`_ArticleCard` 這類單一畫面內部小元件各自重複訂閱同一個 `ChangeNotifier`，徒增不必要的 rebuild 邊界，故本次依實際結構選擇較單純的參數傳遞。
   - **實機驗證修正**：完成後實際跑在裝置上測試，精簡模式開啟時 `culture_screen.dart` 的影音列表出現 `RenderFlex overflowed by 32 pixels`——原因是精簡模式 1 欄的 `GridView.count` 仍套用固定 `childAspectRatio`（1.7），但縮圖放大到 180px 高、標題又放大且允許 2 行後，卡片實際需要的高度會依標題文字長度浮動，固定比例的格子放不下。修正為：精簡模式改用自然高度的 `Column`（逐張 `_VideoCard` 用 `Padding` 疊加，取消固定 aspect ratio），一般模式維持原本 2 欄 `GridView.count`（`childAspectRatio: 0.78`）完全不動。`flutter analyze` 修正後仍無警告/錯誤。這是任務 7 目前唯一一次有實機動態驗證機會（前幾步因無 UI 開關而只能做靜態檢查）並抓到問題的案例，提醒後續其他頁面用固定 aspect ratio 的 Grid／Card 若要放大字級或圖片，需優先考慮改用自然高度佈局，而非只調整比例數值去試誤。

8. **動效關閉開關** — 精簡模式下關閉 `video_waiting_screen.dart`、`reward_overlay.dart` 的 `AnimationController`/implicit animation，範圍小、可放最後做。

任務 1→2→3→4 是地基（tokens、狀態架構、縮放策略、密度規則彼此依賴，需連續做，且需在此階段把「精簡為輔、正常為主」與深模組拆分定案），5→6 可平行進行，7→8 是收尾的高成本畫面客製化，其中任務 7 已依長者使用情境重新排序，學習模組排最後。
