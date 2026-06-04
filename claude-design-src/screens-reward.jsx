// 螢幕: 小米獎勵彈窗

const { TRUKU_COLORS: RC, TRUKU_FONTS: RF } = window;

// 彈窗本體
function MilletRewardPopup({ amount = 10, reason = '每日登入' }) {
  return (
    <div style={{
      position: 'absolute', inset: 0, zIndex: 100,
      background: 'rgba(28, 15, 13, 0.7)',
      backdropFilter: 'blur(8px)', WebkitBackdropFilter: 'blur(8px)',
      display: 'flex', alignItems: 'center', justifyContent: 'center',
      padding: 24,
    }}>
      {/* 卡片 */}
      <div style={{
        width: '100%', maxWidth: 320,
        background: `linear-gradient(160deg, ${RC.cream}, ${RC.creamLight})`,
        borderRadius: 24, padding: '32px 24px 24px',
        position: 'relative', overflow: 'hidden',
        boxShadow: '0 24px 60px rgba(0,0,0,0.5)',
        border: `2px solid ${RC.gold}`,
        textAlign: 'center',
      }}>
        {/* 背景織紋 */}
        <div style={{ position: 'absolute', inset: 0, opacity: 0.1 }}>
          <window.TrukuWeaveBg color={RC.primary} bg="transparent" opacity={1} scale={0.6} />
        </div>

        {/* 四角小菱形裝飾 */}
        <div style={{ position: 'absolute', top: 12, left: 12 }}>
          <window.TrukuDiamond size={12} color={RC.primary} filled stroke={1}/>
        </div>
        <div style={{ position: 'absolute', top: 12, right: 12 }}>
          <window.TrukuDiamond size={12} color={RC.primary} filled stroke={1}/>
        </div>
        <div style={{ position: 'absolute', bottom: 12, left: 12 }}>
          <window.TrukuDiamond size={12} color={RC.primary} filled stroke={1}/>
        </div>
        <div style={{ position: 'absolute', bottom: 12, right: 12 }}>
          <window.TrukuDiamond size={12} color={RC.primary} filled stroke={1}/>
        </div>

        <div style={{ position: 'relative' }}>
          {/* 標籤 */}
          <div style={{
            fontFamily: RF.truku, fontStyle: 'italic', fontSize: 11,
            color: RC.primary, letterSpacing: '0.3em', marginBottom: 6,
          }}>MHUWAY SU</div>
          <div style={{
            fontFamily: RF.display, fontSize: 20, fontWeight: 700,
            color: RC.ink, letterSpacing: '0.08em', marginBottom: 18,
          }}>恭喜獲得小米</div>

          {/* 小米光暈 + 圖 */}
          <div style={{ position: 'relative', width: 140, height: 140, margin: '0 auto 12px' }}>
            <div style={{
              position: 'absolute', inset: 0, borderRadius: '50%',
              background: `radial-gradient(circle, ${RC.gold}60 0%, transparent 70%)`,
            }} />
            {/* 光芒線 */}
            <svg width="140" height="140" viewBox="0 0 140 140" style={{ position: 'absolute', inset: 0 }}>
              {Array.from({ length: 12 }).map((_, i) => {
                const a = (i * 30) * Math.PI / 180;
                const x1 = 70 + Math.cos(a) * 50;
                const y1 = 70 + Math.sin(a) * 50;
                const x2 = 70 + Math.cos(a) * 65;
                const y2 = 70 + Math.sin(a) * 65;
                return <line key={i} x1={x1} y1={y1} x2={x2} y2={y2} stroke={RC.gold} strokeWidth="2" strokeLinecap="round"/>;
              })}
            </svg>
            <img src="badges/millet.png" alt="小米" style={{
              position: 'relative', width: 140, height: 140, objectFit: 'contain',
              filter: 'drop-shadow(0 6px 18px rgba(201,169,97,0.5))',
            }} />
          </div>

          {/* 數量 */}
          <div style={{
            display: 'flex', alignItems: 'baseline', justifyContent: 'center', gap: 6, marginBottom: 6,
          }}>
            <div style={{
              fontFamily: RF.display, fontSize: 14, fontWeight: 600,
              color: RC.primary, letterSpacing: '0.1em',
            }}>+</div>
            <div style={{
              fontFamily: RF.display, fontSize: 56, fontWeight: 700,
              color: RC.primary, letterSpacing: '0.02em', lineHeight: 1,
            }}>{amount}</div>
            <div style={{
              fontFamily: RF.display, fontSize: 16, fontWeight: 600,
              color: RC.inkSoft, letterSpacing: '0.1em',
            }}>顆小米</div>
          </div>

          {/* 原因 */}
          <div style={{
            display: 'inline-block', padding: '4px 12px', borderRadius: 12,
            background: RC.primary + '15', color: RC.primary,
            fontSize: 11, letterSpacing: '0.15em', marginBottom: 20,
          }}>{reason}</div>

          {/* 餘額 */}
          <div style={{
            background: RC.ink, borderRadius: 12, padding: '10px 14px',
            display: 'flex', alignItems: 'center', justifyContent: 'space-between',
            marginBottom: 18,
          }}>
            <div style={{
              fontSize: 11, color: RC.gold, opacity: 0.85, letterSpacing: '0.1em',
            }}>目前小米</div>
            <div style={{
              display: 'flex', alignItems: 'center', gap: 6,
              fontFamily: RF.display, fontSize: 18, fontWeight: 700, color: RC.creamLight,
            }}>
              <img src="badges/millet.png" alt="" style={{ width: 22, height: 22, objectFit: 'contain' }} />
              320
            </div>
          </div>

          {/* 按鈕 */}
          <div style={{ display: 'flex', gap: 8 }}>
            <button style={{
              flex: 1, padding: '14px', borderRadius: 14,
              border: `1.5px solid ${RC.creamDeep}`, background: RC.creamLight,
              color: RC.inkSoft, fontFamily: RF.display, fontSize: 14, fontWeight: 600,
              letterSpacing: '0.1em',
            }}>逛商店</button>
            <button style={{
              flex: 1.4, padding: '14px', borderRadius: 14, border: 'none',
              background: RC.primary, color: RC.creamLight,
              fontFamily: RF.display, fontSize: 14, fontWeight: 600, letterSpacing: '0.15em',
            }}>繼續</button>
          </div>
        </div>
      </div>
    </div>
  );
}

// 登入 + 彈窗
function LoginRewardScreen() {
  return (
    <div style={{ position: 'relative', width: '100%', height: '100%', overflow: 'hidden' }}>
      <window.LoginScreen />
      <MilletRewardPopup amount={10} reason="每日登入"/>
    </div>
  );
}

// 完成單元 + 彈窗
function LessonRewardScreen() {
  return (
    <div style={{ position: 'relative', width: '100%', height: '100%', overflow: 'hidden' }}>
      <window.LessonCardScreen />
      <MilletRewardPopup amount={10} reason="完成單元 · LUTUT"/>
    </div>
  );
}

window.MilletRewardPopup = MilletRewardPopup;
window.LoginRewardScreen = LoginRewardScreen;
window.LessonRewardScreen = LessonRewardScreen;
