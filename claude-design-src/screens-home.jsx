// 螢幕 1: 啟動畫面 Splash
// 螢幕 2: 首頁（4 個模式入口）

const { TRUKU_COLORS: C, TRUKU_FONTS: F } = window;

// ─────────────────────────────────────────────────────────────
// 啟動畫面
// ─────────────────────────────────────────────────────────────
function SplashScreen() {
  return (
    <div style={{
      width: '100%', height: '100%', position: 'relative', overflow: 'hidden',
      background: `linear-gradient(180deg, ${C.midnight} 0%, ${C.primaryDeep} 60%, ${C.primary} 100%)`,
      fontFamily: F.body,
    }}>
      {/* 山稜剪影層 */}
      <div style={{ position: 'absolute', bottom: 0, left: 0, right: 0, opacity: 0.85 }}>
        <window.TrukuMountains width={402} height={180} color="#0E0604" opacity={0.7} />
      </div>
      <div style={{ position: 'absolute', bottom: 30, left: 0, right: 0, opacity: 0.6 }}>
        <window.TrukuMountains width={402} height={120} color="#0E0604" opacity={0.5} />
      </div>

      {/* 織紋紋理 */}
      <div style={{ position: 'absolute', inset: 0, opacity: 0.18 }}>
        <window.TrukuWeaveBg color={C.gold} bg="transparent" opacity={1} scale={1} />
      </div>

      {/* 頂部織紋裝飾 */}
      <div style={{ position: 'absolute', top: 90, left: 0, right: 0, display: 'flex', justifyContent: 'center' }}>
        <window.TrukuChain count={9} size={10} color={C.gold} gap={6} />
      </div>

      {/* 中央 logo 區 */}
      <div style={{
        position: 'absolute', top: '32%', left: 0, right: 0,
        display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 18,
      }}>
        {/* logo */}
        <div style={{ position: 'relative', width: 200, height: 200 }}>
          <div style={{
            position: 'absolute', inset: -10, borderRadius: '50%',
            background: `radial-gradient(circle, ${C.gold}30 0%, transparent 70%)`,
          }} />
          <img src="logo-gold.png" alt="語見太魯閣" style={{
            width: '100%', height: '100%', objectFit: 'contain', position: 'relative',
          }} />
        </div>

        <div style={{ textAlign: 'center' }}>
          <div style={{
            fontFamily: F.truku, fontStyle: 'italic', fontSize: 16,
            color: C.gold, letterSpacing: '0.2em', fontWeight: 400,
          }}>
            Kari Truku · Lnglungan
          </div>
        </div>

        {/* 底部織紋 */}
        <div style={{ marginTop: 4 }}>
          <window.TrukuChain count={5} size={8} color={C.gold} gap={5} />
        </div>
      </div>

      {/* 底部 tagline */}
      <div style={{
        position: 'absolute', bottom: 70, left: 0, right: 0,
        textAlign: 'center', color: C.cream, opacity: 0.7,
        fontFamily: F.body, fontSize: 13, letterSpacing: '0.3em',
      }}>
        說我們的話 · 走我們的山
      </div>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// 首頁 — 4 個模式
// ─────────────────────────────────────────────────────────────
function HomeScreen() {
  const [showProfile, setShowProfile] = React.useState(false);
  if (showProfile && window.ProfileScreen) {
    return (
      <div style={{ position: 'relative', width: '100%', height: '100%' }}>
        <window.ProfileScreen />
        {/* 返回按鈕（左上） */}
        <button
          onClick={() => setShowProfile(false)}
          style={{
            position: 'absolute', top: 56, left: 16, zIndex: 50,
            width: 36, height: 36, borderRadius: 18, border: 'none',
            background: 'rgba(250,245,234,0.18)',
            backdropFilter: 'blur(10px)', WebkitBackdropFilter: 'blur(10px)',
            color: C.creamLight, cursor: 'pointer',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
          }}
        >
          <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke={C.creamLight} strokeWidth="2" strokeLinecap="round">
            <path d="M15 6l-6 6 6 6"/>
          </svg>
        </button>
      </div>
    );
  }
  const modes = [
    {
      key: 'learn',
      zh: '族語學習',
      truku: 'Kari Truku',
      sub: '一天一句·從問候開始',
      bg: C.primary,
      fg: C.creamLight,
      accent: C.gold,
      icon: 'lesson',
    },
    {
      key: 'culture',
      zh: '文化影音',
      truku: 'Lnglungan',
      sub: '部落故事與傳統知識',
      bg: C.midnight,
      fg: C.creamLight,
      accent: C.gold,
      icon: 'film',
    },
    {
      key: 'video',
      zh: '視訊',
      truku: 'Pgkala',
      sub: '和 rudan 一對一',
      bg: C.moss,
      fg: C.creamLight,
      accent: C.gold,
      icon: 'comm',
    },
    {
      key: 'plaza',
      zh: '廣場',
      truku: 'Alang',
      sub: '族人的動態',
      bg: C.creamLight,
      fg: C.primary,
      accent: C.primary,
      icon: 'plaza',
    },
    {
      key: 'event',
      zh: '活動',
      truku: 'Smratuc',
      sub: '部落聚會與走讀',
      bg: C.gold,
      fg: C.ink,
      accent: C.primary,
      icon: 'event',
    },
  ];

  return (
    <div style={{
      width: '100%', minHeight: '100%',
      background: C.creamLight,
      fontFamily: F.body, position: 'relative',
    }}>
      {/* 頂部織紋條 */}
      <div style={{
        height: 6, background: C.primary,
        position: 'relative', overflow: 'hidden',
      }}>
        <div style={{ position: 'absolute', inset: 0, opacity: 0.4 }}>
          <window.TrukuWeaveBg color={C.gold} bg="transparent" opacity={1} scale={0.4} />
        </div>
      </div>

      {/* 標頭 */}
      <div style={{ padding: '60px 24px 18px' }}>
        {/* logo */}
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', marginBottom: 14 }}>
          <img src="logo-red.png" alt="語見太魯閣" style={{ width: 78, height: 78, objectFit: 'contain' }} />
        </div>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 18 }}>
          <div>
            <div style={{
              fontFamily: F.truku, fontStyle: 'italic', fontSize: 13,
              color: C.fog, letterSpacing: '0.15em', marginBottom: 2,
            }}>
              Mhuway su · 你好
            </div>
            <div style={{
              fontFamily: F.display, fontSize: 24, fontWeight: 600,
              color: C.ink, letterSpacing: '0.04em',
            }}>
              Yudaw，今天學什麼？
            </div>
          </div>
          <div
            onClick={() => setShowProfile(true)}
            style={{
              width: 48, height: 48, borderRadius: 24,
              background: C.primary, position: 'relative',
              display: 'flex', alignItems: 'center', justifyContent: 'center',
              overflow: 'hidden', border: `2px solid ${C.gold}`,
              cursor: 'pointer',
            }}>
            <img src="badges/c-orange-happy.png" alt="頭貼" style={{
              width: 54, height: 54, objectFit: 'contain',
            }} />
          </div>
        </div>

        {/* 今日進度卡 */}
        <div style={{
          background: C.ink, color: C.creamLight,
          borderRadius: 18, padding: '16px 18px',
          position: 'relative', overflow: 'hidden',
        }}>
          <div style={{ position: 'absolute', right: -10, top: -10, opacity: 0.18 }}>
            <window.TrukuDiamond size={120} color={C.gold} stroke={1.5} />
          </div>
          {/* 小米幣 chip */}
          <div style={{
            position: 'absolute', top: 14, right: 14, zIndex: 2,
            background: 'rgba(201, 169, 97, 0.18)',
            border: `1px solid ${C.gold}80`,
            borderRadius: 16, padding: '4px 10px 4px 4px',
            display: 'flex', alignItems: 'center', gap: 4,
          }}>
            <img src="badges/millet.png" alt="小米" style={{ width: 22, height: 22, objectFit: 'contain' }} />
            <div style={{ fontFamily: F.display, fontSize: 13, fontWeight: 700, color: C.gold, letterSpacing: '0.04em' }}>
              320
            </div>
          </div>
          <div style={{
            fontFamily: F.truku, fontStyle: 'italic', fontSize: 11,
            color: C.gold, letterSpacing: '0.2em', marginBottom: 4,
          }}>
            TODAY · SAYANG
          </div>
          <div style={{
            fontFamily: F.display, fontSize: 22, fontWeight: 600,
            marginBottom: 10, lineHeight: 1.3,
          }}>
            連續學習 <span style={{ color: C.gold }}>12</span> 天
          </div>
          {/* 進度條 */}
          <div style={{ display: 'flex', gap: 4, marginBottom: 8 }}>
            {Array.from({ length: 7 }).map((_, i) => (
              <div key={i} style={{
                flex: 1, height: 6, borderRadius: 2,
                background: i < 5 ? C.gold : 'rgba(255,255,255,0.15)',
              }} />
            ))}
          </div>
          <div style={{
            fontSize: 12, opacity: 0.85, letterSpacing: '0.05em',
            display: 'flex', alignItems: 'center', gap: 6,
          }}>
            本週目標 5/7 · 完成下個單元再得
            <span style={{ display: 'inline-flex', alignItems: 'center', gap: 2 }}>
              <img src="badges/millet.png" alt="小米" style={{ width: 14, height: 14, objectFit: 'contain' }} />
              <span style={{ color: C.gold, fontWeight: 600 }}>10</span>
            </span>
          </div>
        </div>
      </div>

      {/* 4 個模式 */}
      <div style={{
        padding: '8px 24px 100px',
        display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12,
      }}>
        {modes.map((m, i) => (
          <ModeCard key={m.key} mode={m} large={i === 0} />
        ))}
      </div>

      {/* 底部 Tab Bar */}
      <BottomTab active="home" />
    </div>
  );
}

function ModeCard({ mode, large = false }) {
  return (
    <div style={{
      gridColumn: large ? 'span 2' : 'auto',
      background: mode.bg,
      borderRadius: 20, padding: 18,
      position: 'relative', overflow: 'hidden',
      minHeight: large ? 150 : 170,
      display: 'flex', flexDirection: 'column', justifyContent: 'space-between',
      border: mode.bg === C.creamLight ? `1.5px solid ${C.creamDeep}` : 'none',
    }}>
      {/* 背景織紋 */}
      <div style={{ position: 'absolute', inset: 0, opacity: 0.12 }}>
        <window.TrukuWeaveBg color={mode.accent} bg="transparent" opacity={1} scale={0.6} />
      </div>

      {/* icon */}
      <div style={{ position: 'relative', zIndex: 1, display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
        <ModeIcon name={mode.icon} color={mode.accent} />
        <div style={{
          fontFamily: F.truku, fontStyle: 'italic', fontSize: 11,
          color: mode.accent, letterSpacing: '0.18em', opacity: 0.85,
        }}>
          {mode.truku.toUpperCase()}
        </div>
      </div>

      {/* 文字 */}
      <div style={{ position: 'relative', zIndex: 1 }}>
        <div style={{
          fontFamily: F.display, fontSize: large ? 26 : 22, fontWeight: 600,
          color: mode.fg, letterSpacing: '0.05em', marginBottom: 4, lineHeight: 1.1,
        }}>
          {mode.zh}
        </div>
        <div style={{
          fontSize: 12, color: mode.fg, opacity: 0.7,
          letterSpacing: '0.04em',
        }}>
          {mode.sub}
        </div>
      </div>
    </div>
  );
}

function ModeIcon({ name, color }) {
  const s = 28;
  if (name === 'lesson') {
    return (
      <svg width={s} height={s} viewBox="0 0 28 28" fill="none" stroke={color} strokeWidth="1.6" strokeLinecap="round">
        <path d="M4 6h20v16H4z" />
        <path d="M14 6v16M8 11h4M8 15h4M16 11h4M16 15h4" />
        <circle cx="14" cy="6" r="1.2" fill={color} />
      </svg>
    );
  }
  if (name === 'film') {
    return (
      <svg width={s} height={s} viewBox="0 0 28 28" fill="none" stroke={color} strokeWidth="1.6">
        <rect x="3" y="6" width="22" height="16" rx="2" />
        <path d="M11 11 L17 14 L11 17 Z" fill={color} stroke="none" />
        <path d="M3 10h22M3 18h22" strokeWidth="0.8" opacity="0.5" />
      </svg>
    );
  }
  if (name === 'comm') {
    return (
      <svg width={s} height={s} viewBox="0 0 28 28" fill="none" stroke={color} strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round">
        <rect x="3" y="8" width="16" height="12" rx="2"/>
        <path d="M19 12 L25 9 V19 L19 16 Z" fill={color} fillOpacity="0.15"/>
      </svg>
    );
  }
  if (name === 'plaza') {
    return (
      <svg width={s} height={s} viewBox="0 0 28 28" fill="none" stroke={color} strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round">
        <circle cx="9" cy="10" r="3"/>
        <circle cx="19" cy="10" r="3"/>
        <path d="M3 22c0-3 3-5 6-5s6 2 6 5"/>
        <path d="M13 22c0-3 3-5 6-5s6 2 6 5"/>
      </svg>
    );
  }
  if (name === 'event') {
    return (
      <svg width={s} height={s} viewBox="0 0 28 28" fill="none" stroke={color} strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round">
        <rect x="4" y="6" width="20" height="18" rx="2"/>
        <path d="M4 11h20M9 3v6M19 3v6"/>
        <path d="M10 16 L13 19 L18 14" fill="none"/>
      </svg>
    );
  }
  if (name === 'map') {
    return (
      <svg width={s} height={s} viewBox="0 0 28 28" fill="none" stroke={color} strokeWidth="1.6" strokeLinejoin="round">
        <path d="M14 3 C9 3 6 6.5 6 11 C6 17 14 25 14 25 C14 25 22 17 22 11 C22 6.5 19 3 14 3 Z" />
        <path d="M14 8 L17 11 L14 14 L11 11 Z" fill={color} stroke="none" />
      </svg>
    );
  }
  return null;
}

function BottomTab({ active = 'home' }) {
  const tabs = [
    { key: 'home', label: '首頁', icon: 'home' },
    { key: 'learn', label: '學習', icon: 'book' },
    { key: 'culture', label: '影音', icon: 'play' },
    { key: 'comm', label: '視訊', icon: 'chat' },
    { key: 'plaza', label: '廣場', icon: 'user' },
    { key: 'event', label: '活動', icon: 'cal' },
  ];

  return (
    <div style={{
      position: 'absolute', bottom: 0, left: 0, right: 0,
      background: 'rgba(250, 245, 234, 0.92)',
      backdropFilter: 'blur(20px)',
      WebkitBackdropFilter: 'blur(20px)',
      borderTop: `1px solid ${C.creamDeep}`,
      padding: '10px 8px 28px',
      display: 'flex', justifyContent: 'space-around',
    }}>
      {tabs.map(t => (
        <div key={t.key} style={{
          display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 3,
          color: active === t.key ? C.primary : C.fog,
        }}>
          <TabIcon name={t.icon} color={active === t.key ? C.primary : C.fog} />
          <div style={{ fontSize: 10, letterSpacing: '0.1em', fontWeight: active === t.key ? 600 : 400 }}>
            {t.label}
          </div>
        </div>
      ))}
    </div>
  );
}

function TabIcon({ name, color }) {
  const s = 22;
  const props = { width: s, height: s, viewBox: '0 0 24 24', fill: 'none', stroke: color, strokeWidth: 1.8, strokeLinecap: 'round', strokeLinejoin: 'round' };
  if (name === 'home') return <svg {...props}><path d="M3 11 L12 3 L21 11 V21 H3 Z"/><path d="M9 21v-7h6v7" /></svg>;
  if (name === 'book') return <svg {...props}><path d="M4 4h7v16H4z M13 4h7v16h-7z"/></svg>;
  if (name === 'play') return <svg {...props}><circle cx="12" cy="12" r="9"/><path d="M10 8 L16 12 L10 16Z" fill={color}/></svg>;
  if (name === 'chat') return <svg {...props}><path d="M4 5h16v12H10l-6 5z"/></svg>;
  if (name === 'cal') return <svg {...props}><rect x="3" y="5" width="18" height="16" rx="2"/><path d="M3 10h18M8 3v4M16 3v4"/></svg>;
  if (name === 'user') return <svg {...props}><circle cx="12" cy="9" r="4"/><path d="M4 21c1-4 5-6 8-6s7 2 8 6"/></svg>;
  return null;
}

Object.assign(window, { SplashScreen, HomeScreen, BottomTab });
