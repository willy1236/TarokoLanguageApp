// 螢幕: 文章閱讀畫面 Article Reader

const { TRUKU_COLORS: AC, TRUKU_FONTS: AF } = window;

function ArticleScreen() {
  return (
    <div style={{
      width: '100%', minHeight: '100%',
      background: AC.creamLight, fontFamily: AF.body,
      position: 'relative', color: AC.ink,
    }}>
      {/* 頂部 nav — 含關閉 */}
      <div style={{
        position: 'sticky', top: 0, zIndex: 10,
        background: 'rgba(250, 245, 234, 0.92)',
        backdropFilter: 'blur(20px)', WebkitBackdropFilter: 'blur(20px)',
        borderBottom: `1px solid ${AC.creamDeep}`,
        padding: '54px 16px 12px',
        display: 'flex', alignItems: 'center', justifyContent: 'space-between',
      }}>
        <button style={{
          width: 36, height: 36, borderRadius: 18, border: 'none',
          background: AC.cream, display: 'flex', alignItems: 'center', justifyContent: 'center', cursor: 'pointer',
        }}>
          <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke={AC.ink} strokeWidth="2.2" strokeLinecap="round">
            <path d="M6 6 L18 18 M18 6 L6 18"/>
          </svg>
        </button>
        <div style={{
          fontFamily: AF.truku, fontStyle: 'italic', fontSize: 11,
          color: AC.primary, letterSpacing: '0.25em',
        }}>PATAS · 文章</div>
        <button style={{
          width: 36, height: 36, borderRadius: 18, border: 'none',
          background: AC.cream, display: 'flex', alignItems: 'center', justifyContent: 'center',
        }}>
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke={AC.ink} strokeWidth="1.8">
            <text x="3" y="17" fontFamily="serif" fontSize="14" fontWeight="700" fill={AC.ink}>A</text>
            <text x="13" y="17" fontFamily="serif" fontSize="9" fontWeight="700" fill={AC.ink}>A</text>
          </svg>
        </button>
      </div>

      {/* hero */}
      <div style={{
        position: 'relative', height: 200, overflow: 'hidden',
        background: `linear-gradient(135deg, ${AC.primary}, ${AC.primaryDeep})`,
      }}>
        <div style={{ position: 'absolute', inset: 0, opacity: 0.25 }}>
          <window.TrukuWeaveBg color={AC.gold} bg="transparent" opacity={1} scale={0.9} />
        </div>
        <div style={{ position: 'absolute', bottom: 0, left: 0, right: 0, opacity: 0.6 }}>
          <window.TrukuMountains width={402} height={80} color="#0E0604" opacity={0.7} />
        </div>
      </div>

      {/* 標題區 */}
      <div style={{ padding: '20px 22px 12px' }}>
        <div style={{
          display: 'inline-flex', alignItems: 'center', gap: 6,
          padding: '4px 10px', borderRadius: 4,
          background: AC.primary + '15',
          fontFamily: AF.truku, fontStyle: 'italic', fontSize: 10,
          color: AC.primary, letterSpacing: '0.2em', marginBottom: 14,
        }}>TMINUN · 織布傳統</div>

        <div style={{
          fontFamily: AF.display, fontSize: 26, fontWeight: 700,
          color: AC.ink, letterSpacing: '0.04em', lineHeight: 1.35, marginBottom: 14,
        }}>苧麻怎麼種——<br/>從一株到一塊布的旅程</div>

        <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 4 }}>
          <div style={{
            width: 32, height: 32, borderRadius: 16,
            background: AC.moss, border: `1.5px solid ${AC.gold}`,
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            fontFamily: AF.display, fontSize: 12, fontWeight: 600, color: AC.creamLight,
          }}>Y</div>
          <div style={{ flex: 1 }}>
            <div style={{ fontFamily: AF.display, fontSize: 13, fontWeight: 600, color: AC.ink }}>
              Yudaw Pisaw
            </div>
            <div style={{ fontSize: 11, color: AC.fog, letterSpacing: '0.05em' }}>
              5 月 7 日 · 8 分鐘閱讀 · 1.2k 次閱讀
            </div>
          </div>
        </div>
      </div>

      {/* 分隔織紋 */}
      <div style={{ padding: '8px 22px 16px', display: 'flex', justifyContent: 'center' }}>
        <window.TrukuChain count={5} size={8} color={AC.primary} gap={5} />
      </div>

      {/* 內文 */}
      <div style={{ padding: '0 22px', fontSize: 16, lineHeight: 1.85, letterSpacing: '0.03em', color: AC.inkSoft }}>
        <p style={{ marginTop: 0 }}>
          <span style={{
            fontFamily: AF.display, fontSize: 44, fontWeight: 700,
            color: AC.primary, float: 'left', lineHeight: 0.9,
            marginRight: 8, marginTop: 6,
          }}>苧</span>
          麻（krig）對太魯閣族來說，不只是植物，是一整個世界。從種下、收割、剝皮、曬線、到織布，每一個步驟都是 <span style={{ color: AC.primary, fontWeight: 600 }}>gaya</span>——祖先傳下來的規矩。
        </p>

        {/* 引文 */}
        <div style={{
          margin: '24px -8px',
          padding: '18px 20px',
          background: AC.cream, borderRadius: 14,
          borderLeft: `3px solid ${AC.gold}`,
        }}>
          <div style={{
            fontFamily: AF.truku, fontStyle: 'italic', fontSize: 18,
            color: AC.primary, fontWeight: 600, marginBottom: 6, letterSpacing: '0.04em',
          }}>"Krig o lnglungan na truku."</div>
          <div style={{ fontSize: 13, color: AC.fog, letterSpacing: '0.05em' }}>
            苧麻，是太魯閣人的靈魂。
          </div>
        </div>

        <h3 style={{
          fontFamily: AF.display, fontSize: 19, fontWeight: 700,
          color: AC.ink, letterSpacing: '0.04em', marginTop: 28, marginBottom: 10,
          display: 'flex', alignItems: 'center', gap: 8,
        }}>
          <window.TrukuDiamond size={14} color={AC.primary} filled stroke={1.5}/>
          一、種植的時節
        </h3>

        <p>
          老人家說，苧麻要在 <span style={{ color: AC.primary, fontWeight: 600 }}>kbalay</span>（春雨）來之前下種。土地要選排水好的山坡，不能太濕，不然根會爛。
        </p>

        <p>
          以前部落的女人會一起到山上，帶著歌聲。種下的不只是種子，還有對下一代的期待。
        </p>

        {/* 圖片占位 */}
        <div style={{
          margin: '20px -8px',
          height: 180, borderRadius: 14, overflow: 'hidden',
          background: `repeating-linear-gradient(45deg, ${AC.creamDeep} 0 12px, ${AC.cream} 12px 14px)`,
          display: 'flex', alignItems: 'center', justifyContent: 'center', position: 'relative',
        }}>
          <div style={{
            fontFamily: AF.mono, fontSize: 11,
            color: AC.fog, letterSpacing: '0.15em',
            padding: '6px 12px', background: 'rgba(250,245,234,0.8)', borderRadius: 4,
          }}>圖片：苧麻田</div>
        </div>
        <div style={{ fontSize: 11, color: AC.fog, textAlign: 'center', marginTop: -10, marginBottom: 14, letterSpacing: '0.05em' }}>
          銅門部落的苧麻田·攝於 2024
        </div>

        <h3 style={{
          fontFamily: AF.display, fontSize: 19, fontWeight: 700,
          color: AC.ink, letterSpacing: '0.04em', marginTop: 24, marginBottom: 10,
          display: 'flex', alignItems: 'center', gap: 8,
        }}>
          <window.TrukuDiamond size={14} color={AC.primary} filled stroke={1.5}/>
          二、剝皮與曬線
        </h3>

        <p>
          收割後，要用手把外層的皮剝下，這是最費力的工作。一次要剝幾十株，手會被刮傷⋯⋯
        </p>
      </div>

      {/* 族語小辭典 */}
      <div style={{ padding: '20px 22px 0' }}>
        <div style={{
          background: AC.ink, color: AC.creamLight, borderRadius: 16,
          padding: '16px 18px', position: 'relative', overflow: 'hidden',
        }}>
          <div style={{ position: 'absolute', right: -10, top: -10, opacity: 0.18 }}>
            <window.TrukuDiamond size={80} color={AC.gold} stroke={1.2}/>
          </div>
          <div style={{
            fontFamily: AF.truku, fontStyle: 'italic', fontSize: 11,
            color: AC.gold, letterSpacing: '0.25em', marginBottom: 10,
          }}>HANGAN · 文中族語</div>
          {[
            { t: 'krig', zh: '苧麻' },
            { t: 'gaya', zh: '祖訓 / 規矩' },
            { t: 'kbalay', zh: '春雨' },
          ].map((d, i, a) => (
            <div key={d.t} style={{
              display: 'flex', alignItems: 'center', gap: 12,
              padding: '8px 0',
              borderBottom: i < a.length - 1 ? `1px solid rgba(250, 245, 234, 0.1)` : 'none',
            }}>
              <div style={{
                fontFamily: AF.truku, fontStyle: 'italic', fontSize: 16,
                fontWeight: 500, color: AC.gold, minWidth: 90, letterSpacing: '0.04em',
              }}>{d.t}</div>
              <div style={{ flex: 1, fontSize: 13, opacity: 0.85 }}>{d.zh}</div>
              <button style={{
                width: 32, height: 32, borderRadius: 16,
                background: 'rgba(201, 169, 97, 0.15)', border: `1px solid ${AC.gold}50`,
                display: 'flex', alignItems: 'center', justifyContent: 'center',
              }}>
                <window.SpeakerIcon size={14} color={AC.gold}/>
              </button>
            </div>
          ))}
        </div>
      </div>

      {/* 互動列 */}
      <div style={{
        padding: '20px 22px 30px',
        display: 'flex', gap: 8,
      }}>
        {[
          { icon: '♡', label: '156', name: 'like' },
          { icon: '💬', label: '12', name: 'comm' },
        ].map(b => (
          <div key={b.name} style={{
            flex: 1, padding: '10px 0', borderRadius: 10,
            background: AC.cream, border: `1px solid ${AC.creamDeep}`,
            display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 6,
          }}>
            <div style={{ fontSize: 16, color: AC.primary }}>{b.icon}</div>
            <div style={{ fontSize: 12, color: AC.inkSoft, letterSpacing: '0.05em' }}>{b.label}</div>
          </div>
        ))}
      </div>
    </div>
  );
}

Object.assign(window, { ArticleScreen });
