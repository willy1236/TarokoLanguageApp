// 螢幕 3: 族語學習單元
// 螢幕 4: 學習進行中（單字卡 + 發音）

const { TRUKU_COLORS: LC, TRUKU_FONTS: LF } = window;

// ─────────────────────────────────────────────────────────────
// 學習單元列表
// ─────────────────────────────────────────────────────────────
function LearnScreen() {
  const units = [
    { num: '01', zh: '日常問候', truku: 'Smbarux', words: 12, done: 12, locked: false, current: false },
    { num: '02', zh: '家人稱謂', truku: 'Lutut', words: 18, done: 14, locked: false, current: true },
    { num: '03', zh: '部落地景', truku: 'Dgiyaq Alang', words: 16, done: 0, locked: false, current: false },
    { num: '04', zh: '狩獵與山林', truku: 'Mhuma Bgihur', words: 24, done: 0, locked: true, current: false },
    { num: '05', zh: '織布與染色', truku: 'Tminun', words: 20, done: 0, locked: true, current: false },
  ];

  return (
    <div style={{
      width: '100%', minHeight: '100%',
      background: LC.creamLight, fontFamily: LF.body,
      position: 'relative', paddingBottom: 100,
    }}>
      {/* 頂部紅磚 hero */}
      <div style={{
        background: LC.primary, color: LC.creamLight,
        padding: '64px 24px 28px',
        position: 'relative', overflow: 'hidden',
      }}>
        <div style={{ position: 'absolute', inset: 0, opacity: 0.2 }}>
          <window.TrukuWeaveBg color={LC.gold} bg="transparent" opacity={1} scale={0.7} />
        </div>
        <div style={{ position: 'relative', zIndex: 1 }}>
          <div style={{
            fontFamily: LF.truku, fontStyle: 'italic', fontSize: 12,
            color: LC.gold, letterSpacing: '0.25em', marginBottom: 6,
          }}>
            KARI TRUKU · 族語學習
          </div>
          <div style={{
            fontFamily: LF.display, fontSize: 28, fontWeight: 600,
            letterSpacing: '0.04em', marginBottom: 12,
          }}>
            一句一句，把話說回來
          </div>
          <div style={{ display: 'flex', gap: 16, fontSize: 13, opacity: 0.85 }}>
            <span><b style={{ color: LC.gold, fontSize: 18, fontFamily: LF.display }}>26</b>　已學單字</span>
            <span><b style={{ color: LC.gold, fontSize: 18, fontFamily: LF.display }}>2/5</b>　完成單元</span>
          </div>
        </div>
      </div>

      {/* 單元列表 */}
      <div style={{ padding: '20px 20px 0' }}>
        <div style={{
          display: 'flex', alignItems: 'center', gap: 8,
          marginBottom: 16, paddingLeft: 4,
        }}>
          <window.TrukuDiamond size={14} color={LC.primary} filled />
          <div style={{
            fontFamily: LF.display, fontSize: 18, fontWeight: 600,
            color: LC.ink, letterSpacing: '0.08em',
          }}>初階課程</div>
        </div>

        <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
          {units.map(u => <UnitRow key={u.num} unit={u} />)}
        </div>
      </div>

      <window.BottomTab active="learn" />
    </div>
  );
}

function UnitRow({ unit }) {
  const pct = unit.done / unit.words;
  return (
    <div style={{
      background: unit.current ? LC.ink : LC.cream,
      borderRadius: 16, padding: '14px 16px',
      display: 'flex', alignItems: 'center', gap: 14,
      position: 'relative', overflow: 'hidden',
      opacity: unit.locked ? 0.5 : 1,
      border: unit.current ? 'none' : `1px solid ${LC.creamDeep}`,
    }}>
      {/* 單元號 */}
      <div style={{
        width: 52, height: 52, flexShrink: 0,
        position: 'relative',
        display: 'flex', alignItems: 'center', justifyContent: 'center',
      }}>
        <svg width="52" height="52" viewBox="0 0 52 52" style={{ position: 'absolute' }}>
          <path d="M26 4 L48 26 L26 48 L4 26 Z"
            fill={unit.current ? LC.primary : 'transparent'}
            stroke={unit.current ? LC.gold : LC.primary}
            strokeWidth="1.5" />
          {pct > 0 && pct < 1 && (
            <path d="M26 4 L48 26 L26 48 L4 26 Z"
              fill="none" stroke={LC.gold} strokeWidth="2"
              strokeDasharray={`${pct * 124} 124`} />
          )}
        </svg>
        <div style={{
          position: 'relative', zIndex: 1,
          fontFamily: LF.display, fontSize: 14, fontWeight: 600,
          color: unit.current ? LC.creamLight : LC.primary,
        }}>{unit.num}</div>
      </div>

      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{
          fontFamily: LF.truku, fontStyle: 'italic', fontSize: 11,
          color: unit.current ? LC.gold : LC.fog,
          letterSpacing: '0.15em', marginBottom: 2,
        }}>
          {unit.truku.toUpperCase()}
        </div>
        <div style={{
          fontFamily: LF.display, fontSize: 17, fontWeight: 600,
          color: unit.current ? LC.creamLight : LC.ink,
          letterSpacing: '0.05em', marginBottom: 4,
        }}>
          {unit.zh}
        </div>
        <div style={{
          fontSize: 11, color: unit.current ? 'rgba(242,232,213,0.7)' : LC.fog,
          letterSpacing: '0.05em',
        }}>
          {unit.locked ? '完成上一單元解鎖' :
            unit.done === unit.words ? `✓ 全部完成 · ${unit.words} 句` :
            `${unit.done} / ${unit.words} 句`}
        </div>
      </div>

      {/* 動作圖示 */}
      <div style={{ flexShrink: 0 }}>
        {unit.locked ? (
          <svg width="20" height="20" viewBox="0 0 20 20" fill="none" stroke={LC.fog} strokeWidth="1.5">
            <rect x="4" y="9" width="12" height="9" rx="1.5" />
            <path d="M7 9V6a3 3 0 016 0v3" />
          </svg>
        ) : (
          <svg width="20" height="20" viewBox="0 0 20 20" fill="none"
            stroke={unit.current ? LC.gold : LC.primary} strokeWidth="2" strokeLinecap="round">
            <path d="M7 4 L13 10 L7 16" />
          </svg>
        )}
      </div>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// 單字卡學習中
// ─────────────────────────────────────────────────────────────
function LessonCardScreen() {
  return (
    <div style={{
      width: '100%', minHeight: '100%',
      background: LC.creamLight, fontFamily: LF.body,
      position: 'relative', paddingBottom: 40,
    }}>
      {/* 頂部進度 */}
      <div style={{ padding: '60px 20px 0', display: 'flex', alignItems: 'center', gap: 12 }}>
        <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke={LC.ink} strokeWidth="2" strokeLinecap="round">
          <path d="M15 4 L7 12 L15 20" />
        </svg>
        <div style={{ flex: 1, height: 6, background: LC.creamDeep, borderRadius: 3, overflow: 'hidden' }}>
          <div style={{
            width: '60%', height: '100%',
            background: `linear-gradient(90deg, ${LC.primary}, ${LC.gold})`,
          }} />
        </div>
        <div style={{ fontFamily: LF.mono, fontSize: 12, color: LC.fog, letterSpacing: '0.1em' }}>
          9 / 15
        </div>
      </div>

      {/* 單元標 */}
      <div style={{ padding: '24px 20px 8px' }}>
        <div style={{
          fontFamily: LF.truku, fontStyle: 'italic', fontSize: 12,
          color: LC.fog, letterSpacing: '0.2em', marginBottom: 4,
        }}>
          UNIT 02 · LUTUT
        </div>
        <div style={{
          fontFamily: LF.display, fontSize: 18, fontWeight: 500,
          color: LC.inkSoft, letterSpacing: '0.05em',
        }}>
          家人稱謂
        </div>
      </div>

      {/* 主卡片 */}
      <div style={{ padding: '8px 20px 0' }}>
        <div style={{
          background: LC.ink, color: LC.creamLight,
          borderRadius: 24, padding: '32px 24px 28px',
          position: 'relative', overflow: 'hidden',
          minHeight: 380,
          display: 'flex', flexDirection: 'column',
        }}>
          {/* 背景織紋 */}
          <div style={{ position: 'absolute', inset: 0, opacity: 0.1 }}>
            <window.TrukuWeaveBg color={LC.gold} bg="transparent" opacity={1} scale={0.8} />
          </div>
          {/* 角落菱形 */}
          <div style={{ position: 'absolute', top: 18, right: 18, opacity: 0.6 }}>
            <window.TrukuDiamond size={26} color={LC.gold} stroke={1.2} />
          </div>

          {/* 提示 */}
          <div style={{ position: 'relative', zIndex: 1 }}>
            <div style={{
              fontFamily: LF.body, fontSize: 11,
              color: LC.gold, letterSpacing: '0.2em', marginBottom: 24, fontWeight: 500,
            }}>
              聆聽 · 跟讀
            </div>
          </div>

          {/* 主族語詞 */}
          <div style={{ position: 'relative', zIndex: 1, flex: 1, display: 'flex', flexDirection: 'column', justifyContent: 'center' }}>
            <div style={{
              fontFamily: LF.truku, fontStyle: 'italic', fontSize: 56,
              fontWeight: 500, color: LC.creamLight,
              letterSpacing: '0.02em', lineHeight: 1.05, marginBottom: 8,
            }}>
              Tama
            </div>
            <div style={{
              fontFamily: LF.display, fontSize: 22, fontWeight: 500,
              color: LC.gold, letterSpacing: '0.15em',
            }}>
              爸爸
            </div>
            <div style={{
              fontFamily: LF.mono, fontSize: 11,
              color: 'rgba(242,232,213,0.5)',
              letterSpacing: '0.05em', marginTop: 14,
            }}>
              [ˈta.ma] · n. 父親；對男性長輩的稱呼
            </div>
          </div>

          {/* 播放按鈕 */}
          <div style={{ position: 'relative', zIndex: 1, marginTop: 20, display: 'flex', gap: 10, alignItems: 'center' }}>
            <button style={{
              flex: 1, height: 56, borderRadius: 14, border: 'none',
              background: LC.gold, color: LC.ink,
              fontFamily: LF.display, fontSize: 15, fontWeight: 600,
              letterSpacing: '0.1em', cursor: 'pointer',
              display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 10,
            }}>
              <window.SpeakerIcon size={20} color={LC.ink} />
              <span>播放發音</span>
            </button>
            <button style={{
              width: 56, height: 56, borderRadius: 14, border: `1px solid ${LC.gold}`,
              background: 'transparent', color: LC.gold, cursor: 'pointer',
              display: 'flex', alignItems: 'center', justifyContent: 'center',
            }}>
              {/* 慢速 */}
              <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke={LC.gold} strokeWidth="1.6" strokeLinecap="round">
                <circle cx="12" cy="13" r="7" />
                <path d="M12 9v4l2 2" />
                <path d="M9 3h6" />
              </svg>
            </button>
          </div>
        </div>

        {/* 例句 */}
        <div style={{
          marginTop: 14, padding: '14px 16px',
          background: LC.cream, borderRadius: 14,
          borderLeft: `3px solid ${LC.primary}`,
        }}>
          <div style={{
            fontSize: 11, color: LC.fog, letterSpacing: '0.15em',
            marginBottom: 6,
          }}>
            EXAMPLE · 例句
          </div>
          <div style={{
            fontFamily: LF.truku, fontStyle: 'italic', fontSize: 17,
            color: LC.primary, fontWeight: 500, marginBottom: 4,
          }}>
            Mhuway su, tama.
          </div>
          <div style={{ fontSize: 14, color: LC.inkSoft, letterSpacing: '0.05em' }}>
            爸爸，謝謝你。
          </div>
        </div>

        {/* 知道/不熟 */}
        <div style={{ marginTop: 16, display: 'flex', gap: 10 }}>
          <button style={{
            flex: 1, height: 50, borderRadius: 12,
            border: `1.5px solid ${LC.creamDeep}`,
            background: LC.creamLight, color: LC.inkSoft,
            fontFamily: LF.display, fontSize: 14, fontWeight: 500,
            letterSpacing: '0.1em', cursor: 'pointer',
          }}>再聽一次</button>
          <button style={{
            flex: 1, height: 50, borderRadius: 12, border: 'none',
            background: LC.primary, color: LC.creamLight,
            fontFamily: LF.display, fontSize: 14, fontWeight: 600,
            letterSpacing: '0.1em', cursor: 'pointer',
          }}>我會了 →</button>
        </div>
      </div>
    </div>
  );
}

Object.assign(window, { LearnScreen, LessonCardScreen });
