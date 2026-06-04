// 螢幕: 文章列表（文化影音的文章分頁進階版）

const { TRUKU_COLORS: ALC, TRUKU_FONTS: ALF } = window;

function ArticleListScreen() {
  const featured = {
    title: '苧麻記事——祖母教我織布的那年夏天',
    excerpt: '從種下、收割、剝皮、曬線、到織布，每一個步驟都是 gaya——祖先傳下來的規矩。',
    author: 'Sayun Lowking', tribe: '銅門部落',
    read: '8 分鐘', views: '1.2k', cat: '織布傳統',
  };
  const articles = [
    { title: '走過立霧溪——一條河的族語名字', author: 'Pisaw', tribe: '太管處青年志工', read: '5 分鐘', views: '486', cat: '地景', color: CC.moss, date: '5/24' },
    { title: 'Gaya 不是規矩，是呼吸的方式', author: 'Yudaw', tribe: '富世部落', read: '12 分鐘', views: '892', cat: '文化', color: CC.primary, date: '5/22' },
    { title: '阿公教我打獵那天說的話', author: 'Watan', tribe: '崇德部落', read: '7 分鐘', views: '634', cat: '口述', color: CC.gold, date: '5/20' },
    { title: '小米播種祭的前一夜', author: 'Bakan', tribe: '秀林部落', read: '10 分鐘', views: '512', cat: '祭儀', color: CC.primary, date: '5/18' },
    { title: '紋面這件事——和祖母的最後一道線', author: 'Sayun', tribe: '銅門部落', read: '15 分鐘', views: '2.1k', cat: '口述', color: CC.moss, date: '5/15' },
    { title: '溪流命名史：那些祖先唱過的水', author: 'Pisaw', tribe: '太管處青年志工', read: '9 分鐘', views: '378', cat: '地景', color: CC.gold, date: '5/12' },
  ];

  return (
    <div style={{
      width: '100%', minHeight: '100%', background: CC.midnight,
      fontFamily: CF.body, color: CC.creamLight, paddingBottom: 100,
    }}>
      {/* 頂部 nav */}
      <div style={{
        padding: '54px 16px 14px', display: 'flex', alignItems: 'center', gap: 10,
        background: CC.midnightSoft, borderBottom: `1px solid rgba(250,245,234,0.08)`,
      }}>
        <button style={{
          width: 36, height: 36, borderRadius: 18, border: 'none',
          background: 'rgba(250,245,234,0.1)', color: CC.creamLight,
          display: 'flex', alignItems: 'center', justifyContent: 'center',
        }}>
          <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke={CC.creamLight} strokeWidth="2" strokeLinecap="round">
            <path d="M15 6l-6 6 6 6"/>
          </svg>
        </button>
        <div style={{ flex: 1 }}>
          <div style={{
            fontFamily: CF.truku, fontStyle: 'italic', fontSize: 11,
            color: CC.gold, letterSpacing: '0.25em',
          }}>PATAS KARI</div>
          <div style={{
            fontFamily: CF.display, fontSize: 17, fontWeight: 600,
            letterSpacing: '0.04em',
          }}>族人寫的文章</div>
        </div>
        <button style={{
          width: 36, height: 36, borderRadius: 18, border: 'none',
          background: 'rgba(250,245,234,0.1)', color: CC.creamLight,
          display: 'flex', alignItems: 'center', justifyContent: 'center',
        }}>
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke={CC.creamLight} strokeWidth="1.8"><circle cx="11" cy="11" r="7"/><path d="M16 16l5 5"/></svg>
        </button>
      </div>

      {/* 分類 chips */}
      <div style={{ padding: '14px 20px 0', display: 'flex', gap: 8, overflowX: 'auto' }}>
        {['全部', '熱門', '織布傳統', '地景', '口述歷史', '祭儀', '文化'].map((c, i) => (
          <div key={c} style={{
            padding: '7px 14px', borderRadius: 18,
            background: i === 0 ? CC.gold : 'transparent',
            color: i === 0 ? CC.ink : CC.cream,
            border: i === 0 ? 'none' : `1px solid ${CC.cream}30`,
            fontSize: 12, letterSpacing: '0.06em', whiteSpace: 'nowrap',
            fontWeight: i === 0 ? 600 : 400,
          }}>{c}</div>
        ))}
      </div>

      {/* 精選大卡 */}
      <div style={{ padding: '16px 20px 0' }}>
        <div style={{
          fontFamily: CF.truku, fontStyle: 'italic', fontSize: 10,
          color: CC.gold, letterSpacing: '0.2em', marginBottom: 10,
        }}>SLHAYAN · 編輯精選</div>
        <div style={{
          background: CC.midnightSoft, borderRadius: 16, overflow: 'hidden',
          border: `1px solid ${CC.gold}40`,
        }}>
          {/* hero */}
          <div style={{
            height: 150, position: 'relative', overflow: 'hidden',
            background: `linear-gradient(135deg, ${CC.primary}, ${CC.primaryDeep})`,
          }}>
            <div style={{ position: 'absolute', inset: 0, opacity: 0.25 }}>
              <window.TrukuWeaveBg color={CC.gold} bg="transparent" opacity={1} scale={0.7} />
            </div>
            <div style={{ position: 'absolute', bottom: 0, left: 0, right: 0, opacity: 0.5 }}>
              <window.TrukuMountains width={362} height={50} color="#0E0604" opacity={0.6} />
            </div>
            <div style={{
              position: 'absolute', top: 12, left: 12,
              padding: '4px 10px', borderRadius: 4,
              background: CC.gold, fontSize: 10, color: CC.ink, fontWeight: 600,
              letterSpacing: '0.15em',
            }}>本週精選</div>
            <div style={{
              position: 'absolute', top: 12, right: 12,
              padding: '3px 8px', borderRadius: 3,
              background: 'rgba(0,0,0,0.55)', fontSize: 10, color: CC.gold,
              letterSpacing: '0.08em',
            }}>{featured.cat}</div>
          </div>
          {/* 內容 */}
          <div style={{ padding: '14px 16px' }}>
            <div style={{
              fontFamily: CF.display, fontSize: 17, fontWeight: 600,
              color: CC.creamLight, letterSpacing: '0.04em', marginBottom: 8, lineHeight: 1.35,
            }}>{featured.title}</div>
            <div style={{
              fontSize: 12, color: CC.cream, opacity: 0.75, lineHeight: 1.55,
              letterSpacing: '0.03em', marginBottom: 12,
            }}>{featured.excerpt}</div>
            <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
              <div style={{
                width: 28, height: 28, borderRadius: 14,
                background: `linear-gradient(135deg, ${CC.moss}, ${CC.mossDeep})`,
                display: 'flex', alignItems: 'center', justifyContent: 'center',
                fontFamily: CF.display, fontSize: 12, color: CC.gold, fontWeight: 600,
              }}>{featured.author[0]}</div>
              <div style={{ flex: 1 }}>
                <div style={{ fontSize: 12, color: CC.cream, letterSpacing: '0.04em' }}>
                  {featured.author}
                </div>
                <div style={{ fontSize: 10, color: CC.fog, letterSpacing: '0.05em', marginTop: 1 }}>
                  {featured.tribe} · {featured.read} · {featured.views} 閱讀
                </div>
              </div>
              <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke={CC.gold} strokeWidth="2" strokeLinecap="round">
                <path d="M5 12h14M13 6l6 6-6 6"/>
              </svg>
            </div>
          </div>
        </div>
      </div>

      {/* 排序列 */}
      <div style={{
        padding: '20px 20px 8px', display: 'flex', alignItems: 'center', justifyContent: 'space-between',
      }}>
        <div style={{
          fontFamily: CF.display, fontSize: 14, fontWeight: 600,
          color: CC.cream, letterSpacing: '0.06em',
        }}>最新發布</div>
        <div style={{
          display: 'flex', alignItems: 'center', gap: 4,
          fontSize: 11, color: CC.gold, letterSpacing: '0.08em',
        }}>
          <svg width="11" height="11" viewBox="0 0 24 24" fill="none" stroke={CC.gold} strokeWidth="2"><path d="M3 6h18M6 12h12M9 18h6"/></svg>
          最新
        </div>
      </div>

      {/* 文章列表 */}
      <div style={{ padding: '0 20px', display: 'flex', flexDirection: 'column', gap: 10 }}>
        {articles.map((a, i) => (
          <div key={i} style={{
            background: CC.midnightSoft, borderRadius: 12,
            border: `1px solid ${CC.cream}10`,
            display: 'flex', gap: 12, padding: '12px',
          }}>
            {/* 縮圖 */}
            <div style={{
              width: 72, height: 86, borderRadius: 8, flexShrink: 0,
              background: `linear-gradient(135deg, ${a.color}, ${a.color}AA)`,
              position: 'relative', overflow: 'hidden',
              display: 'flex', alignItems: 'center', justifyContent: 'center',
            }}>
              <div style={{ position: 'absolute', inset: 0, opacity: 0.35 }}>
                <window.TrukuWeaveBg color={CC.gold} bg="transparent" opacity={1} scale={0.35} />
              </div>
              <div style={{
                position: 'relative', fontFamily: CF.display,
                fontSize: 20, color: CC.gold, fontWeight: 600,
              }}>文</div>
              <div style={{
                position: 'absolute', bottom: 4, right: 4,
                padding: '1px 5px', borderRadius: 2,
                background: 'rgba(0,0,0,0.6)', fontFamily: CF.mono,
                fontSize: 8, color: CC.cream, letterSpacing: '0.05em',
              }}>{a.date}</div>
            </div>
            <div style={{ flex: 1, display: 'flex', flexDirection: 'column', justifyContent: 'space-between', minWidth: 0 }}>
              <div>
                <div style={{
                  display: 'inline-block', padding: '2px 7px', borderRadius: 3,
                  background: `${CC.gold}20`, color: CC.gold, fontSize: 9,
                  letterSpacing: '0.12em', marginBottom: 5,
                }}>{a.cat}</div>
                <div style={{
                  fontFamily: CF.display, fontSize: 14, fontWeight: 600,
                  color: CC.cream, letterSpacing: '0.04em', lineHeight: 1.35,
                  overflow: 'hidden', textOverflow: 'ellipsis',
                  display: '-webkit-box', WebkitLineClamp: 2, WebkitBoxOrient: 'vertical',
                }}>{a.title}</div>
              </div>
              <div style={{ display: 'flex', alignItems: 'center', gap: 8, fontSize: 10, color: CC.fog, letterSpacing: '0.05em', marginTop: 6 }}>
                <span>@{a.author}</span>
                <span style={{ opacity: 0.5 }}>·</span>
                <span>{a.read}</span>
                <span style={{ opacity: 0.5 }}>·</span>
                <span>{a.views}</span>
              </div>
            </div>
          </div>
        ))}
      </div>

      {/* 載入更多 */}
      <div style={{ padding: '20px 20px 0', textAlign: 'center' }}>
        <button style={{
          padding: '10px 24px', borderRadius: 20, border: `1px solid ${CC.gold}50`,
          background: 'rgba(201,169,97,0.08)', color: CC.gold,
          fontSize: 12, letterSpacing: '0.1em',
        }}>載入更多文章</button>
      </div>
    </div>
  );
}

window.ArticleListScreen = ArticleListScreen;
