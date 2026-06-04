// 螢幕: 答題式單字卡 Quiz

const { TRUKU_COLORS: QC, TRUKU_FONTS: QF } = window;

function QuizScreen() {
  const options = [
    { truku: 'Tama', zh: '爸爸', state: 'correct' },
    { truku: 'Bubu', zh: '媽媽', state: 'default' },
    { truku: 'Baki', zh: '爺爺', state: 'wrong' },
    { truku: 'Payi', zh: '奶奶', state: 'default' },
  ];

  const stateBg = (s) => {
    if (s === 'correct') return { bg: QC.moss, fg: QC.creamLight, border: QC.gold };
    if (s === 'wrong') return { bg: QC.creamLight, fg: '#A33', border: '#A33' };
    return { bg: QC.cream, fg: QC.ink, border: QC.creamDeep };
  };

  return (
    <div style={{
      width: '100%', minHeight: '100%',
      background: QC.creamLight, fontFamily: QF.body,
      position: 'relative', paddingBottom: 40,
    }}>
      {/* 頂部進度 */}
      <div style={{ padding: '60px 20px 0', display: 'flex', alignItems: 'center', gap: 12 }}>
        <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke={QC.ink} strokeWidth="2" strokeLinecap="round">
          <path d="M18 6 L6 18 M6 6 L18 18" />
        </svg>
        <div style={{ flex: 1, height: 6, background: QC.creamDeep, borderRadius: 3, overflow: 'hidden' }}>
          <div style={{ width: '40%', height: '100%', background: `linear-gradient(90deg, ${QC.primary}, ${QC.gold})` }} />
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 4 }}>
          {[1,1,1,0,0].map((h, i) => (
            <svg key={i} width="14" height="14" viewBox="0 0 24 24" fill={h ? '#D9534F' : 'none'} stroke="#D9534F" strokeWidth="2">
              <path d="M12 21s-7-4.5-9.5-9C1 9 2 5.5 5 4c2-.5 4 .5 7 4 3-3.5 5-4.5 7-4 3 1.5 4 5 2.5 8-2.5 4.5-9.5 9-9.5 9z"/>
            </svg>
          ))}
        </div>
      </div>

      {/* 單元標 */}
      <div style={{ padding: '20px 20px 8px' }}>
        <div style={{
          fontFamily: QF.truku, fontStyle: 'italic', fontSize: 11,
          color: QC.fog, letterSpacing: '0.2em', marginBottom: 4,
        }}>UNIT 02 · LUTUT · 第 6 / 15 題</div>
        <div style={{
          fontFamily: QF.display, fontSize: 16, fontWeight: 500,
          color: QC.inkSoft, letterSpacing: '0.05em',
        }}>選出正確的族語</div>
      </div>

      {/* 題目卡 */}
      <div style={{ padding: '12px 20px 0' }}>
        <div style={{
          background: QC.ink, color: QC.creamLight,
          borderRadius: 22, padding: '36px 24px 28px',
          position: 'relative', overflow: 'hidden',
          minHeight: 220,
          display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center',
        }}>
          <div style={{ position: 'absolute', inset: 0, opacity: 0.1 }}>
            <window.TrukuWeaveBg color={QC.gold} bg="transparent" opacity={1} scale={0.8} />
          </div>
          <div style={{ position: 'absolute', top: 16, right: 16, opacity: 0.5 }}>
            <window.TrukuDiamond size={22} color={QC.gold} stroke={1.2} />
          </div>
          <div style={{ position: 'absolute', top: 16, left: 16, opacity: 0.5 }}>
            <window.TrukuDiamond size={22} color={QC.gold} stroke={1.2} />
          </div>

          <div style={{ position: 'relative', zIndex: 1, textAlign: 'center' }}>
            <div style={{
              fontSize: 11, color: QC.gold, letterSpacing: '0.25em', marginBottom: 14, fontWeight: 500,
            }}>下面這個中文，族語怎麼說？</div>
            <div style={{
              fontFamily: QF.display, fontSize: 64, fontWeight: 700,
              color: QC.creamLight, letterSpacing: '0.1em', lineHeight: 1,
            }}>爸爸</div>

            {/* 喇叭按鈕 */}
            <button style={{
              marginTop: 22,
              width: 52, height: 52, borderRadius: 26, border: `1.5px solid ${QC.gold}`,
              background: 'rgba(201, 169, 97, 0.15)', cursor: 'pointer',
              display: 'inline-flex', alignItems: 'center', justifyContent: 'center',
            }}>
              <window.SpeakerIcon size={22} color={QC.gold} />
            </button>
            <div style={{ fontSize: 10, color: QC.gold, opacity: 0.7, letterSpacing: '0.2em', marginTop: 6 }}>
              點擊聽發音
            </div>
          </div>
        </div>
      </div>

      {/* 4 個選項 */}
      <div style={{ padding: '20px 20px 0', display: 'flex', flexDirection: 'column', gap: 10 }}>
        {options.map((o, i) => {
          const s = stateBg(o.state);
          return (
            <div key={i} style={{
              background: s.bg, color: s.fg,
              borderRadius: 14, padding: '14px 16px',
              border: `1.5px solid ${s.border}`,
              display: 'flex', alignItems: 'center', gap: 14,
              position: 'relative', overflow: 'hidden',
              cursor: 'pointer',
            }}>
              {/* 選項編號 */}
              <div style={{
                width: 32, height: 32, flexShrink: 0,
                display: 'flex', alignItems: 'center', justifyContent: 'center',
                position: 'relative',
              }}>
                <window.TrukuDiamond size={32} color={o.state === 'default' ? QC.primary : (o.state === 'correct' ? QC.gold : '#A33')} filled={o.state !== 'default'} stroke={1.5}/>
                <div style={{
                  position: 'absolute', zIndex: 1,
                  fontFamily: QF.display, fontSize: 13, fontWeight: 600,
                  color: o.state === 'default' ? QC.primary : QC.creamLight,
                }}>{['A','B','C','D'][i]}</div>
              </div>

              <div style={{ flex: 1 }}>
                <div style={{
                  fontFamily: QF.truku, fontStyle: 'italic', fontSize: 20,
                  fontWeight: 600, letterSpacing: '0.04em', marginBottom: 2,
                }}>{o.truku}</div>
                <div style={{ fontSize: 11, opacity: 0.65, letterSpacing: '0.08em' }}>{o.zh}</div>
              </div>

              {/* 狀態圖示 */}
              {o.state === 'correct' && (
                <div style={{
                  width: 28, height: 28, borderRadius: 14,
                  background: QC.gold, display: 'flex', alignItems: 'center', justifyContent: 'center',
                }}>
                  <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke={QC.ink} strokeWidth="3" strokeLinecap="round" strokeLinejoin="round">
                    <path d="M5 12 L10 17 L19 7"/>
                  </svg>
                </div>
              )}
              {o.state === 'wrong' && (
                <div style={{
                  width: 28, height: 28, borderRadius: 14,
                  background: '#A33', display: 'flex', alignItems: 'center', justifyContent: 'center',
                }}>
                  <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke={QC.creamLight} strokeWidth="3" strokeLinecap="round">
                    <path d="M6 6 L18 18 M18 6 L6 18"/>
                  </svg>
                </div>
              )}
            </div>
          );
        })}
      </div>

      {/* 答對提示 */}
      <div style={{ padding: '20px 20px 0' }}>
        <div style={{
          background: QC.cream, borderRadius: 14, padding: '14px 16px',
          borderLeft: `3px solid ${QC.moss}`,
        }}>
          <div style={{ fontSize: 11, color: QC.moss, letterSpacing: '0.2em', marginBottom: 6, fontWeight: 600 }}>
            ✓ MALU · 答對了
          </div>
          <div style={{
            fontFamily: QF.truku, fontStyle: 'italic', fontSize: 17,
            color: QC.primary, fontWeight: 500, marginBottom: 4,
          }}>
            Mhuway su, tama.
          </div>
          <div style={{ fontSize: 13, color: QC.inkSoft }}>爸爸，謝謝你。</div>
        </div>

        <button style={{
          marginTop: 14, width: '100%', height: 52, borderRadius: 14, border: 'none',
          background: QC.primary, color: QC.creamLight,
          fontFamily: QF.display, fontSize: 15, fontWeight: 600,
          letterSpacing: '0.2em', cursor: 'pointer',
        }}>下一題 →</button>
      </div>
    </div>
  );
}

Object.assign(window, { QuizScreen });
