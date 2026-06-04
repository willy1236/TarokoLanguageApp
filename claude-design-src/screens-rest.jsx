// 螢幕 5: 文化影音專區
// 螢幕 6: 互動專區（視訊/貼文/活動）
// 螢幕 7: 部落地圖

const { TRUKU_COLORS: CC, TRUKU_FONTS: CF } = window;

// ─────────────────────────────────────────────────────────────
// 文化影音
// ─────────────────────────────────────────────────────────────
function CultureScreen() {
  return (
    <div style={{ width: '100%', minHeight: '100%', background: CC.midnight, fontFamily: CF.body, paddingBottom: 100, color: CC.creamLight }}>
      {/* hero featured video */}
      <div style={{
        position: 'relative', height: 360, overflow: 'hidden',
        background: `linear-gradient(180deg, ${CC.mossDeep} 0%, ${CC.midnight} 100%)`,
      }}>
        {/* 假圖片：條紋占位 */}
        <div style={{
          position: 'absolute', inset: 0,
          background: `repeating-linear-gradient(135deg, ${CC.mossDeep} 0 24px, ${CC.midnight} 24px 28px)`,
          opacity: 0.6,
        }} />
        <div style={{ position: 'absolute', inset: 0, opacity: 0.25 }}>
          <window.TrukuWeaveBg color={CC.gold} bg="transparent" opacity={1} scale={1} />
        </div>
        {/* 漸層遮罩 */}
        <div style={{
          position: 'absolute', inset: 0,
          background: `linear-gradient(180deg, transparent 0%, transparent 50%, ${CC.midnight} 100%)`,
        }} />

        {/* 頂部 nav */}
        <div style={{ position: 'absolute', top: 60, left: 0, right: 0, padding: '0 20px', display: 'flex', justifyContent: 'space-between', alignItems: 'center', zIndex: 2 }}>
          <div style={{
            fontFamily: CF.truku, fontStyle: 'italic', fontSize: 13,
            color: CC.gold, letterSpacing: '0.25em',
          }}>LNGLUNGAN</div>
          <div style={{
            width: 36, height: 36, borderRadius: 18,
            background: 'rgba(0,0,0,0.4)', display: 'flex', alignItems: 'center', justifyContent: 'center',
            border: `1px solid ${CC.gold}40`,
          }}>
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke={CC.gold} strokeWidth="2"><circle cx="11" cy="11" r="7"/><path d="M16 16l5 5"/></svg>
          </div>
        </div>

        {/* hero info */}
        <div style={{ position: 'absolute', bottom: 24, left: 20, right: 20, zIndex: 2 }}>
          <div style={{
            fontSize: 11, color: CC.gold, letterSpacing: '0.25em', marginBottom: 8,
          }}>本週精選 · GAYA</div>
          <div style={{
            fontFamily: CF.display, fontSize: 26, fontWeight: 600,
            letterSpacing: '0.04em', lineHeight: 1.2, marginBottom: 6,
          }}>
            紋面的故事——<br/>祖母的最後一道線
          </div>
          <div style={{ fontSize: 12, opacity: 0.7, letterSpacing: '0.05em', marginBottom: 14 }}>
            口述 · Bakan Nawi　|　12 分鐘
          </div>
          <button style={{
            display: 'flex', alignItems: 'center', gap: 10,
            padding: '10px 20px', borderRadius: 30, border: 'none',
            background: CC.gold, color: CC.ink,
            fontFamily: CF.display, fontSize: 14, fontWeight: 600,
            letterSpacing: '0.1em', cursor: 'pointer',
          }}>
            <window.PlayIcon size={12} color={CC.ink} />
            <span>立即觀看</span>
          </button>
        </div>
      </div>

      {/* 主分頁切換：影音 / 文章 */}
      <div style={{ padding: '20px 20px 0', display: 'flex', gap: 0, borderBottom: `1px solid ${CC.cream}18` }}>
        {[
          { key: 'video', label: '影音', truku: 'patas hngak', active: true },
          { key: 'article', label: '文章', truku: 'patas kari', active: false },
        ].map((tab) => (
          <div key={tab.key} style={{
            flex: 1, padding: '12px 0', textAlign: 'center', position: 'relative', cursor: 'pointer',
          }}>
            <div style={{
              fontFamily: CF.display, fontSize: 16, fontWeight: 600,
              color: tab.active ? CC.gold : CC.fog, letterSpacing: '0.08em', marginBottom: 2,
            }}>{tab.label}</div>
            <div style={{
              fontFamily: CF.truku, fontStyle: 'italic', fontSize: 10,
              color: tab.active ? CC.cream : CC.fog, opacity: tab.active ? 0.7 : 0.5, letterSpacing: '0.15em',
            }}>{tab.truku}</div>
            {tab.active && (
              <div style={{
                position: 'absolute', bottom: -1, left: '20%', right: '20%', height: 2, background: CC.gold,
              }} />
            )}
          </div>
        ))}
      </div>

      {/* 分類 chips */}
      <div style={{ padding: '16px 20px 8px', display: 'flex', gap: 8, overflowX: 'auto' }}>
        {['全部', '口述歷史', '織布傳統', '祭儀', '部落音樂', '美食'].map((c, i) => (
          <div key={c} style={{
            padding: '8px 16px', borderRadius: 20,
            background: i === 0 ? CC.primary : 'transparent',
            color: i === 0 ? CC.creamLight : CC.cream,
            border: i === 0 ? 'none' : `1px solid ${CC.cream}30`,
            fontSize: 13, letterSpacing: '0.08em', whiteSpace: 'nowrap',
          }}>{c}</div>
        ))}
      </div>

      {/* 影片區段標頭 */}
      <div style={{ padding: '8px 20px 10px', display: 'flex', alignItems: 'baseline', justifyContent: 'space-between' }}>
        <div>
          <div style={{ fontFamily: CF.display, fontSize: 15, fontWeight: 600, color: CC.cream, letterSpacing: '0.06em' }}>
            最新影片
          </div>
          <div style={{ fontFamily: CF.truku, fontStyle: 'italic', fontSize: 10, color: CC.fog, letterSpacing: '0.15em', marginTop: 2 }}>
            patas hngak · 共 24 部
          </div>
        </div>
        <div style={{ fontSize: 11, color: CC.gold, letterSpacing: '0.1em' }}>查看全部 →</div>
      </div>

      {/* video grid */}
      <div style={{ padding: '0 20px 0', display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
        {[
          { title: '苧麻怎麼種', author: 'Yudaw', dur: '6:20', tag: '織布' },
          { title: '溪流命名史', author: 'Pisaw', dur: '8:14', tag: '地景' },
          { title: '小米播種祭', author: 'Sayun', dur: '15:02', tag: '祭儀' },
          { title: '老人家的歌', author: 'Bakan', dur: '4:36', tag: '音樂' },
        ].map((v, i) => (
          <div key={i} style={{
            background: CC.midnightSoft, borderRadius: 14, overflow: 'hidden',
            border: `1px solid ${CC.cream}10`,
          }}>
            <div style={{
              height: 100, position: 'relative',
              background: i % 2 === 0
                ? `linear-gradient(135deg, ${CC.primary}, ${CC.primaryDeep})`
                : `linear-gradient(135deg, ${CC.moss}, ${CC.mossDeep})`,
            }}>
              <div style={{ position: 'absolute', inset: 0, opacity: 0.3 }}>
                <window.TrukuWeaveBg color={CC.gold} bg="transparent" opacity={1} scale={0.5} />
              </div>
              <div style={{
                position: 'absolute', top: 8, left: 8,
                padding: '3px 8px', borderRadius: 4,
                background: 'rgba(0,0,0,0.5)', fontSize: 10, color: CC.gold,
                letterSpacing: '0.1em',
              }}>{v.tag}</div>
              <div style={{
                position: 'absolute', bottom: 8, right: 8,
                padding: '2px 6px', borderRadius: 3,
                background: 'rgba(0,0,0,0.7)', fontSize: 10, color: CC.creamLight,
                fontFamily: CF.mono,
              }}>{v.dur}</div>
              <div style={{ position: 'absolute', inset: 0, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                <div style={{
                  width: 36, height: 36, borderRadius: 18,
                  background: 'rgba(0,0,0,0.5)', display: 'flex', alignItems: 'center', justifyContent: 'center',
                  border: `1px solid ${CC.gold}80`,
                }}>
                  <window.PlayIcon size={12} color={CC.gold} />
                </div>
              </div>
            </div>
            <div style={{ padding: '10px 12px' }}>
              <div style={{ fontFamily: CF.display, fontSize: 14, fontWeight: 600, marginBottom: 3, letterSpacing: '0.04em' }}>
                {v.title}
              </div>
              <div style={{ fontSize: 11, color: CC.fog, letterSpacing: '0.05em' }}>
                @{v.author}
              </div>
            </div>
          </div>
        ))}
      </div>

      {/* 文章區段標頭 */}
      <div style={{ padding: '28px 20px 10px', display: 'flex', alignItems: 'baseline', justifyContent: 'space-between' }}>
        <div>
          <div style={{ fontFamily: CF.display, fontSize: 15, fontWeight: 600, color: CC.cream, letterSpacing: '0.06em' }}>
            族人寫的文章
          </div>
          <div style={{ fontFamily: CF.truku, fontStyle: 'italic', fontSize: 10, color: CC.fog, letterSpacing: '0.15em', marginTop: 2 }}>
            patas kari · 共 18 篇
          </div>
        </div>
        <div style={{ fontSize: 11, color: CC.gold, letterSpacing: '0.1em' }}>查看全部 →</div>
      </div>

      {/* 主打文章卡（大） */}
      <div style={{ padding: '0 20px 12px' }}>
        <div style={{
          background: CC.midnightSoft, borderRadius: 16, overflow: 'hidden',
          border: `1px solid ${CC.cream}10`,
        }}>
          <div style={{
            height: 120, position: 'relative',
            background: `linear-gradient(135deg, ${CC.primary}, ${CC.primaryDeep})`,
          }}>
            <div style={{ position: 'absolute', inset: 0, opacity: 0.25 }}>
              <window.TrukuWeaveBg color={CC.gold} bg="transparent" opacity={1} scale={0.7} />
            </div>
            <div style={{
              position: 'absolute', top: 12, left: 12,
              padding: '4px 10px', borderRadius: 4,
              background: CC.gold, fontSize: 10, color: CC.ink, fontWeight: 600,
              letterSpacing: '0.12em',
            }}>編輯精選</div>
            <div style={{
              position: 'absolute', bottom: 14, left: 16, right: 16,
              fontFamily: CF.display, fontSize: 19, fontWeight: 600,
              color: CC.creamLight, letterSpacing: '0.04em', lineHeight: 1.25,
            }}>
              苧麻記事——<br/>祖母教我織布的那年夏天
            </div>
          </div>
          <div style={{ padding: '14px 16px', display: 'flex', alignItems: 'center', gap: 10 }}>
            <div style={{
              width: 28, height: 28, borderRadius: 14,
              background: `linear-gradient(135deg, ${CC.moss}, ${CC.mossDeep})`,
              display: 'flex', alignItems: 'center', justifyContent: 'center',
              fontFamily: CF.display, fontSize: 12, color: CC.gold, fontWeight: 600,
            }}>S</div>
            <div style={{ flex: 1 }}>
              <div style={{ fontSize: 12, color: CC.cream, letterSpacing: '0.04em' }}>
                Sayun Lowking
              </div>
              <div style={{ fontSize: 10, color: CC.fog, letterSpacing: '0.05em', marginTop: 1 }}>
                8 分鐘 · 1.2k 閱讀 · 3 天前
              </div>
            </div>
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke={CC.fog} strokeWidth="1.8" strokeLinecap="round">
              <path d="M5 12h14M13 6l6 6-6 6"/>
            </svg>
          </div>
        </div>
      </div>

      {/* 文章列表 */}
      <div style={{ padding: '0 20px 0', display: 'flex', flexDirection: 'column', gap: 10 }}>
        {[
          { title: '走過立霧溪——一條河的族語名字', author: 'Pisaw', read: '5 分鐘', views: '486', cat: '地景' },
          { title: 'Gaya 不是規矩，是呼吸的方式', author: 'Yudaw', read: '12 分鐘', views: '892', cat: '文化' },
          { title: '阿公教我打獵那天說的話', author: 'Watan', read: '7 分鐘', views: '634', cat: '口述' },
        ].map((a, i) => (
          <div key={i} style={{
            display: 'flex', gap: 12, padding: '12px',
            background: CC.midnightSoft, borderRadius: 12,
            border: `1px solid ${CC.cream}10`,
          }}>
            <div style={{
              width: 64, height: 64, borderRadius: 8, flexShrink: 0,
              background: i % 2 === 0
                ? `linear-gradient(135deg, ${CC.moss}, ${CC.mossDeep})`
                : `linear-gradient(135deg, ${CC.primary}40, ${CC.ink})`,
              position: 'relative', overflow: 'hidden',
              display: 'flex', alignItems: 'center', justifyContent: 'center',
            }}>
              <div style={{ position: 'absolute', inset: 0, opacity: 0.4 }}>
                <window.TrukuWeaveBg color={CC.gold} bg="transparent" opacity={1} scale={0.4} />
              </div>
              <div style={{
                position: 'relative', fontFamily: CF.display, fontSize: 22,
                color: CC.gold, fontWeight: 600,
              }}>文</div>
            </div>
            <div style={{ flex: 1, display: 'flex', flexDirection: 'column', justifyContent: 'space-between', minWidth: 0 }}>
              <div>
                <div style={{
                  display: 'inline-block', padding: '2px 7px', borderRadius: 3,
                  background: `${CC.gold}20`, color: CC.gold, fontSize: 9,
                  letterSpacing: '0.12em', marginBottom: 4,
                }}>{a.cat}</div>
                <div style={{
                  fontFamily: CF.display, fontSize: 13, fontWeight: 600,
                  color: CC.cream, letterSpacing: '0.03em', lineHeight: 1.35,
                  overflow: 'hidden', textOverflow: 'ellipsis',
                  display: '-webkit-box', WebkitLineClamp: 2, WebkitBoxOrient: 'vertical',
                }}>{a.title}</div>
              </div>
              <div style={{ fontSize: 10, color: CC.fog, letterSpacing: '0.05em', marginTop: 4 }}>
                @{a.author} · {a.read} · {a.views} 閱讀
              </div>
            </div>
          </div>
        ))}
      </div>

      {/* 發布雙按鈕 */}
      <div style={{ padding: '20px', display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10 }}>
        <div style={{
          padding: '16px 14px', borderRadius: 14,
          background: `linear-gradient(135deg, ${CC.primary}, ${CC.primaryDeep})`,
          position: 'relative', overflow: 'hidden',
        }}>
          <div style={{ position: 'absolute', inset: 0, opacity: 0.18 }}>
            <window.TrukuWeaveBg color={CC.gold} bg="transparent" opacity={1} scale={0.4} />
          </div>
          <div style={{ position: 'relative' }}>
            <div style={{
              width: 36, height: 36, borderRadius: 18,
              background: CC.gold, display: 'flex', alignItems: 'center', justifyContent: 'center', marginBottom: 10,
            }}>
              <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke={CC.ink} strokeWidth="2" strokeLinecap="round">
                <rect x="3" y="6" width="13" height="12" rx="2"/>
                <path d="M16 10l5-3v10l-5-3z" fill={CC.ink}/>
              </svg>
            </div>
            <div style={{
              fontFamily: CF.display, fontSize: 15, fontWeight: 600,
              color: CC.creamLight, letterSpacing: '0.06em', marginBottom: 2,
            }}>發布影片</div>
            <div style={{
              fontFamily: CF.truku, fontStyle: 'italic', fontSize: 10,
              color: CC.gold, letterSpacing: '0.15em',
            }}>patas hngak</div>
          </div>
        </div>
        <div style={{
          padding: '16px 14px', borderRadius: 14,
          background: `linear-gradient(135deg, ${CC.moss}, ${CC.mossDeep})`,
          position: 'relative', overflow: 'hidden',
        }}>
          <div style={{ position: 'absolute', inset: 0, opacity: 0.18 }}>
            <window.TrukuWeaveBg color={CC.gold} bg="transparent" opacity={1} scale={0.4} />
          </div>
          <div style={{ position: 'relative' }}>
            <div style={{
              width: 36, height: 36, borderRadius: 18,
              background: CC.gold, display: 'flex', alignItems: 'center', justifyContent: 'center', marginBottom: 10,
            }}>
              <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke={CC.ink} strokeWidth="2" strokeLinecap="round">
                <path d="M5 4h11l3 3v13H5z"/>
                <path d="M9 11h6M9 14h6M9 17h4"/>
              </svg>
            </div>
            <div style={{
              fontFamily: CF.display, fontSize: 15, fontWeight: 600,
              color: CC.creamLight, letterSpacing: '0.06em', marginBottom: 2,
            }}>發布文章</div>
            <div style={{
              fontFamily: CF.truku, fontStyle: 'italic', fontSize: 10,
              color: CC.gold, letterSpacing: '0.15em',
            }}>patas kari</div>
          </div>
        </div>
      </div>

      <window.BottomTab active="culture" />
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// 互動專區（1對1 視訊配對）
// ─────────────────────────────────────────────────────────────
function CommunityScreen() {
  return (
    <div style={{ width: '100%', minHeight: '100%', background: CC.creamLight, fontFamily: CF.body, paddingBottom: 100 }}>
      <div style={{ padding: '60px 20px 16px' }}>
        <div style={{
          fontFamily: CF.truku, fontStyle: 'italic', fontSize: 12,
          color: CC.fog, letterSpacing: '0.25em', marginBottom: 4,
        }}>PGKALA · 互動</div>
        <div style={{
          fontFamily: CF.display, fontSize: 26, fontWeight: 600,
          color: CC.ink, letterSpacing: '0.04em',
        }}>面對面，學族語</div>
      </div>

      {/* 1對1 視訊大卡 */}
      <div style={{ padding: '0 20px 20px' }}>
        <div style={{
          background: CC.ink, color: CC.creamLight, borderRadius: 22,
          padding: '22px 20px 20px', position: 'relative', overflow: 'hidden',
        }}>
          <div style={{ position: 'absolute', inset: 0, opacity: 0.12 }}>
            <window.TrukuWeaveBg color={CC.gold} bg="transparent" opacity={1} scale={0.7} />
          </div>
          <div style={{ position: 'relative', zIndex: 1 }}>
            <div style={{
              fontFamily: CF.truku, fontStyle: 'italic', fontSize: 11,
              color: CC.gold, letterSpacing: '0.25em', marginBottom: 6,
            }}>1 ON 1 · KMSAPUH</div>
            <div style={{
              fontFamily: CF.display, fontSize: 20, fontWeight: 600,
              letterSpacing: '0.04em', marginBottom: 4, lineHeight: 1.3,
            }}>
              和耆老一對一<br/>用族語聊 10 分鐘
            </div>
            <div style={{ fontSize: 12, opacity: 0.7, letterSpacing: '0.05em', marginBottom: 16 }}>
              系統會幫你配對線上的 rudan
            </div>

            {/* 線上耆老頭像疊圖 */}
            <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 16 }}>
              <div style={{ display: 'flex' }}>
                {['B', 'Y', 'P', 'S'].map((c, i) => (
                  <div key={i} style={{
                    width: 32, height: 32, borderRadius: 16,
                    marginLeft: i === 0 ? 0 : -10,
                    background: i % 2 === 0 ? CC.primary : CC.moss,
                    border: `2px solid ${CC.ink}`,
                    display: 'flex', alignItems: 'center', justifyContent: 'center',
                    color: CC.gold, fontFamily: CF.display, fontWeight: 600, fontSize: 12,
                    zIndex: 4 - i,
                  }}>{c}</div>
                ))}
              </div>
              <div style={{ fontSize: 11, opacity: 0.85, letterSpacing: '0.05em' }}>
                <span style={{ color: '#5BC97D' }}>●</span> 4 位 rudan 在線
              </div>
            </div>

            <button style={{
              width: '100%',
              padding: '14px', borderRadius: 30, border: 'none',
              background: CC.gold, color: CC.ink,
              fontFamily: CF.display, fontSize: 15, fontWeight: 600, letterSpacing: '0.1em',
              display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8,
            }}>
              <svg width="16" height="16" viewBox="0 0 24 24" fill={CC.ink}>
                <path d="M15 5l5-2v18l-5-2H4V5h11z"/>
              </svg>
              開始配對
            </button>
          </div>
        </div>
      </div>

      {/* 主題選擇 */}
      <div style={{ padding: '0 20px 14px' }}>
        <div style={{
          fontFamily: CF.display, fontSize: 14, fontWeight: 600, color: CC.ink,
          letterSpacing: '0.06em', marginBottom: 10,
        }}>想聊什麼主題？</div>
        <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8 }}>
          {[
            { zh: '日常問候', truku: 'mhuway', active: true },
            { zh: '家人稱謂', truku: 'qbsuran' },
            { zh: '部落故事', truku: 'kari rudan' },
            { zh: '織布技藝', truku: 'tminun' },
            { zh: '山林知識', truku: 'dgiyaq' },
          ].map((t, i) => (
            <div key={i} style={{
              padding: '8px 14px', borderRadius: 20,
              background: t.active ? CC.primary : 'transparent',
              color: t.active ? CC.creamLight : CC.inkSoft,
              border: t.active ? 'none' : `1px solid ${CC.creamDeep}`,
              fontSize: 12, letterSpacing: '0.06em',
              display: 'flex', alignItems: 'center', gap: 6,
            }}>
              <span>{t.zh}</span>
              <span style={{
                fontFamily: CF.truku, fontStyle: 'italic', fontSize: 10,
                opacity: 0.7,
              }}>· {t.truku}</span>
            </div>
          ))}
        </div>
      </div>

      {/* 推薦耆老 */}
      <div style={{ padding: '6px 20px 0' }}>
        <div style={{
          display: 'flex', alignItems: 'baseline', justifyContent: 'space-between', marginBottom: 12,
        }}>
          <div style={{
            fontFamily: CF.display, fontSize: 14, fontWeight: 600, color: CC.ink, letterSpacing: '0.06em',
          }}>線上 rudan</div>
          <div style={{ fontSize: 11, color: CC.primary, letterSpacing: '0.1em' }}>查看全部 →</div>
        </div>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
          {[
            { name: 'Bakan rudan', tribe: '銅門部落', age: 78, online: true, calls: 124, themes: ['日常問候', '部落故事'] },
            { name: 'Yudaw baki', tribe: '秀林部落', age: 82, online: true, calls: 89, themes: ['山林知識'] },
            { name: 'Iwan yaki', tribe: '富世部落', age: 71, online: false, calls: 56, themes: ['織布技藝'] },
          ].map((r, i) => (
            <div key={i} style={{
              background: CC.cream, borderRadius: 14, padding: '12px 14px',
              border: `1px solid ${CC.creamDeep}`,
              display: 'flex', alignItems: 'center', gap: 12,
            }}>
              <div style={{ position: 'relative', flexShrink: 0 }}>
                <div style={{
                  width: 48, height: 48, borderRadius: 24,
                  background: i % 2 === 0 ? CC.primary : CC.moss,
                  display: 'flex', alignItems: 'center', justifyContent: 'center',
                  color: CC.gold, fontFamily: CF.display, fontWeight: 600, fontSize: 16,
                  border: `1.5px solid ${CC.gold}`,
                }}>{r.name[0]}</div>
                <div style={{
                  position: 'absolute', bottom: 0, right: 0,
                  width: 12, height: 12, borderRadius: 6,
                  background: r.online ? '#5BC97D' : CC.fog,
                  border: `2px solid ${CC.cream}`,
                }} />
              </div>
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{
                  fontFamily: CF.display, fontSize: 14, fontWeight: 600,
                  color: CC.ink, letterSpacing: '0.04em',
                }}>{r.name}</div>
                <div style={{ fontSize: 11, color: CC.fog, letterSpacing: '0.05em', marginTop: 1 }}>
                  {r.tribe} · {r.age} 歲 · 已通話 {r.calls} 次
                </div>
                <div style={{ display: 'flex', gap: 4, marginTop: 5 }}>
                  {r.themes.map(t => (
                    <span key={t} style={{
                      padding: '2px 7px', borderRadius: 3,
                      background: CC.primary + '15', color: CC.primary,
                      fontSize: 10, letterSpacing: '0.05em',
                    }}>{t}</span>
                  ))}
                </div>
              </div>
              <button style={{
                padding: '8px 12px', borderRadius: 18, border: 'none',
                background: r.online ? CC.primary : 'transparent',
                color: r.online ? CC.creamLight : CC.fog,
                fontSize: 11, letterSpacing: '0.08em',
                border: r.online ? 'none' : `1px solid ${CC.creamDeep}`,
                display: 'flex', alignItems: 'center', gap: 4,
              }}>
                {r.online ? (
                  <>
                    <svg width="11" height="11" viewBox="0 0 24 24" fill={CC.creamLight}>
                      <path d="M15 5l5-2v18l-5-2H4V5h11z"/>
                    </svg>
                    通話
                  </>
                ) : '預約'}
              </button>
            </div>
          ))}
        </div>
      </div>

      {/* 通話歷史 */}
      <div style={{ padding: '24px 20px 0' }}>
        <div style={{
          fontFamily: CF.display, fontSize: 14, fontWeight: 600, color: CC.ink,
          letterSpacing: '0.06em', marginBottom: 10,
        }}>最近通話</div>
        <div style={{
          background: CC.cream, borderRadius: 14, padding: '12px 14px',
          border: `1px solid ${CC.creamDeep}`,
          display: 'flex', alignItems: 'center', gap: 12,
        }}>
          <div style={{
            width: 38, height: 38, borderRadius: 19,
            background: CC.moss,
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            color: CC.gold, fontFamily: CF.display, fontWeight: 600, fontSize: 13,
          }}>P</div>
          <div style={{ flex: 1 }}>
            <div style={{ fontFamily: CF.display, fontSize: 13, fontWeight: 600, color: CC.ink }}>
              Pisaw baki
            </div>
            <div style={{ fontSize: 11, color: CC.fog, letterSpacing: '0.05em' }}>
              昨天 · 12 分 28 秒 · 學了 8 個新詞
            </div>
          </div>
          <div style={{ fontSize: 11, color: CC.primary, letterSpacing: '0.1em' }}>再聊 →</div>
        </div>
      </div>

      <window.BottomTab active="comm" />
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// 視訊配對等候畫面
// ─────────────────────────────────────────────────────────────
function VideoWaitingScreen() {
  return (
    <div style={{
      width: '100%', minHeight: '100%', background: CC.ink, fontFamily: CF.body,
      color: CC.creamLight, position: 'relative', overflow: 'hidden',
      display: 'flex', flexDirection: 'column',
    }}>
      {/* 背景織紋 */}
      <div style={{ position: 'absolute', inset: 0, opacity: 0.08 }}>
        <window.TrukuWeaveBg color={CC.gold} bg="transparent" opacity={1} scale={1.2} />
      </div>
      <div style={{
        position: 'absolute', inset: 0,
        background: `radial-gradient(ellipse at 50% 40%, ${CC.primary}30 0%, transparent 70%)`,
      }} />

      {/* 頂部 */}
      <div style={{
        position: 'relative', padding: '60px 20px 0',
        display: 'flex', alignItems: 'center', justifyContent: 'space-between',
      }}>
        <button style={{
          width: 36, height: 36, borderRadius: 18, border: 'none',
          background: 'rgba(255,255,255,0.1)', color: CC.creamLight,
          display: 'flex', alignItems: 'center', justifyContent: 'center',
        }}>
          <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke={CC.creamLight} strokeWidth="2" strokeLinecap="round">
            <path d="M18 6L6 18M6 6l12 12"/>
          </svg>
        </button>
        <div style={{ textAlign: 'center' }}>
          <div style={{
            fontFamily: CF.truku, fontStyle: 'italic', fontSize: 10,
            color: CC.gold, letterSpacing: '0.25em',
          }}>SMTRUNG · 配對中</div>
        </div>
        <div style={{ width: 36 }} />
      </div>

      {/* 中央：脈動圓圈 + 頭像 */}
      <div style={{
        flex: 1, position: 'relative', display: 'flex', flexDirection: 'column',
        alignItems: 'center', justifyContent: 'center', gap: 32, padding: '0 20px',
      }}>
        <div style={{ position: 'relative', width: 220, height: 220 }}>
          {/* 脈動圈 */}
          {[1, 2, 3].map(i => (
            <div key={i} style={{
              position: 'absolute', inset: 0, borderRadius: '50%',
              border: `1px solid ${CC.gold}`,
              opacity: 0.5 - i * 0.12,
              transform: `scale(${1 + i * 0.18})`,
            }} />
          ))}
          {/* 中央菱形 */}
          <div style={{
            position: 'absolute', inset: 0, display: 'flex',
            alignItems: 'center', justifyContent: 'center',
          }}>
            <div style={{
              width: 140, height: 140, borderRadius: 70,
              background: `radial-gradient(circle, ${CC.primary}, ${CC.primaryDeep})`,
              display: 'flex', alignItems: 'center', justifyContent: 'center',
              border: `2px solid ${CC.gold}`,
              boxShadow: `0 0 60px ${CC.primary}60`,
            }}>
              <window.TrukuDiamond size={70} color={CC.gold} stroke={1.5} />
            </div>
          </div>
        </div>

        <div style={{ textAlign: 'center' }}>
          <div style={{
            fontFamily: CF.display, fontSize: 24, fontWeight: 600,
            letterSpacing: '0.08em',
          }}>正在尋找</div>
        </div>
      </div>

      {/* 取消按鈕 */}
      <div style={{ position: 'relative', padding: '0 20px 50px', display: 'flex', justifyContent: 'center' }}>
        <button style={{
          padding: '14px 36px', borderRadius: 30, border: `1px solid ${CC.creamLight}40`,
          background: 'transparent', color: CC.creamLight,
          fontFamily: CF.display, fontSize: 14, letterSpacing: '0.1em',
        }}>取消配對</button>
      </div>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// 視訊通話中畫面
// ─────────────────────────────────────────────────────────────
function VideoCallScreen() {
  return (
    <div style={{
      width: '100%', minHeight: '100%', background: CC.ink, fontFamily: CF.body,
      color: CC.creamLight, position: 'relative', overflow: 'hidden',
    }}>
      {/* 對方視訊（全螢幕） */}
      <div style={{
        position: 'absolute', inset: 0,
        background: `linear-gradient(160deg, ${CC.mossDeep} 0%, ${CC.ink} 60%, ${CC.primaryDeep} 100%)`,
      }}>
        <div style={{ position: 'absolute', inset: 0, opacity: 0.1 }}>
          <window.TrukuWeaveBg color={CC.gold} bg="transparent" opacity={1} scale={1} />
        </div>
        {/* 模擬人像剪影 */}
        <div style={{
          position: 'absolute', left: '50%', top: '42%',
          transform: 'translate(-50%, -50%)',
          width: 180, height: 180, borderRadius: 90,
          background: `radial-gradient(circle at 50% 35%, ${CC.primaryLight}80, ${CC.primaryDeep})`,
          display: 'flex', alignItems: 'center', justifyContent: 'center',
          fontFamily: CF.display, fontSize: 56, color: CC.gold, fontWeight: 600,
          border: `2px solid ${CC.gold}40`,
        }}>B</div>
      </div>

      {/* 頂部：對方資訊 + 計時 */}
      <div style={{
        position: 'relative', padding: '60px 20px 0',
        display: 'flex', alignItems: 'flex-start', justifyContent: 'space-between',
      }}>
        <div style={{
          background: 'rgba(28,15,13,0.6)', backdropFilter: 'blur(10px)',
          padding: '8px 14px', borderRadius: 22,
          display: 'flex', alignItems: 'center', gap: 8,
        }}>
          <div style={{
            width: 8, height: 8, borderRadius: 4, background: '#FF4444',
          }} />
          <div style={{ fontFamily: CF.mono, fontSize: 13, letterSpacing: '0.1em' }}>
            03:42
          </div>
          <div style={{ width: 1, height: 12, background: CC.creamLight + '40' }} />
          <div style={{ fontSize: 11, opacity: 0.85 }}>剩 6 分</div>
        </div>
        <button style={{
          width: 40, height: 40, borderRadius: 20, border: 'none',
          background: 'rgba(28,15,13,0.6)', backdropFilter: 'blur(10px)',
          color: CC.creamLight,
          display: 'flex', alignItems: 'center', justifyContent: 'center',
        }}>
          <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke={CC.creamLight} strokeWidth="2">
            <circle cx="12" cy="6" r="1.5" fill={CC.creamLight}/>
            <circle cx="12" cy="12" r="1.5" fill={CC.creamLight}/>
            <circle cx="12" cy="18" r="1.5" fill={CC.creamLight}/>
          </svg>
        </button>
      </div>

      {/* 對方姓名 */}
      <div style={{
        position: 'absolute', top: '62%', left: 0, right: 0,
        textAlign: 'center', zIndex: 2,
      }}>
        <div style={{
          fontFamily: CF.display, fontSize: 24, fontWeight: 600,
          letterSpacing: '0.05em', marginBottom: 4,
          textShadow: '0 2px 12px rgba(0,0,0,0.5)',
        }}>Bakan rudan</div>
        <div style={{
          fontSize: 12, opacity: 0.85, letterSpacing: '0.1em',
          textShadow: '0 1px 8px rgba(0,0,0,0.5)',
        }}>銅門部落 · 78 歲</div>
      </div>

      {/* 自己的小視窗 */}
      <div style={{
        position: 'absolute', top: 110, right: 16,
        width: 100, height: 140, borderRadius: 14, overflow: 'hidden',
        background: `linear-gradient(160deg, ${CC.moss}, ${CC.mossDeep})`,
        border: `1.5px solid ${CC.gold}80`,
        boxShadow: '0 6px 20px rgba(0,0,0,0.4)',
        display: 'flex', alignItems: 'center', justifyContent: 'center',
      }}>
        <div style={{
          width: 44, height: 44, borderRadius: 22,
          background: CC.primary,
          display: 'flex', alignItems: 'center', justifyContent: 'center',
          fontFamily: CF.display, fontSize: 18, color: CC.gold, fontWeight: 600,
          border: `1.5px solid ${CC.gold}`,
        }}>S</div>
        <div style={{
          position: 'absolute', bottom: 6, left: 6,
          fontSize: 10, color: CC.creamLight, letterSpacing: '0.05em',
          textShadow: '0 1px 2px rgba(0,0,0,0.6)',
        }}>你</div>
      </div>

      {/* 主題提示 chip */}
      <div style={{
        position: 'absolute', left: 16, bottom: 150,
        padding: '6px 12px', borderRadius: 14,
        background: 'rgba(201,169,97,0.15)', border: `1px solid ${CC.gold}50`,
        fontSize: 11, color: CC.gold, letterSpacing: '0.08em',
        display: 'flex', alignItems: 'center', gap: 6,
      }}>
        <span style={{ fontFamily: CF.truku, fontStyle: 'italic' }}>kari</span>
        主題：日常問候
      </div>

      {/* 底部控制列 */}
      <div style={{
        position: 'absolute', bottom: 0, left: 0, right: 0,
        padding: '16px 20px 40px',
        background: 'linear-gradient(to top, rgba(28,15,13,0.95), transparent)',
        display: 'flex', alignItems: 'center', justifyContent: 'space-around', gap: 12,
      }}>
        {[
          { icon: 'mic', label: '靜音' },
          { icon: 'cam', label: '鏡頭' },
          { icon: 'note', label: '筆記' },
          { icon: 'end', label: '結束', danger: true },
        ].map(c => (
          <div key={c.icon} style={{
            display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 6,
          }}>
            <div style={{
              width: c.danger ? 60 : 52, height: c.danger ? 60 : 52,
              borderRadius: c.danger ? 30 : 26,
              background: c.danger ? '#D8392C' : 'rgba(255,255,255,0.12)',
              backdropFilter: 'blur(10px)',
              border: c.danger ? 'none' : `1px solid ${CC.creamLight}20`,
              display: 'flex', alignItems: 'center', justifyContent: 'center',
            }}>
              {c.icon === 'mic' && (
                <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke={CC.creamLight} strokeWidth="2" strokeLinecap="round">
                  <rect x="9" y="3" width="6" height="12" rx="3" fill={CC.creamLight}/>
                  <path d="M5 11a7 7 0 0014 0M12 18v3"/>
                </svg>
              )}
              {c.icon === 'cam' && (
                <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke={CC.creamLight} strokeWidth="2">
                  <rect x="3" y="6" width="13" height="12" rx="2"/>
                  <path d="M16 10l5-3v10l-5-3z" fill={CC.creamLight}/>
                </svg>
              )}
              {c.icon === 'note' && (
                <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke={CC.creamLight} strokeWidth="2" strokeLinecap="round">
                  <path d="M5 4h11l3 3v13H5z"/>
                  <path d="M9 11h6M9 15h4"/>
                </svg>
              )}
              {c.icon === 'end' && (
                <svg width="26" height="26" viewBox="0 0 24 24" fill={CC.creamLight} transform="rotate(135)">
                  <path d="M22 16.92v3a2 2 0 01-2.18 2 19.79 19.79 0 01-8.63-3.07 19.5 19.5 0 01-6-6 19.79 19.79 0 01-3.07-8.67A2 2 0 014.11 2h3a2 2 0 012 1.72c.13.96.37 1.91.71 2.81a2 2 0 01-.45 2.11L8.09 9.91a16 16 0 006 6l1.27-1.27a2 2 0 012.11-.45c.9.34 1.85.58 2.81.71A2 2 0 0122 16.92z"/>
                </svg>
              )}
            </div>
            <div style={{ fontSize: 10, opacity: 0.85, letterSpacing: '0.08em' }}>
              {c.label}
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// 部落地圖
// ─────────────────────────────────────────────────────────────
function MapScreen() {
  const pins = [
    { x: '38%', y: '32%', name: 'Skadang', zh: '大同部落', big: true },
    { x: '58%', y: '45%', name: 'Tpuqu', zh: '砂卡礑', big: false },
    { x: '28%', y: '58%', name: 'Bsuring', zh: '布洛灣', big: false },
    { x: '68%', y: '70%', name: 'Tkijig', zh: '崇德', big: false },
    { x: '46%', y: '78%', name: 'Bsngun', zh: '秀林', big: false },
  ];

  return (
    <div style={{ width: '100%', minHeight: '100%', background: CC.midnight, fontFamily: CF.body, position: 'relative', paddingBottom: 100 }}>
      {/* 地圖背景 */}
      <div style={{
        position: 'absolute', inset: 0, height: '100%',
        background: `radial-gradient(ellipse at 40% 40%, ${CC.mossDeep} 0%, ${CC.midnight} 70%)`,
      }}>
        {/* 等高線山形 */}
        <svg width="100%" height="100%" viewBox="0 0 402 874" preserveAspectRatio="xMidYMid slice" style={{ position: 'absolute', inset: 0 }}>
          {[0.15, 0.25, 0.35, 0.45, 0.55].map((s, i) => (
            <path key={i}
              d={`M${-50 + i*20} ${300 + i*40} Q${100 + i*30} ${200 + i*20} ${200} ${280 + i*30} T${450 - i*20} ${340 + i*40}`}
              fill="none" stroke={CC.gold} strokeWidth="0.6" opacity={0.25 - i * 0.04}/>
          ))}
          {/* 河流 */}
          <path d="M-20 600 Q120 580 200 620 T420 600" fill="none" stroke={CC.gold} strokeWidth="1.2" opacity="0.35" />
          <path d="M-20 600 Q120 580 200 620 T420 600" fill="none" stroke={CC.gold} strokeWidth="3" opacity="0.1" />
        </svg>
        {/* 織紋疊層 */}
        <div style={{ position: 'absolute', inset: 0, opacity: 0.06 }}>
          <window.TrukuWeaveBg color={CC.gold} bg="transparent" opacity={1} scale={1.4} />
        </div>
      </div>

      {/* 頂部資訊 */}
      <div style={{ position: 'relative', padding: '60px 20px 0', color: CC.creamLight, zIndex: 2 }}>
        <div style={{
          fontFamily: CF.truku, fontStyle: 'italic', fontSize: 12,
          color: CC.gold, letterSpacing: '0.25em', marginBottom: 4,
        }}>ALANG · 部落地圖</div>
        <div style={{
          fontFamily: CF.display, fontSize: 24, fontWeight: 600,
          letterSpacing: '0.04em', marginBottom: 6,
        }}>太魯閣族祖居地</div>
        <div style={{ fontSize: 12, opacity: 0.7, letterSpacing: '0.05em' }}>
          點選部落 · 聽地名故事 · 學族語
        </div>
      </div>

      {/* pins */}
      <div style={{ position: 'absolute', inset: 0 }}>
        {pins.map(p => (
          <div key={p.name} style={{
            position: 'absolute', left: p.x, top: p.y,
            transform: 'translate(-50%, -50%)',
            display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 4,
            zIndex: p.big ? 3 : 2,
          }}>
            <div style={{ position: 'relative' }}>
              {p.big && (
                <div style={{
                  position: 'absolute', inset: -8, borderRadius: '50%',
                  background: CC.gold, opacity: 0.2,
                  animation: 'pulse 2s ease-in-out infinite',
                }} />
              )}
              <window.TrukuDiamond size={p.big ? 22 : 14} color={CC.gold} filled stroke={1.2} />
            </div>
            <div style={{
              padding: '3px 8px', borderRadius: 4,
              background: 'rgba(28, 15, 13, 0.85)',
              fontFamily: CF.truku, fontStyle: 'italic', fontSize: p.big ? 12 : 10,
              color: CC.gold, letterSpacing: '0.1em',
              border: `0.5px solid ${CC.gold}50`,
              whiteSpace: 'nowrap',
            }}>{p.name}</div>
            {p.big && (
              <div style={{ fontSize: 10, color: CC.creamLight, opacity: 0.7, letterSpacing: '0.1em' }}>
                {p.zh}
              </div>
            )}
          </div>
        ))}
      </div>

      {/* 底部資訊卡（被選中的部落） */}
      <div style={{
        position: 'absolute', left: 16, right: 16, bottom: 100,
        background: CC.creamLight, borderRadius: 18, padding: '16px 18px',
        boxShadow: '0 12px 36px rgba(0,0,0,0.4)',
        zIndex: 5,
      }}>
        <div style={{ display: 'flex', alignItems: 'flex-start', gap: 12, marginBottom: 10 }}>
          <div style={{
            width: 42, height: 42, flexShrink: 0,
            display: 'flex', alignItems: 'center', justifyContent: 'center',
          }}>
            <window.TrukuDiamond size={42} color={CC.primary} filled stroke={1.5} />
          </div>
          <div style={{ flex: 1 }}>
            <div style={{
              fontFamily: CF.truku, fontStyle: 'italic', fontSize: 12,
              color: CC.primary, letterSpacing: '0.15em',
            }}>SKADANG</div>
            <div style={{
              fontFamily: CF.display, fontSize: 18, fontWeight: 600, color: CC.ink,
              letterSpacing: '0.04em',
            }}>大同部落</div>
          </div>
          <button style={{
            padding: '6px 12px', borderRadius: 18, border: 'none',
            background: CC.primary, color: CC.creamLight,
            fontSize: 11, letterSpacing: '0.1em', display: 'flex', alignItems: 'center', gap: 4,
          }}>
            <window.SpeakerIcon size={12} color={CC.creamLight} />
            發音
          </button>
        </div>
        <div style={{ fontSize: 12, color: CC.inkSoft, lineHeight: 1.5, letterSpacing: '0.03em' }}>
          位於海拔 1,128 公尺。族語意為「楓葉樹之地」，每年秋季有楓紅祭典。
        </div>
        <div style={{ marginTop: 10, display: 'flex', gap: 6 }}>
          {['口述故事', '族語名', '老照片'].map(t => (
            <div key={t} style={{
              padding: '4px 10px', borderRadius: 4,
              background: CC.cream, fontSize: 10,
              color: CC.primary, letterSpacing: '0.08em',
            }}>{t}</div>
          ))}
        </div>
      </div>

      <window.BottomTab active="map" />
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// 廣場 - 文章 / 活動發布
// ─────────────────────────────────────────────────────────────
function PlazaScreen() {
  return (
    <div style={{ width: '100%', minHeight: '100%', background: CC.creamLight, fontFamily: CF.body, paddingBottom: 100 }}>
      <div style={{ padding: '60px 20px 16px', display: 'flex', alignItems: 'flex-end', justifyContent: 'space-between' }}>
        <div>
          <div style={{
            fontFamily: CF.truku, fontStyle: 'italic', fontSize: 12,
            color: CC.fog, letterSpacing: '0.25em', marginBottom: 4,
          }}>ALANG · 廣場</div>
          <div style={{
            fontFamily: CF.display, fontSize: 26, fontWeight: 600,
            color: CC.ink, letterSpacing: '0.04em',
          }}>族人在這裡</div>
        </div>
        <button style={{
          padding: '10px 16px', borderRadius: 22, border: 'none',
          background: CC.primary, color: CC.creamLight,
          fontFamily: CF.display, fontSize: 13, fontWeight: 600, letterSpacing: '0.08em',
          display: 'flex', alignItems: 'center', gap: 6,
        }}>
          <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke={CC.creamLight} strokeWidth="2.5" strokeLinecap="round">
            <path d="M12 4v16M4 12h16"/>
          </svg>
          發布
        </button>
      </div>

      {/* 分頁 */}
      <div style={{ padding: '0 20px', display: 'flex', gap: 24, borderBottom: `1px solid ${CC.creamDeep}` }}>
        {[['動態', true], ['活動', false]].map(([t, active]) => (
          <div key={t} style={{
            padding: '10px 0', position: 'relative',
            fontFamily: CF.display, fontSize: 14, fontWeight: active ? 600 : 400,
            color: active ? CC.primary : CC.fog, letterSpacing: '0.1em',
          }}>{t}{active && (
            <div style={{ position: 'absolute', bottom: -1, left: 0, right: 0, height: 2, background: CC.primary }} />
          )}</div>
        ))}
      </div>

      {/* 即將開始活動 */}
      <div style={{ padding: '16px 20px 8px' }}>
        <div style={{
          fontFamily: CF.truku, fontStyle: 'italic', fontSize: 10,
          color: CC.fog, letterSpacing: '0.2em', marginBottom: 8,
        }}>SMRATUC · 近期活動</div>
        <div style={{ display: 'flex', gap: 10, overflowX: 'auto', paddingBottom: 4 }}>
          {[
            { m: 'JUN', d: '15', title: '青年族語營', loc: '秀林部落', n: 23, color: CC.primary },
            { m: 'JUN', d: '22', title: '苧麻採集走讀', loc: '銅門部落', n: 12, color: CC.moss },
            { m: 'JUL', d: '03', title: '部落歌謠之夜', loc: '富世社區', n: 41, color: CC.primary },
          ].map((e, i) => (
            <div key={i} style={{
              minWidth: 200, background: CC.ink, color: CC.creamLight, borderRadius: 14,
              padding: '14px', position: 'relative', overflow: 'hidden',
            }}>
              <div style={{ position: 'absolute', right: -16, top: -16, opacity: 0.13 }}>
                <window.TrukuDiamond size={80} color={CC.gold} stroke={1.2} />
              </div>
              <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 10, position: 'relative' }}>
                <div style={{
                  width: 44, height: 44, borderRadius: 8, background: e.color,
                  display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center',
                }}>
                  <div style={{ fontSize: 8, color: CC.gold, letterSpacing: '0.15em' }}>{e.m}</div>
                  <div style={{ fontFamily: CF.display, fontSize: 18, fontWeight: 700, color: CC.creamLight, lineHeight: 1 }}>{e.d}</div>
                </div>
                <div style={{ flex: 1 }}>
                  <div style={{ fontFamily: CF.display, fontSize: 14, fontWeight: 600, letterSpacing: '0.04em' }}>{e.title}</div>
                  <div style={{ fontSize: 10, opacity: 0.65, letterSpacing: '0.05em', marginTop: 2 }}>{e.loc}</div>
                </div>
              </div>
              <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', position: 'relative' }}>
                <div style={{ fontSize: 10, color: CC.gold, letterSpacing: '0.1em' }}>● {e.n} 人報名</div>
                <button style={{
                  padding: '5px 12px', borderRadius: 14, border: `1px solid ${CC.gold}80`,
                  background: 'transparent', color: CC.gold,
                  fontSize: 11, letterSpacing: '0.1em',
                }}>我要參加</button>
              </div>
            </div>
          ))}
        </div>
      </div>

      {/* 貼文列表 */}
      <div style={{ padding: '20px 20px 0' }}>
        <div style={{
          fontFamily: CF.truku, fontStyle: 'italic', fontSize: 10,
          color: CC.fog, letterSpacing: '0.2em', marginBottom: 10,
        }}>PATAS · 族人發文</div>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
          {[
            { name: 'Sayun', sub: '銅門部落 · 3 小時前', text: '今天跟 yaki 學了「mhuway」這個詞，原來是「謝謝」也是「祝福」的意思 ✦', tag: 'Mhuway', likes: 24, comments: 6 },
            { name: 'Pisaw', sub: '太管處青年志工 · 昨天', text: '誰知道立霧溪的族語怎麼念？我聽過長輩說 Yayung Bsngun 但不確定拼法...', tag: '求救', likes: 8, comments: 12 },
            { name: 'Bakan', sub: '秀林部落 · 2 天前', text: '上週末跟著耆老去採苧麻，第一次看到整片山坡的青色，真的很美。', tag: '走讀', likes: 56, comments: 9 },
          ].map((p, i) => (
            <div key={i} style={{
              background: CC.cream, borderRadius: 16, padding: '14px 16px',
              border: `1px solid ${CC.creamDeep}`,
            }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 10 }}>
                <div style={{
                  width: 38, height: 38, borderRadius: 19,
                  background: i % 2 === 0 ? CC.primary : CC.moss,
                  display: 'flex', alignItems: 'center', justifyContent: 'center',
                  color: CC.gold, fontFamily: CF.display, fontWeight: 600, fontSize: 14,
                  border: `1.5px solid ${CC.gold}`,
                }}>{p.name[0]}</div>
                <div style={{ flex: 1 }}>
                  <div style={{ fontFamily: CF.display, fontSize: 14, fontWeight: 600, color: CC.ink, letterSpacing: '0.04em' }}>{p.name}</div>
                  <div style={{ fontSize: 11, color: CC.fog, letterSpacing: '0.05em' }}>{p.sub}</div>
                </div>
                <div style={{
                  padding: '3px 10px', borderRadius: 12,
                  background: CC.primary + '15', color: CC.primary,
                  fontFamily: CF.truku, fontStyle: 'italic', fontSize: 11, letterSpacing: '0.1em',
                }}>#{p.tag}</div>
              </div>
              <div style={{ fontSize: 14, color: CC.inkSoft, lineHeight: 1.55, marginBottom: 10, letterSpacing: '0.03em' }}>{p.text}</div>
              <div style={{ display: 'flex', gap: 18, fontSize: 12, color: CC.fog }}>
                <span>♡ {p.likes}</span>
                <span>💬 {p.comments}</span>
              </div>
            </div>
          ))}
        </div>
      </div>

      <window.BottomTab active="plaza" />
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// 發布頁面（動態 / 活動）
// ─────────────────────────────────────────────────────────────
function ComposeScreen() {
  return (
    <div style={{ width: '100%', minHeight: '100%', background: CC.creamLight, fontFamily: CF.body, paddingBottom: 100 }}>
      {/* 頂部 nav */}
      <div style={{
        position: 'sticky', top: 0, zIndex: 10,
        background: CC.creamLight, borderBottom: `1px solid ${CC.creamDeep}`,
        padding: '54px 16px 12px',
        display: 'flex', alignItems: 'center', justifyContent: 'space-between',
      }}>
        <button style={{
          padding: '6px 4px', border: 'none', background: 'transparent',
          color: CC.inkSoft, fontSize: 14, letterSpacing: '0.05em',
        }}>取消</button>
        <div style={{
          fontFamily: CF.display, fontSize: 15, fontWeight: 600,
          color: CC.ink, letterSpacing: '0.08em',
        }}>新發布</div>
        <button style={{
          padding: '6px 16px', borderRadius: 16, border: 'none',
          background: CC.primary, color: CC.creamLight,
          fontFamily: CF.display, fontSize: 13, fontWeight: 600, letterSpacing: '0.08em',
        }}>發布</button>
      </div>

      {/* 類型切換（segment） */}
      <div style={{ padding: '18px 20px 0' }}>
        <div style={{
          display: 'flex', background: CC.cream, borderRadius: 12,
          padding: 4, border: `1px solid ${CC.creamDeep}`,
        }}>
          {[
            { key: 'post', label: '動態', truku: 'patas', active: true, icon: 'pen' },
            { key: 'event', label: '活動', truku: 'smratuc', active: false, icon: 'cal' },
          ].map(t => (
            <div key={t.key} style={{
              flex: 1, padding: '10px 12px', borderRadius: 9,
              background: t.active ? CC.creamLight : 'transparent',
              boxShadow: t.active ? '0 1px 3px rgba(0,0,0,0.08)' : 'none',
              display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 6,
            }}>
              {t.icon === 'pen' && (
                <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke={t.active ? CC.primary : CC.fog} strokeWidth="2" strokeLinecap="round">
                  <path d="M14 4l6 6L8 22H2v-6L14 4z"/>
                </svg>
              )}
              {t.icon === 'cal' && (
                <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke={t.active ? CC.primary : CC.fog} strokeWidth="2" strokeLinecap="round">
                  <rect x="3" y="5" width="18" height="16" rx="2"/>
                  <path d="M3 10h18M8 3v4M16 3v4"/>
                </svg>
              )}
              <span style={{
                fontFamily: CF.display, fontSize: 13, fontWeight: 600,
                color: t.active ? CC.primary : CC.fog, letterSpacing: '0.08em',
              }}>{t.label}</span>
              <span style={{
                fontFamily: CF.truku, fontStyle: 'italic', fontSize: 10,
                color: t.active ? CC.gold : CC.fog, opacity: 0.8, letterSpacing: '0.1em',
              }}>{t.truku}</span>
            </div>
          ))}
        </div>
      </div>

      {/* 作者資訊 */}
      <div style={{ padding: '16px 20px 0', display: 'flex', alignItems: 'center', gap: 12 }}>
        <div style={{
          width: 40, height: 40, borderRadius: 20,
          background: CC.primary,
          display: 'flex', alignItems: 'center', justifyContent: 'center',
          color: CC.gold, fontFamily: CF.display, fontWeight: 600, fontSize: 16,
          border: `1.5px solid ${CC.gold}`,
        }}>S</div>
        <div style={{ flex: 1 }}>
          <div style={{ fontFamily: CF.display, fontSize: 14, fontWeight: 600, color: CC.ink, letterSpacing: '0.04em' }}>
            Sayun Lowking
          </div>
          <div style={{
            display: 'flex', alignItems: 'center', gap: 4, marginTop: 2,
            fontSize: 11, color: CC.fog, letterSpacing: '0.05em',
          }}>
            <svg width="11" height="11" viewBox="0 0 24 24" fill="none" stroke={CC.fog} strokeWidth="2">
              <circle cx="12" cy="12" r="9"/>
              <path d="M3 12h18M12 3a14 14 0 010 18M12 3a14 14 0 000 18"/>
            </svg>
            公開 · 所有族人都看得到
          </div>
        </div>
      </div>

      {/* 文字輸入區 */}
      <div style={{ padding: '14px 20px 0' }}>
        <div style={{
          minHeight: 140, padding: '14px 16px',
          background: CC.cream, borderRadius: 14,
          border: `1px solid ${CC.creamDeep}`,
          fontSize: 15, color: CC.ink, lineHeight: 1.6, letterSpacing: '0.03em',
        }}>
          今天跟 yaki 學了一個新詞...
          <span style={{
            display: 'inline-block', width: 1.5, height: 18,
            background: CC.primary, marginLeft: 2, verticalAlign: 'middle',
            animation: 'blink 1s infinite',
          }} />
        </div>
      </div>

      {/* 圖片附件區 */}
      <div style={{ padding: '12px 20px 0', display: 'flex', gap: 8 }}>
        <div style={{
          width: 80, height: 80, borderRadius: 10, position: 'relative',
          background: `linear-gradient(135deg, ${CC.moss}, ${CC.mossDeep})`,
          overflow: 'hidden',
        }}>
          <div style={{ position: 'absolute', inset: 0, opacity: 0.35 }}>
            <window.TrukuWeaveBg color={CC.gold} bg="transparent" opacity={1} scale={0.4} />
          </div>
          <div style={{
            position: 'absolute', top: 4, right: 4,
            width: 18, height: 18, borderRadius: 9,
            background: 'rgba(0,0,0,0.6)',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
          }}>
            <svg width="10" height="10" viewBox="0 0 24 24" fill="none" stroke={CC.creamLight} strokeWidth="3" strokeLinecap="round">
              <path d="M18 6L6 18M6 6l12 12"/>
            </svg>
          </div>
        </div>
        <div style={{
          width: 80, height: 80, borderRadius: 10,
          border: `1.5px dashed ${CC.fog}80`,
          display: 'flex', alignItems: 'center', justifyContent: 'center',
          color: CC.fog,
        }}>
          <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke={CC.fog} strokeWidth="1.8" strokeLinecap="round">
            <path d="M12 5v14M5 12h14"/>
          </svg>
        </div>
      </div>

      {/* 標籤建議 */}
      <div style={{ padding: '20px 20px 0' }}>
        <div style={{
          fontFamily: CF.truku, fontStyle: 'italic', fontSize: 10,
          color: CC.fog, letterSpacing: '0.2em', marginBottom: 8,
        }}>HANGAN · 標籤</div>
        <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6 }}>
          {[
            { tag: 'Mhuway', active: true },
            { tag: '族語心得' },
            { tag: '走讀' },
            { tag: '老人家的話' },
            { tag: '求救' },
            { tag: 'Gaya' },
          ].map((t, i) => (
            <div key={i} style={{
              padding: '6px 12px', borderRadius: 14,
              background: t.active ? CC.primary : 'transparent',
              color: t.active ? CC.creamLight : CC.inkSoft,
              border: t.active ? 'none' : `1px solid ${CC.creamDeep}`,
              fontFamily: CF.truku, fontStyle: 'italic', fontSize: 12,
              letterSpacing: '0.08em',
              display: 'flex', alignItems: 'center', gap: 4,
            }}>
              <span style={{ opacity: 0.7 }}>#</span>{t.tag}
            </div>
          ))}
        </div>
      </div>

      {/* 工具列 */}
      <div style={{
        position: 'fixed', bottom: 0, left: 0, right: 0,
        background: CC.creamLight, borderTop: `1px solid ${CC.creamDeep}`,
        padding: '12px 20px 28px',
        display: 'flex', alignItems: 'center', gap: 22,
      }}>
        {[
          { icon: 'img', label: '圖片' },
          { icon: 'mic', label: '錄音' },
          { icon: 'tag', label: '標籤' },
          { icon: 'loc', label: '部落' },
        ].map(t => (
          <div key={t.icon} style={{
            display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 3,
          }}>
            <div style={{
              width: 36, height: 36, borderRadius: 18,
              background: CC.cream,
              display: 'flex', alignItems: 'center', justifyContent: 'center',
            }}>
              {t.icon === 'img' && (
                <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke={CC.primary} strokeWidth="1.8" strokeLinecap="round">
                  <rect x="3" y="4" width="18" height="16" rx="2"/>
                  <circle cx="9" cy="10" r="2"/>
                  <path d="M21 16l-5-5L4 20"/>
                </svg>
              )}
              {t.icon === 'mic' && (
                <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke={CC.primary} strokeWidth="1.8" strokeLinecap="round">
                  <rect x="9" y="3" width="6" height="12" rx="3"/>
                  <path d="M5 11a7 7 0 0014 0M12 18v3"/>
                </svg>
              )}
              {t.icon === 'tag' && (
                <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke={CC.primary} strokeWidth="1.8" strokeLinecap="round">
                  <path d="M20 12l-8 8L3 11V3h8l9 9z"/>
                  <circle cx="7.5" cy="7.5" r="1" fill={CC.primary}/>
                </svg>
              )}
              {t.icon === 'loc' && (
                <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke={CC.primary} strokeWidth="1.8" strokeLinecap="round">
                  <path d="M12 22s8-7 8-13a8 8 0 10-16 0c0 6 8 13 8 13z"/>
                  <circle cx="12" cy="9" r="2.5"/>
                </svg>
              )}
            </div>
            <div style={{ fontSize: 10, color: CC.inkSoft, letterSpacing: '0.05em' }}>
              {t.label}
            </div>
          </div>
        ))}
        <div style={{ flex: 1 }} />
        <div style={{
          fontFamily: CF.mono, fontSize: 11, color: CC.fog,
        }}>14 / 500</div>
      </div>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// 活動列表（瀏覽 + 報名）
// ─────────────────────────────────────────────────────────────
function EventsScreen() {
  const events = [
    {
      m: 'JUN', d: '15', day: '週六', title: '青年族語營', loc: '秀林部落',
      time: '09:00 — 17:00', n: 23, max: 30, tag: '族語', host: 'Sayun Lowking',
      desc: '三天兩夜，跟著耆老學族語、織布、聽部落故事。', color: CC.primary, featured: true,
    },
    {
      m: 'JUN', d: '22', day: '週六', title: '苧麻採集走讀', loc: '銅門部落',
      time: '06:00 — 12:00', n: 12, max: 20, tag: '走讀', host: 'Bakan Nawi', color: CC.moss,
    },
    {
      m: 'JUL', d: '03', day: '週日', title: '部落歌謠之夜', loc: '富世社區活動中心',
      time: '19:00 — 21:00', n: 41, max: 60, tag: '音樂', host: 'Pisaw baki', color: CC.primary,
    },
    {
      m: 'JUL', d: '12', day: '週六', title: '太魯閣語讀書會', loc: '線上',
      time: '20:00 — 21:30', n: 8, max: 15, tag: '線上', host: 'Yudaw', color: CC.moss,
    },
    {
      m: 'JUL', d: '20', day: '週日', title: '織布工坊體驗', loc: '銅門工藝坊',
      time: '13:00 — 17:00', n: 6, max: 10, tag: '工藝', host: 'Iwan yaki', color: CC.primary,
    },
  ];

  return (
    <div style={{ width: '100%', minHeight: '100%', background: CC.creamLight, fontFamily: CF.body, paddingBottom: 100 }}>
      {/* 頂部 */}
      <div style={{ padding: '60px 20px 14px', display: 'flex', alignItems: 'flex-end', justifyContent: 'space-between' }}>
        <div>
          <div style={{
            fontFamily: CF.truku, fontStyle: 'italic', fontSize: 12,
            color: CC.fog, letterSpacing: '0.25em', marginBottom: 4,
          }}>SMRATUC · 活動</div>
          <div style={{
            fontFamily: CF.display, fontSize: 26, fontWeight: 600,
            color: CC.ink, letterSpacing: '0.04em',
          }}>近期部落聚會</div>
        </div>
        <button style={{
          padding: '10px 16px', borderRadius: 22, border: 'none',
          background: CC.primary, color: CC.creamLight,
          fontFamily: CF.display, fontSize: 13, fontWeight: 600, letterSpacing: '0.08em',
          display: 'flex', alignItems: 'center', gap: 6,
        }}>
          <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke={CC.creamLight} strokeWidth="2.5" strokeLinecap="round">
            <path d="M12 4v16M4 12h16"/>
          </svg>
          發起
        </button>
      </div>

      {/* 篩選 chips */}
      <div style={{
        padding: '0 20px 14px', display: 'flex', gap: 8, overflowX: 'auto',
      }}>
        {['全部', '本月', '族語', '走讀', '工藝', '線上'].map((c, i) => (
          <div key={c} style={{
            padding: '7px 14px', borderRadius: 20,
            background: i === 0 ? CC.ink : 'transparent',
            color: i === 0 ? CC.creamLight : CC.inkSoft,
            border: i === 0 ? 'none' : `1px solid ${CC.creamDeep}`,
            fontSize: 12, letterSpacing: '0.06em', whiteSpace: 'nowrap',
          }}>{c}</div>
        ))}
      </div>

      {/* 精選大卡 */}
      <div style={{ padding: '0 20px 14px' }}>
        <div style={{
          background: CC.ink, color: CC.creamLight, borderRadius: 18,
          overflow: 'hidden', position: 'relative',
        }}>
          {/* 頂部視覺 */}
          <div style={{
            height: 130, position: 'relative',
            background: `linear-gradient(135deg, ${CC.primary}, ${CC.primaryDeep})`,
          }}>
            <div style={{ position: 'absolute', inset: 0, opacity: 0.25 }}>
              <window.TrukuWeaveBg color={CC.gold} bg="transparent" opacity={1} scale={0.7} />
            </div>
            <div style={{ position: 'absolute', bottom: 0, left: 0, right: 0, opacity: 0.5 }}>
              <window.TrukuMountains width={402} height={60} color="#0E0604" opacity={0.6} />
            </div>
            <div style={{
              position: 'absolute', top: 14, left: 14,
              padding: '4px 10px', borderRadius: 4,
              background: CC.gold, fontSize: 10, color: CC.ink, fontWeight: 600,
              letterSpacing: '0.15em',
            }}>編輯精選</div>
            <div style={{
              position: 'absolute', top: 14, right: 14,
              background: 'rgba(28,15,13,0.55)', backdropFilter: 'blur(8px)',
              borderRadius: 8, padding: '6px 10px', textAlign: 'center',
              border: `1px solid ${CC.gold}50`,
            }}>
              <div style={{ fontSize: 8, color: CC.gold, letterSpacing: '0.18em' }}>{events[0].m}</div>
              <div style={{ fontFamily: CF.display, fontSize: 18, fontWeight: 700, color: CC.creamLight, lineHeight: 1 }}>{events[0].d}</div>
            </div>
          </div>
          {/* 內容 */}
          <div style={{ padding: '16px 18px', position: 'relative' }}>
            <div style={{
              fontFamily: CF.display, fontSize: 19, fontWeight: 600,
              letterSpacing: '0.04em', marginBottom: 6,
            }}>{events[0].title}</div>
            <div style={{ fontSize: 12, opacity: 0.75, lineHeight: 1.5, letterSpacing: '0.03em', marginBottom: 10 }}>
              {events[0].desc}
            </div>
            <div style={{ display: 'flex', alignItems: 'center', gap: 14, fontSize: 11, opacity: 0.85, marginBottom: 12 }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: 4 }}>
                <svg width="11" height="11" viewBox="0 0 24 24" fill="none" stroke={CC.gold} strokeWidth="2"><circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/></svg>
                {events[0].time}
              </div>
              <div style={{ display: 'flex', alignItems: 'center', gap: 4 }}>
                <svg width="11" height="11" viewBox="0 0 24 24" fill="none" stroke={CC.gold} strokeWidth="2"><path d="M12 22s8-7 8-13a8 8 0 10-16 0c0 6 8 13 8 13z"/></svg>
                {events[0].loc}
              </div>
            </div>
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 12 }}>
              <div style={{ flex: 1 }}>
                <div style={{ height: 5, background: 'rgba(250,245,234,0.15)', borderRadius: 3, overflow: 'hidden', marginBottom: 4 }}>
                  <div style={{ width: `${events[0].n/events[0].max*100}%`, height: '100%', background: CC.gold }} />
                </div>
                <div style={{ fontSize: 10, opacity: 0.7, letterSpacing: '0.05em' }}>
                  {events[0].n}/{events[0].max} 人 · 剩 {events[0].max - events[0].n} 個名額
                </div>
              </div>
              <button style={{
                padding: '10px 20px', borderRadius: 22, border: 'none',
                background: CC.gold, color: CC.ink,
                fontFamily: CF.display, fontSize: 13, fontWeight: 600, letterSpacing: '0.1em',
              }}>我要參加</button>
            </div>
          </div>
        </div>
      </div>

      {/* 列表分隔 */}
      <div style={{
        padding: '6px 20px 10px',
        display: 'flex', alignItems: 'center', gap: 10,
      }}>
        <div style={{ flex: 1, height: 1, background: CC.creamDeep }} />
        <div style={{
          fontFamily: CF.truku, fontStyle: 'italic', fontSize: 10,
          color: CC.fog, letterSpacing: '0.2em',
        }}>更多活動</div>
        <div style={{ flex: 1, height: 1, background: CC.creamDeep }} />
      </div>

      {/* 活動清單 */}
      <div style={{ padding: '0 20px', display: 'flex', flexDirection: 'column', gap: 10 }}>
        {events.slice(1).map((e, i) => (
          <div key={i} style={{
            background: CC.cream, borderRadius: 14, padding: '12px',
            border: `1px solid ${CC.creamDeep}`,
            display: 'flex', gap: 12,
          }}>
            {/* 日期方塊 */}
            <div style={{
              width: 56, flexShrink: 0,
              background: e.color, borderRadius: 10,
              display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center',
              padding: '10px 0', position: 'relative', overflow: 'hidden',
            }}>
              <div style={{ position: 'absolute', inset: 0, opacity: 0.18 }}>
                <window.TrukuWeaveBg color={CC.gold} bg="transparent" opacity={1} scale={0.3} />
              </div>
              <div style={{ position: 'relative', fontSize: 9, color: CC.gold, letterSpacing: '0.18em' }}>{e.m}</div>
              <div style={{ position: 'relative', fontFamily: CF.display, fontSize: 22, fontWeight: 700, color: CC.creamLight, lineHeight: 1 }}>{e.d}</div>
              <div style={{ position: 'relative', fontSize: 9, color: CC.creamLight, opacity: 0.7, letterSpacing: '0.1em', marginTop: 2 }}>{e.day}</div>
            </div>
            <div style={{ flex: 1, minWidth: 0 }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginBottom: 3 }}>
                <div style={{
                  padding: '2px 7px', borderRadius: 3,
                  background: CC.primary + '15', color: CC.primary,
                  fontSize: 9, letterSpacing: '0.1em',
                }}>{e.tag}</div>
                {e.n / e.max > 0.7 && (
                  <div style={{
                    padding: '2px 7px', borderRadius: 3,
                    background: '#A33' + '15', color: '#A33',
                    fontSize: 9, letterSpacing: '0.1em',
                  }}>即將額滿</div>
                )}
              </div>
              <div style={{
                fontFamily: CF.display, fontSize: 14, fontWeight: 600,
                color: CC.ink, letterSpacing: '0.04em', marginBottom: 3,
              }}>{e.title}</div>
              <div style={{ fontSize: 11, color: CC.fog, letterSpacing: '0.05em', marginBottom: 6 }}>
                {e.time} · {e.loc}
              </div>
              <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: 4, fontSize: 11, color: CC.inkSoft }}>
                  <svg width="11" height="11" viewBox="0 0 24 24" fill="none" stroke={CC.inkSoft} strokeWidth="2"><circle cx="12" cy="9" r="3"/><path d="M4 21c1-4 4-6 8-6s7 2 8 6"/></svg>
                  {e.n}/{e.max}
                </div>
                <button style={{
                  padding: '5px 12px', borderRadius: 12, border: `1px solid ${CC.primary}`,
                  background: 'transparent', color: CC.primary,
                  fontSize: 11, letterSpacing: '0.08em',
                }}>查看</button>
              </div>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// 發布活動頁面
// ─────────────────────────────────────────────────────────────
function ComposeEventScreen() {
  return (
    <div style={{ width: '100%', minHeight: '100%', background: CC.creamLight, fontFamily: CF.body, paddingBottom: 100 }}>
      {/* 頂部 nav */}
      <div style={{
        position: 'sticky', top: 0, zIndex: 10,
        background: CC.creamLight, borderBottom: `1px solid ${CC.creamDeep}`,
        padding: '54px 16px 12px',
        display: 'flex', alignItems: 'center', justifyContent: 'space-between',
      }}>
        <button style={{
          padding: '6px 4px', border: 'none', background: 'transparent',
          color: CC.inkSoft, fontSize: 14, letterSpacing: '0.05em',
        }}>取消</button>
        <div style={{
          fontFamily: CF.display, fontSize: 15, fontWeight: 600,
          color: CC.ink, letterSpacing: '0.08em',
        }}>新發布</div>
        <button style={{
          padding: '6px 16px', borderRadius: 16, border: 'none',
          background: CC.primary, color: CC.creamLight,
          fontFamily: CF.display, fontSize: 13, fontWeight: 600, letterSpacing: '0.08em',
        }}>發布</button>
      </div>

      {/* 類型切換 */}
      <div style={{ padding: '18px 20px 0' }}>
        <div style={{
          display: 'flex', background: CC.cream, borderRadius: 12,
          padding: 4, border: `1px solid ${CC.creamDeep}`,
        }}>
          {[
            { key: 'post', label: '動態', truku: 'patas', active: false, icon: 'pen' },
            { key: 'event', label: '活動', truku: 'smratuc', active: true, icon: 'cal' },
          ].map(t => (
            <div key={t.key} style={{
              flex: 1, padding: '10px 12px', borderRadius: 9,
              background: t.active ? CC.creamLight : 'transparent',
              boxShadow: t.active ? '0 1px 3px rgba(0,0,0,0.08)' : 'none',
              display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 6,
            }}>
              {t.icon === 'pen' && (
                <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke={t.active ? CC.primary : CC.fog} strokeWidth="2" strokeLinecap="round">
                  <path d="M14 4l6 6L8 22H2v-6L14 4z"/>
                </svg>
              )}
              {t.icon === 'cal' && (
                <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke={t.active ? CC.primary : CC.fog} strokeWidth="2" strokeLinecap="round">
                  <rect x="3" y="5" width="18" height="16" rx="2"/>
                  <path d="M3 10h18M8 3v4M16 3v4"/>
                </svg>
              )}
              <span style={{
                fontFamily: CF.display, fontSize: 13, fontWeight: 600,
                color: t.active ? CC.primary : CC.fog, letterSpacing: '0.08em',
              }}>{t.label}</span>
              <span style={{
                fontFamily: CF.truku, fontStyle: 'italic', fontSize: 10,
                color: t.active ? CC.gold : CC.fog, opacity: 0.8, letterSpacing: '0.1em',
              }}>{t.truku}</span>
            </div>
          ))}
        </div>
      </div>

      {/* 活動封面 */}
      <div style={{ padding: '16px 20px 0' }}>
        <div style={{
          height: 140, borderRadius: 14, position: 'relative', overflow: 'hidden',
          background: `linear-gradient(135deg, ${CC.primary}, ${CC.primaryDeep})`,
        }}>
          <div style={{ position: 'absolute', inset: 0, opacity: 0.25 }}>
            <window.TrukuWeaveBg color={CC.gold} bg="transparent" opacity={1} scale={0.7} />
          </div>
          <div style={{
            position: 'absolute', inset: 0, display: 'flex', flexDirection: 'column',
            alignItems: 'center', justifyContent: 'center', gap: 6,
          }}>
            <div style={{
              width: 44, height: 44, borderRadius: 22,
              background: 'rgba(250,245,234,0.2)', backdropFilter: 'blur(10px)',
              display: 'flex', alignItems: 'center', justifyContent: 'center',
            }}>
              <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke={CC.creamLight} strokeWidth="2" strokeLinecap="round">
                <path d="M12 5v14M5 12h14"/>
              </svg>
            </div>
            <div style={{ fontSize: 12, color: CC.creamLight, letterSpacing: '0.1em' }}>
              加入活動封面
            </div>
          </div>
        </div>
      </div>

      {/* 活動標題 */}
      <div style={{ padding: '16px 20px 0' }}>
        <div style={{
          fontFamily: CF.truku, fontStyle: 'italic', fontSize: 10,
          color: CC.fog, letterSpacing: '0.2em', marginBottom: 6,
        }}>HANGAN · 活動名稱</div>
        <div style={{
          padding: '12px 14px', background: CC.cream, borderRadius: 12,
          border: `1px solid ${CC.creamDeep}`,
          fontFamily: CF.display, fontSize: 17, fontWeight: 600,
          color: CC.ink, letterSpacing: '0.04em',
        }}>
          青年族語營·秀林部落
          <span style={{
            display: 'inline-block', width: 1.5, height: 18,
            background: CC.primary, marginLeft: 2, verticalAlign: 'middle',
          }} />
        </div>
      </div>

      {/* 時間 + 地點 兩欄 */}
      <div style={{ padding: '14px 20px 0', display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10 }}>
        {/* 日期時間 */}
        <div style={{
          padding: '12px 14px', background: CC.cream, borderRadius: 12,
          border: `1px solid ${CC.creamDeep}`,
        }}>
          <div style={{
            display: 'flex', alignItems: 'center', gap: 6,
            fontFamily: CF.truku, fontStyle: 'italic', fontSize: 10,
            color: CC.fog, letterSpacing: '0.18em', marginBottom: 6,
          }}>
            <svg width="11" height="11" viewBox="0 0 24 24" fill="none" stroke={CC.fog} strokeWidth="2">
              <rect x="3" y="5" width="18" height="16" rx="2"/>
              <path d="M3 10h18M8 3v4M16 3v4"/>
            </svg>
            JIYAX · 日期
          </div>
          <div style={{ fontFamily: CF.display, fontSize: 15, fontWeight: 600, color: CC.ink, letterSpacing: '0.04em' }}>
            6/15 週六
          </div>
          <div style={{ fontSize: 11, color: CC.inkSoft, marginTop: 2, letterSpacing: '0.05em' }}>
            09:00 — 17:00
          </div>
        </div>

        {/* 地點 */}
        <div style={{
          padding: '12px 14px', background: CC.cream, borderRadius: 12,
          border: `1px solid ${CC.creamDeep}`,
        }}>
          <div style={{
            display: 'flex', alignItems: 'center', gap: 6,
            fontFamily: CF.truku, fontStyle: 'italic', fontSize: 10,
            color: CC.fog, letterSpacing: '0.18em', marginBottom: 6,
          }}>
            <svg width="11" height="11" viewBox="0 0 24 24" fill="none" stroke={CC.fog} strokeWidth="2" strokeLinecap="round">
              <path d="M12 22s8-7 8-13a8 8 0 10-16 0c0 6 8 13 8 13z"/>
              <circle cx="12" cy="9" r="2.5"/>
            </svg>
            ALANG · 地點
          </div>
          <div style={{ fontFamily: CF.display, fontSize: 15, fontWeight: 600, color: CC.ink, letterSpacing: '0.04em' }}>
            秀林部落
          </div>
          <div style={{ fontSize: 11, color: CC.inkSoft, marginTop: 2, letterSpacing: '0.05em' }}>
            花蓮縣秀林鄉
          </div>
        </div>
      </div>

      {/* 名額 */}
      <div style={{ padding: '14px 20px 0' }}>
        <div style={{
          padding: '12px 14px', background: CC.cream, borderRadius: 12,
          border: `1px solid ${CC.creamDeep}`,
          display: 'flex', alignItems: 'center', justifyContent: 'space-between',
        }}>
          <div>
            <div style={{
              fontFamily: CF.truku, fontStyle: 'italic', fontSize: 10,
              color: CC.fog, letterSpacing: '0.18em', marginBottom: 4,
            }}>SEEDIQ · 名額</div>
            <div style={{ fontFamily: CF.display, fontSize: 15, fontWeight: 600, color: CC.ink, letterSpacing: '0.04em' }}>
              30 人
            </div>
          </div>
          <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
            <button style={{
              width: 30, height: 30, borderRadius: 15,
              border: `1px solid ${CC.creamDeep}`, background: CC.creamLight,
              color: CC.primary, fontSize: 16, fontWeight: 600,
            }}>−</button>
            <button style={{
              width: 30, height: 30, borderRadius: 15,
              border: 'none', background: CC.primary,
              color: CC.creamLight, fontSize: 16, fontWeight: 600,
            }}>+</button>
          </div>
        </div>
      </div>

      {/* 活動說明 */}
      <div style={{ padding: '14px 20px 0' }}>
        <div style={{
          fontFamily: CF.truku, fontStyle: 'italic', fontSize: 10,
          color: CC.fog, letterSpacing: '0.2em', marginBottom: 6,
        }}>KARI · 活動說明</div>
        <div style={{
          minHeight: 90, padding: '12px 14px',
          background: CC.cream, borderRadius: 12,
          border: `1px solid ${CC.creamDeep}`,
          fontSize: 13, color: CC.inkSoft, lineHeight: 1.6, letterSpacing: '0.03em',
        }}>
          三天兩夜，跟著耆老學族語、織布、聽部落故事...
        </div>
      </div>

      {/* 標籤 */}
      <div style={{ padding: '16px 20px 0' }}>
        <div style={{
          fontFamily: CF.truku, fontStyle: 'italic', fontSize: 10,
          color: CC.fog, letterSpacing: '0.2em', marginBottom: 8,
        }}>HANGAN · 標籤</div>
        <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6 }}>
          {[
            { tag: '族語營', active: true },
            { tag: '青年' },
            { tag: '部落體驗' },
            { tag: '免費' },
            { tag: '住宿' },
          ].map((t, i) => (
            <div key={i} style={{
              padding: '6px 12px', borderRadius: 14,
              background: t.active ? CC.primary : 'transparent',
              color: t.active ? CC.creamLight : CC.inkSoft,
              border: t.active ? 'none' : `1px solid ${CC.creamDeep}`,
              fontFamily: CF.truku, fontStyle: 'italic', fontSize: 12,
              letterSpacing: '0.08em',
              display: 'flex', alignItems: 'center', gap: 4,
            }}>
              <span style={{ opacity: 0.7 }}>#</span>{t.tag}
            </div>
          ))}
        </div>
      </div>

      {/* 底部工具列 */}
      <div style={{
        position: 'fixed', bottom: 0, left: 0, right: 0,
        background: CC.creamLight, borderTop: `1px solid ${CC.creamDeep}`,
        padding: '12px 20px 28px',
        display: 'flex', alignItems: 'center', gap: 10,
      }}>
        <div style={{ flex: 1, display: 'flex', alignItems: 'center', gap: 8 }}>
          <div style={{
            width: 32, height: 32, borderRadius: 16, background: CC.cream,
            display: 'flex', alignItems: 'center', justifyContent: 'center',
          }}>
            <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke={CC.primary} strokeWidth="2">
              <circle cx="12" cy="12" r="9"/>
              <path d="M3 12h18M12 3a14 14 0 010 18M12 3a14 14 0 000 18"/>
            </svg>
          </div>
          <div style={{ fontSize: 12, color: CC.inkSoft, letterSpacing: '0.05em' }}>
            公開給所有族人
          </div>
        </div>
        <button style={{
          padding: '8px 14px', borderRadius: 16, border: `1px solid ${CC.creamDeep}`,
          background: CC.creamLight, color: CC.inkSoft, fontSize: 12, letterSpacing: '0.08em',
        }}>預覽</button>
      </div>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// 個人頁面
// ─────────────────────────────────────────────────────────────
function ProfileScreen() {
  return (
    <div style={{ width: '100%', minHeight: '100%', background: CC.creamLight, fontFamily: CF.body, paddingBottom: 100 }}>
      {/* hero 卡 */}
      <div style={{
        position: 'relative', overflow: 'hidden',
        background: `linear-gradient(160deg, ${CC.primary}, ${CC.primaryDeep})`,
        padding: '60px 20px 28px',
        color: CC.creamLight,
      }}>
        <div style={{ position: 'absolute', inset: 0, opacity: 0.15 }}>
          <window.TrukuWeaveBg color={CC.gold} bg="transparent" opacity={1} scale={0.8} />
        </div>
        <div style={{ position: 'relative', display: 'flex', justifyContent: 'flex-end', marginBottom: 12 }}>
          <button style={{
            width: 36, height: 36, borderRadius: 18, border: 'none',
            background: 'rgba(250,245,234,0.15)', color: CC.creamLight,
            display: 'flex', alignItems: 'center', justifyContent: 'center',
          }}>
            <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke={CC.creamLight} strokeWidth="1.8">
              <circle cx="12" cy="12" r="3"/>
              <path d="M19 12a7 7 0 00-.1-1.2l2.1-1.6-2-3.4-2.5 1a7 7 0 00-2-1.2l-.4-2.6h-4l-.4 2.6a7 7 0 00-2 1.2l-2.5-1-2 3.4 2.1 1.6A7 7 0 005 12c0 .4 0 .8.1 1.2l-2.1 1.6 2 3.4 2.5-1a7 7 0 002 1.2l.4 2.6h4l.4-2.6a7 7 0 002-1.2l2.5 1 2-3.4-2.1-1.6c.1-.4.1-.8.1-1.2z"/>
            </svg>
          </button>
        </div>
        <div style={{ position: 'relative', display: 'flex', alignItems: 'center', gap: 16 }}>
          <div style={{
            width: 80, height: 80, borderRadius: 40, position: 'relative',
            background: CC.ink, border: `2px solid ${CC.gold}`,
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            overflow: 'hidden',
          }}>
            <img src="badges/c-orange-happy.png" alt="頭貼" style={{
              width: 88, height: 88, objectFit: 'contain', objectPosition: 'center',
            }} />
            {/* 編輯角標 */}
            <div style={{
              position: 'absolute', bottom: -2, right: -2,
              width: 26, height: 26, borderRadius: 13,
              background: CC.gold, border: `2px solid ${CC.primary}`,
              display: 'flex', alignItems: 'center', justifyContent: 'center',
            }}>
              <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke={CC.ink} strokeWidth="2.5" strokeLinecap="round">
                <path d="M14 4l6 6L8 22H2v-6L14 4z"/>
              </svg>
            </div>
          </div>
          <div style={{ flex: 1 }}>
            <div style={{
              fontFamily: CF.truku, fontStyle: 'italic', fontSize: 11,
              color: CC.gold, letterSpacing: '0.2em', marginBottom: 4,
            }}>SAYUN LOWKING</div>
            <div style={{
              fontFamily: CF.display, fontSize: 22, fontWeight: 600,
              letterSpacing: '0.04em', marginBottom: 4,
            }}>陳莎韻</div>
            <div style={{ fontSize: 12, opacity: 0.85, letterSpacing: '0.05em' }}>
              銅門部落 · 加入 124 天
            </div>
          </div>
        </div>

        {/* 學習統計 */}
        <div style={{
          position: 'relative', marginTop: 20,
          display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: 10,
        }}>
          {[
            { n: '248', l: '已學詞彙' },
            { n: '36', l: '通話次數' },
            { n: '12', l: '發文' },
          ].map(s => (
            <div key={s.l} style={{
              background: 'rgba(250,245,234,0.1)', borderRadius: 12,
              padding: '10px 12px', textAlign: 'center',
              border: `1px solid ${CC.gold}40`,
            }}>
              <div style={{ fontFamily: CF.display, fontSize: 20, fontWeight: 700, color: CC.gold }}>
                {s.n}
              </div>
              <div style={{ fontSize: 10, opacity: 0.8, letterSpacing: '0.05em', marginTop: 2 }}>
                {s.l}
              </div>
            </div>
          ))}
        </div>
      </div>

      {/* 我的徽章 / 大頭貼選擇 */}
      <div style={{ padding: '20px 20px 0' }}>
        <div style={{
          display: 'flex', alignItems: 'baseline', justifyContent: 'space-between', marginBottom: 8,
        }}>
          <div style={{
            fontFamily: CF.truku, fontStyle: 'italic', fontSize: 10,
            color: CC.fog, letterSpacing: '0.2em',
          }}>LUKUS · 大頭貼</div>
          <div style={{ display: 'flex', alignItems: 'center', gap: 4, fontSize: 11, color: CC.primary, letterSpacing: '0.1em' }}>
            前往商店 →
          </div>
        </div>
        <div style={{
          background: CC.cream, borderRadius: 14, padding: '14px',
          border: `1px solid ${CC.creamDeep}`,
        }}>
          <div style={{ fontSize: 11, color: CC.fog, letterSpacing: '0.05em', marginBottom: 10 }}>
            從擁有的徽章中選一個作為頭貼
          </div>
          <div style={{ display: 'flex', gap: 8, overflowX: 'auto' }}>
            {[
              { img: 'badges/c-orange-happy.png', selected: true },
              { img: 'badges/c-red.png' },
              { img: 'badges/c-green-laugh.png' },
              { img: 'badges/g-happy.png' },
              { img: 'badges/c-cyan-love.png' },
            ].map((b, i) => (
              <div key={i} style={{
                width: 56, height: 56, borderRadius: 28, flexShrink: 0, position: 'relative',
                background: b.selected ? CC.primary : 'transparent',
                border: b.selected ? `2px solid ${CC.gold}` : `1.5px solid ${CC.creamDeep}`,
                display: 'flex', alignItems: 'center', justifyContent: 'center',
                overflow: 'hidden',
              }}>
                <img src={b.img} alt="" style={{ width: 62, height: 62, objectFit: 'contain' }} />
                {b.selected && (
                  <div style={{
                    position: 'absolute', bottom: -2, right: -2,
                    width: 18, height: 18, borderRadius: 9,
                    background: CC.gold, border: `1.5px solid ${CC.creamLight}`,
                    display: 'flex', alignItems: 'center', justifyContent: 'center',
                  }}>
                    <svg width="9" height="9" viewBox="0 0 24 24" fill="none" stroke={CC.ink} strokeWidth="3.5" strokeLinecap="round" strokeLinejoin="round">
                      <path d="M5 12l5 5L20 7"/>
                    </svg>
                  </div>
                )}
              </div>
            ))}
            {/* 加號 — 前往商店 */}
            <div style={{
              width: 56, height: 56, borderRadius: 28, flexShrink: 0,
              border: `1.5px dashed ${CC.gold}80`,
              display: 'flex', alignItems: 'center', justifyContent: 'center',
              background: 'rgba(201,169,97,0.06)',
            }}>
              <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke={CC.primary} strokeWidth="2" strokeLinecap="round">
                <path d="M12 5v14M5 12h14"/>
              </svg>
            </div>
          </div>
          <div style={{
            marginTop: 12, paddingTop: 12, borderTop: `1px solid ${CC.creamDeep}`,
            display: 'flex', alignItems: 'center', gap: 10,
          }}>
            <img src="badges/millet.png" alt="小米" style={{ width: 26, height: 26, objectFit: 'contain' }} />
            <div style={{ flex: 1 }}>
              <div style={{ fontFamily: CF.display, fontSize: 13, fontWeight: 600, color: CC.ink, letterSpacing: '0.04em' }}>
                目前小米：<span style={{ color: CC.primary }}>320</span>
              </div>
              <div style={{ fontSize: 10, color: CC.fog, letterSpacing: '0.05em' }}>
                每日登入 / 完成單元都能得小米
              </div>
            </div>
            <button style={{
              padding: '7px 12px', borderRadius: 14, border: 'none',
              background: CC.primary, color: CC.creamLight,
              fontFamily: CF.display, fontSize: 11, fontWeight: 600, letterSpacing: '0.08em',
            }}>逛商店</button>
          </div>
        </div>
      </div>

      {/* 帳號設定 */}
      <div style={{ padding: '20px 20px 0' }}>
        <div style={{
          fontFamily: CF.truku, fontStyle: 'italic', fontSize: 10,
          color: CC.fog, letterSpacing: '0.2em', marginBottom: 8,
        }}>HANGAN · 帳號</div>
        <div style={{
          background: CC.cream, borderRadius: 14,
          border: `1px solid ${CC.creamDeep}`, overflow: 'hidden',
        }}>
          {[
            { label: '中文姓名', value: '陳莎韻', editable: true },
            { label: '族語名字', value: 'Sayun Lowking', truku: true, editable: true },
            { label: '部落', value: '銅門 Dowmung', editable: true },
            { label: '電子信箱', value: 'sayun@truku.org', editable: false },
          ].map((row, i, arr) => (
            <div key={row.label} style={{
              padding: '14px 16px',
              borderBottom: i < arr.length - 1 ? `1px solid ${CC.creamDeep}` : 'none',
              display: 'flex', alignItems: 'center', justifyContent: 'space-between',
            }}>
              <div>
                <div style={{ fontSize: 11, color: CC.fog, letterSpacing: '0.05em', marginBottom: 2 }}>
                  {row.label}
                </div>
                <div style={{
                  fontFamily: row.truku ? CF.truku : CF.display, fontStyle: row.truku ? 'italic' : 'normal',
                  fontSize: 14, fontWeight: 600, color: CC.ink, letterSpacing: '0.03em',
                }}>
                  {row.value}
                </div>
              </div>
              {row.editable && (
                <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke={CC.primary} strokeWidth="1.8" strokeLinecap="round">
                  <path d="M14 4l6 6L8 22H2v-6L14 4z"/>
                </svg>
              )}
            </div>
          ))}
        </div>
      </div>

      {/* 偏好設定 */}
      <div style={{ padding: '20px 20px 0' }}>
        <div style={{
          fontFamily: CF.truku, fontStyle: 'italic', fontSize: 10,
          color: CC.fog, letterSpacing: '0.2em', marginBottom: 8,
        }}>SMPUNG · 偏好</div>
        <div style={{
          background: CC.cream, borderRadius: 14,
          border: `1px solid ${CC.creamDeep}`, overflow: 'hidden',
        }}>
          {[
            { label: '通知', value: '已開啟', toggle: true, on: true },
            { label: '族語顯示', value: '優先顯示拼音', chevron: true },
            { label: '字級大小', value: '中', chevron: true },
            { label: '通話開放', value: '所有族人', toggle: true, on: true },
          ].map((row, i, arr) => (
            <div key={row.label} style={{
              padding: '14px 16px',
              borderBottom: i < arr.length - 1 ? `1px solid ${CC.creamDeep}` : 'none',
              display: 'flex', alignItems: 'center', justifyContent: 'space-between',
            }}>
              <div style={{
                fontFamily: CF.display, fontSize: 14, color: CC.ink, letterSpacing: '0.04em',
              }}>{row.label}</div>
              <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                <div style={{ fontSize: 12, color: CC.fog, letterSpacing: '0.05em' }}>
                  {row.value}
                </div>
                {row.toggle && (
                  <div style={{
                    width: 36, height: 22, borderRadius: 11, padding: 2,
                    background: row.on ? CC.primary : CC.creamDeep,
                    display: 'flex', justifyContent: row.on ? 'flex-end' : 'flex-start',
                  }}>
                    <div style={{ width: 18, height: 18, borderRadius: 9, background: CC.creamLight }} />
                  </div>
                )}
                {row.chevron && (
                  <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke={CC.fog} strokeWidth="2" strokeLinecap="round">
                    <path d="M9 6l6 6-6 6"/>
                  </svg>
                )}
              </div>
            </div>
          ))}
        </div>
      </div>

      {/* 其他 */}
      <div style={{ padding: '20px 20px 0' }}>
        <div style={{
          fontFamily: CF.truku, fontStyle: 'italic', fontSize: 10,
          color: CC.fog, letterSpacing: '0.2em', marginBottom: 8,
        }}>QITA · 其他</div>
        <div style={{
          background: CC.cream, borderRadius: 14,
          border: `1px solid ${CC.creamDeep}`, overflow: 'hidden',
        }}>
          {['關於語見太魯閣', '隱私權政策', '聯絡我們'].map((label, i, arr) => (
            <div key={label} style={{
              padding: '14px 16px',
              borderBottom: i < arr.length - 1 ? `1px solid ${CC.creamDeep}` : 'none',
              display: 'flex', alignItems: 'center', justifyContent: 'space-between',
              fontFamily: CF.display, fontSize: 14, color: CC.ink, letterSpacing: '0.04em',
            }}>
              {label}
              <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke={CC.fog} strokeWidth="2" strokeLinecap="round">
                <path d="M9 6l6 6-6 6"/>
              </svg>
            </div>
          ))}
        </div>
      </div>

      {/* 登出 */}
      <div style={{ padding: '24px 20px 0' }}>
        <button style={{
          width: '100%', padding: '14px', borderRadius: 14, border: `1px solid ${CC.primary}40`,
          background: 'transparent', color: CC.primary,
          fontFamily: CF.display, fontSize: 14, fontWeight: 600, letterSpacing: '0.1em',
          display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8,
        }}>
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke={CC.primary} strokeWidth="2" strokeLinecap="round">
            <path d="M16 17l5-5-5-5M21 12H9M9 21H5a2 2 0 01-2-2V5a2 2 0 012-2h4"/>
          </svg>
          登出
        </button>
        <div style={{
          textAlign: 'center', marginTop: 14,
          fontFamily: CF.mono, fontSize: 10, color: CC.fog, letterSpacing: '0.15em',
        }}>v1.0.0 · MHUWAY SU</div>
      </div>
    </div>
  );
}

Object.assign(window, { CultureScreen, CommunityScreen, MapScreen, VideoWaitingScreen, VideoCallScreen, PlazaScreen, ComposeScreen, EventsScreen, ComposeEventScreen, ProfileScreen });
