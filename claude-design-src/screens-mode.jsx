// 螢幕: 族語學習選擇模式（學習 vs 答題）

const { TRUKU_COLORS: MC, TRUKU_FONTS: MF } = window;

function LearnModePickScreen() {
  return (
    <div style={{
      width: '100%', minHeight: '100%',
      background: MC.creamLight, fontFamily: MF.body,
      position: 'relative', paddingBottom: 40,
    }}>
      {/* 頂部 nav */}
      <div style={{ padding: '60px 20px 0', display: 'flex', alignItems: 'center', gap: 12 }}>
        <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke={MC.ink} strokeWidth="2" strokeLinecap="round">
          <path d="M15 4 L7 12 L15 20" />
        </svg>
        <div style={{ flex: 1, fontFamily: MF.display, fontSize: 16, fontWeight: 600, color: MC.ink, letterSpacing: '0.05em' }}>
          家人稱謂
        </div>
        <div style={{
          padding: '4px 10px', borderRadius: 12, background: MC.primary + '15',
          fontFamily: MF.truku, fontStyle: 'italic', fontSize: 11, color: MC.primary, letterSpacing: '0.15em',
        }}>UNIT 02</div>
      </div>

      {/* 標頭 */}
      <div style={{ padding: '24px 20px 8px' }}>
        <div style={{
          fontFamily: MF.truku, fontStyle: 'italic', fontSize: 12,
          color: MC.fog, letterSpacing: '0.25em', marginBottom: 6,
        }}>LUTUT · 18 句</div>
        <div style={{
          fontFamily: MF.display, fontSize: 26, fontWeight: 600,
          color: MC.ink, letterSpacing: '0.04em', marginBottom: 4, lineHeight: 1.25,
        }}>你想怎麼學？</div>
        <div style={{ fontSize: 13, color: MC.inkSoft, opacity: 0.7, letterSpacing: '0.04em' }}>
          先學新單字，再來測試自己。
        </div>
      </div>

      {/* 進度條 */}
      <div style={{ padding: '12px 20px 0' }}>
        <div style={{
          background: MC.cream, borderRadius: 12, padding: '12px 14px',
          display: 'flex', alignItems: 'center', gap: 12,
          border: `1px solid ${MC.creamDeep}`,
        }}>
          <window.TrukuDiamond size={18} color={MC.primary} filled stroke={1.5}/>
          <div style={{ flex: 1 }}>
            <div style={{ fontSize: 11, color: MC.fog, letterSpacing: '0.1em', marginBottom: 4 }}>
              本單元進度
            </div>
            <div style={{ height: 6, background: MC.creamDeep, borderRadius: 3, overflow: 'hidden' }}>
              <div style={{ width: '78%', height: '100%', background: `linear-gradient(90deg, ${MC.primary}, ${MC.gold})` }} />
            </div>
          </div>
          <div style={{
            fontFamily: MF.display, fontSize: 14, fontWeight: 600, color: MC.primary, letterSpacing: '0.05em',
          }}>14<span style={{ fontSize: 10, opacity: 0.6 }}>/18</span></div>
        </div>
      </div>

      {/* 兩個模式卡 */}
      <div style={{ padding: '20px 20px 0', display: 'flex', flexDirection: 'column', gap: 14 }}>
        {/* 學習模式 */}
        <div style={{
          background: MC.ink, color: MC.creamLight,
          borderRadius: 22, padding: '22px 22px 22px',
          position: 'relative', overflow: 'hidden',
          minHeight: 180,
        }}>
          <div style={{ position: 'absolute', inset: 0, opacity: 0.12 }}>
            <window.TrukuWeaveBg color={MC.gold} bg="transparent" opacity={1} scale={0.7} />
          </div>
          <div style={{ position: 'absolute', right: -10, top: -10, opacity: 0.45 }}>
            <window.TrukuDiamond size={120} color={MC.gold} stroke={1.2}/>
          </div>

          <div style={{ position: 'relative', zIndex: 1 }}>
            <div style={{
              display: 'inline-flex', alignItems: 'center', gap: 6,
              padding: '4px 10px', borderRadius: 4,
              background: 'rgba(201, 169, 97, 0.15)', border: `0.5px solid ${MC.gold}50`,
              fontFamily: MF.truku, fontStyle: 'italic', fontSize: 10,
              color: MC.gold, letterSpacing: '0.2em', marginBottom: 14,
            }}>SLHAYAN · 學習</div>

            <div style={{
              fontFamily: MF.display, fontSize: 26, fontWeight: 600,
              color: MC.creamLight, letterSpacing: '0.05em', marginBottom: 6,
            }}>學習模式</div>
            <div style={{ fontSize: 13, opacity: 0.75, letterSpacing: '0.04em', lineHeight: 1.6, marginBottom: 18 }}>
              一張一張單字卡 · 跟讀發音<br/>例句解說 · 沒有時間壓力
            </div>

            <button style={{
              display: 'inline-flex', alignItems: 'center', gap: 10,
              padding: '12px 22px', borderRadius: 28, border: 'none',
              background: MC.gold, color: MC.ink,
              fontFamily: MF.display, fontSize: 14, fontWeight: 600, letterSpacing: '0.15em',
            }}>
              <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke={MC.ink} strokeWidth="2.5" strokeLinecap="round"><path d="M4 6h12M4 12h12M4 18h8"/></svg>
              開始學習
            </button>
          </div>
        </div>

        {/* 答題模式 */}
        <div style={{
          background: MC.primary, color: MC.creamLight,
          borderRadius: 22, padding: '22px 22px',
          position: 'relative', overflow: 'hidden',
          minHeight: 180,
        }}>
          <div style={{ position: 'absolute', inset: 0, opacity: 0.15 }}>
            <window.TrukuWeaveBg color={MC.gold} bg="transparent" opacity={1} scale={0.7} />
          </div>
          <div style={{ position: 'absolute', right: -10, top: -10, opacity: 0.4 }}>
            <window.TrukuDiamond size={120} color={MC.gold} stroke={1.2}/>
          </div>

          <div style={{ position: 'relative', zIndex: 1 }}>
            <div style={{
              display: 'inline-flex', alignItems: 'center', gap: 6,
              padding: '4px 10px', borderRadius: 4,
              background: 'rgba(0, 0, 0, 0.18)', border: `0.5px solid ${MC.gold}40`,
              fontFamily: MF.truku, fontStyle: 'italic', fontSize: 10,
              color: MC.gold, letterSpacing: '0.2em', marginBottom: 14,
            }}>SMRMUN · 測驗</div>

            <div style={{
              fontFamily: MF.display, fontSize: 26, fontWeight: 600,
              color: MC.creamLight, letterSpacing: '0.05em', marginBottom: 6,
            }}>答題模式</div>
            <div style={{ fontSize: 13, opacity: 0.85, letterSpacing: '0.04em', lineHeight: 1.6, marginBottom: 18 }}>
              四選一測驗 · 三條命挑戰<br/>累積答對紀錄 · 解鎖下個單元
            </div>

            <div style={{ display: 'flex', alignItems: 'center', gap: 14 }}>
              <button style={{
                display: 'inline-flex', alignItems: 'center', gap: 10,
                padding: '12px 22px', borderRadius: 28, border: 'none',
                background: MC.gold, color: MC.ink,
                fontFamily: MF.display, fontSize: 14, fontWeight: 600, letterSpacing: '0.15em',
              }}>
                <svg width="14" height="14" viewBox="0 0 24 24" fill={MC.ink} stroke="none"><path d="M4 2.5 L13 8 L4 13.5 Z"/></svg>
                開始答題
              </button>
              <div style={{ fontSize: 11, color: MC.gold, letterSpacing: '0.1em' }}>
                上次：<span style={{ fontFamily: MF.display, fontWeight: 600, fontSize: 14 }}>12</span>/15
              </div>
            </div>
          </div>
        </div>
      </div>

      {/* 額外練習 */}
      <div style={{ padding: '24px 20px 0' }}>
        <div style={{
          fontFamily: MF.display, fontSize: 13, fontWeight: 600, color: MC.fog,
          letterSpacing: '0.2em', marginBottom: 10,
        }}>進階練習</div>
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10 }}>
          {[
            { zh: '聽音辨字', truku: 'Mqita kari', icon: 'ear' },
            { zh: '我來念念', truku: 'Mha ku', icon: 'mic' },
          ].map(p => (
            <div key={p.zh} style={{
              background: MC.cream, borderRadius: 14, padding: '14px',
              border: `1px solid ${MC.creamDeep}`,
            }}>
              <div style={{
                width: 34, height: 34, borderRadius: 17,
                background: MC.primary + '12',
                display: 'flex', alignItems: 'center', justifyContent: 'center',
                marginBottom: 10,
              }}>
                {p.icon === 'ear' ? (
                  <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke={MC.primary} strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"><path d="M6 9a6 6 0 0112 0c0 3-2 4-2 6a3 3 0 01-6 0M9 13l-3 1"/></svg>
                ) : (
                  <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke={MC.primary} strokeWidth="1.8" strokeLinecap="round"><rect x="9" y="3" width="6" height="11" rx="3"/><path d="M5 11a7 7 0 0014 0M12 18v3"/></svg>
                )}
              </div>
              <div style={{
                fontFamily: MF.display, fontSize: 14, fontWeight: 600, color: MC.ink,
                letterSpacing: '0.04em', marginBottom: 2,
              }}>{p.zh}</div>
              <div style={{
                fontFamily: MF.truku, fontStyle: 'italic', fontSize: 10,
                color: MC.fog, letterSpacing: '0.12em',
              }}>{p.truku}</div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}

Object.assign(window, { LearnModePickScreen });
