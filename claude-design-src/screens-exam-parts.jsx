// 螢幕: 太魯閣語認證模擬考四部分

const { TRUKU_COLORS: XC, TRUKU_FONTS: XF } = window;

// 共用頂部（計時 + 題號 + 進度）
function ExamHeader({ part, partZh, partTruku, n, total, time, score }) {
  return (
    <>
      <div style={{
        background: XC.ink, color: XC.creamLight,
        padding: '54px 16px 14px', position: 'relative', overflow: 'hidden',
      }}>
        <div style={{ position: 'absolute', inset: 0, opacity: 0.08 }}>
          <window.TrukuWeaveBg color={XC.gold} bg="transparent" opacity={1} scale={0.5} />
        </div>
        <div style={{ position: 'relative', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
          <button style={{
            width: 36, height: 36, borderRadius: 18, border: 'none',
            background: 'rgba(250,245,234,0.12)', color: XC.creamLight,
            display: 'flex', alignItems: 'center', justifyContent: 'center',
          }}>
            <svg width="14" height="14" viewBox="0 0 24 24" fill={XC.creamLight}>
              <rect x="7" y="5" width="4" height="14" rx="1"/>
              <rect x="13" y="5" width="4" height="14" rx="1"/>
            </svg>
          </button>
          <div style={{ textAlign: 'center' }}>
            <div style={{
              fontFamily: XF.truku, fontStyle: 'italic', fontSize: 10,
              color: XC.gold, letterSpacing: '0.25em', marginBottom: 2,
            }}>{partTruku} · 第{part}部分</div>
            <div style={{ display: 'flex', alignItems: 'center', gap: 6, justifyContent: 'center' }}>
              <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke={XC.gold} strokeWidth="2">
                <circle cx="12" cy="13" r="8"/>
                <path d="M12 9v4l2.5 2M9 2h6"/>
              </svg>
              <div style={{
                fontFamily: XF.mono, fontSize: 18, fontWeight: 600,
                color: XC.gold, letterSpacing: '0.08em',
              }}>{time}</div>
            </div>
          </div>
          <div style={{
            padding: '6px 12px', borderRadius: 14,
            background: 'rgba(201,169,97,0.18)', border: `0.5px solid ${XC.gold}50`,
            fontSize: 12, color: XC.gold, letterSpacing: '0.08em',
          }}>{n} / {total}</div>
        </div>
        <div style={{
          position: 'relative', marginTop: 14, height: 4,
          background: 'rgba(255,255,255,0.1)', borderRadius: 2, overflow: 'hidden',
        }}>
          <div style={{ width: `${n/total*100}%`, height: '100%', background: XC.gold }} />
        </div>
      </div>

      {/* part label bar */}
      <div style={{
        padding: '12px 20px', display: 'flex', alignItems: 'center', gap: 8,
        background: XC.cream, borderBottom: `1px solid ${XC.creamDeep}`,
      }}>
        <div style={{
          padding: '4px 10px', borderRadius: 4,
          background: XC.primary + '15',
          fontFamily: XF.truku, fontStyle: 'italic', fontSize: 10,
          color: XC.primary, letterSpacing: '0.2em',
        }}>{partTruku}</div>
        <div style={{
          fontFamily: XF.display, fontSize: 13, fontWeight: 600,
          color: XC.ink, letterSpacing: '0.04em',
        }}>{partZh}</div>
        <div style={{ flex: 1 }} />
        <div style={{ fontSize: 11, color: XC.fog, letterSpacing: '0.05em' }}>
          每題播 2 次 · {score} 分
        </div>
      </div>
    </>
  );
}

// 共用音檔卡
function AudioCard({ playing = '播放中', plays = '第 1 次 / 共 2 次' }) {
  return (
    <div style={{
      background: XC.ink, color: XC.creamLight, borderRadius: 14,
      padding: '16px', position: 'relative', overflow: 'hidden',
      display: 'flex', alignItems: 'center', gap: 14,
    }}>
      <div style={{ position: 'absolute', inset: 0, opacity: 0.08 }}>
        <window.TrukuWeaveBg color={XC.gold} bg="transparent" opacity={1} scale={0.6} />
      </div>
      <div style={{
        width: 48, height: 48, borderRadius: 24, flexShrink: 0,
        background: XC.gold,
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        position: 'relative',
      }}>
        {/* pulse */}
        <div style={{
          position: 'absolute', inset: -4, borderRadius: '50%',
          background: XC.gold, opacity: 0.3,
          animation: 'pulse 1.5s ease-in-out infinite',
        }} />
        <window.PlayIcon size={18} color={XC.ink} />
      </div>
      <div style={{ flex: 1, position: 'relative' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 2, height: 22 }}>
          {[8, 16, 11, 20, 14, 22, 17, 9, 19, 12, 16, 7, 14, 18, 10, 8, 14, 6].map((h, i) => (
            <div key={i} style={{
              width: 3, height: h, borderRadius: 1.5,
              background: i < 9 ? XC.gold : 'rgba(201,169,97,0.35)',
            }} />
          ))}
        </div>
        <div style={{ fontSize: 10, color: XC.creamLight, opacity: 0.65, marginTop: 5, letterSpacing: '0.05em' }}>
          {playing} · {plays}
        </div>
      </div>
    </div>
  );
}

// 底部上一題/下一題
function ExamFooter() {
  return (
    <div style={{
      position: 'absolute', bottom: 0, left: 0, right: 0,
      background: XC.creamLight, borderTop: `1px solid ${XC.creamDeep}`,
      padding: '12px 16px 24px',
      display: 'flex', gap: 8,
    }}>
      <button style={{
        flex: 1, padding: '13px', borderRadius: 12, border: `1.5px solid ${XC.creamDeep}`,
        background: XC.cream, color: XC.inkSoft,
        fontFamily: XF.display, fontSize: 14, fontWeight: 500, letterSpacing: '0.1em',
        display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 6,
      }}>
        <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke={XC.inkSoft} strokeWidth="2" strokeLinecap="round"><path d="M15 6l-6 6 6 6"/></svg>
        上一題
      </button>
      <button style={{
        flex: 1.4, padding: '13px', borderRadius: 12, border: 'none',
        background: XC.primary, color: XC.creamLight,
        fontFamily: XF.display, fontSize: 14, fontWeight: 600, letterSpacing: '0.15em',
        display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 6,
      }}>
        下一題
        <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke={XC.creamLight} strokeWidth="2" strokeLinecap="round"><path d="M9 6l6 6-6 6"/></svg>
      </button>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// 第一部分：是非題（圖片 + 聽族語 → O/X）
// ─────────────────────────────────────────────────────────────
function ExamPart1() {
  return (
    <div style={{
      width: '100%', minHeight: '100%', background: XC.creamLight, fontFamily: XF.body,
      position: 'relative', paddingBottom: 80,
    }}>
      <ExamHeader part="一" partZh="是非題" partTruku="MALU INI" n={3} total={10} time="04:32" score={2}/>

      {/* 提示 */}
      <div style={{ padding: '14px 20px 0', fontSize: 12, color: XC.inkSoft, lineHeight: 1.6, letterSpacing: '0.03em' }}>
        聽完族語句子後，判斷圖片是否符合句意：
      </div>

      {/* 音檔 */}
      <div style={{ padding: '10px 20px 0' }}>
        <AudioCard />
      </div>

      {/* 圖片 */}
      <div style={{ padding: '14px 20px 0' }}>
        <div style={{
          height: 220, borderRadius: 16, position: 'relative', overflow: 'hidden',
          background: `linear-gradient(135deg, ${XC.moss}, ${XC.mossDeep})`,
          border: `1.5px solid ${XC.creamDeep}`,
          display: 'flex', alignItems: 'center', justifyContent: 'center',
        }}>
          <div style={{ position: 'absolute', inset: 0, opacity: 0.18 }}>
            <window.TrukuWeaveBg color={XC.gold} bg="transparent" opacity={1} scale={0.7} />
          </div>
          <div style={{
            position: 'absolute', top: 12, left: 12,
            padding: '4px 10px', borderRadius: 4,
            background: 'rgba(28,15,13,0.55)', backdropFilter: 'blur(6px)',
            fontSize: 10, color: XC.gold, letterSpacing: '0.15em',
          }}>第 3 題 · 題目圖片</div>
          <div style={{ fontSize: 90, lineHeight: 1, filter: 'drop-shadow(0 6px 16px rgba(0,0,0,0.45))' }}>🌿</div>
        </div>
      </div>

      {/* O X 按鈕 */}
      <div style={{ padding: '20px 20px 0', display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
        {[
          { key: 'O', label: '符合', truku: 'MALU', selected: true, color: XC.moss },
          { key: 'X', label: '不符合', truku: 'INI', selected: false, color: '#A33' },
        ].map(o => (
          <div key={o.key} style={{
            background: o.selected ? o.color : XC.cream,
            color: o.selected ? XC.creamLight : XC.ink,
            borderRadius: 16, padding: '20px 14px',
            border: o.selected ? `2.5px solid ${XC.gold}` : `1.5px solid ${XC.creamDeep}`,
            display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 6,
            position: 'relative',
          }}>
            <div style={{
              fontFamily: XF.display, fontSize: 56, fontWeight: 700, lineHeight: 1,
              color: o.selected ? XC.creamLight : o.color, letterSpacing: '0.05em',
            }}>{o.key}</div>
            <div style={{
              fontFamily: XF.display, fontSize: 14, fontWeight: 600, letterSpacing: '0.08em',
            }}>{o.label}</div>
            <div style={{
              fontFamily: XF.truku, fontStyle: 'italic', fontSize: 11,
              opacity: 0.85, letterSpacing: '0.15em',
              color: o.selected ? XC.gold : XC.fog,
            }}>{o.truku}</div>
            {o.selected && (
              <div style={{
                position: 'absolute', top: 8, right: 8,
                width: 22, height: 22, borderRadius: 11,
                background: XC.gold, display: 'flex', alignItems: 'center', justifyContent: 'center',
              }}>
                <svg width="11" height="11" viewBox="0 0 24 24" fill="none" stroke={XC.ink} strokeWidth="3" strokeLinecap="round" strokeLinejoin="round">
                  <path d="M5 12l5 5L20 7"/>
                </svg>
              </div>
            )}
          </div>
        ))}
      </div>

      <ExamFooter />
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// 第二部分：選擇題(一) — 3 張圖中選
// ─────────────────────────────────────────────────────────────
function ExamPart2() {
  const options = [
    { letter: 'A', emoji: '🧵', label: '織布', truku: 'tminun', bg: XC.primary },
    { letter: 'B', emoji: '🌿', label: '苧麻', truku: 'krig', bg: XC.moss, selected: true },
    { letter: 'C', emoji: '⛰️', label: '山林', truku: 'dgiyaq', bg: XC.primaryDeep },
  ];

  return (
    <div style={{
      width: '100%', minHeight: '100%', background: XC.creamLight, fontFamily: XF.body,
      position: 'relative', paddingBottom: 80,
    }}>
      <ExamHeader part="二" partZh="選擇題(一)" partTruku="MNHUWAY" n={6} total={10} time="03:18" score={3}/>

      <div style={{ padding: '14px 20px 0', fontSize: 12, color: XC.inkSoft, lineHeight: 1.6, letterSpacing: '0.03em' }}>
        聽完族語句子後，從 3 張圖片中選出語意最相符的：
      </div>

      <div style={{ padding: '10px 20px 0' }}>
        <AudioCard />
      </div>

      {/* 3 圖選項 */}
      <div style={{ padding: '14px 20px 0', display: 'flex', flexDirection: 'column', gap: 10 }}>
        {options.map(o => (
          <div key={o.letter} style={{
            display: 'flex', alignItems: 'center', gap: 12,
            background: o.selected ? XC.ink : XC.cream,
            borderRadius: 14, padding: '10px',
            border: o.selected ? `2px solid ${XC.gold}` : `1.5px solid ${XC.creamDeep}`,
          }}>
            <div style={{
              width: 36, height: 36, borderRadius: 18, flexShrink: 0,
              background: o.selected ? XC.gold : 'transparent',
              border: o.selected ? 'none' : `1.5px solid ${XC.fog}`,
              display: 'flex', alignItems: 'center', justifyContent: 'center',
              fontFamily: XF.display, fontSize: 14, fontWeight: 700,
              color: o.selected ? XC.ink : XC.fog,
            }}>{o.letter}</div>
            <div style={{
              width: 90, height: 80, borderRadius: 10, flexShrink: 0,
              background: `linear-gradient(135deg, ${o.bg}, ${o.bg}DD)`,
              display: 'flex', alignItems: 'center', justifyContent: 'center',
              position: 'relative', overflow: 'hidden',
            }}>
              <div style={{ position: 'absolute', inset: 0, opacity: 0.18 }}>
                <window.TrukuWeaveBg color={XC.gold} bg="transparent" opacity={1} scale={0.4} />
              </div>
              <div style={{ fontSize: 40, position: 'relative', filter: 'drop-shadow(0 3px 8px rgba(0,0,0,0.4))' }}>{o.emoji}</div>
            </div>
            <div style={{ flex: 1, color: o.selected ? XC.creamLight : XC.ink }}>
              <div style={{ fontFamily: XF.display, fontSize: 15, fontWeight: 600, letterSpacing: '0.04em' }}>{o.label}</div>
              <div style={{
                fontFamily: XF.truku, fontStyle: 'italic', fontSize: 11,
                color: o.selected ? XC.gold : XC.fog, letterSpacing: '0.12em', marginTop: 2,
              }}>{o.truku}</div>
            </div>
            {o.selected && (
              <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke={XC.gold} strokeWidth="3" strokeLinecap="round" strokeLinejoin="round">
                <path d="M5 12l5 5L20 7"/>
              </svg>
            )}
          </div>
        ))}
      </div>

      <ExamFooter />
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// 第三部分：選擇題(二) — 中文 → 選族語
// ─────────────────────────────────────────────────────────────
function ExamPart3() {
  const options = [
    { letter: 'A', truku: 'Mhuway su, tama.', selected: false },
    { letter: 'B', truku: 'Manu hangan su?', selected: true },
    { letter: 'C', truku: 'Mha ku mhuma krig.', selected: false },
  ];

  return (
    <div style={{
      width: '100%', minHeight: '100%', background: XC.creamLight, fontFamily: XF.body,
      position: 'relative', paddingBottom: 80,
    }}>
      <ExamHeader part="三" partZh="選擇題(二)" partTruku="KARI HANGAN" n={11} total={10} time="02:54" score={4}/>

      <div style={{ padding: '14px 20px 0', fontSize: 12, color: XC.inkSoft, lineHeight: 1.6, letterSpacing: '0.03em' }}>
        聽完中文句子和 3 句族語句子後，選出語意最接近的族語：
      </div>

      <div style={{ padding: '10px 20px 0' }}>
        <AudioCard playing="中文 + 族語播放中"/>
      </div>

      {/* 中文題目卡 */}
      <div style={{ padding: '14px 20px 0' }}>
        <div style={{
          background: XC.cream, borderRadius: 14, padding: '14px 16px',
          border: `1px solid ${XC.creamDeep}`, borderLeft: `4px solid ${XC.gold}`,
        }}>
          <div style={{
            fontFamily: XF.truku, fontStyle: 'italic', fontSize: 10,
            color: XC.fog, letterSpacing: '0.2em', marginBottom: 4,
          }}>KARI · 中文題目</div>
          <div style={{
            fontFamily: XF.display, fontSize: 18, fontWeight: 600,
            color: XC.ink, letterSpacing: '0.06em',
          }}>「你叫什麼名字？」</div>
        </div>
      </div>

      {/* 族語選項 */}
      <div style={{ padding: '14px 20px 0' }}>
        <div style={{
          fontFamily: XF.truku, fontStyle: 'italic', fontSize: 10,
          color: XC.fog, letterSpacing: '0.2em', marginBottom: 8,
        }}>KARI TRUKU · 族語選項</div>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
          {options.map(o => (
            <div key={o.letter} style={{
              background: o.selected ? XC.ink : XC.cream,
              color: o.selected ? XC.creamLight : XC.ink,
              borderRadius: 12, padding: '14px 16px',
              border: o.selected ? `2px solid ${XC.gold}` : `1.5px solid ${XC.creamDeep}`,
              display: 'flex', alignItems: 'center', gap: 12,
            }}>
              <div style={{
                width: 32, height: 32, borderRadius: 16, flexShrink: 0,
                background: o.selected ? XC.gold : 'transparent',
                border: o.selected ? 'none' : `1.5px solid ${XC.fog}`,
                display: 'flex', alignItems: 'center', justifyContent: 'center',
                fontFamily: XF.display, fontSize: 13, fontWeight: 700,
                color: o.selected ? XC.ink : XC.fog,
              }}>{o.letter}</div>
              <div style={{
                flex: 1, fontFamily: XF.truku, fontStyle: 'italic', fontSize: 16,
                fontWeight: o.selected ? 600 : 500, letterSpacing: '0.04em',
                color: o.selected ? XC.creamLight : XC.primary,
              }}>{o.truku}</div>
              {o.selected && (
                <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke={XC.gold} strokeWidth="3" strokeLinecap="round" strokeLinejoin="round">
                  <path d="M5 12l5 5L20 7"/>
                </svg>
              )}
            </div>
          ))}
        </div>
      </div>

      <ExamFooter />
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// 第四部分：配合題 — 5 圖中選相關圖
// ─────────────────────────────────────────────────────────────
function ExamPart4() {
  const options = [
    { letter: 'A', emoji: '🧵', label: '織布', truku: 'tminun', bg: XC.primary },
    { letter: 'B', emoji: '🌿', label: '苧麻', truku: 'krig', bg: XC.moss, selected: true },
    { letter: 'C', emoji: '🏞️', label: '溪谷', truku: 'rusuq', bg: XC.primaryDeep },
    { letter: 'D', emoji: '🍠', label: '小米', truku: 'masu', bg: XC.goldDeep },
    { letter: 'E', emoji: '🏠', label: '部落', truku: 'alang', bg: XC.mossDeep },
  ];

  return (
    <div style={{
      width: '100%', minHeight: '100%', background: XC.creamLight, fontFamily: XF.body,
      position: 'relative', paddingBottom: 80,
    }}>
      <ExamHeader part="四" partZh="配合題" partTruku="PNTBARAH HRAY" n={26} total={10} time="01:42" score={5}/>

      <div style={{ padding: '14px 20px 0', fontSize: 12, color: XC.inkSoft, lineHeight: 1.6, letterSpacing: '0.03em' }}>
        聽完族語對話後，從 5 張圖片中選出最相關的：
      </div>

      <div style={{ padding: '10px 20px 0' }}>
        <AudioCard playing="對話播放中"/>
      </div>

      {/* 對話 hint card */}
      <div style={{ padding: '14px 20px 0' }}>
        <div style={{
          background: XC.cream, borderRadius: 12, padding: '12px 14px',
          border: `1px solid ${XC.creamDeep}`, borderLeft: `3px solid ${XC.gold}`,
        }}>
          <div style={{
            display: 'flex', alignItems: 'center', gap: 6, marginBottom: 6,
            fontFamily: XF.truku, fontStyle: 'italic', fontSize: 10,
            color: XC.fog, letterSpacing: '0.2em',
          }}>
            <span style={{
              padding: '2px 7px', borderRadius: 3, background: XC.primary, color: XC.creamLight,
              fontSize: 9, fontWeight: 600, letterSpacing: '0.1em',
            }}>對話</span>
            DUMA · 兩人對話
          </div>
          <div style={{
            display: 'flex', alignItems: 'center', gap: 6, marginTop: 6,
          }}>
            <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke={XC.primary} strokeWidth="2"><circle cx="12" cy="9" r="3"/><path d="M5 21c1-4 4-5 7-5"/></svg>
            <div style={{ fontSize: 12, color: XC.inkSoft, letterSpacing: '0.04em' }}>
              對話內容播放中，請仔細聆聽⋯
            </div>
          </div>
        </div>
      </div>

      {/* 5 圖網格 */}
      <div style={{ padding: '14px 20px 0' }}>
        <div style={{
          fontFamily: XF.truku, fontStyle: 'italic', fontSize: 10,
          color: XC.fog, letterSpacing: '0.2em', marginBottom: 8,
        }}>QITA · 從 5 張圖中選一張</div>
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 8 }}>
          {options.slice(0, 4).map(o => (
            <ExamImgCard key={o.letter} o={o}/>
          ))}
        </div>
        <div style={{ marginTop: 8, display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 8 }}>
          <ExamImgCard o={options[4]}/>
          <div style={{
            borderRadius: 12, border: `1.5px dashed ${XC.creamDeep}`,
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            padding: '20px', color: XC.fog,
            fontFamily: XF.truku, fontStyle: 'italic', fontSize: 11, letterSpacing: '0.1em',
          }}>5 選 1</div>
        </div>
      </div>

      <ExamFooter />
    </div>
  );
}

function ExamImgCard({ o }) {
  return (
    <div style={{
      position: 'relative', overflow: 'hidden',
      borderRadius: 12,
      border: o.selected ? `2.5px solid ${XC.gold}` : `1.5px solid ${XC.creamDeep}`,
      boxShadow: o.selected ? `0 0 0 3px ${XC.gold}25` : 'none',
    }}>
      <div style={{
        height: 100, position: 'relative', overflow: 'hidden',
        background: `linear-gradient(135deg, ${o.bg}, ${o.bg}DD)`,
        display: 'flex', alignItems: 'center', justifyContent: 'center',
      }}>
        <div style={{ position: 'absolute', inset: 0, opacity: 0.18 }}>
          <window.TrukuWeaveBg color={XC.gold} bg="transparent" opacity={1} scale={0.4} />
        </div>
        <div style={{
          position: 'absolute', top: 6, left: 6,
          width: 22, height: 22, borderRadius: 11,
          background: o.selected ? XC.gold : 'rgba(28,15,13,0.65)',
          color: o.selected ? XC.ink : XC.creamLight,
          fontFamily: XF.display, fontSize: 11, fontWeight: 700,
          display: 'flex', alignItems: 'center', justifyContent: 'center',
          backdropFilter: 'blur(4px)',
        }}>{o.letter}</div>
        <div style={{ fontSize: 38, position: 'relative', filter: 'drop-shadow(0 3px 8px rgba(0,0,0,0.4))' }}>{o.emoji}</div>
        {o.selected && (
          <div style={{
            position: 'absolute', top: 6, right: 6,
            width: 22, height: 22, borderRadius: 11,
            background: XC.gold,
            display: 'flex', alignItems: 'center', justifyContent: 'center',
          }}>
            <svg width="11" height="11" viewBox="0 0 24 24" fill="none" stroke={XC.ink} strokeWidth="3" strokeLinecap="round" strokeLinejoin="round">
              <path d="M5 12l5 5L20 7"/>
            </svg>
          </div>
        )}
      </div>
      <div style={{
        padding: '6px 10px',
        background: o.selected ? XC.ink : XC.cream,
        color: o.selected ? XC.creamLight : XC.ink,
      }}>
        <div style={{ fontFamily: XF.display, fontSize: 12, fontWeight: 600, letterSpacing: '0.04em' }}>{o.label}</div>
        <div style={{
          fontFamily: XF.truku, fontStyle: 'italic', fontSize: 9,
          color: o.selected ? XC.gold : XC.fog, letterSpacing: '0.1em', marginTop: 1,
        }}>{o.truku}</div>
      </div>
    </div>
  );
}

window.ExamPart1 = ExamPart1;
window.ExamPart2 = ExamPart2;
window.ExamPart3 = ExamPart3;
window.ExamPart4 = ExamPart4;
