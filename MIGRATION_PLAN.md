# 語見太魯閣 — Flutter UI 遷移計畫

> 目標：將 `claude-design-src/` 內的所有設計稿完整對應到 Flutter 實作。
> 設計來源：JSX + HTML prototype（含 design-tokens.jsx / screens-*.jsx）
> 每個 Phase 為獨立 session 可接手的最小完整單位。

---

## 現況快照（2026-06-04）

### ✅ 已完成（Phase 0）
| 檔案 | 狀態 |
|---|---|
| `lib/core/constants/app_colors.dart` | 太魯閣設計代幣，完整對應 `TRUKU_COLORS` |
| `lib/shared/widgets/truku_painters.dart` | `TrukuWeavePainter`、`TrukuMountainsPainter` |
| `lib/shared/widgets/truku_widgets.dart` | `TrukuDiamond`、`TrukuChain` |
| `lib/screens/auth/login_screen.dart` | 完整依設計稿重構 |
| `pubspec.yaml` | 已加入 `google_fonts: ^6.2.1` |

### ✅ 已完成（Phase 1）
| 檔案 | 狀態 |
|---|---|
| `lib/screens/splash/splash_screen.dart` | SplashScreen，2.5 秒後跳轉 /login |
| `lib/shared/widgets/truku_bottom_tab.dart` | 6-tab 自訂 SVG 亮色底部導覽 |
| `lib/main.dart` | initialRoute `/splash`，ProfileScreen 改為 overlay |

### ✅ 已完成（Phase 2）
| 檔案 | 狀態 |
|---|---|
| `lib/screens/home/home_screen.dart` | HomeScreen 亮色主題，頂色條、標頭、今日進度卡、5 張 ModeCard |
| `lib/shared/widgets/mode_card.dart` | ModeCard + ModeIcon（lesson/film/comm/plaza/event 自訂 SVG）|
| `lib/main.dart` | IndexedStack index 0 → HomeScreen，移除 _OldHomeTab |

### ✅ 已完成（Phase 3）
| 檔案 | 狀態 |
|---|---|
| `lib/screens/learn/learn_screen.dart` | LearnScreen + UnitRow，5 個狀態（current/done/partial/locked/open） |
| `lib/screens/learn/lesson_card_screen.dart` | LessonCardScreen，深色主卡 + 播放按鈕 + 例句左邊框 |
| `lib/main.dart` | IndexedStack index 1 → LearnScreen，移除 _OldLearningTab |

### ✅ 已完成（Phase 4）
| 檔案 | 狀態 |
|---|---|
| `lib/screens/culture/culture_screen.dart` | CultureScreen，暗色主題，Hero 區、分頁切換、分類 chips、影片格、文章列表 |
| `lib/main.dart` | IndexedStack index 2 → CultureScreen，移除 _PlaceholderTab |

### ✅ 已完成（Phase 5）
| 檔案 | 狀態 |
|---|---|
| `lib/screens/community/community_screen.dart` | CommunityScreen，亮色主題，1on1 暗色大卡、主題 chips、耆老列表、最近通話 |
| `lib/screens/community/video_waiting_screen.dart` | VideoWaitingScreen，暗色，脈衝動畫 AnimationController，TrukuDiamond 中央 |
| `lib/screens/community/video_call_screen.dart` | VideoCallScreen，全屏暗色，計時器、自拍小窗、底部控制列（靜音/鏡頭/筆記/結束） |
| `lib/main.dart` | IndexedStack index 3 → CommunityScreen，移除 _PlaceholderTab |

### ✅ 已完成（Phase 6）
| 檔案 | 狀態 |
|---|---|
| `lib/screens/plaza/plaza_screen.dart` | PlazaScreen，亮色主題，動態/活動分頁，近期活動小卡、貼文列表、精選活動卡 |
| `lib/screens/plaza/events_screen.dart` | EventsScreen，亮色主題，篩選 chips、精選大卡、活動清單 |
| `lib/screens/plaza/compose_screen.dart` | ComposeScreen，動態/活動類型切換、文字輸入、標籤選擇、工具列 |
| `lib/main.dart` | IndexedStack index 4 → PlazaScreen，index 5 → EventsScreen，移除 _PlaceholderTab |

### ❌ 尚未遷移（lib/main.dart 內的舊版畫面）
- `HomeScreen`（版面完全不同，需重寫，Phase 2）
- `ProfileScreen`（需重寫，Phase 7）

### 新畫面（設計稿有、Flutter 完全未建）
QuizScreen、PlazaScreen、ComposeScreen、EventsScreen、ShopScreen、RewardScreen

---

## 字型使用規則

```dart
// 標題 / 大字
GoogleFonts.notoSerifTc(fontSize: 24, fontWeight: FontWeight.w600)

// 內文（全域 ThemeData 已設定，無需明寫）
GoogleFonts.notoSansTc(...)

// 族語拼音（最重要！每個單字卡都用）
GoogleFonts.crimsonPro(fontStyle: FontStyle.italic, fontSize: 56)

// 數字 / IPA 標音
GoogleFonts.jetBrainsMono(fontSize: 12)
```

## 顏色使用規則

```dart
// 暗色畫面（login, splash, culture, video call）
背景: AppColors.midnight (#1C0F0D)
漸層底: AppColors.primaryDeep (#4A0F0C)
文字: AppColors.creamLight (#FAF5EA)
強調: AppColors.gold (#C9A961)

// 亮色畫面（home, learn, plaza, profile）
背景: AppColors.creamLight (#FAF5EA)
卡片: AppColors.cream (#F2E8D5)
主色: AppColors.primary (#7A1F1A)
文字: AppColors.ink (#1C0F0D)
次要文字: AppColors.fog (#A89C88)

// 進度條（所有畫面）
填充: AppColors.gold
軌道: AppColors.creamDeep（亮色畫面）/ Colors.white12（暗色畫面）
```

---

## Phase 1 — App Shell 重構

**目標：** 重建導航架構，Tab 數量從 5 個改為 6 個，背景改為亮色。
**設計參考：** `claude-design-src/screens-home.jsx`（`BottomTab` function，第 386-419 行）

### Tab 結構（設計稿定義）

| index | key | 標籤 | icon |
|---|---|---|---|
| 0 | home | 首頁 | home |
| 1 | learn | 學習 | book |
| 2 | culture | 影音 | play |
| 3 | comm | 視訊 | chat |
| 4 | plaza | 廣場 | user |
| 5 | event | 活動 | cal |

> ⚠️ **注意：** Profile 不再是 Tab！改由首頁右上角頭像按鈕進入，以覆蓋方式顯示（見 `screens-home.jsx` 第 80-103 行）。

### BottomTab 視覺規格

```
背景: rgba(250, 245, 234, 0.92) + backdropFilter blur 20px
border-top: 1px solid AppColors.creamDeep
padding: 10px 8px 28px（底部留 28px 給 home indicator）
active icon: AppColors.primary
inactive icon: AppColors.fog
label: 10px, active 600, inactive 400
```

### Tab icon SVG 規格（自訂 SVG，非 Material icon）

每個 icon 都是自訂 SVG，需用 `CustomPaint` 或直接 `CustomPainter` 實作：
- home: `M3 11 L12 3 L21 11 V21 H3 Z` + `M9 21v-7h6v7`
- book: `M4 4h7v16H4z M13 4h7v16h-7z`
- play: circle r=9 + `M10 8 L16 12 L10 16Z`（filled）
- chat: `M4 5h16v12H10l-6 5z`
- user: circle r=4 + path
- cal: rect + path

### 路由更新

```dart
// 需新增路由
'/splash': SplashScreen
'/home': MainContainer（index 0）
'/learn': LearnListScreen
'/lesson': LessonCardScreen
'/culture': CultureScreen
'/profile': ProfileScreen（overlay，非路由）
```

### 驗收條件
- [x] 6-tab BottomNavigationBar，使用自訂 SVG icon
- [x] 亮色（creamLight）底色 Tab Bar
- [x] ProfileScreen 改為首頁 avatar 觸發的 Stack overlay
- [x] SplashScreen 作為 initialRoute，停留 2.5 秒後自動跳轉 `/login`

---

## Phase 2 — Splash & Home

**目標：** 實作啟動畫面與首頁（最重要的入口畫面）。
**設計參考：** `claude-design-src/screens-home.jsx`（全檔）

### SplashScreen 規格

- 背景：同登入頁漸層（midnight → primaryDeep → primary）
- 山脈：**兩層**，底層 height=180 opacity=0.85，上層 height=120 bottom=30 opacity=0.6
- 織紋：`TrukuWeavePainter(gold, opacity: 0.18)`
- 頂部裝飾：`TrukuChain(count: 9, size: 10, gap: 6)` at top 90
- 中央：Logo（200×200，暫用 Icon），放射狀金色光暈，Crimson Pro 斜體副標
- 底部 tagline：「說我們的話 · 走我們的山」cream 70% opacity
- **動作**：顯示後 2.5 秒自動 `pushReplacementNamed('/login')`

### HomeScreen 規格（亮色主題）

整體背景：`AppColors.creamLight`

**① 頂部色條（6px 高）**
- 背景：`AppColors.primary`
- 上面疊加 `TrukuWeavePainter(gold, opacity: 0.4, scale: 0.4)`

**② 標頭區（padding: top 60, h 24, bottom 18）**
- Logo 圖示（78×78，暫用語言圖示 AppColors.primary 色）
- 左：問候語 Crimson Pro italic 13px fog，「今天學什麼？」Noto Serif TC 24px 600 ink
- 右：Avatar 圓形（48×48，primary 底，gold border 2px）→ 點擊顯示 ProfileScreen overlay

**③ 今日進度卡（dark card）**
- 背景：`AppColors.ink`，圓角 18，padding 16/18
- 右上角：小米幣 chip（半透明金色框，顯示數字 320）
- 右背景：`TrukuDiamond(size: 120, color: gold)` 半透明裝飾
- 標籤：Crimson Pro italic 11px gold「TODAY · SAYANG」
- 標題：Noto Serif TC 22px「連續學習 **12** 天」（數字金色）
- 進度格：7 格小方塊（5 金色 + 2 白色 15%）
- 說明文字：13px creamLight 85%

**④ 模式卡格（2 欄，第一張全寬）**

| 卡片 | key | 背景色 | 前景色 | 強調色 | 大小 |
|---|---|---|---|---|---|
| 族語學習 | learn | primary | creamLight | gold | 全寬（span 2）|
| 文化影音 | culture | midnight | creamLight | gold | 半寬 |
| 視訊 | video | moss | creamLight | gold | 半寬 |
| 廣場 | plaza | creamLight | primary | primary | 半寬 |
| 活動 | event | gold | ink | primary | 半寬 |

每張卡片：
- 圓角 20，padding 18，minHeight 大=150 / 小=170
- 背景疊加 `TrukuWeavePainter(accent, opacity: 0.12, scale: 0.6)`
- 右上：Crimson Pro italic 11px accent（Truku 名稱）
- 左上：`ModeIcon`（自訂 SVG）
- 左下：中文名稱 Noto Serif TC 26px/22px，副標 12px 70% opacity
- `plaza` 卡片有 `border: 1.5px solid creamDeep`

**ModeIcon SVG 路徑**（需用 `CustomPainter` 或 `Path`）：
- lesson（書）: `M4 6h20v16H4z M14 6v16 M8 11h4 M8 15h4 M16 11h4 M16 15h4`
- film（影片）: rect + 三角播放 + 橫線
- comm（視訊）: rect 16×12 + 三角右耳
- plaza（人群）: 兩個 circle + 兩條 path
- event（日曆）: rect + 橫線 + 兩條豎線 + 勾

### 驗收條件
- [x] SplashScreen 2.5 秒後自動跳轉
- [x] HomeScreen 亮色主題，5 張 ModeCard 正確排列
- [x] 點擊 Avatar 出現 ProfileScreen overlay（帶返回按鈕）
- [x] 今日進度卡顯示正確（暗色，七格進度）

---

## Phase 3 — 族語學習流程

**目標：** 實作學習的核心功能畫面。
**設計參考：** `claude-design-src/screens-learn.jsx`（全檔）

### LearnScreen（單元列表）

背景：`AppColors.creamLight`

**頂部 Hero（primary 底）**
- padding: top 64, h 24, bottom 28
- 背景疊加 `TrukuWeavePainter(gold, opacity: 0.2, scale: 0.7)`
- 副標籤：Crimson Pro italic 12px gold「KARI TRUKU · 族語學習」
- 主標：Noto Serif TC 28px 600「一句一句，把話說回來」
- 統計：Noto Serif TC 18px gold 數字 + 13px 85% 文字說明

**單元列表（`UnitRow`）**

每一列（圓角 16，padding 14/16）：
- **狀態**：
  - `current`（進行中）：`AppColors.ink` 底
  - 一般：`AppColors.cream` 底 + `creamDeep` 1px border
  - `locked`：opacity 0.5
- **左側菱形框**（52×52）：
  - SVG `M26 4 L48 26 L26 48 L4 26 Z`（菱形輪廓，非 TrukuDiamond）
  - current → primary 底 + gold stroke
  - 進行中（0<pct<1）→ 疊加 strokeDasharray 金色進度
  - 中心顯示：Noto Serif TC 14px 600 單元號碼
- **中間文字區**：
  - Crimson Pro italic 11px fog/gold（Truku 名）
  - Noto Serif TC 17px 600 ink/creamLight（中文名）
  - 11px 進度文字（x/y句 或 鎖定說明）
- **右側圖示**：
  - locked → 鎖頭 SVG fog
  - current/open → 右箭頭 SVG（current 用 gold，其他 primary）

**預設單元資料**：
```dart
[
  { num: '01', zh: '日常問候', truku: 'Smbarux', words: 12, done: 12 },
  { num: '02', zh: '家人稱謂', truku: 'Lutut', words: 18, done: 14, current: true },
  { num: '03', zh: '部落地景', truku: 'Dgiyaq Alang', words: 16, done: 0 },
  { num: '04', zh: '狩獵與山林', truku: 'Mhuma Bgihur', words: 24, done: 0, locked: true },
  { num: '05', zh: '織布與染色', truku: 'Tminun', words: 20, done: 0, locked: true },
]
```

### LessonCardScreen（單字卡）

背景：`AppColors.creamLight`

**頂部進度列**（padding top 60）：
- 返回箭頭 SVG（ink 色）
- 漸層進度條：`LinearGradient(primary → gold)` 在 creamDeep 軌道上，height 6
- 右側「9 / 15」JetBrains Mono 12px fog

**單元標籤**（padding top 24）：
- Crimson Pro italic 12px fog「UNIT 02 · LUTUT」
- Noto Serif TC 18px 500 inkSoft「家人稱謂」

**主卡片（dark）**：
- 背景 ink，圓角 24，padding 32/24/28，minHeight 380
- 背景疊加 `TrukuWeavePainter(gold, opacity: 0.1, scale: 0.8)`
- 右上角：`TrukuDiamond(size: 26, color: gold)` opacity 0.6
- 提示文字：11px gold letterSpacing「聆聽 · 跟讀」
- **族語主詞**：Crimson Pro italic **56px** 500 creamLight
- **中文翻譯**：Noto Serif TC 22px 500 gold letterSpacing 0.15em
- **IPA 標音**：JetBrains Mono 11px cream 50% opacity

**播放按鈕列**：
- 主按鈕：gold 底 ink 字，height 56，Noto Serif TC 15px「播放發音」
- 副按鈕：透明底 gold border，width 56（慢速播放圖示）

**例句卡片**（marginTop 14）：
- creamDeep 底，圓角 14，`borderLeft: 3px solid primary`
- 11px fog「EXAMPLE · 例句」
- Crimson Pro italic 17px primary（族語句）
- 14px inkSoft（中文句）

**底部按鈕**：
- 「再聽一次」：creamLight 底 creamDeep border，Noto Serif TC 14px
- 「我會了 →」：primary 底 creamLight 字，Noto Serif TC 14px 600

### 驗收條件
- [x] LearnScreen 亮色主題，primary hero，5 個 UnitRow 含狀態區分
- [x] UnitRow 菱形框有進度 strokeDasharray
- [x] LessonCardScreen 深色主卡，Crimson Pro 56px 族語詞
- [x] 例句左邊框樣式正確

---

## Phase 4 — 文化影音（CultureScreen）

**目標：** 實作暗色的影音瀏覽畫面。
**設計參考：** `claude-design-src/screens-rest.jsx`（第 1-200 行）

### CultureScreen 規格

整體：`AppColors.midnight` 底，`AppColors.creamLight` 文字

**① Hero 影片區（height 360）**
- 背景漸層：mossDeep → midnight（上至下）
- 條紋占位圖：`repeating-linear-gradient(135deg, mossDeep 0 24px, midnight 24px 28px)`
- 疊加：`TrukuWeavePainter(gold, opacity: 0.25)`
- 底部漸層遮罩：transparent → midnight
- 頂部 nav（top 60）：左「LNGLUNGAN」Crimson Pro italic gold，右搜尋圓鈕
- 底部 info（bottom 24）：
  - 11px gold「本週精選 · GAYA」
  - Noto Serif TC 26px 600（標題）
  - 12px 70% opacity（作者 + 時長）
  - gold 底圓角播放按鈕（TrukuPlayIcon）

**② 分頁切換（影音 / 文章）**
- 底線 tab（active 用 gold 2px 底線）
- Noto Serif TC 16px 600，active gold / inactive fog
- Crimson Pro italic 10px 副標

**③ 分類 chips（horizontally scrollable）**
- `['全部', '口述歷史', '織布傳統', '祭儀', '部落音樂', '美食']`
- active：primary 底 creamLight 字
- inactive：transparent 底 + `cream 30%` border

**④ 影片格（2 欄 grid）**
每格：縮圖（條紋占位）+ 右側標題/副標/時長

### 驗收條件
- [x] 暗色主題全畫面
- [x] Hero 區有兩層漸層疊加
- [x] 分頁切換 gold 底線高亮
- [x] chips 橫向可捲動，active 狀態正確

---

## Phase 5 — 社群與視訊

**目標：** 實作社群配對、等待、視訊通話畫面。
**設計參考：** `claude-design-src/screens-rest.jsx`（CommunityScreen / VideoWaitingScreen / VideoCallScreen 部分）

### CommunityScreen（長輩配對）
- 亮色主題（creamLight 底）
- 長輩列表（頭像 + 名字 + 族語 + 在線狀態）
- 撥打按鈕 → 進入 VideoWaitingScreen

### VideoWaitingScreen（等待配對）
- 暗色（midnight）
- 脈衝動畫：`AnimationController` scale 1.0→1.4，opacity 1→0，循環
- 中央圓形頭像 + 狀態文字

### VideoCallScreen（視訊中）
- 全屏暗色
- 全屏模擬影像（條紋占位）
- 右上角小窗（自己的畫面）
- 底部控制列：靜音、攝影機、筆記、結束（紅色圓鈕）
- 頂部計時器（Mono 字體）
- 錄音指示紅點

### 驗收條件
- [x] VideoWaitingScreen 脈衝動畫流暢
- [x] VideoCallScreen 全屏佈局，控制按鈕功能佈局正確

---

## Phase 6 — 廣場與活動

**目標：** 實作社交貼文與活動列表。
**設計參考：** `claude-design-src/screens-rest.jsx`（PlazaScreen / ComposeScreen 部分）

### PlazaScreen
- 亮色主題
- 分頁：貼文 / 活動
- 貼文列表（頭像 + 內容 + 圖片）
- 活動列表（日期 + 地點 + 報名按鈕）

### ComposeScreen（發文 / 發活動）
- 標題輸入、內容輸入
- 標籤選擇、附件按鈕
- 頂部 AppBar：取消 / 發布

### 驗收條件
- [x] PlazaScreen 分頁切換正常
- [x] ComposeScreen 基本表單可輸入

---

## Phase 7 — 個人中心與商店

**目標：** 重構 ProfileScreen，新增 ShopScreen 與 RewardScreen。
**設計參考：** screens-rest.jsx（ProfileScreen 部分）+ design-tokens.jsx（小米幣系統）

### ProfileScreen 重構重點
- **目前**：深色 Tab 畫面
- **設計稿**：亮色（creamLight），從 HomeScreen overlay 顯示
- 頂部：頭貼 + 名字 + 等級（Truku 風格 Badge）
- 統計三格：連續學習 / 已學單字 / 社群貢獻
- 選單項目：學習進度、收藏、參與活動、帳號設定
- 登出按鈕（danger 紅色）

### ShopScreen（小米幣兌換）
- 小米幣餘額顯示（gold 底 chip）
- 商品格（圖示 + 名稱 + 售價）
- 兌換按鈕

### RewardScreen（獎勵彈出）
- 半透明暗色 Modal overlay
- 動畫：金色菱形放大 + 小米幣數字跳動
- 「+10 millet」顯示
- 確認按鈕

### 驗收條件
- [ ] ProfileScreen 改為亮色 overlay 模式
- [ ] ShopScreen 小米幣餘額顯示
- [ ] RewardScreen 動畫彈窗

---

## 共用元件清單（跨 Phase 使用）

以下元件建議在第一次需要時建立於 `lib/shared/widgets/`，供後續複用：

| 元件 | 建立於 Phase | 描述 |
|---|---|---|
| `TrukuBottomTab` | Phase 1 | 6-tab 亮色底部導航 |
| `ModeCard` | Phase 2 | 首頁模式入口卡片 |
| `ModeIcon` | Phase 2 | 自訂 SVG 模式圖示 |
| `TrukuHeroHeader` | Phase 3 | primary 底設計標題區 |
| `UnitRow` | Phase 3 | 學習單元列表項目 |
| `ProgressSegments` | Phase 2/3 | 方格式進度條（7格） |
| `CategoryChips` | Phase 4 | 橫向可捲分類標籤 |
| `TrukuTabBar` | Phase 4 | 底線式分頁（影音/文章） |
| `ElderListTile` | Phase 5 | 長輩列表項目 |
| `VideoControlBar` | Phase 5 | 視訊控制按鈕列 |
| `RewardOverlay` | Phase 7 | 獎勵動畫彈窗 |

---

## 給每個 Session 的工作說明

在接手任一 Phase 時，請依序執行：

1. **閱讀本文件**，確認當前 Phase 目標與範圍
2. **閱讀對應的設計 JSX 檔案**（`claude-design-src/screens-*.jsx`），理解視覺規格
3. **閱讀 `lib/core/constants/app_colors.dart`** 取得色彩常數
4. **確認已完成的 Phase**（不要重複實作）
5. 實作完後，**更新本文件**中對應 Phase 的驗收條件（打勾），並更新「現況快照」

---

## 設計檔案索引

| 檔案 | 包含畫面 |
|---|---|
| `claude-design-src/design-tokens.jsx` | 顏色、字型、全共用元件（Weave/Mountain/Diamond/Chain） |
| `claude-design-src/screens-login.jsx` | LoginScreen |
| `claude-design-src/screens-home.jsx` | SplashScreen、HomeScreen、ModeCard、BottomTab |
| `claude-design-src/screens-learn.jsx` | LearnScreen（單元列表）、LessonCardScreen（單字卡） |
| `claude-design-src/screens-rest.jsx` | CultureScreen、CommunityScreen、VideoWaitingScreen、VideoCallScreen、PlazaScreen、ComposeScreen、MapScreen、ProfileScreen |
