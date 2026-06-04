// 互動原型：navigation context + tap overlays
const { useState, useEffect, createContext, useContext, useCallback } = React;

const NavCtx = createContext(null);
const useNav = () => useContext(NavCtx);

// 點擊熱區 — 透明覆蓋元素，可點擊跳到指定畫面
function TapZone({ to, style, children, replace = false }) {
  const nav = useNav();
  return (
    <div
      onClick={(e) => { e.stopPropagation(); nav.go(to, { replace }); }}
      style={{ cursor: 'pointer', ...style }}
    >
      {children}
    </div>
  );
}

// Bottom tab 點擊區（蓋在原本的 BottomTab 上）
function BottomTabOverlay({ active }) {
  const tabs = ['home', 'learn', 'culture', 'comm', 'plaza'];
  return (
    <div style={{
      position: 'absolute', bottom: 0, left: 0, right: 0, height: 84,
      display: 'flex', zIndex: 20,
    }}>
      {tabs.map(t => (
        <TapZone key={t} to={t} style={{ flex: 1 }} />
      ))}
    </div>
  );
}

// 包裝畫面 + 注入互動覆蓋層
function Screen({ id, children, taps = [], tabActive = null, swipeBack = false }) {
  const nav = useNav();
  return (
    <div style={{ position: 'relative', width: '100%', height: '100%' }}>
      {children}
      {/* 點擊熱區 */}
      {taps.map((t, i) => (
        <TapZone key={i} to={t.to} style={{
          position: 'absolute', zIndex: 15,
          left: t.x, top: t.y, width: t.w, height: t.h,
        }} />
      ))}
      {/* 滑動返回 */}
      {swipeBack && (
        <div
          onClick={() => nav.back()}
          style={{
            position: 'absolute', left: 0, top: 0, width: 16, height: '100%',
            zIndex: 25, cursor: 'pointer',
          }}
        />
      )}
      {/* tab bar 蓋層 */}
      {tabActive && <BottomTabOverlay active={tabActive} />}
    </div>
  );
}

// 主路由
function Prototype() {
  const [history, setHistory] = useState(['splash']);
  const screen = history[history.length - 1];

  const go = useCallback((to, opts = {}) => {
    setHistory(h => opts.replace ? [...h.slice(0, -1), to] : [...h, to]);
  }, []);
  const back = useCallback(() => {
    setHistory(h => h.length > 1 ? h.slice(0, -1) : h);
  }, []);
  const reset = useCallback((to) => setHistory([to]), []);

  // splash 自動跳 login
  useEffect(() => {
    if (screen === 'splash') {
      const t = setTimeout(() => go('login', { replace: true }), 2200);
      return () => clearTimeout(t);
    }
  }, [screen, go]);

  const nav = { go, back, reset, current: screen };

  // 各畫面的點擊熱區配置（402×874 phone area，去掉狀態列大約從 y=60 開始）
  // 底部 tab 高 84，bottom = 874-84 = 790 起
  const screens = {
    splash: <window.SplashScreen />,
    login: (
      <Screen id="login" taps={[
        // 登入按鈕（大致在中下方）
        { x: 30, y: 550, w: 342, h: 60, to: 'home' },
        { x: 30, y: 620, w: 342, h: 50, to: 'home' },
        { x: 30, y: 690, w: 342, h: 50, to: 'home' },
        // 跳過 / 訪客
        { x: 30, y: 770, w: 342, h: 40, to: 'home' },
      ]}>
        <window.LoginScreen />
      </Screen>
    ),
    home: (
      <Screen id="home" tabActive="home" taps={[
        // 4 個模式入口卡片（推測位置：從 y~200 開始，每張卡 ~150 高）
        { x: 20, y: 200, w: 362, h: 140, to: 'learn' },
        { x: 20, y: 350, w: 362, h: 140, to: 'culture' },
        { x: 20, y: 500, w: 362, h: 140, to: 'comm' },
        { x: 20, y: 650, w: 362, h: 130, to: 'plaza' },
      ]}>
        <window.HomeScreen />
      </Screen>
    ),
    learn: (
      <Screen id="learn" tabActive="learn" swipeBack taps={[
        // 各單元卡片
        { x: 20, y: 280, w: 362, h: 100, to: 'mode' },
        { x: 20, y: 390, w: 362, h: 100, to: 'mode' },
        { x: 20, y: 500, w: 362, h: 100, to: 'mode' },
        { x: 20, y: 610, w: 362, h: 100, to: 'mode' },
      ]}>
        <window.LearnScreen />
      </Screen>
    ),
    mode: (
      <Screen id="mode" swipeBack taps={[
        { x: 20, y: 200, w: 362, h: 180, to: 'lesson' },  // 學習模式
        { x: 20, y: 400, w: 362, h: 180, to: 'quiz' },    // 答題模式
        { x: 20, y: 600, w: 175, h: 130, to: 'lesson' },  // 進階1
        { x: 207, y: 600, w: 175, h: 130, to: 'lesson' }, // 進階2
      ]}>
        <window.LearnModePickScreen />
      </Screen>
    ),
    lesson: (
      <Screen id="lesson" swipeBack taps={[
        // 左上關閉按鈕
        { x: 0, y: 50, w: 60, h: 50, to: 'mode' },
        // 下一張（畫面右半）
        { x: 220, y: 730, w: 162, h: 80, to: 'quiz' },
      ]}>
        <window.LessonCardScreen />
      </Screen>
    ),
    quiz: (
      <Screen id="quiz" swipeBack taps={[
        { x: 0, y: 50, w: 60, h: 50, to: 'mode' },
      ]}>
        <window.QuizScreen />
      </Screen>
    ),
    culture: (
      <Screen id="culture" tabActive="culture" taps={[
        // 主打橫幅（影音）
        { x: 20, y: 280, w: 362, h: 200, to: 'video' },
        // 影片格 (大致 2x2)
        { x: 20, y: 540, w: 175, h: 160, to: 'video' },
        { x: 207, y: 540, w: 175, h: 160, to: 'video' },
        { x: 20, y: 710, w: 175, h: 160, to: 'video' },
        { x: 207, y: 710, w: 175, h: 160, to: 'video' },
        // 文章區大卡（再下面）
        { x: 20, y: 950, w: 362, h: 200, to: 'article' },
        { x: 20, y: 1170, w: 362, h: 90, to: 'article' },
        { x: 20, y: 1270, w: 362, h: 90, to: 'article' },
        { x: 20, y: 1370, w: 362, h: 90, to: 'article' },
      ]}>
        <window.CultureScreen />
      </Screen>
    ),
    video: (
      <Screen id="video" swipeBack taps={[
        { x: 0, y: 50, w: 60, h: 50, to: 'culture' },
      ]}>
        <window.VideoPlayerScreen />
      </Screen>
    ),
    article: (
      <Screen id="article" swipeBack taps={[
        { x: 0, y: 50, w: 60, h: 50, to: 'culture' },
      ]}>
        <window.ArticleScreen />
      </Screen>
    ),
    comm: (
      <Screen id="comm" tabActive="comm" taps={[
        // 開始配對 CTA
        { x: 40, y: 380, w: 322, h: 60, to: 'vwait' },
        // 通話按鈕區
        { x: 300, y: 730, w: 80, h: 50, to: 'vwait' },
        { x: 300, y: 810, w: 80, h: 50, to: 'vwait' },
      ]}>
        <window.CommunityScreen />
      </Screen>
    ),
    vwait: (
      <Screen id="vwait" taps={[
        // 取消配對
        { x: 100, y: 760, w: 200, h: 60, to: 'comm', replace: true },
        // 中央區點任何處模擬配對成功 → 視訊中
        { x: 90, y: 280, w: 220, h: 220, to: 'vcall', replace: true },
      ]}>
        <window.VideoWaitingScreen />
      </Screen>
    ),
    vcall: (
      <Screen id="vcall" taps={[
        // 結束按鈕（最右下）
        { x: 300, y: 770, w: 80, h: 80, to: 'comm', replace: true },
      ]}>
        <window.VideoCallScreen />
      </Screen>
    ),
    plaza: (
      <Screen id="plaza" tabActive="plaza" taps={[
        // 發布按鈕
        { x: 290, y: 70, w: 90, h: 50, to: 'compose' },
        // 活動橫向卡（含「我要參加」）
        { x: 20, y: 230, w: 200, h: 160 },
        { x: 230, y: 230, w: 200, h: 160 },
      ]}>
        <window.PlazaScreen />
      </Screen>
    ),
    compose: (
      <Screen id="compose" taps={[
        // 取消
        { x: 0, y: 50, w: 80, h: 50, to: 'plaza', replace: true },
        // 發布
        { x: 320, y: 50, w: 80, h: 50, to: 'plaza', replace: true },
        // 切換到活動 segment
        { x: 200, y: 130, w: 180, h: 50, to: 'compose-event', replace: true },
      ]}>
        <window.ComposeScreen />
      </Screen>
    ),
    'compose-event': (
      <Screen id="compose-event" taps={[
        { x: 0, y: 50, w: 80, h: 50, to: 'plaza', replace: true },
        { x: 320, y: 50, w: 80, h: 50, to: 'plaza', replace: true },
        // 切回動態
        { x: 30, y: 130, w: 170, h: 50, to: 'compose', replace: true },
      ]}>
        <window.ComposeEventScreen />
      </Screen>
    ),
    profile: (
      <Screen id="profile" swipeBack taps={[
        // 登出 — 回登入
        { x: 30, y: 1450, w: 342, h: 60, to: 'login', replace: true },
      ]}>
        <window.ProfileScreen />
      </Screen>
    ),
  };

  return (
    <NavCtx.Provider value={nav}>
      <div style={{
        minHeight: '100vh', background: '#1C0F0D',
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        padding: '24px', position: 'relative',
      }}>
        {/* 左右導覽提示 */}
        <ProtoChrome nav={nav} screen={screen} />

        {/* iOS 框 */}
        <div style={{ position: 'relative' }}>
          <window.IOSDevice
            width={402}
            height={874}
            dark={['splash','login','culture','video','vwait','vcall'].includes(screen)}
          >
            {screens[screen]}
          </window.IOSDevice>
        </div>
      </div>
    </NavCtx.Provider>
  );
}

// 原型 chrome：標題 + 返回 + 重設 + 畫面選單
function ProtoChrome({ nav, screen }) {
  const [menu, setMenu] = useState(false);
  const labels = {
    splash: '01 啟動', login: '02 登入', home: '03 首頁',
    learn: '04 族語學習', mode: '05 選擇模式',
    lesson: '06 單字卡', quiz: '07 答題',
    culture: '08 文化影音', video: '09 影片播放', article: '10 文章閱讀',
    comm: '11 互動專區', vwait: '12 視訊配對', vcall: '13 視訊中',
    plaza: '14 廣場', compose: '15 發布動態', 'compose-event': '16 發布活動',
    profile: '17 個人頁',
  };
  return (
    <>
      {/* 頂部標題列 */}
      <div style={{
        position: 'fixed', top: 0, left: 0, right: 0, zIndex: 100,
        padding: '14px 20px',
        display: 'flex', alignItems: 'center', justifyContent: 'space-between',
        background: 'linear-gradient(to bottom, rgba(28,15,13,0.95), rgba(28,15,13,0))',
        color: '#F2E8D5', fontFamily: '"Noto Sans TC", sans-serif',
      }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
          <button
            onClick={() => nav.back()}
            disabled={nav.current === 'splash'}
            style={{
              width: 36, height: 36, borderRadius: 18,
              background: 'rgba(242,232,213,0.1)', border: `1px solid #C9A96140`,
              color: '#C9A961', cursor: 'pointer',
              display: 'flex', alignItems: 'center', justifyContent: 'center',
            }}
          >
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round">
              <path d="M15 6l-6 6 6 6"/>
            </svg>
          </button>
          <div>
            <div style={{
              fontFamily: '"Crimson Pro", serif', fontStyle: 'italic',
              fontSize: 11, color: '#C9A961', letterSpacing: '0.25em',
            }}>KARI TRUKU · 互動原型</div>
            <div style={{
              fontFamily: '"Noto Serif TC", serif', fontSize: 16, fontWeight: 600,
              letterSpacing: '0.04em',
            }}>{labels[screen] || screen}</div>
          </div>
        </div>
        <div style={{ display: 'flex', gap: 8 }}>
          <button
            onClick={() => setMenu(m => !m)}
            style={{
              padding: '8px 14px', borderRadius: 18,
              background: 'rgba(242,232,213,0.1)', border: `1px solid #C9A96140`,
              color: '#C9A961', cursor: 'pointer', fontSize: 12, letterSpacing: '0.1em',
            }}
          >畫面 ☰</button>
          <button
            onClick={() => nav.reset('splash')}
            style={{
              padding: '8px 14px', borderRadius: 18,
              background: 'rgba(242,232,213,0.1)', border: `1px solid #C9A96140`,
              color: '#C9A961', cursor: 'pointer', fontSize: 12, letterSpacing: '0.1em',
            }}
          >重設</button>
        </div>
      </div>

      {/* 畫面選單 */}
      {menu && (
        <div style={{
          position: 'fixed', top: 70, right: 20, zIndex: 200,
          background: '#2A1A15', border: `1px solid #C9A96140`,
          borderRadius: 14, padding: 8, minWidth: 220,
          maxHeight: '70vh', overflowY: 'auto',
          boxShadow: '0 16px 40px rgba(0,0,0,0.5)',
        }}>
          {Object.entries(labels).map(([k, v]) => (
            <div
              key={k}
              onClick={() => { nav.reset(k); setMenu(false); }}
              style={{
                padding: '10px 12px', borderRadius: 8,
                color: nav.current === k ? '#C9A961' : '#F2E8D5',
                background: nav.current === k ? 'rgba(201,169,97,0.12)' : 'transparent',
                fontSize: 13, letterSpacing: '0.05em', cursor: 'pointer',
                fontFamily: '"Noto Serif TC", serif',
              }}
            >{v}</div>
          ))}
        </div>
      )}

      {/* 底部提示 */}
      <div style={{
        position: 'fixed', bottom: 16, left: '50%', transform: 'translateX(-50%)',
        zIndex: 100, padding: '8px 16px', borderRadius: 20,
        background: 'rgba(42,26,21,0.85)', backdropFilter: 'blur(10px)',
        color: '#C9A961', fontSize: 11, letterSpacing: '0.1em',
        fontFamily: '"Crimson Pro", serif', fontStyle: 'italic',
        border: `1px solid #C9A96130`,
      }}>
        點擊卡片 / 按鈕 / Tab 即可導覽 · 左邊緣點擊返回
      </div>
    </>
  );
}

window.Prototype = Prototype;
