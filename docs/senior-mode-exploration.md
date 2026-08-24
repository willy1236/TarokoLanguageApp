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

3. **調整 textScaler 策略** — 現有 `main.dart` 的 `clamp(0.85–1.15)` 上限會擋住精簡模式想要的放大字級，需改成依精簡模式開關切換不同 clamp 範圍（例如一般 0.85–1.15、精簡模式 1.0–1.5），並讓 tokens 層（任務1）感知這個縮放。

4. **制定資訊密度規則 + fallback 機制** — 定義精簡模式下的密度上限（如列表卡片最多顯示幾個欄位、首頁區塊數量上限），並確立「未特製精簡版頁面一律 fallback 回正常模式畫面」的規則與程式碼路徑（例如 `SeniorModeController.hasCustomLayout(routeName)` 之類的查詢介面）。此任務決定後續任務 6 每個頁面「要不要做精簡版」的判斷依據，需在任務 6 之前定案。

5. **導航簡化** — 修改 `main.dart`（`MainContainer`）與 `truku_bottom_tab.dart`：精簡模式下減少分頁數量、放大 `TrukuBottomTab` 觸控熱區，範圍集中、風險可控。

6. **無障礙補強** — 目前僅 4 處 `Semantics`、0 個 `Tooltip`，覆蓋率最低但工作量最大。建議先從長者實際會用的核心頁（社群/視訊通話、活動、文化影音、個人資料）補起，學習模組排在後面，而非一次全站覆蓋。

7. **高複雜度互動畫面另開精簡版流程** — 依「長者實際使用情境」重新排序優先級（互動性高、情感連結強的功能優先，學習功能因長者實用性較低而調降）：
   1. `video_call_screen.dart` / 社群互動相關畫面（視訊通話，長者高頻使用、UI 密度最高）
   2. `events_screen.dart` / `event_detail_screen.dart`、文化影音（`video_detail_screen.dart`/`article_detail_screen.dart`）
   3. `profile_screen.dart`、`my_bookmarks_screen.dart`/`my_likes_screen.dart`（個人資料與收藏清單，8/24 新增）
   4. 表單類：`event_compose_screen.dart`、`forum_compose_screen.dart`（複雜表單，8/24 後 event_compose 又新增 429 行改動，複雜度更高）、`avatar_crop_screen.dart`（拖曳裁切手勢對長者不友善）
   5. 新增的 4 組搜尋頁（`article_search_screen.dart` 等，8/24 新增，互動密度高但目前文件未評估，需一併納入評估範圍）
   6. `listening_quiz_screen.dart` 系列等 Learn 模組（多步驟測驗，長者實用性較低，**優先級最低**）

8. **動效關閉開關** — 精簡模式下關閉 `video_waiting_screen.dart`、`reward_overlay.dart` 的 `AnimationController`/implicit animation，範圍小、可放最後做。

任務 1→2→3→4 是地基（tokens、狀態架構、縮放策略、密度規則彼此依賴，需連續做，且需在此階段把「精簡為輔、正常為主」與深模組拆分定案），5→6 可平行進行，7→8 是收尾的高成本畫面客製化，其中任務 7 已依長者使用情境重新排序，學習模組排最後。
