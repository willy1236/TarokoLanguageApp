// 螢幕: 小米商店 Shop

const { TRUKU_COLORS: SC, TRUKU_FONTS: SF } = window;

// 小米幣顯示元件
function MilletCoin({ size = 18 }) {
  return (
    <img src="badges/millet.png" alt="小米" style={{
      width: size, height: size, objectFit: 'contain', display: 'inline-block',
      verticalAlign: 'middle',
    }} />
  );
}

function MilletPrice({ amount, size = 16, color }) {
  return (
    <span style={{
      display: 'inline-flex', alignItems: 'center', gap: 4,
      fontFamily: SF.display, fontWeight: 700, color: color || SC.primary,
      fontSize: size,
    }}>
      <MilletCoin size={size + 4} />
      {amount}
    </span>
  );
}

function ShopScreen() {
  const featured = [
    { id: 'g-heart', img: 'badges/g-heart.png', name: '金徽·愛心', truku: 'Lukus Lhang', price: 280, rare: 'GOLD' },
    { id: 'c-cyan-love', img: 'badges/c-cyan-love.png', name: '青徽·愛戀', truku: 'Lukus Btasil', price: 120, rare: 'NEW' },
  ];

  const colored = [
    { id: 'c-red', img: 'badges/c-red.png', name: '紅徽', truku: 'Lhang', price: 80 },
    { id: 'c-orange-happy', img: 'badges/c-orange-happy.png', name: '橙徽·歡', truku: 'Mqaras', price: 100, owned: true },
    { id: 'c-yellow-wink', img: 'badges/c-yellow-wink.png', name: '黃徽·眨', truku: 'Mqita', price: 100 },
    { id: 'c-green-laugh', img: 'badges/c-green-laugh.png', name: '綠徽·笑', truku: 'Mngangah', price: 120 },
    { id: 'c-orange-shy', img: 'badges/c-orange-shy.png', name: '橙徽·靦', truku: 'Mqaras', price: 100 },
    { id: 'c-green-star', img: 'badges/c-green-star.png', name: '綠徽·星', truku: 'Bituq', price: 150 },
    { id: 'c-red-eat', img: 'badges/c-red-eat.png', name: '紅徽·食', truku: 'Mkan', price: 80 },
    { id: 'c-cyan-fight', img: 'badges/c-cyan-fight.png', name: '青徽·拳', truku: 'Mtgjiyax', price: 150 },
  ];

  const gold = [
    { id: 'g-calm', img: 'badges/g-calm.png', name: '金徽·靜', truku: 'Smbabuy', price: 220 },
    { id: 'g-happy', img: 'badges/g-happy.png', name: '金徽·喜', truku: 'Mqaras', price: 220 },
    { id: 'g-cry', img: 'badges/g-cry.png', name: '金徽·泣', truku: 'Lmingis', price: 200, locked: '完成 5 單元解鎖' },
    { id: 'g-smile', img: 'badges/g-smile.png', name: '金徽·笑', truku: 'Mngangah', price: 260 },
    { id: 'g-eat', img: 'badges/g-eat.png', name: '金徽·食', truku: 'Mkan', price: 200 },
  ];

  return (
    <div style={{
      width: '100%', minHeight: '100%', background: SC.creamLight,
      fontFamily: SF.body, paddingBottom: 100,
    }}>
      {/* hero header */}
      <div style={{
        position: 'relative', overflow: 'hidden',
        background: `linear-gradient(160deg, ${SC.primary} 0%, ${SC.primaryDeep} 100%)`,
        padding: '60px 20px 24px', color: SC.creamLight,
      }}>
        <div style={{ position: 'absolute', inset: 0, opacity: 0.15 }}>
          <window.TrukuWeaveBg color={SC.gold} bg="transparent" opacity={1} scale={0.7} />
        </div>

        {/* top row */}
        <div style={{ position: 'relative', display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 18 }}>
          <button style={{
            width: 36, height: 36, borderRadius: 18, border: 'none',
            background: 'rgba(250,245,234,0.15)', color: SC.creamLight,
            display: 'flex', alignItems: 'center', justifyContent: 'center',
          }}>
            <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke={SC.creamLight} strokeWidth="2" strokeLinecap="round">
              <path d="M15 6l-6 6 6 6"/>
            </svg>
          </button>
          <div style={{
            fontFamily: SF.truku, fontStyle: 'italic', fontSize: 12,
            color: SC.gold, letterSpacing: '0.25em',
          }}>SAPAH SMPUNG · 小米商店</div>
          <button style={{
            width: 36, height: 36, borderRadius: 18, border: 'none',
            background: 'rgba(250,245,234,0.15)', color: SC.creamLight,
            display: 'flex', alignItems: 'center', justifyContent: 'center',
          }}>
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke={SC.creamLight} strokeWidth="1.8" strokeLinecap="round">
              <circle cx="12" cy="12" r="9"/>
              <path d="M12 8v4l3 2"/>
            </svg>
          </button>
        </div>

        {/* balance card */}
        <div style={{
          position: 'relative', background: 'rgba(28,15,13,0.6)',
          backdropFilter: 'blur(12px)', WebkitBackdropFilter: 'blur(12px)',
          border: `1px solid ${SC.gold}50`, borderRadius: 18, padding: '16px 18px',
          display: 'flex', alignItems: 'center', gap: 14,
        }}>
          <div style={{
            width: 64, height: 64, flexShrink: 0,
            background: `radial-gradient(circle, ${SC.gold}40 0%, transparent 70%)`,
            display: 'flex', alignItems: 'center', justifyContent: 'center',
          }}>
            <img src="badges/millet.png" alt="小米" style={{ width: 60, height: 60, objectFit: 'contain' }} />
          </div>
          <div style={{ flex: 1 }}>
            <div style={{
              fontFamily: SF.truku, fontStyle: 'italic', fontSize: 11,
              color: SC.gold, letterSpacing: '0.2em', marginBottom: 4,
            }}>BURAW · 我的小米</div>
            <div style={{
              fontFamily: SF.display, fontSize: 30, fontWeight: 700, color: SC.creamLight,
              letterSpacing: '0.03em', lineHeight: 1,
            }}>320</div>
            <div style={{
              display: 'inline-flex', alignItems: 'center', gap: 4, marginTop: 6,
              padding: '2px 8px', borderRadius: 10,
              background: '#5BC97D' + '25', border: `0.5px solid #5BC97D80`,
              fontSize: 10, color: '#7FE49A', letterSpacing: '0.05em',
            }}>
              <svg width="9" height="9" viewBox="0 0 24 24" fill="none" stroke="#7FE49A" strokeWidth="3" strokeLinecap="round">
                <path d="M12 19V5M5 12l7-7 7 7"/>
              </svg>
              今日 +20
            </div>
          </div>
          <button style={{
            padding: '8px 14px', borderRadius: 16, border: `1px solid ${SC.gold}`,
            background: 'transparent', color: SC.gold,
            fontFamily: SF.display, fontSize: 12, fontWeight: 600, letterSpacing: '0.1em',
          }}>賺取小米</button>
        </div>

        {/* 賺取方式提示 */}
        <div style={{
          position: 'relative', marginTop: 12,
          display: 'flex', gap: 8, fontSize: 11, color: SC.creamLight, opacity: 0.85,
        }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 4, padding: '4px 10px', borderRadius: 10, background: 'rgba(250,245,234,0.08)' }}>
            <span style={{ color: SC.gold }}>●</span>每日登入 +10
          </div>
          <div style={{ display: 'flex', alignItems: 'center', gap: 4, padding: '4px 10px', borderRadius: 10, background: 'rgba(250,245,234,0.08)' }}>
            <span style={{ color: SC.gold }}>●</span>完成單元 +10
          </div>
        </div>
      </div>

      {/* 分類切換 */}
      <div style={{ padding: '18px 20px 10px', display: 'flex', gap: 8, overflowX: 'auto' }}>
        {['全部', '彩徽 Btasil', '金徽 GOLD', '限定', '已擁有'].map((c, i) => (
          <div key={c} style={{
            padding: '8px 14px', borderRadius: 18,
            background: i === 0 ? SC.ink : 'transparent',
            color: i === 0 ? SC.creamLight : SC.inkSoft,
            border: i === 0 ? 'none' : `1px solid ${SC.creamDeep}`,
            fontSize: 12, letterSpacing: '0.06em', whiteSpace: 'nowrap', fontWeight: i === 0 ? 600 : 400,
          }}>{c}</div>
        ))}
      </div>

      {/* 精選 */}
      <div style={{ padding: '8px 20px 0' }}>
        <div style={{
          display: 'flex', alignItems: 'baseline', justifyContent: 'space-between', marginBottom: 10,
        }}>
          <div style={{ fontFamily: SF.display, fontSize: 15, fontWeight: 600, color: SC.ink, letterSpacing: '0.06em' }}>精選</div>
          <div style={{ fontFamily: SF.truku, fontStyle: 'italic', fontSize: 10, color: SC.fog, letterSpacing: '0.15em' }}>
            mkmali · 限時推薦
          </div>
        </div>
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10 }}>
          {featured.map(b => (
            <div key={b.id} style={{
              position: 'relative', overflow: 'hidden',
              background: b.rare === 'GOLD'
                ? `linear-gradient(160deg, #2A1A15, ${SC.primaryDeep})`
                : `linear-gradient(160deg, ${SC.moss}, ${SC.mossDeep})`,
              borderRadius: 16, padding: '14px',
              border: `1px solid ${SC.gold}50`,
            }}>
              <div style={{ position: 'absolute', inset: 0, opacity: 0.13 }}>
                <window.TrukuWeaveBg color={SC.gold} bg="transparent" opacity={1} scale={0.5} />
              </div>
              <div style={{
                position: 'absolute', top: 8, right: 8,
                padding: '2px 8px', borderRadius: 3,
                background: b.rare === 'GOLD' ? SC.gold : '#5BC97D',
                color: b.rare === 'GOLD' ? SC.ink : SC.ink,
                fontFamily: SF.display, fontSize: 9, fontWeight: 700, letterSpacing: '0.15em',
              }}>{b.rare}</div>
              <div style={{
                position: 'relative', display: 'flex', justifyContent: 'center',
                marginBottom: 10, marginTop: 8,
              }}>
                <img src={b.img} alt={b.name} style={{
                  width: 88, height: 88, objectFit: 'contain',
                  filter: 'drop-shadow(0 4px 12px rgba(0,0,0,0.4))',
                }} />
              </div>
              <div style={{ position: 'relative', textAlign: 'center', marginBottom: 8 }}>
                <div style={{
                  fontFamily: SF.display, fontSize: 13, fontWeight: 600,
                  color: SC.creamLight, letterSpacing: '0.04em',
                }}>{b.name}</div>
                <div style={{
                  fontFamily: SF.truku, fontStyle: 'italic', fontSize: 10,
                  color: SC.gold, letterSpacing: '0.1em', marginTop: 1, opacity: 0.85,
                }}>{b.truku}</div>
              </div>
              <button style={{
                position: 'relative', width: '100%',
                padding: '8px', borderRadius: 18, border: 'none',
                background: SC.gold, color: SC.ink,
                display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 6,
                fontFamily: SF.display, fontSize: 13, fontWeight: 700,
              }}>
                <MilletCoin size={16} />
                {b.price}
              </button>
            </div>
          ))}
        </div>
      </div>

      {/* 彩徽 */}
      <div style={{ padding: '24px 20px 0' }}>
        <div style={{
          display: 'flex', alignItems: 'baseline', justifyContent: 'space-between', marginBottom: 10,
        }}>
          <div>
            <div style={{ fontFamily: SF.display, fontSize: 15, fontWeight: 600, color: SC.ink, letterSpacing: '0.06em' }}>
              彩徽
            </div>
            <div style={{ fontFamily: SF.truku, fontStyle: 'italic', fontSize: 10, color: SC.fog, letterSpacing: '0.15em', marginTop: 2 }}>
              btasil · 共 20 款
            </div>
          </div>
          <div style={{ fontSize: 11, color: SC.primary, letterSpacing: '0.1em' }}>查看全部 →</div>
        </div>
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: 8 }}>
          {colored.map(b => (
            <ShopBadgeCard key={b.id} badge={b} variant="colored" />
          ))}
        </div>
      </div>

      {/* 金徽 */}
      <div style={{ padding: '24px 20px 0' }}>
        <div style={{
          display: 'flex', alignItems: 'baseline', justifyContent: 'space-between', marginBottom: 10,
        }}>
          <div>
            <div style={{
              fontFamily: SF.display, fontSize: 15, fontWeight: 600, color: SC.ink, letterSpacing: '0.06em',
              display: 'flex', alignItems: 'center', gap: 6,
            }}>
              金徽
              <span style={{
                padding: '2px 8px', borderRadius: 3, background: SC.gold, color: SC.ink,
                fontSize: 9, fontWeight: 700, letterSpacing: '0.15em',
              }}>GOLD</span>
            </div>
            <div style={{ fontFamily: SF.truku, fontStyle: 'italic', fontSize: 10, color: SC.fog, letterSpacing: '0.15em', marginTop: 2 }}>
              rsuhug · 稀有款式
            </div>
          </div>
          <div style={{ fontSize: 11, color: SC.primary, letterSpacing: '0.1em' }}>查看全部 →</div>
        </div>
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: 8 }}>
          {gold.map(b => (
            <ShopBadgeCard key={b.id} badge={b} variant="gold" />
          ))}
        </div>
      </div>
    </div>
  );
}

function ShopBadgeCard({ badge, variant }) {
  const isGold = variant === 'gold';
  return (
    <div style={{
      position: 'relative', overflow: 'hidden',
      background: isGold
        ? `linear-gradient(160deg, #2A1A15, ${SC.midnight})`
        : SC.cream,
      border: `1px solid ${isGold ? SC.gold + '50' : SC.creamDeep}`,
      borderRadius: 12, padding: '10px 8px 8px',
      opacity: badge.locked ? 0.55 : 1,
    }}>
      {badge.owned && (
        <div style={{
          position: 'absolute', top: 4, right: 4,
          padding: '1px 6px', borderRadius: 8,
          background: '#5BC97D', color: SC.ink,
          fontSize: 8, fontWeight: 700, letterSpacing: '0.1em',
          zIndex: 2,
        }}>已擁有</div>
      )}
      {badge.locked && (
        <div style={{
          position: 'absolute', top: 4, right: 4,
          width: 18, height: 18, borderRadius: 9,
          background: 'rgba(0,0,0,0.5)',
          display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 2,
        }}>
          <svg width="9" height="9" viewBox="0 0 24 24" fill="none" stroke={SC.gold} strokeWidth="2.5" strokeLinecap="round">
            <rect x="5" y="11" width="14" height="9" rx="1.5"/>
            <path d="M8 11V7a4 4 0 018 0v4"/>
          </svg>
        </div>
      )}
      <div style={{ display: 'flex', justifyContent: 'center', marginBottom: 6 }}>
        <img src={badge.img} alt={badge.name} style={{
          width: 64, height: 64, objectFit: 'contain',
          filter: isGold ? 'drop-shadow(0 3px 8px rgba(201,169,97,0.3))' : 'drop-shadow(0 2px 4px rgba(0,0,0,0.15))',
        }} />
      </div>
      <div style={{
        textAlign: 'center',
        fontFamily: SF.display, fontSize: 11, fontWeight: 600,
        color: isGold ? SC.creamLight : SC.ink,
        letterSpacing: '0.04em', marginBottom: 2,
      }}>{badge.name}</div>
      <div style={{
        textAlign: 'center', display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 3,
        fontFamily: SF.display, fontSize: 12, fontWeight: 700,
        color: isGold ? SC.gold : SC.primary,
      }}>
        <MilletCoin size={13} />
        {badge.price}
      </div>
      {badge.locked && (
        <div style={{
          textAlign: 'center', fontSize: 9, color: SC.fog,
          marginTop: 4, letterSpacing: '0.05em',
        }}>{badge.locked}</div>
      )}
    </div>
  );
}

window.ShopScreen = ShopScreen;
window.MilletCoin = MilletCoin;
window.MilletPrice = MilletPrice;
