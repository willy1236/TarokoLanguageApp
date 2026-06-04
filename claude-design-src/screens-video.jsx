// 螢幕: 影片播放畫面 Video Player

const { TRUKU_COLORS: VC, TRUKU_FONTS: VF } = window;

function VideoPlayerScreen() {
  return (
    <div style={{
      width: '100%', minHeight: '100%',
      background: VC.midnight, fontFamily: VF.body,
      position: 'relative', color: VC.creamLight,
    }}>
      {/* 影片區 */}
      <div style={{
        position: 'relative', height: 460, overflow: 'hidden',
        background: `linear-gradient(180deg, ${VC.mossDeep} 0%, ${VC.midnight} 100%)`,
      }}>
        {/* 假影片畫面：條紋占位 */}
        <div style={{
          position: 'absolute', inset: 0,
          background: `repeating-linear-gradient(135deg, ${VC.mossDeep} 0 28px, ${VC.midnight} 28px 32px)`,
          opacity: 0.7,
        }} />
        <div style={{ position: 'absolute', inset: 0, opacity: 0.18 }}>
          <window.TrukuWeaveBg color={VC.gold} bg="transparent" opacity={1} scale={1.1} />
        </div>
        {/* 影片中央播放圖示 */}
        <div style={{ position: 'absolute', inset: 0, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
          <div style={{
            width: 72, height: 72, borderRadius: 36,
            background: 'rgba(0, 0, 0, 0.4)',
            border: `1.5px solid ${VC.gold}`,
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            backdropFilter: 'blur(8px)',
          }}>
            <window.PlayIcon size={26} color={VC.gold} />
          </div>
        </div>

        {/* 頂部漸層 */}
        <div style={{
          position: 'absolute', top: 0, left: 0, right: 0, height: 140,
          background: 'linear-gradient(180deg, rgba(0,0,0,0.65) 0%, transparent 100%)',
        }} />

        {/* 頂部 nav — 含關閉按鈕 */}
        <div style={{
          position: 'absolute', top: 56, left: 0, right: 0,
          padding: '0 16px', display: 'flex', alignItems: 'center', justifyContent: 'space-between', zIndex: 5,
        }}>
          {/* 關閉 X */}
          <button style={{
            width: 40, height: 40, borderRadius: 20, border: 'none',
            background: 'rgba(0, 0, 0, 0.5)',
            backdropFilter: 'blur(10px)', WebkitBackdropFilter: 'blur(10px)',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            cursor: 'pointer',
          }}>
            <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke={VC.creamLight} strokeWidth="2.2" strokeLinecap="round">
              <path d="M6 6 L18 18 M18 6 L6 18"/>
            </svg>
          </button>

          <div style={{
            fontFamily: VF.truku, fontStyle: 'italic', fontSize: 11,
            color: VC.gold, letterSpacing: '0.2em',
          }}>LNGLUNGAN</div>

          {/* 更多 */}
          <button style={{
            width: 40, height: 40, borderRadius: 20, border: 'none',
            background: 'rgba(0, 0, 0, 0.5)',
            backdropFilter: 'blur(10px)', WebkitBackdropFilter: 'blur(10px)',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
          }}>
            <svg width="18" height="18" viewBox="0 0 24 24" fill={VC.creamLight}>
              <circle cx="5" cy="12" r="2"/><circle cx="12" cy="12" r="2"/><circle cx="19" cy="12" r="2"/>
            </svg>
          </button>
        </div>

        {/* 底部漸層 + 控制條 */}
        <div style={{
          position: 'absolute', bottom: 0, left: 0, right: 0, height: 100,
          background: 'linear-gradient(0deg, rgba(0,0,0,0.7) 0%, transparent 100%)',
        }} />

        <div style={{ position: 'absolute', bottom: 14, left: 16, right: 16, zIndex: 5 }}>
          {/* 進度條 */}
          <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 10 }}>
            <div style={{ fontFamily: VF.mono, fontSize: 11, color: VC.creamLight, opacity: 0.85 }}>3:24</div>
            <div style={{ flex: 1, height: 3, background: 'rgba(255,255,255,0.25)', borderRadius: 2, position: 'relative' }}>
              <div style={{ width: '28%', height: '100%', background: VC.gold, borderRadius: 2 }} />
              <div style={{
                position: 'absolute', left: '28%', top: '50%',
                transform: 'translate(-50%, -50%)',
                width: 12, height: 12, borderRadius: 6, background: VC.gold,
              }} />
            </div>
            <div style={{ fontFamily: VF.mono, fontSize: 11, color: VC.creamLight, opacity: 0.7 }}>12:00</div>
          </div>
          {/* 控制按鈕 */}
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 28 }}>
            <svg width="24" height="24" viewBox="0 0 24 24" fill={VC.creamLight}>
              <path d="M11 5 L4 12 L11 19 Z M19 5 L12 12 L19 19 Z" opacity="0.85"/>
            </svg>
            <div style={{
              width: 48, height: 48, borderRadius: 24, background: VC.gold,
              display: 'flex', alignItems: 'center', justifyContent: 'center',
            }}>
              {/* pause */}
              <div style={{ display: 'flex', gap: 4 }}>
                <div style={{ width: 4, height: 16, background: VC.ink, borderRadius: 1 }} />
                <div style={{ width: 4, height: 16, background: VC.ink, borderRadius: 1 }} />
              </div>
            </div>
            <svg width="24" height="24" viewBox="0 0 24 24" fill={VC.creamLight}>
              <path d="M5 5 L12 12 L5 19 Z M13 5 L20 12 L13 19 Z" opacity="0.85"/>
            </svg>
          </div>
        </div>
      </div>

      {/* 影片資訊 */}
      <div style={{ padding: '18px 20px 0' }}>
        <div style={{
          display: 'inline-flex', alignItems: 'center', gap: 6,
          padding: '4px 10px', borderRadius: 4,
          background: VC.primary + '30', border: `0.5px solid ${VC.gold}40`,
          fontFamily: VF.truku, fontStyle: 'italic', fontSize: 10,
          color: VC.gold, letterSpacing: '0.2em', marginBottom: 12,
        }}>GAYA · 口述歷史</div>

        <div style={{
          fontFamily: VF.display, fontSize: 22, fontWeight: 600,
          color: VC.creamLight, letterSpacing: '0.04em', lineHeight: 1.3, marginBottom: 8,
        }}>
          紋面的故事——<br/>祖母的最後一道線
        </div>

        <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 18 }}>
          <div style={{
            width: 32, height: 32, borderRadius: 16,
            background: VC.primary, border: `1.5px solid ${VC.gold}`,
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            fontFamily: VF.display, fontSize: 12, fontWeight: 600, color: VC.creamLight,
          }}>B</div>
          <div style={{ flex: 1 }}>
            <div style={{ fontFamily: VF.display, fontSize: 13, fontWeight: 600, color: VC.creamLight, letterSpacing: '0.04em' }}>
              Bakan Nawi
            </div>
            <div style={{ fontSize: 10, color: VC.fog, letterSpacing: '0.08em' }}>
              口述者 · 銅門部落 · 86 歲
            </div>
          </div>
        </div>

        {/* 描述 */}
        <div style={{ fontSize: 13, color: VC.cream, opacity: 0.75, lineHeight: 1.7, letterSpacing: '0.03em', paddingBottom: 24 }}>
          紋面（patas）對太魯閣族來說是成年的標記，也是進入靈界的通行證。Bakan yaki 回憶起祖母替她紋面那一天的故事⋯⋯
        </div>
      </div>
    </div>
  );
}

Object.assign(window, { VideoPlayerScreen });
