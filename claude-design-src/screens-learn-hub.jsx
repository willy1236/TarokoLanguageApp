// 螢幕: 族語學習中心（日常學習 vs 考試準備）+ 歷屆試題

const { TRUKU_COLORS: HC, TRUKU_FONTS: HF } = window;

function LearnHubScreen() {
  return (
    <div style={{
      width: '100%', minHeight: '100%',
      background: HC.creamLight, fontFamily: HF.body,
      paddingBottom: 100, position: 'relative',
    }}>
      {/* hero */}
      <div style={{
        background: HC.primary, color: HC.creamLight,
        padding: '60px 24px 28px', position: 'relative', overflow: 'hidden',
      }}>
        <div style={{ position: 'absolute', inset: 0, opacity: 0.18 }}>
          <window.TrukuWeaveBg color={HC.gold} bg="transparent" opacity={1} scale={0.7} />
        </div>
        <div style={{ position: 'relative' }}>
          <div style={{
            fontFamily: HF.truku, fontStyle: 'italic', fontSize: 12,
            color: HC.gold, letterSpacing: '0.25em', marginBottom: 6,
          }}>KARI TRUKU · 族語學習</div>
          <div style={{
            fontFamily: HF.display, fontSize: 26, fontWeight: 600,
            letterSpacing: '0.04em', marginBottom: 6, lineHeight: 1.3,
          }}>選擇你今天的學習</div>
          <div style={{ fontSize: 12, opacity: 0.8, letterSpacing: '0.05em' }}>
            一句一句，把話說回來
          </div>
        </div>
      </div>

      {/* 兩個模式卡 */}
      <div style={{ padding: '20px 20px 0', display: 'flex', flexDirection: 'column', gap: 14 }}>
        {/* 日常學習 */}
        <div style={{
          background: HC.ink, color: HC.creamLight,
          borderRadius: 22, padding: '20px 22px',
          position: 'relative', overflow: 'hidden',
        }}>
          <div style={{ position: 'absolute', inset: 0, opacity: 0.12 }}>
            <window.TrukuWeaveBg color={HC.gold} bg="transparent" opacity={1} scale={0.6} />
          </div>
          <div style={{ position: 'absolute', right: -16, top: -16, opacity: 0.45 }}>
            <window.TrukuDiamond size={130} color={HC.gold} stroke={1.2}/>
          </div>
          <div style={{ position: 'relative' }}>
            <div style={{
              display: 'inline-flex', padding: '4px 10px', borderRadius: 4,
              background: 'rgba(201, 169, 97, 0.15)', border: `0.5px solid ${HC.gold}50`,
              fontFamily: HF.truku, fontStyle: 'italic', fontSize: 10,
              color: HC.gold, letterSpacing: '0.2em', marginBottom: 14,
            }}>SLHAYAN · 日常學習</div>

            <div style={{
              fontFamily: HF.display, fontSize: 24, fontWeight: 600,
              letterSpacing: '0.05em', marginBottom: 6,
            }}>日常學習</div>
            <div style={{ fontSize: 12, opacity: 0.75, lineHeight: 1.6, marginBottom: 16, letterSpacing: '0.04em' }}>
              從問候開始，一天一句<br/>單字卡跟讀 · 答題挑戰
            </div>

            {/* 進度條 */}
            <div style={{ marginBottom: 16 }}>
              <div style={{
                display: 'flex', justifyContent: 'space-between',
                fontSize: 10, color: HC.gold, marginBottom: 4, letterSpacing: '0.08em',
              }}>
                <span>本週進度</span>
                <span>26 / 90 句</span>
              </div>
              <div style={{ height: 5, background: 'rgba(255,255,255,0.12)', borderRadius: 3, overflow: 'hidden' }}>
                <div style={{ width: '29%', height: '100%', background: HC.gold }} />
              </div>
            </div>

            <button style={{
              padding: '11px 22px', borderRadius: 24, border: 'none',
              background: HC.gold, color: HC.ink,
              fontFamily: HF.display, fontSize: 13, fontWeight: 600, letterSpacing: '0.15em',
              display: 'inline-flex', alignItems: 'center', gap: 8,
            }}>
              <svg width="13" height="13" viewBox="0 0 24 24" fill={HC.ink}><path d="M5 3l14 9-14 9z"/></svg>
              繼續學習
            </button>
          </div>
        </div>

        {/* 考試準備 */}
        <div style={{
          background: HC.cream, color: HC.ink,
          borderRadius: 22, padding: '20px 22px',
          position: 'relative', overflow: 'hidden',
          border: `1px solid ${HC.creamDeep}`,
        }}>
          <div style={{ position: 'absolute', right: -16, top: -16, opacity: 0.18 }}>
            <window.TrukuDiamond size={130} color={HC.primary} stroke={1.5}/>
          </div>
          <div style={{ position: 'relative' }}>
            <div style={{
              display: 'inline-flex', padding: '4px 10px', borderRadius: 4,
              background: HC.primary + '15',
              fontFamily: HF.truku, fontStyle: 'italic', fontSize: 10,
              color: HC.primary, letterSpacing: '0.2em', marginBottom: 14,
            }}>SMRMUN · 考試準備</div>

            <div style={{
              fontFamily: HF.display, fontSize: 24, fontWeight: 600,
              color: HC.ink, letterSpacing: '0.05em', marginBottom: 6,
            }}>考試準備</div>
            <div style={{ fontSize: 12, color: HC.inkSoft, opacity: 0.75, lineHeight: 1.6, marginBottom: 16, letterSpacing: '0.04em' }}>
              族語認證歷屆試題<br/>初級 · 中級 · 中高級 · 高級
            </div>

            {/* stats */}
            <div style={{
              display: 'flex', gap: 14, marginBottom: 16,
              padding: '10px 12px', borderRadius: 10,
              background: HC.creamLight, border: `1px solid ${HC.creamDeep}`,
            }}>
              <div>
                <div style={{ fontFamily: HF.display, fontSize: 16, fontWeight: 700, color: HC.primary }}>12</div>
                <div style={{ fontSize: 9, color: HC.fog, letterSpacing: '0.1em' }}>套試題</div>
              </div>
              <div style={{ width: 1, background: HC.creamDeep }} />
              <div>
                <div style={{ fontFamily: HF.display, fontSize: 16, fontWeight: 700, color: HC.primary }}>248</div>
                <div style={{ fontSize: 9, color: HC.fog, letterSpacing: '0.1em' }}>已答對</div>
              </div>
              <div style={{ width: 1, background: HC.creamDeep }} />
              <div>
                <div style={{ fontFamily: HF.display, fontSize: 16, fontWeight: 700, color: HC.primary }}>76%</div>
                <div style={{ fontSize: 9, color: HC.fog, letterSpacing: '0.1em' }}>正確率</div>
              </div>
            </div>

            <button style={{
              padding: '11px 22px', borderRadius: 24, border: 'none',
              background: HC.primary, color: HC.creamLight,
              fontFamily: HF.display, fontSize: 13, fontWeight: 600, letterSpacing: '0.15em',
              display: 'inline-flex', alignItems: 'center', gap: 8,
            }}>
              <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke={HC.creamLight} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                <path d="M5 5h10l4 4v10H5z"/>
                <path d="M9 11h6M9 14h4"/>
              </svg>
              開始練習
            </button>
          </div>
        </div>
      </div>

      <window.BottomTab active="learn" />
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// 歷屆試題列表
// ─────────────────────────────────────────────────────────────
function ExamPrepScreen() {
  const levels = [
    { code: '初級', truku: 'PRINAH', desc: '基礎詞彙與問候', sets: 4, done: 3, color: '#5BC97D' },
    { code: '中級', truku: 'KRANA', desc: '日常會話與短文', sets: 4, done: 2, color: HC.gold, current: true },
    { code: '中高級', truku: 'BAGA', desc: '族語短文與閱讀', sets: 2, done: 0, color: HC.primary },
    { code: '高級', truku: 'MQRAS', desc: '族語論述與文化', sets: 2, done: 0, color: HC.ink, locked: true },
  ];
  const recent = [
    { year: '113 年', code: '中級', score: 82, total: 100, date: '5/10', pass: true },
    { year: '112 年', code: '中級', score: 68, total: 100, date: '5/3', pass: false },
    { year: '113 年', code: '初級', score: 95, total: 100, date: '4/28', pass: true },
  ];

  return (
    <div style={{
      width: '100%', minHeight: '100%',
      background: HC.creamLight, fontFamily: HF.body,
      paddingBottom: 100, position: 'relative',
    }}>
      {/* 頂部 nav */}
      <div style={{ padding: '60px 16px 0', display: 'flex', alignItems: 'center', gap: 10 }}>
        <button style={{
          width: 36, height: 36, borderRadius: 18, border: 'none',
          background: HC.cream,
          display: 'flex', alignItems: 'center', justifyContent: 'center',
        }}>
          <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke={HC.ink} strokeWidth="2" strokeLinecap="round">
            <path d="M15 6l-6 6 6 6"/>
          </svg>
        </button>
        <div>
          <div style={{
            fontFamily: HF.truku, fontStyle: 'italic', fontSize: 11,
            color: HC.fog, letterSpacing: '0.2em',
          }}>SMRMUN · 考試準備</div>
          <div style={{
            fontFamily: HF.display, fontSize: 17, fontWeight: 600,
            color: HC.ink, letterSpacing: '0.04em',
          }}>歷屆試題</div>
        </div>
      </div>

      {/* 等級分區 */}
      <div style={{ padding: '20px 20px 0' }}>
        <div style={{
          fontFamily: HF.display, fontSize: 14, fontWeight: 600, color: HC.ink,
          letterSpacing: '0.08em', marginBottom: 10,
        }}>族語認證等級</div>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
          {levels.map((l, i) => (
            <div key={l.code} style={{
              background: l.current ? HC.ink : HC.cream,
              color: l.current ? HC.creamLight : HC.ink,
              borderRadius: 14, padding: '14px 16px',
              border: l.current ? 'none' : `1px solid ${HC.creamDeep}`,
              display: 'flex', alignItems: 'center', gap: 14,
              opacity: l.locked ? 0.5 : 1, position: 'relative', overflow: 'hidden',
            }}>
              {/* 等級徽章 */}
              <div style={{
                width: 50, height: 50, flexShrink: 0, position: 'relative',
                display: 'flex', alignItems: 'center', justifyContent: 'center',
              }}>
                <window.TrukuDiamond size={50} color={l.color} filled stroke={1.5}/>
                <div style={{
                  position: 'absolute', fontFamily: HF.display, fontSize: 13, fontWeight: 700,
                  color: l.color === HC.gold ? HC.ink : HC.creamLight,
                }}>{l.code[0]}</div>
              </div>

              <div style={{ flex: 1 }}>
                <div style={{ display: 'flex', alignItems: 'baseline', gap: 6, marginBottom: 2 }}>
                  <div style={{
                    fontFamily: HF.display, fontSize: 16, fontWeight: 600, letterSpacing: '0.04em',
                  }}>{l.code}</div>
                  <div style={{
                    fontFamily: HF.truku, fontStyle: 'italic', fontSize: 10,
                    color: l.current ? HC.gold : HC.fog, letterSpacing: '0.15em',
                  }}>{l.truku}</div>
                </div>
                <div style={{
                  fontSize: 11, opacity: l.current ? 0.75 : 1, color: l.current ? HC.creamLight : HC.fog,
                  letterSpacing: '0.05em', marginBottom: 6,
                }}>{l.desc}</div>
                {/* 進度 */}
                {!l.locked && (
                  <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                    <div style={{
                      flex: 1, height: 4, borderRadius: 2,
                      background: l.current ? 'rgba(255,255,255,0.15)' : HC.creamDeep,
                      overflow: 'hidden',
                    }}>
                      <div style={{
                        width: `${l.done / l.sets * 100}%`, height: '100%',
                        background: l.current ? HC.gold : HC.primary,
                      }} />
                    </div>
                    <div style={{
                      fontSize: 10, opacity: 0.8, letterSpacing: '0.05em',
                    }}>{l.done}/{l.sets}</div>
                  </div>
                )}
                {l.locked && (
                  <div style={{ fontSize: 10, color: HC.fog, letterSpacing: '0.08em' }}>
                    完成中級解鎖
                  </div>
                )}
              </div>

              {/* arrow */}
              {l.locked ? (
                <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke={HC.fog} strokeWidth="2">
                  <rect x="5" y="11" width="14" height="9" rx="1.5"/>
                  <path d="M8 11V7a4 4 0 018 0v4"/>
                </svg>
              ) : (
                <svg width="16" height="16" viewBox="0 0 24 24" fill="none"
                  stroke={l.current ? HC.gold : HC.primary} strokeWidth="2" strokeLinecap="round">
                  <path d="M9 6l6 6-6 6"/>
                </svg>
              )}
            </div>
          ))}
        </div>
      </div>

      {/* 最近練習紀錄 */}
      <div style={{ padding: '24px 20px 0' }}>
        <div style={{
          display: 'flex', alignItems: 'baseline', justifyContent: 'space-between', marginBottom: 10,
        }}>
          <div style={{ fontFamily: HF.display, fontSize: 14, fontWeight: 600, color: HC.ink, letterSpacing: '0.08em' }}>
            最近練習
          </div>
          <div style={{ fontSize: 11, color: HC.primary, letterSpacing: '0.1em' }}>查看全部 →</div>
        </div>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
          {recent.map((r, i) => (
            <div key={i} style={{
              background: HC.cream, borderRadius: 12, padding: '12px 14px',
              border: `1px solid ${HC.creamDeep}`,
              display: 'flex', alignItems: 'center', gap: 12,
            }}>
              <div style={{
                width: 44, height: 44, borderRadius: 8, flexShrink: 0,
                background: r.pass ? '#5BC97D' + '20' : '#A33' + '20',
                display: 'flex', alignItems: 'center', justifyContent: 'center',
                fontFamily: HF.display, fontSize: 16, fontWeight: 700,
                color: r.pass ? '#3F8D5C' : '#A33',
              }}>{r.score}</div>
              <div style={{ flex: 1 }}>
                <div style={{
                  fontFamily: HF.display, fontSize: 13, fontWeight: 600, color: HC.ink, letterSpacing: '0.04em',
                }}>{r.year} · {r.code}</div>
                <div style={{ fontSize: 10, color: HC.fog, letterSpacing: '0.05em', marginTop: 2 }}>
                  {r.date} 練習 · 滿分 {r.total}
                </div>
              </div>
              <div style={{
                padding: '3px 8px', borderRadius: 3,
                background: r.pass ? '#5BC97D' + '20' : '#A33' + '20',
                color: r.pass ? '#3F8D5C' : '#A33',
                fontSize: 10, fontWeight: 600, letterSpacing: '0.1em',
              }}>{r.pass ? '通過' : '未過'}</div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}

window.LearnHubScreen = LearnHubScreen;
window.ExamPrepScreen = ExamPrepScreen;

// ─────────────────────────────────────────────────────────────
// 題型選擇（單字 / 聽力 / 閱讀 / 綜合）
// ─────────────────────────────────────────────────────────────
function ExamTypeScreen() {
  const types = [
    {
      key: 'vocab', zh: '單字題型', truku: 'HANGAN', desc: '族語詞彙與中文對照',
      count: 48, done: 36, icon: 'word', color: HC.primary,
    },
    {
      key: 'listen', zh: '聽力題型', truku: 'PNTBARAH', desc: '聽族語發音選擇答案',
      count: 32, done: 18, icon: 'ear', color: HC.moss,
    },
    {
      key: 'read', zh: '閱讀題型', truku: 'PATAS', desc: '族語短文理解',
      count: 24, done: 10, icon: 'book', color: HC.gold,
    },
    {
      key: 'mix', zh: '綜合模擬', truku: 'SMRMUN', desc: '完整一份試卷 30 題',
      count: 4, done: 1, icon: 'paper', color: HC.ink, full: true,
    },
  ];

  return (
    <div style={{
      width: '100%', minHeight: '100%',
      background: HC.creamLight, fontFamily: HF.body,
      paddingBottom: 60, position: 'relative',
    }}>
      {/* 頂部 nav */}
      <div style={{ padding: '60px 16px 0', display: 'flex', alignItems: 'center', gap: 10 }}>
        <button style={{
          width: 36, height: 36, borderRadius: 18, border: 'none',
          background: HC.cream,
          display: 'flex', alignItems: 'center', justifyContent: 'center',
        }}>
          <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke={HC.ink} strokeWidth="2" strokeLinecap="round">
            <path d="M15 6l-6 6 6 6"/>
          </svg>
        </button>
        <div style={{ flex: 1 }}>
          <div style={{
            fontFamily: HF.truku, fontStyle: 'italic', fontSize: 11,
            color: HC.fog, letterSpacing: '0.2em',
          }}>113 年 · 中級 KRANA</div>
          <div style={{
            fontFamily: HF.display, fontSize: 17, fontWeight: 600,
            color: HC.ink, letterSpacing: '0.04em',
          }}>選擇題型</div>
        </div>
        <div style={{
          padding: '4px 10px', borderRadius: 12,
          background: HC.gold + '25', border: `0.5px solid ${HC.gold}80`,
          fontFamily: HF.display, fontSize: 12, fontWeight: 600,
          color: HC.goldDeep, letterSpacing: '0.08em',
        }}>76%</div>
      </div>

      {/* 整體進度 */}
      <div style={{ padding: '20px 20px 0' }}>
        <div style={{
          background: HC.ink, color: HC.creamLight, borderRadius: 16,
          padding: '14px 16px', position: 'relative', overflow: 'hidden',
        }}>
          <div style={{ position: 'absolute', inset: 0, opacity: 0.12 }}>
            <window.TrukuWeaveBg color={HC.gold} bg="transparent" opacity={1} scale={0.5} />
          </div>
          <div style={{ position: 'relative', display: 'flex', alignItems: 'center', gap: 14 }}>
            <div style={{
              width: 54, height: 54, flexShrink: 0,
              display: 'flex', alignItems: 'center', justifyContent: 'center', position: 'relative',
            }}>
              <window.TrukuDiamond size={54} color={HC.gold} stroke={1.5}/>
              <div style={{
                position: 'absolute', fontFamily: HF.display, fontSize: 14, fontWeight: 700,
                color: HC.gold,
              }}>65</div>
            </div>
            <div style={{ flex: 1 }}>
              <div style={{
                fontFamily: HF.display, fontSize: 14, fontWeight: 600, letterSpacing: '0.04em',
              }}>已完成 65 / 108 題</div>
              <div style={{ fontSize: 10, color: HC.gold, opacity: 0.85, letterSpacing: '0.08em', marginTop: 2 }}>
                繼續加油 · 還剩 43 題
              </div>
            </div>
          </div>
        </div>
      </div>

      {/* 題型列表 */}
      <div style={{ padding: '20px 20px 0' }}>
        <div style={{
          fontFamily: HF.truku, fontStyle: 'italic', fontSize: 10,
          color: HC.fog, letterSpacing: '0.2em', marginBottom: 10,
        }}>SMRMUN BAGA · 題型分類</div>

        <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
          {types.filter(t => !t.full).map((t) => (
            <ExamTypeCard key={t.key} type={t} />
          ))}
        </div>

        {/* 綜合模擬 — 特別處理 */}
        <div style={{ marginTop: 14 }}>
          <ExamTypeCard type={types.find(t => t.full)} fullWidth />
        </div>
      </div>
    </div>
  );
}

function ExamTypeCard({ type, fullWidth }) {
  const pct = type.done / type.count;
  const isDark = type.full;
  return (
    <div style={{
      background: isDark ? HC.ink : HC.cream,
      color: isDark ? HC.creamLight : HC.ink,
      borderRadius: 16, padding: '14px 16px',
      border: isDark ? `1px solid ${HC.gold}40` : `1px solid ${HC.creamDeep}`,
      display: 'flex', alignItems: 'center', gap: 14,
      position: 'relative', overflow: 'hidden',
    }}>
      {isDark && (
        <div style={{ position: 'absolute', inset: 0, opacity: 0.1 }}>
          <window.TrukuWeaveBg color={HC.gold} bg="transparent" opacity={1} scale={0.5} />
        </div>
      )}
      {/* 圖示 */}
      <div style={{
        width: 50, height: 50, flexShrink: 0, position: 'relative',
        borderRadius: 14,
        background: isDark ? 'rgba(201,169,97,0.15)' : type.color + '15',
        display: 'flex', alignItems: 'center', justifyContent: 'center',
      }}>
        <ExamIcon name={type.icon} color={isDark ? HC.gold : type.color} />
      </div>
      <div style={{ flex: 1, position: 'relative' }}>
        <div style={{ display: 'flex', alignItems: 'baseline', gap: 6, marginBottom: 2 }}>
          <div style={{
            fontFamily: HF.display, fontSize: 16, fontWeight: 600, letterSpacing: '0.04em',
          }}>{type.zh}</div>
          <div style={{
            fontFamily: HF.truku, fontStyle: 'italic', fontSize: 10,
            color: isDark ? HC.gold : HC.fog, letterSpacing: '0.15em',
          }}>{type.truku}</div>
        </div>
        <div style={{
          fontSize: 11, color: isDark ? HC.creamLight : HC.fog,
          opacity: isDark ? 0.7 : 1, letterSpacing: '0.05em', marginBottom: 6,
        }}>{type.desc}</div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
          <div style={{
            flex: 1, height: 4, borderRadius: 2,
            background: isDark ? 'rgba(255,255,255,0.12)' : HC.creamDeep, overflow: 'hidden',
          }}>
            <div style={{
              width: `${pct * 100}%`, height: '100%',
              background: isDark ? HC.gold : type.color,
            }} />
          </div>
          <div style={{
            fontSize: 10, opacity: isDark ? 0.85 : 0.7, letterSpacing: '0.05em',
            color: isDark ? HC.creamLight : HC.inkSoft,
          }}>{type.done}/{type.count}</div>
        </div>
      </div>
      {/* arrow */}
      <svg width="16" height="16" viewBox="0 0 24 24" fill="none"
        stroke={isDark ? HC.gold : type.color} strokeWidth="2" strokeLinecap="round">
        <path d="M9 6l6 6-6 6"/>
      </svg>
    </div>
  );
}

function ExamIcon({ name, color }) {
  const p = { width: 22, height: 22, viewBox: '0 0 24 24', fill: 'none', stroke: color, strokeWidth: 1.8, strokeLinecap: 'round', strokeLinejoin: 'round' };
  if (name === 'word') return <svg {...p}><path d="M4 5h16M4 12h16M4 19h10"/><circle cx="20" cy="19" r="2" fill={color}/></svg>;
  if (name === 'ear') return <svg {...p}><path d="M6 9a6 6 0 0112 0c0 3-2 4-2 6a3 3 0 01-6 0"/><path d="M9 13l-3 1"/></svg>;
  if (name === 'book') return <svg {...p}><path d="M4 5h7v15H4z M13 5h7v15h-7z"/><path d="M4 9h7M13 9h7"/></svg>;
  if (name === 'paper') return <svg {...p}><path d="M6 3h10l4 4v14H6z"/><path d="M10 11h7M10 15h5M10 7h2"/></svg>;
  return null;
}

window.ExamTypeScreen = ExamTypeScreen;
