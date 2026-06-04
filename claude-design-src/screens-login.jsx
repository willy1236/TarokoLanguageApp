// 螢幕 0: 登入畫面 Login

const { TRUKU_COLORS: LGC, TRUKU_FONTS: LGF } = window;

function LoginScreen() {
  return (
    <div style={{
      width: '100%', height: '100%', position: 'relative', overflow: 'hidden',
      background: `linear-gradient(180deg, ${LGC.midnight} 0%, ${LGC.primaryDeep} 55%, ${LGC.primary} 100%)`,
      fontFamily: LGF.body, color: LGC.creamLight,
    }}>
      {/* 山稜剪影 */}
      <div style={{ position: 'absolute', bottom: 0, left: 0, right: 0, opacity: 0.7, zIndex: 1 }}>
        <window.TrukuMountains width={402} height={200} color="#0E0604" opacity={0.8} />
      </div>
      {/* 織紋紋理 */}
      <div style={{ position: 'absolute', inset: 0, opacity: 0.12 }}>
        <window.TrukuWeaveBg color={LGC.gold} bg="transparent" opacity={1} scale={1} />
      </div>

      {/* 頂部 logo 區 */}
      <div style={{
        position: 'relative', zIndex: 2,
        paddingTop: 80, display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 10,
      }}>
        <img src="logo-gold.png" alt="語見太魯閣" style={{ width: 130, height: 130, objectFit: 'contain' }} />
        <div style={{
          fontFamily: LGF.truku, fontStyle: 'italic', fontSize: 13,
          color: LGC.gold, letterSpacing: '0.2em',
        }}>Kari Truku · Lnglungan</div>
        <div style={{ marginTop: 2 }}>
          <window.TrukuChain count={5} size={7} color={LGC.gold} gap={5} />
        </div>
      </div>

      {/* 表單區 */}
      <div style={{
        position: 'absolute', left: 24, right: 24, bottom: 60, zIndex: 3,
        display: 'flex', flexDirection: 'column', gap: 12,
      }}>
        <div style={{ marginBottom: 4 }}>
          <div style={{
            fontFamily: LGF.truku, fontStyle: 'italic', fontSize: 11,
            color: LGC.gold, letterSpacing: '0.25em', marginBottom: 4,
          }}>MHUWAY SU · 歡迎回來</div>
          <div style={{
            fontFamily: LGF.display, fontSize: 22, fontWeight: 600,
            color: LGC.creamLight, letterSpacing: '0.05em',
          }}>登入，繼續說我們的話</div>
        </div>

        {/* 帳號輸入 */}
        <div style={{
          background: 'rgba(250, 245, 234, 0.08)',
          border: `1px solid ${LGC.gold}40`,
          borderRadius: 12, padding: '12px 16px',
          backdropFilter: 'blur(10px)', WebkitBackdropFilter: 'blur(10px)',
        }}>
          <div style={{ fontSize: 10, color: LGC.gold, letterSpacing: '0.2em', marginBottom: 4 }}>HANGAN · 帳號</div>
          <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke={LGC.cream} strokeWidth="1.6"><circle cx="12" cy="9" r="4"/><path d="M4 21c1-4 5-6 8-6s7 2 8 6"/></svg>
            <div style={{ flex: 1, fontSize: 15, color: LGC.creamLight, letterSpacing: '0.05em' }}>yudaw.bakan</div>
          </div>
        </div>

        {/* 密碼輸入 */}
        <div style={{
          background: 'rgba(250, 245, 234, 0.08)',
          border: `1px solid ${LGC.cream}25`,
          borderRadius: 12, padding: '12px 16px',
          backdropFilter: 'blur(10px)', WebkitBackdropFilter: 'blur(10px)',
        }}>
          <div style={{ fontSize: 10, color: LGC.cream, letterSpacing: '0.2em', marginBottom: 4, opacity: 0.7 }}>PASWAD · 密碼</div>
          <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke={LGC.cream} strokeWidth="1.6"><rect x="5" y="11" width="14" height="10" rx="2"/><path d="M8 11V7a4 4 0 018 0v4"/></svg>
            <div style={{ flex: 1, fontSize: 18, color: LGC.creamLight, letterSpacing: '0.4em' }}>••••••••</div>
            <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke={LGC.cream} strokeWidth="1.6" opacity="0.7"><path d="M2 12s4-7 10-7 10 7 10 7-4 7-10 7-10-7-10-7z"/><circle cx="12" cy="12" r="3"/></svg>
          </div>
        </div>

        {/* 忘記密碼 */}
        <div style={{ textAlign: 'right', fontSize: 12, color: LGC.cream, opacity: 0.7, letterSpacing: '0.05em' }}>
          忘記密碼？
        </div>

        {/* 登入按鈕 */}
        <button style={{
          height: 52, borderRadius: 14, border: 'none',
          background: LGC.gold, color: LGC.ink,
          fontFamily: LGF.display, fontSize: 16, fontWeight: 600,
          letterSpacing: '0.2em', cursor: 'pointer', marginTop: 4,
          boxShadow: '0 8px 24px rgba(201, 169, 97, 0.25)',
        }}>登　入</button>

        {/* 分隔 */}
        <div style={{ display: 'flex', alignItems: 'center', gap: 12, margin: '8px 0' }}>
          <div style={{ flex: 1, height: 1, background: `${LGC.cream}25` }} />
          <div style={{ fontSize: 10, color: LGC.cream, opacity: 0.6, letterSpacing: '0.2em' }}>OR</div>
          <div style={{ flex: 1, height: 1, background: `${LGC.cream}25` }} />
        </div>

        {/* 第三方登入 */}
        <div style={{ display: 'flex', gap: 10 }}>
          {[
            { label: 'Apple', icon: <svg width="18" height="18" viewBox="0 0 24 24" fill={LGC.creamLight}><path d="M17 12.5c0-2.5 2-3.7 2.1-3.8-1.1-1.7-2.9-1.9-3.5-2-1.5-.2-2.9.9-3.7.9s-1.9-.9-3.2-.9c-1.6 0-3.1 1-3.9 2.4-1.7 2.9-.4 7.2 1.2 9.5.8 1.1 1.8 2.4 3.1 2.4 1.2 0 1.7-.8 3.2-.8s1.9.8 3.2.8 2.2-1.2 3-2.3c.9-1.3 1.3-2.6 1.3-2.7 0-.1-2.6-1-2.6-3.5zM14.7 5.4c.7-.8 1.1-2 1-3.1-1 0-2.2.7-2.9 1.5-.6.7-1.2 1.9-1 3 1.1.1 2.2-.6 2.9-1.4z"/></svg> },
            { label: '部落帳號', icon: <window.TrukuDiamond size={18} color={LGC.gold} filled stroke={1.2}/> },
            { label: 'Google', icon: <svg width="18" height="18" viewBox="0 0 24 24"><path fill={LGC.creamLight} d="M12 11v3h5c-.2 1.3-1.5 3.8-5 3.8-3 0-5.4-2.5-5.4-5.5S9 6.8 12 6.8c1.7 0 2.8.7 3.5 1.3l2.4-2.3C16.3 4.4 14.4 3.5 12 3.5c-4.7 0-8.5 3.8-8.5 8.5s3.8 8.5 8.5 8.5c4.9 0 8.2-3.4 8.2-8.3 0-.6-.1-1-.1-1.4H12z"/></svg> },
          ].map(o => (
            <div key={o.label} style={{
              flex: 1, height: 48, borderRadius: 12,
              border: `1px solid ${LGC.cream}25`,
              background: 'rgba(250, 245, 234, 0.05)',
              display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', gap: 2,
              backdropFilter: 'blur(10px)',
            }}>
              {o.icon}
              <div style={{ fontSize: 9, color: LGC.cream, opacity: 0.8, letterSpacing: '0.1em' }}>{o.label}</div>
            </div>
          ))}
        </div>

        {/* 註冊 */}
        <div style={{ textAlign: 'center', fontSize: 13, color: LGC.cream, opacity: 0.85, marginTop: 12, letterSpacing: '0.05em' }}>
          還沒有帳號？<span style={{ color: LGC.gold, fontWeight: 600, marginLeft: 4 }}>立即註冊</span>
        </div>
      </div>
    </div>
  );
}

Object.assign(window, { LoginScreen });
