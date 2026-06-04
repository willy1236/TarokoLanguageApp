// 螢幕: 發布影片

const { TRUKU_COLORS: VPC, TRUKU_FONTS: VPF } = window;

function ComposeVideoScreen() {
  const categories = [
    { zh: '口述歷史', truku: 'kari rudan', selected: true },
    { zh: '織布傳統', truku: 'tminun' },
    { zh: '祭儀', truku: 'gaya' },
    { zh: '部落音樂', truku: 'uyas' },
    { zh: '美食', truku: 'mkan' },
    { zh: '地景', truku: 'dgiyaq' },
  ];

  return (
    <div style={{
      width: '100%', minHeight: '100%', background: VPC.creamLight, fontFamily: VPF.body,
      paddingBottom: 100,
    }}>
      {/* 頂部 nav */}
      <div style={{
        position: 'sticky', top: 0, zIndex: 10,
        background: VPC.creamLight, borderBottom: `1px solid ${VPC.creamDeep}`,
        padding: '54px 16px 12px',
        display: 'flex', alignItems: 'center', justifyContent: 'space-between',
      }}>
        <button style={{
          padding: '6px 4px', border: 'none', background: 'transparent',
          color: VPC.inkSoft, fontSize: 14, letterSpacing: '0.05em',
        }}>取消</button>
        <div style={{
          fontFamily: VPF.display, fontSize: 15, fontWeight: 600,
          color: VPC.ink, letterSpacing: '0.08em',
        }}>發布影片</div>
        <button style={{
          padding: '6px 16px', borderRadius: 16, border: 'none',
          background: VPC.primary, color: VPC.creamLight,
          fontFamily: VPF.display, fontSize: 13, fontWeight: 600, letterSpacing: '0.08em',
        }}>發布</button>
      </div>

      {/* 影片上傳區 */}
      <div style={{ padding: '18px 20px 0' }}>
        <div style={{
          height: 200, borderRadius: 16, position: 'relative', overflow: 'hidden',
          background: `linear-gradient(135deg, ${VPC.moss}, ${VPC.mossDeep})`,
        }}>
          <div style={{ position: 'absolute', inset: 0, opacity: 0.18 }}>
            <window.TrukuWeaveBg color={VPC.gold} bg="transparent" opacity={1} scale={0.6} />
          </div>
          <div style={{ position: 'absolute', bottom: 0, left: 0, right: 0, opacity: 0.55 }}>
            <window.TrukuMountains width={362} height={50} color="#0E0604" opacity={0.7} />
          </div>
          {/* 上傳中 hint */}
          <div style={{
            position: 'absolute', top: 12, left: 12,
            padding: '4px 10px', borderRadius: 4,
            background: 'rgba(28,15,13,0.6)', backdropFilter: 'blur(6px)',
            fontFamily: VPF.truku, fontStyle: 'italic', fontSize: 10,
            color: VPC.gold, letterSpacing: '0.2em',
          }}>已上傳</div>
          {/* 時長 */}
          <div style={{
            position: 'absolute', top: 12, right: 12,
            padding: '3px 8px', borderRadius: 3,
            background: 'rgba(0,0,0,0.65)', fontFamily: VPF.mono,
            fontSize: 11, color: VPC.creamLight, letterSpacing: '0.05em',
          }}>12:34</div>
          {/* 中央播放 */}
          <div style={{
            position: 'absolute', inset: 0, display: 'flex',
            alignItems: 'center', justifyContent: 'center',
          }}>
            <div style={{
              width: 60, height: 60, borderRadius: 30,
              background: 'rgba(0,0,0,0.5)', backdropFilter: 'blur(8px)',
              display: 'flex', alignItems: 'center', justifyContent: 'center',
              border: `1.5px solid ${VPC.gold}80`,
            }}>
              <window.PlayIcon size={22} color={VPC.gold} />
            </div>
          </div>
          {/* 換縮圖 / 重選 */}
          <div style={{
            position: 'absolute', bottom: 12, right: 12,
            display: 'flex', gap: 8,
          }}>
            <button style={{
              padding: '6px 10px', borderRadius: 14, border: 'none',
              background: 'rgba(28,15,13,0.6)', backdropFilter: 'blur(6px)',
              color: VPC.creamLight, fontSize: 11, letterSpacing: '0.05em',
              display: 'flex', alignItems: 'center', gap: 4,
            }}>
              <svg width="11" height="11" viewBox="0 0 24 24" fill="none" stroke={VPC.creamLight} strokeWidth="2"><rect x="3" y="4" width="18" height="16" rx="2"/><circle cx="9" cy="10" r="2"/><path d="M21 16l-5-5L4 20"/></svg>
              換縮圖
            </button>
          </div>
        </div>
      </div>

      {/* 作者列 */}
      <div style={{ padding: '14px 20px 0', display: 'flex', alignItems: 'center', gap: 12 }}>
        <div style={{
          width: 36, height: 36, borderRadius: 18,
          background: VPC.primary, border: `1.5px solid ${VPC.gold}`,
          overflow: 'hidden', display: 'flex', alignItems: 'center', justifyContent: 'center',
        }}>
          <img src="badges/c-orange-happy.png" alt="" style={{ width: 40, height: 40, objectFit: 'contain' }} />
        </div>
        <div style={{ flex: 1 }}>
          <div style={{ fontFamily: VPF.display, fontSize: 13, fontWeight: 600, color: VPC.ink, letterSpacing: '0.04em' }}>
            Sayun Lowking
          </div>
          <div style={{
            display: 'flex', alignItems: 'center', gap: 4,
            fontSize: 10, color: VPC.fog, letterSpacing: '0.05em',
          }}>
            <svg width="9" height="9" viewBox="0 0 24 24" fill="none" stroke={VPC.fog} strokeWidth="2"><circle cx="12" cy="12" r="9"/><path d="M3 12h18M12 3a14 14 0 010 18M12 3a14 14 0 000 18"/></svg>
            公開 · 所有族人都看得到
          </div>
        </div>
      </div>

      {/* 標題輸入 */}
      <div style={{ padding: '16px 20px 0' }}>
        <div style={{
          fontFamily: VPF.truku, fontStyle: 'italic', fontSize: 10,
          color: VPC.fog, letterSpacing: '0.2em', marginBottom: 6,
        }}>HANGAN · 影片標題</div>
        <div style={{
          padding: '12px 14px', background: VPC.cream, borderRadius: 12,
          border: `1px solid ${VPC.creamDeep}`,
          fontFamily: VPF.display, fontSize: 16, fontWeight: 600,
          color: VPC.ink, letterSpacing: '0.04em',
        }}>
          祖母教我織布的那年夏天
          <span style={{
            display: 'inline-block', width: 1.5, height: 18,
            background: VPC.primary, marginLeft: 2, verticalAlign: 'middle',
          }} />
        </div>
      </div>

      {/* 描述 */}
      <div style={{ padding: '14px 20px 0' }}>
        <div style={{
          fontFamily: VPF.truku, fontStyle: 'italic', fontSize: 10,
          color: VPC.fog, letterSpacing: '0.2em', marginBottom: 6,
        }}>KARI · 影片描述</div>
        <div style={{
          minHeight: 80, padding: '12px 14px',
          background: VPC.cream, borderRadius: 12,
          border: `1px solid ${VPC.creamDeep}`,
          fontSize: 13, color: VPC.inkSoft, lineHeight: 1.6, letterSpacing: '0.03em',
        }}>
          紋面（patas）對太魯閣族來說是成年的標記，也是進入靈界的通行證...
        </div>
      </div>

      {/* 分類 */}
      <div style={{ padding: '14px 20px 0' }}>
        <div style={{
          fontFamily: VPF.truku, fontStyle: 'italic', fontSize: 10,
          color: VPC.fog, letterSpacing: '0.2em', marginBottom: 8,
        }}>GAYA · 分類（選一個）</div>
        <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6 }}>
          {categories.map((c, i) => (
            <div key={i} style={{
              padding: '7px 12px', borderRadius: 14,
              background: c.selected ? VPC.primary : 'transparent',
              color: c.selected ? VPC.creamLight : VPC.inkSoft,
              border: c.selected ? 'none' : `1px solid ${VPC.creamDeep}`,
              fontSize: 12, letterSpacing: '0.06em',
              display: 'flex', alignItems: 'center', gap: 5,
            }}>
              <span>{c.zh}</span>
              <span style={{
                fontFamily: VPF.truku, fontStyle: 'italic', fontSize: 10,
                color: c.selected ? VPC.gold : VPC.fog, opacity: 0.85,
              }}>· {c.truku}</span>
            </div>
          ))}
        </div>
      </div>

      {/* 口述者資訊（選填） */}
      <div style={{ padding: '16px 20px 0' }}>
        <div style={{
          fontFamily: VPF.truku, fontStyle: 'italic', fontSize: 10,
          color: VPC.fog, letterSpacing: '0.2em', marginBottom: 8,
        }}>RUDAN · 口述者資訊（選填）</div>
        <div style={{
          background: VPC.cream, borderRadius: 12,
          border: `1px solid ${VPC.creamDeep}`, overflow: 'hidden',
        }}>
          {[
            { label: '口述者姓名', value: 'Bakan Nawi' },
            { label: '部落', value: '銅門部落' },
            { label: '年齡', value: '86 歲' },
          ].map((r, i, arr) => (
            <div key={r.label} style={{
              padding: '10px 14px',
              borderBottom: i < arr.length - 1 ? `1px solid ${VPC.creamDeep}` : 'none',
              display: 'flex', alignItems: 'center', justifyContent: 'space-between',
              fontSize: 13,
            }}>
              <div style={{ fontSize: 12, color: VPC.fog, letterSpacing: '0.05em' }}>{r.label}</div>
              <div style={{
                fontFamily: VPF.display, fontWeight: 500,
                color: VPC.ink, letterSpacing: '0.03em',
              }}>{r.value}</div>
            </div>
          ))}
        </div>
      </div>

      {/* 標籤 */}
      <div style={{ padding: '14px 20px 0' }}>
        <div style={{
          fontFamily: VPF.truku, fontStyle: 'italic', fontSize: 10,
          color: VPC.fog, letterSpacing: '0.2em', marginBottom: 8,
        }}>SBARAH · 標籤</div>
        <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6 }}>
          {[
            { tag: '紋面', active: true },
            { tag: '織布', active: true },
            { tag: '祖母' },
            { tag: '銅門部落' },
            { tag: '老人家' },
          ].map((t, i) => (
            <div key={i} style={{
              padding: '6px 12px', borderRadius: 14,
              background: t.active ? VPC.primary : 'transparent',
              color: t.active ? VPC.creamLight : VPC.inkSoft,
              border: t.active ? 'none' : `1px solid ${VPC.creamDeep}`,
              fontFamily: VPF.truku, fontStyle: 'italic', fontSize: 12,
              letterSpacing: '0.08em',
            }}>
              <span style={{ opacity: 0.7 }}>#</span>{t.tag}
            </div>
          ))}
        </div>
      </div>

      {/* 底部 */}
      <div style={{
        position: 'fixed', bottom: 0, left: 0, right: 0,
        background: VPC.creamLight, borderTop: `1px solid ${VPC.creamDeep}`,
        padding: '12px 20px 28px',
        display: 'flex', alignItems: 'center', gap: 10,
      }}>
        <div style={{ flex: 1, display: 'flex', alignItems: 'center', gap: 8 }}>
          <div style={{
            width: 32, height: 32, borderRadius: 16, background: VPC.cream,
            display: 'flex', alignItems: 'center', justifyContent: 'center',
          }}>
            <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke={VPC.primary} strokeWidth="2">
              <circle cx="12" cy="12" r="9"/>
              <path d="M3 12h18M12 3a14 14 0 010 18M12 3a14 14 0 000 18"/>
            </svg>
          </div>
          <div style={{ fontSize: 12, color: VPC.inkSoft, letterSpacing: '0.05em' }}>
            公開給所有族人
          </div>
        </div>
        <button style={{
          padding: '8px 14px', borderRadius: 16, border: `1px solid ${VPC.creamDeep}`,
          background: VPC.creamLight, color: VPC.inkSoft, fontSize: 12, letterSpacing: '0.08em',
        }}>儲存草稿</button>
      </div>
    </div>
  );
}

window.ComposeVideoScreen = ComposeVideoScreen;
