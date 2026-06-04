// 螢幕: 發布文章

const { TRUKU_COLORS: APC, TRUKU_FONTS: APF } = window;

function ComposeArticleScreen() {
  const categories = [
    { zh: '口述歷史', truku: 'kari rudan' },
    { zh: '織布傳統', truku: 'tminun', selected: true },
    { zh: '祭儀', truku: 'gaya' },
    { zh: '部落音樂', truku: 'uyas' },
    { zh: '美食', truku: 'mkan' },
    { zh: '地景', truku: 'dgiyaq' },
  ];

  return (
    <div style={{
      width: '100%', minHeight: '100%', background: APC.creamLight, fontFamily: APF.body,
      paddingBottom: 100,
    }}>
      {/* 頂部 nav */}
      <div style={{
        position: 'sticky', top: 0, zIndex: 10,
        background: APC.creamLight, borderBottom: `1px solid ${APC.creamDeep}`,
        padding: '54px 16px 12px',
        display: 'flex', alignItems: 'center', justifyContent: 'space-between',
      }}>
        <button style={{
          padding: '6px 4px', border: 'none', background: 'transparent',
          color: APC.inkSoft, fontSize: 14, letterSpacing: '0.05em',
        }}>取消</button>
        <div style={{
          fontFamily: APF.display, fontSize: 15, fontWeight: 600,
          color: APC.ink, letterSpacing: '0.08em',
        }}>發布文章</div>
        <div style={{ display: 'flex', gap: 6 }}>
          <button style={{
            padding: '6px 12px', borderRadius: 16, border: `1px solid ${APC.creamDeep}`,
            background: APC.creamLight, color: APC.inkSoft, fontSize: 12, letterSpacing: '0.06em',
          }}>預覽</button>
          <button style={{
            padding: '6px 16px', borderRadius: 16, border: 'none',
            background: APC.primary, color: APC.creamLight,
            fontFamily: APF.display, fontSize: 13, fontWeight: 600, letterSpacing: '0.08em',
          }}>發布</button>
        </div>
      </div>

      {/* 封面 hero */}
      <div style={{ padding: '16px 20px 0' }}>
        <div style={{
          height: 130, borderRadius: 14, position: 'relative', overflow: 'hidden',
          background: `linear-gradient(135deg, ${APC.primary}, ${APC.primaryDeep})`,
        }}>
          <div style={{ position: 'absolute', inset: 0, opacity: 0.22 }}>
            <window.TrukuWeaveBg color={APC.gold} bg="transparent" opacity={1} scale={0.6} />
          </div>
          <div style={{ position: 'absolute', bottom: 0, left: 0, right: 0, opacity: 0.5 }}>
            <window.TrukuMountains width={362} height={40} color="#0E0604" opacity={0.6} />
          </div>
          <div style={{
            position: 'absolute', inset: 0, display: 'flex', flexDirection: 'column',
            alignItems: 'center', justifyContent: 'center', gap: 6,
          }}>
            <div style={{
              width: 42, height: 42, borderRadius: 21,
              background: 'rgba(250,245,234,0.2)', backdropFilter: 'blur(10px)',
              display: 'flex', alignItems: 'center', justifyContent: 'center',
            }}>
              <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke={APC.creamLight} strokeWidth="2" strokeLinecap="round">
                <path d="M12 4v16M4 12h16"/>
              </svg>
            </div>
            <div style={{ fontSize: 12, color: APC.creamLight, letterSpacing: '0.1em' }}>
              加入封面圖
            </div>
          </div>
        </div>
      </div>

      {/* 作者列 */}
      <div style={{ padding: '14px 20px 0', display: 'flex', alignItems: 'center', gap: 12 }}>
        <div style={{
          width: 36, height: 36, borderRadius: 18,
          background: APC.primary, border: `1.5px solid ${APC.gold}`,
          overflow: 'hidden', display: 'flex', alignItems: 'center', justifyContent: 'center',
        }}>
          <img src="badges/c-orange-happy.png" alt="" style={{ width: 40, height: 40, objectFit: 'contain' }} />
        </div>
        <div style={{ flex: 1 }}>
          <div style={{ fontFamily: APF.display, fontSize: 13, fontWeight: 600, color: APC.ink, letterSpacing: '0.04em' }}>
            Sayun Lowking
          </div>
          <div style={{ fontSize: 10, color: APC.fog, letterSpacing: '0.05em' }}>
            預估閱讀 8 分鐘
          </div>
        </div>
      </div>

      {/* 標題 */}
      <div style={{ padding: '16px 20px 0' }}>
        <div style={{
          fontFamily: APF.truku, fontStyle: 'italic', fontSize: 10,
          color: APC.fog, letterSpacing: '0.2em', marginBottom: 6,
        }}>HANGAN · 標題</div>
        <div style={{
          padding: '14px 16px', background: APC.cream, borderRadius: 12,
          border: `1px solid ${APC.creamDeep}`,
          fontFamily: APF.display, fontSize: 19, fontWeight: 700,
          color: APC.ink, letterSpacing: '0.04em', lineHeight: 1.35,
        }}>
          苧麻怎麼種——從一株到一塊布的旅程
          <span style={{
            display: 'inline-block', width: 1.5, height: 22,
            background: APC.primary, marginLeft: 2, verticalAlign: 'middle',
          }} />
        </div>
      </div>

      {/* 副標 */}
      <div style={{ padding: '12px 20px 0' }}>
        <div style={{
          fontFamily: APF.truku, fontStyle: 'italic', fontSize: 10,
          color: APC.fog, letterSpacing: '0.2em', marginBottom: 6,
        }}>SBARAH · 副標題（選填）</div>
        <div style={{
          padding: '10px 14px', background: APC.cream, borderRadius: 12,
          border: `1px solid ${APC.creamDeep}`,
          fontSize: 13, color: APC.inkSoft, letterSpacing: '0.04em', lineHeight: 1.5,
        }}>
          老人家說的話與我學到的事
        </div>
      </div>

      {/* 內文編輯器 toolbar */}
      <div style={{ padding: '14px 20px 0' }}>
        <div style={{
          fontFamily: APF.truku, fontStyle: 'italic', fontSize: 10,
          color: APC.fog, letterSpacing: '0.2em', marginBottom: 8,
        }}>PATAS · 內文</div>
        <div style={{
          background: APC.cream, borderRadius: 12,
          border: `1px solid ${APC.creamDeep}`, overflow: 'hidden',
        }}>
          {/* 格式工具列 */}
          <div style={{
            display: 'flex', gap: 4, padding: '8px 10px',
            borderBottom: `1px solid ${APC.creamDeep}`,
            background: APC.creamLight,
          }}>
            {[
              { k: 'h', label: 'H', font: 700, size: 14 },
              { k: 'b', label: 'B', font: 700, size: 13 },
              { k: 'i', label: 'I', font: 500, size: 13, italic: true },
              { k: 'q', icon: 'quote' },
              { k: 'list', icon: 'list' },
              { k: 'img', icon: 'img' },
              { k: 'truku', label: 'kari', font: 500, size: 11, italic: true, truku: true },
            ].map(t => (
              <div key={t.k} style={{
                width: 32, height: 28, borderRadius: 6,
                background: t.truku ? APC.primary + '15' : 'transparent',
                color: t.truku ? APC.primary : APC.inkSoft,
                display: 'flex', alignItems: 'center', justifyContent: 'center',
                fontFamily: t.truku ? APF.truku : APF.display,
                fontSize: t.size || 13, fontWeight: t.font || 500,
                fontStyle: t.italic ? 'italic' : 'normal',
              }}>
                {t.icon === 'quote' && <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke={APC.inkSoft} strokeWidth="2"><path d="M6 7h4v8H4V11l2-4zm10 0h4v8h-6V11l2-4z"/></svg>}
                {t.icon === 'list' && <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke={APC.inkSoft} strokeWidth="2" strokeLinecap="round"><path d="M9 7h11M9 12h11M9 17h11"/><circle cx="5" cy="7" r="1.2" fill={APC.inkSoft}/><circle cx="5" cy="12" r="1.2" fill={APC.inkSoft}/><circle cx="5" cy="17" r="1.2" fill={APC.inkSoft}/></svg>}
                {t.icon === 'img' && <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke={APC.inkSoft} strokeWidth="2"><rect x="3" y="4" width="18" height="16" rx="2"/><circle cx="9" cy="10" r="2"/><path d="M21 16l-5-5L4 20"/></svg>}
                {t.label}
              </div>
            ))}
          </div>
          {/* 內文 */}
          <div style={{
            minHeight: 180, padding: '14px 16px',
            fontSize: 14, color: APC.inkSoft, lineHeight: 1.7, letterSpacing: '0.03em',
          }}>
            <span style={{
              fontFamily: APF.display, fontSize: 36, fontWeight: 700,
              color: APC.primary, float: 'left', lineHeight: 0.9,
              marginRight: 6, marginTop: 4,
            }}>苧</span>
            麻（<span style={{ fontFamily: APF.truku, fontStyle: 'italic', color: APC.primary, fontWeight: 600 }}>krig</span>）對太魯閣族來說，不只是植物，是一整個世界。從種下、收割、剝皮、曬線、到織布，每一個步驟都是
            <span style={{
              display: 'inline-block', width: 1.5, height: 16,
              background: APC.primary, marginLeft: 2, verticalAlign: 'middle',
            }} />
          </div>
        </div>
      </div>

      {/* 分類 */}
      <div style={{ padding: '16px 20px 0' }}>
        <div style={{
          fontFamily: APF.truku, fontStyle: 'italic', fontSize: 10,
          color: APC.fog, letterSpacing: '0.2em', marginBottom: 8,
        }}>GAYA · 分類（選一個）</div>
        <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6 }}>
          {categories.map((c, i) => (
            <div key={i} style={{
              padding: '7px 12px', borderRadius: 14,
              background: c.selected ? APC.primary : 'transparent',
              color: c.selected ? APC.creamLight : APC.inkSoft,
              border: c.selected ? 'none' : `1px solid ${APC.creamDeep}`,
              fontSize: 12, letterSpacing: '0.06em',
              display: 'flex', alignItems: 'center', gap: 5,
            }}>
              <span>{c.zh}</span>
              <span style={{
                fontFamily: APF.truku, fontStyle: 'italic', fontSize: 10,
                color: c.selected ? APC.gold : APC.fog, opacity: 0.85,
              }}>· {c.truku}</span>
            </div>
          ))}
        </div>
      </div>

      {/* 標籤 */}
      <div style={{ padding: '14px 20px 0' }}>
        <div style={{
          fontFamily: APF.truku, fontStyle: 'italic', fontSize: 10,
          color: APC.fog, letterSpacing: '0.2em', marginBottom: 8,
        }}>SBARAH · 標籤</div>
        <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6 }}>
          {[
            { tag: '苧麻', active: true },
            { tag: '織布', active: true },
            { tag: 'krig', active: true, truku: true },
            { tag: '老人家' },
            { tag: '部落知識' },
          ].map((t, i) => (
            <div key={i} style={{
              padding: '6px 12px', borderRadius: 14,
              background: t.active ? APC.primary : 'transparent',
              color: t.active ? APC.creamLight : APC.inkSoft,
              border: t.active ? 'none' : `1px solid ${APC.creamDeep}`,
              fontFamily: t.truku ? APF.truku : APF.body,
              fontStyle: t.truku ? 'italic' : 'normal',
              fontSize: 12, letterSpacing: '0.08em',
            }}>
              <span style={{ opacity: 0.7 }}>#</span>{t.tag}
            </div>
          ))}
        </div>
      </div>

      {/* 底部工具列 */}
      <div style={{
        position: 'fixed', bottom: 0, left: 0, right: 0,
        background: APC.creamLight, borderTop: `1px solid ${APC.creamDeep}`,
        padding: '12px 20px 28px',
        display: 'flex', alignItems: 'center', gap: 12,
      }}>
        <div style={{ display: 'flex', gap: 6 }}>
          {[
            { icon: 'img' },
            { icon: 'quote' },
            { icon: 'tag' },
          ].map(t => (
            <div key={t.icon} style={{
              width: 36, height: 36, borderRadius: 18, background: APC.cream,
              display: 'flex', alignItems: 'center', justifyContent: 'center',
            }}>
              {t.icon === 'img' && <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke={APC.primary} strokeWidth="2"><rect x="3" y="4" width="18" height="16" rx="2"/><circle cx="9" cy="10" r="2"/><path d="M21 16l-5-5L4 20"/></svg>}
              {t.icon === 'quote' && <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke={APC.primary} strokeWidth="2"><path d="M6 7h4v8H4V11l2-4zm10 0h4v8h-6V11l2-4z"/></svg>}
              {t.icon === 'tag' && <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke={APC.primary} strokeWidth="2" strokeLinecap="round"><path d="M20 12l-8 8L3 11V3h8l9 9z"/><circle cx="7.5" cy="7.5" r="1" fill={APC.primary}/></svg>}
            </div>
          ))}
        </div>
        <div style={{ flex: 1, textAlign: 'right' }}>
          <div style={{ fontFamily: APF.mono, fontSize: 11, color: APC.fog }}>248 字</div>
          <div style={{ fontSize: 9, color: APC.fog, marginTop: 1, letterSpacing: '0.05em' }}>已自動儲存草稿</div>
        </div>
      </div>
    </div>
  );
}

window.ComposeArticleScreen = ComposeArticleScreen;
