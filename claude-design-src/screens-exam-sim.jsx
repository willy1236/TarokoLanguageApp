// 螢幕: 考試模擬（正式測驗模式）

const { TRUKU_COLORS: EC, TRUKU_FONTS: EF } = window;

function ExamSimScreen() {
  // 答題狀態：done = 已答, current = 當前, marked = 標記, blank = 未答
  const palette = [
    'done','done','done','marked','done','done','done','done','done','done',
    'done','current','blank','blank','marked','blank','blank','blank','blank','blank',
    'blank','blank','blank','blank','blank','blank','blank','blank','blank','blank',
  ];

  return (
    <div style={{
      width: '100%', minHeight: '100%',
      background: EC.creamLight, fontFamily: EF.body,
      position: 'relative', paddingBottom: 80,
    }}>
      {/* 頂部 — 計時 + 題號 + 退出 */}
      <div style={{
        background: EC.ink, color: EC.creamLight,
        padding: '54px 16px 14px', position: 'relative', overflow: 'hidden',
      }}>
        <div style={{ position: 'absolute', inset: 0, opacity: 0.08 }}>
          <window.TrukuWeaveBg color={EC.gold} bg="transparent" opacity={1} scale={0.5} />
        </div>
        <div style={{ position: 'relative', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
          {/* 暫停 */}
          <button style={{
            width: 36, height: 36, borderRadius: 18, border: 'none',
            background: 'rgba(250,245,234,0.12)', color: EC.creamLight,
            display: 'flex', alignItems: 'center', justifyContent: 'center',
          }}>
            <svg width="14" height="14" viewBox="0 0 24 24" fill={EC.creamLight}>
              <rect x="7" y="5" width="4" height="14" rx="1"/>
              <rect x="13" y="5" width="4" height="14" rx="1"/>
            </svg>
          </button>

          {/* 中央：計時 */}
          <div style={{ textAlign: 'center' }}>
            <div style={{
              fontFamily: EF.truku, fontStyle: 'italic', fontSize: 10,
              color: EC.gold, letterSpacing: '0.25em', marginBottom: 2,
            }}>SMRMUN · 模擬考</div>
            <div style={{
              display: 'flex', alignItems: 'center', gap: 6, justifyContent: 'center',
            }}>
              <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke={EC.gold} strokeWidth="2">
                <circle cx="12" cy="13" r="8"/>
                <path d="M12 9v4l2.5 2M9 2h6"/>
              </svg>
              <div style={{
                fontFamily: EF.mono, fontSize: 18, fontWeight: 600,
                color: EC.gold, letterSpacing: '0.08em',
              }}>28:42</div>
            </div>
          </div>

          {/* 題號 */}
          <div style={{
            padding: '6px 12px', borderRadius: 14,
            background: 'rgba(201,169,97,0.18)', border: `0.5px solid ${EC.gold}50`,
            fontSize: 12, color: EC.gold, letterSpacing: '0.08em',
          }}>12 / 30</div>
        </div>

        {/* 進度條 */}
        <div style={{
          position: 'relative', marginTop: 14, height: 4,
          background: 'rgba(255,255,255,0.1)', borderRadius: 2, overflow: 'hidden',
        }}>
          <div style={{ width: '40%', height: '100%', background: EC.gold }} />
        </div>
      </div>

      {/* 題型徽章 */}
      <div style={{ padding: '16px 20px 0', display: 'flex', alignItems: 'center', gap: 8 }}>
        <div style={{
          padding: '4px 10px', borderRadius: 4,
          background: EC.moss + '20', border: `0.5px solid ${EC.moss}`,
          fontFamily: EF.truku, fontStyle: 'italic', fontSize: 10,
          color: EC.moss, letterSpacing: '0.2em',
        }}>PNTBARAH · 聽力</div>
        <div style={{
          padding: '4px 10px', borderRadius: 4,
          background: EC.primary + '15',
          fontSize: 10, color: EC.primary, letterSpacing: '0.1em',
        }}>2 分</div>
        <div style={{ flex: 1 }} />
        <button
          style={{
            display: 'flex', alignItems: 'center', gap: 4,
            padding: '5px 10px', borderRadius: 12,
            border: `1px solid ${EC.creamDeep}`, background: 'transparent',
            color: EC.inkSoft, fontSize: 11, letterSpacing: '0.08em',
          }}>
          <svg width="11" height="11" viewBox="0 0 24 24" fill="none" stroke={EC.inkSoft} strokeWidth="2"><path d="M5 5l5 14 3-7 7-3z"/></svg>
          標記
        </button>
      </div>

      {/* 題目主卡 */}
      <div style={{ padding: '14px 20px 0' }}>
        <div style={{
          background: EC.cream, borderRadius: 16, padding: '18px 18px',
          border: `1px solid ${EC.creamDeep}`,
        }}>
          <div style={{
            fontFamily: EF.display, fontSize: 13, fontWeight: 600,
            color: EC.inkSoft, letterSpacing: '0.06em', marginBottom: 12, lineHeight: 1.5,
          }}>
            請聆聽以下族語，選出正確中文翻譯：
          </div>

          {/* 播放音檔卡 */}
          <div style={{
            background: EC.ink, color: EC.creamLight, borderRadius: 14,
            padding: '18px 18px', position: 'relative', overflow: 'hidden',
            display: 'flex', alignItems: 'center', gap: 14,
          }}>
            <div style={{ position: 'absolute', inset: 0, opacity: 0.08 }}>
              <window.TrukuWeaveBg color={EC.gold} bg="transparent" opacity={1} scale={0.6} />
            </div>
            {/* 播放按鈕 */}
            <div style={{
              width: 52, height: 52, borderRadius: 26, flexShrink: 0,
              background: EC.gold, position: 'relative',
              display: 'flex', alignItems: 'center', justifyContent: 'center',
            }}>
              <window.PlayIcon size={20} color={EC.ink} />
            </div>
            <div style={{ flex: 1, position: 'relative' }}>
              <div style={{
                fontFamily: EF.truku, fontStyle: 'italic', fontSize: 11,
                color: EC.gold, letterSpacing: '0.2em', marginBottom: 6,
              }}>第 12 題 · 音檔</div>
              {/* 波形 */}
              <div style={{ display: 'flex', alignItems: 'center', gap: 2, height: 24 }}>
                {[6, 14, 9, 18, 12, 22, 15, 8, 20, 10, 17, 6, 14, 18, 11, 9, 16, 7, 13, 5].map((h, i) => (
                  <div key={i} style={{
                    width: 3, height: h, borderRadius: 1.5,
                    background: i < 8 ? EC.gold : 'rgba(201,169,97,0.4)',
                  }} />
                ))}
              </div>
              <div style={{ fontSize: 10, color: EC.creamLight, opacity: 0.6, marginTop: 4, letterSpacing: '0.05em' }}>
                可重複播放 2 次
              </div>
            </div>
          </div>
        </div>
      </div>

      {/* 4 個選項 */}
      <div style={{ padding: '16px 20px 0', display: 'flex', flexDirection: 'column', gap: 8 }}>
        {[
          { letter: 'A', text: '今天天氣很好', selected: false },
          { letter: 'B', text: '謝謝你，爸爸', selected: true },
          { letter: 'C', text: '我要去山上', selected: false },
          { letter: 'D', text: '吃飯了嗎', selected: false },
        ].map(o => (
          <div key={o.letter} style={{
            background: o.selected ? EC.ink : EC.cream,
            color: o.selected ? EC.creamLight : EC.ink,
            borderRadius: 12, padding: '12px 14px',
            border: o.selected ? `1.5px solid ${EC.gold}` : `1.5px solid ${EC.creamDeep}`,
            display: 'flex', alignItems: 'center', gap: 12,
          }}>
            <div style={{
              width: 30, height: 30, borderRadius: 15, flexShrink: 0,
              background: o.selected ? EC.gold : 'transparent',
              border: o.selected ? 'none' : `1.5px solid ${EC.fog}`,
              display: 'flex', alignItems: 'center', justifyContent: 'center',
              fontFamily: EF.display, fontSize: 13, fontWeight: 700,
              color: o.selected ? EC.ink : EC.fog,
            }}>{o.letter}</div>
            <div style={{
              flex: 1, fontSize: 14, letterSpacing: '0.04em',
              fontWeight: o.selected ? 500 : 400,
            }}>{o.text}</div>
            {o.selected && (
              <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke={EC.gold} strokeWidth="3" strokeLinecap="round" strokeLinejoin="round">
                <path d="M5 12l5 5L20 7"/>
              </svg>
            )}
          </div>
        ))}
      </div>

      {/* 答題卡 (palette) */}
      <div style={{ padding: '22px 20px 0' }}>
        <div style={{
          display: 'flex', alignItems: 'baseline', justifyContent: 'space-between', marginBottom: 10,
        }}>
          <div style={{
            fontFamily: EF.truku, fontStyle: 'italic', fontSize: 10,
            color: EC.fog, letterSpacing: '0.2em',
          }}>HANGAN · 答題卡</div>
          <div style={{ display: 'flex', gap: 10, fontSize: 10, color: EC.fog, letterSpacing: '0.05em' }}>
            <span style={{ display: 'inline-flex', alignItems: 'center', gap: 4 }}>
              <span style={{ width: 8, height: 8, borderRadius: 2, background: EC.primary }}></span>已答
            </span>
            <span style={{ display: 'inline-flex', alignItems: 'center', gap: 4 }}>
              <span style={{ width: 8, height: 8, borderRadius: 2, background: EC.gold }}></span>標記
            </span>
            <span style={{ display: 'inline-flex', alignItems: 'center', gap: 4 }}>
              <span style={{ width: 8, height: 8, borderRadius: 2, border: `1px solid ${EC.fog}` }}></span>未答
            </span>
          </div>
        </div>
        <div style={{
          background: EC.cream, borderRadius: 12, padding: '12px',
          border: `1px solid ${EC.creamDeep}`,
          display: 'grid', gridTemplateColumns: 'repeat(10, 1fr)', gap: 6,
        }}>
          {palette.map((s, i) => (
            <div key={i} style={{
              aspectRatio: '1', borderRadius: 6,
              background: s === 'done' ? EC.primary
                : s === 'current' ? EC.ink
                : s === 'marked' ? EC.gold
                : 'transparent',
              border: s === 'blank' ? `1px solid ${EC.creamDeep}` :
                s === 'current' ? `2px solid ${EC.gold}` : 'none',
              color: s === 'blank' ? EC.fog : (s === 'marked' ? EC.ink : EC.creamLight),
              fontFamily: EF.display, fontSize: 11, fontWeight: 600,
              display: 'flex', alignItems: 'center', justifyContent: 'center',
              letterSpacing: '0.02em',
            }}>{i + 1}</div>
          ))}
        </div>
      </div>

      {/* 底部操作列 */}
      <div style={{
        position: 'absolute', bottom: 0, left: 0, right: 0,
        background: EC.creamLight, borderTop: `1px solid ${EC.creamDeep}`,
        padding: '12px 16px 24px',
        display: 'flex', gap: 8,
      }}>
        <button style={{
          flex: 1, padding: '13px', borderRadius: 12, border: `1.5px solid ${EC.creamDeep}`,
          background: EC.cream, color: EC.inkSoft,
          fontFamily: EF.display, fontSize: 14, fontWeight: 500, letterSpacing: '0.1em',
          display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 6,
        }}>
          <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke={EC.inkSoft} strokeWidth="2" strokeLinecap="round">
            <path d="M15 6l-6 6 6 6"/>
          </svg>
          上一題
        </button>
        <button style={{
          flex: 1.4, padding: '13px', borderRadius: 12, border: 'none',
          background: EC.primary, color: EC.creamLight,
          fontFamily: EF.display, fontSize: 14, fontWeight: 600, letterSpacing: '0.15em',
          display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 6,
        }}>
          下一題
          <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke={EC.creamLight} strokeWidth="2" strokeLinecap="round">
            <path d="M9 6l6 6-6 6"/>
          </svg>
        </button>
      </div>
    </div>
  );
}

window.ExamSimScreen = ExamSimScreen;

// ─────────────────────────────────────────────────────────────
// 圖片選擇題型
// ─────────────────────────────────────────────────────────────
function ExamSimImageScreen() {
  const palette = [
    'done','done','done','marked','done','done','done','done','done','done',
    'done','done','done','current','marked','blank','blank','blank','blank','blank',
    'blank','blank','blank','blank','blank','blank','blank','blank','blank','blank',
  ];

  const options = [
    { letter: 'A', label: '織布', truku: 'tminun', emoji: '🧵', bg: EC.primary, selected: false },
    { letter: 'B', label: '苧麻', truku: 'krig', emoji: '🌿', bg: EC.moss, selected: true },
    { letter: 'C', label: '山林', truku: 'dgiyaq', emoji: '⛰️', bg: EC.primaryDeep, selected: false },
    { letter: 'D', label: '溪流', truku: 'yayung', emoji: '💧', bg: EC.mossDeep, selected: false },
  ];

  return (
    <div style={{
      width: '100%', minHeight: '100%',
      background: EC.creamLight, fontFamily: EF.body,
      position: 'relative', paddingBottom: 80,
    }}>
      {/* 頂部 — 計時 + 題號 */}
      <div style={{
        background: EC.ink, color: EC.creamLight,
        padding: '54px 16px 14px', position: 'relative', overflow: 'hidden',
      }}>
        <div style={{ position: 'absolute', inset: 0, opacity: 0.08 }}>
          <window.TrukuWeaveBg color={EC.gold} bg="transparent" opacity={1} scale={0.5} />
        </div>
        <div style={{ position: 'relative', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
          <button style={{
            width: 36, height: 36, borderRadius: 18, border: 'none',
            background: 'rgba(250,245,234,0.12)', color: EC.creamLight,
            display: 'flex', alignItems: 'center', justifyContent: 'center',
          }}>
            <svg width="14" height="14" viewBox="0 0 24 24" fill={EC.creamLight}>
              <rect x="7" y="5" width="4" height="14" rx="1"/>
              <rect x="13" y="5" width="4" height="14" rx="1"/>
            </svg>
          </button>
          <div style={{ textAlign: 'center' }}>
            <div style={{
              fontFamily: EF.truku, fontStyle: 'italic', fontSize: 10,
              color: EC.gold, letterSpacing: '0.25em', marginBottom: 2,
            }}>SMRMUN · 模擬考</div>
            <div style={{ display: 'flex', alignItems: 'center', gap: 6, justifyContent: 'center' }}>
              <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke={EC.gold} strokeWidth="2">
                <circle cx="12" cy="13" r="8"/>
                <path d="M12 9v4l2.5 2M9 2h6"/>
              </svg>
              <div style={{
                fontFamily: EF.mono, fontSize: 18, fontWeight: 600,
                color: EC.gold, letterSpacing: '0.08em',
              }}>26:18</div>
            </div>
          </div>
          <div style={{
            padding: '6px 12px', borderRadius: 14,
            background: 'rgba(201,169,97,0.18)', border: `0.5px solid ${EC.gold}50`,
            fontSize: 12, color: EC.gold, letterSpacing: '0.08em',
          }}>14 / 30</div>
        </div>
        <div style={{
          position: 'relative', marginTop: 14, height: 4,
          background: 'rgba(255,255,255,0.1)', borderRadius: 2, overflow: 'hidden',
        }}>
          <div style={{ width: '47%', height: '100%', background: EC.gold }} />
        </div>
      </div>

      {/* 題型徽章 */}
      <div style={{ padding: '16px 20px 0', display: 'flex', alignItems: 'center', gap: 8 }}>
        <div style={{
          padding: '4px 10px', borderRadius: 4,
          background: EC.gold + '20', border: `0.5px solid ${EC.gold}`,
          fontFamily: EF.truku, fontStyle: 'italic', fontSize: 10,
          color: EC.goldDeep, letterSpacing: '0.2em',
        }}>PNQITA · 看圖辨識</div>
        <div style={{
          padding: '4px 10px', borderRadius: 4,
          background: EC.primary + '15',
          fontSize: 10, color: EC.primary, letterSpacing: '0.1em',
        }}>3 分</div>
        <div style={{ flex: 1 }} />
        <button style={{
          display: 'flex', alignItems: 'center', gap: 4,
          padding: '5px 10px', borderRadius: 12,
          border: `1px solid ${EC.creamDeep}`, background: 'transparent',
          color: EC.inkSoft, fontSize: 11, letterSpacing: '0.08em',
        }}>
          <svg width="11" height="11" viewBox="0 0 24 24" fill="none" stroke={EC.inkSoft} strokeWidth="2"><path d="M5 5l5 14 3-7 7-3z"/></svg>
          標記
        </button>
      </div>

      {/* 題目 */}
      <div style={{ padding: '14px 20px 0' }}>
        <div style={{
          background: EC.cream, borderRadius: 16, padding: '18px',
          border: `1px solid ${EC.creamDeep}`,
        }}>
          <div style={{
            fontFamily: EF.display, fontSize: 13, fontWeight: 500,
            color: EC.inkSoft, letterSpacing: '0.04em', marginBottom: 10, lineHeight: 1.5,
          }}>
            下列哪一張圖片是族語「
            <span style={{
              fontFamily: EF.truku, fontStyle: 'italic', fontSize: 22, fontWeight: 600,
              color: EC.primary, padding: '0 2px',
            }}>krig</span>
            」的意思？
          </div>
          <div style={{
            display: 'flex', alignItems: 'center', gap: 8,
            padding: '8px 12px', borderRadius: 10,
            background: EC.ink, color: EC.gold,
          }}>
            <window.SpeakerIcon size={14} color={EC.gold}/>
            <span style={{ fontSize: 11, letterSpacing: '0.1em' }}>點擊聽發音</span>
          </div>
        </div>
      </div>

      {/* 4 張圖選項 */}
      <div style={{ padding: '14px 20px 0', display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10 }}>
        {options.map(o => (
          <div key={o.letter} style={{
            position: 'relative', overflow: 'hidden',
            borderRadius: 14,
            border: o.selected ? `2.5px solid ${EC.gold}` : `1.5px solid ${EC.creamDeep}`,
            boxShadow: o.selected ? `0 0 0 3px ${EC.gold}25` : 'none',
          }}>
            {/* 圖片區（占位） */}
            <div style={{
              height: 130, position: 'relative', overflow: 'hidden',
              background: `linear-gradient(135deg, ${o.bg}, ${o.bg}DD)`,
              display: 'flex', alignItems: 'center', justifyContent: 'center',
            }}>
              <div style={{ position: 'absolute', inset: 0, opacity: 0.18 }}>
                <window.TrukuWeaveBg color={EC.gold} bg="transparent" opacity={1} scale={0.5} />
              </div>
              {/* 字母標 */}
              <div style={{
                position: 'absolute', top: 8, left: 8,
                width: 26, height: 26, borderRadius: 13,
                background: o.selected ? EC.gold : 'rgba(28,15,13,0.65)',
                color: o.selected ? EC.ink : EC.creamLight,
                fontFamily: EF.display, fontSize: 12, fontWeight: 700,
                display: 'flex', alignItems: 'center', justifyContent: 'center',
                backdropFilter: 'blur(4px)',
              }}>{o.letter}</div>
              {/* 圖片佔位（emoji 表意） */}
              <div style={{
                fontSize: 52, lineHeight: 1, position: 'relative',
                filter: 'drop-shadow(0 4px 12px rgba(0,0,0,0.4))',
              }}>{o.emoji}</div>
              {o.selected && (
                <div style={{
                  position: 'absolute', top: 8, right: 8,
                  width: 26, height: 26, borderRadius: 13,
                  background: EC.gold,
                  display: 'flex', alignItems: 'center', justifyContent: 'center',
                }}>
                  <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke={EC.ink} strokeWidth="3" strokeLinecap="round" strokeLinejoin="round">
                    <path d="M5 12l5 5L20 7"/>
                  </svg>
                </div>
              )}
            </div>
            {/* 圖說 */}
            <div style={{
              padding: '8px 12px',
              background: o.selected ? EC.ink : EC.cream,
              color: o.selected ? EC.creamLight : EC.ink,
            }}>
              <div style={{
                fontFamily: EF.display, fontSize: 13, fontWeight: 600, letterSpacing: '0.04em',
              }}>{o.label}</div>
              <div style={{
                fontFamily: EF.truku, fontStyle: 'italic', fontSize: 10,
                color: o.selected ? EC.gold : EC.fog, letterSpacing: '0.1em', marginTop: 1,
              }}>{o.truku}</div>
            </div>
          </div>
        ))}
      </div>

      {/* 答題卡 */}
      <div style={{ padding: '20px 20px 0' }}>
        <div style={{
          display: 'flex', alignItems: 'baseline', justifyContent: 'space-between', marginBottom: 10,
        }}>
          <div style={{
            fontFamily: EF.truku, fontStyle: 'italic', fontSize: 10,
            color: EC.fog, letterSpacing: '0.2em',
          }}>HANGAN · 答題卡</div>
          <div style={{ display: 'flex', gap: 10, fontSize: 10, color: EC.fog, letterSpacing: '0.05em' }}>
            <span style={{ display: 'inline-flex', alignItems: 'center', gap: 4 }}>
              <span style={{ width: 8, height: 8, borderRadius: 2, background: EC.primary }}></span>已答
            </span>
            <span style={{ display: 'inline-flex', alignItems: 'center', gap: 4 }}>
              <span style={{ width: 8, height: 8, borderRadius: 2, background: EC.gold }}></span>標記
            </span>
            <span style={{ display: 'inline-flex', alignItems: 'center', gap: 4 }}>
              <span style={{ width: 8, height: 8, borderRadius: 2, border: `1px solid ${EC.fog}` }}></span>未答
            </span>
          </div>
        </div>
        <div style={{
          background: EC.cream, borderRadius: 12, padding: '12px',
          border: `1px solid ${EC.creamDeep}`,
          display: 'grid', gridTemplateColumns: 'repeat(10, 1fr)', gap: 6,
        }}>
          {palette.map((s, i) => (
            <div key={i} style={{
              aspectRatio: '1', borderRadius: 6,
              background: s === 'done' ? EC.primary
                : s === 'current' ? EC.ink
                : s === 'marked' ? EC.gold
                : 'transparent',
              border: s === 'blank' ? `1px solid ${EC.creamDeep}` :
                s === 'current' ? `2px solid ${EC.gold}` : 'none',
              color: s === 'blank' ? EC.fog : (s === 'marked' ? EC.ink : EC.creamLight),
              fontFamily: EF.display, fontSize: 11, fontWeight: 600,
              display: 'flex', alignItems: 'center', justifyContent: 'center',
              letterSpacing: '0.02em',
            }}>{i + 1}</div>
          ))}
        </div>
      </div>

      {/* 底部 */}
      <div style={{
        position: 'absolute', bottom: 0, left: 0, right: 0,
        background: EC.creamLight, borderTop: `1px solid ${EC.creamDeep}`,
        padding: '12px 16px 24px',
        display: 'flex', gap: 8,
      }}>
        <button style={{
          flex: 1, padding: '13px', borderRadius: 12, border: `1.5px solid ${EC.creamDeep}`,
          background: EC.cream, color: EC.inkSoft,
          fontFamily: EF.display, fontSize: 14, fontWeight: 500, letterSpacing: '0.1em',
          display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 6,
        }}>
          <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke={EC.inkSoft} strokeWidth="2" strokeLinecap="round">
            <path d="M15 6l-6 6 6 6"/>
          </svg>
          上一題
        </button>
        <button style={{
          flex: 1.4, padding: '13px', borderRadius: 12, border: 'none',
          background: EC.primary, color: EC.creamLight,
          fontFamily: EF.display, fontSize: 14, fontWeight: 600, letterSpacing: '0.15em',
          display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 6,
        }}>
          下一題
          <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke={EC.creamLight} strokeWidth="2" strokeLinecap="round">
            <path d="M9 6l6 6-6 6"/>
          </svg>
        </button>
      </div>
    </div>
  );
}

window.ExamSimImageScreen = ExamSimImageScreen;
