// 語見太魯閣 — 設計系統 tokens & 共用元件

const TRUKU_COLORS = {
  // 主色：苧麻染紅 / 太魯閣紅褐
  primary: '#7A1F1A',
  primaryDeep: '#4A0F0C',
  primaryLight: '#A8463E',

  // 黑（織布經線）
  ink: '#1C0F0D',
  inkSoft: '#3A2520',

  // 米白（苧麻原色）
  cream: '#F2E8D5',
  creamLight: '#FAF5EA',
  creamDeep: '#E8DBC0',

  // 山林苔綠
  moss: '#3D5A3D',
  mossDeep: '#1F3220',

  // 傳統珠飾金
  gold: '#C9A961',
  goldDeep: '#8E7234',

  // 深底
  midnight: '#1C0F0D',
  midnightSoft: '#2A1A15',

  // 灰階
  fog: '#A89C88',
  mist: '#D4C9B5',
};

const TRUKU_FONTS = {
  display: '"Noto Serif TC", "Songti TC", serif',
  body: '"Noto Sans TC", -apple-system, system-ui, sans-serif',
  truku: '"Crimson Pro", Georgia, serif', // 族語拉丁拼音用
  mono: '"JetBrains Mono", monospace',
};

// ─────────────────────────────────────────────────────────────
// 太魯閣菱形織紋 SVG pattern（puniri — 祖靈之眼）
// ─────────────────────────────────────────────────────────────
function TrukuWeavePattern({ id = 'truku-weave', color = '#7A1F1A', bg = 'transparent', scale = 1, opacity = 1 }) {
  const s = 24 * scale;
  return (
    <defs>
      <pattern id={id} x="0" y="0" width={s} height={s} patternUnits="userSpaceOnUse">
        {bg !== 'transparent' && <rect width={s} height={s} fill={bg} />}
        <g opacity={opacity} stroke={color} strokeWidth={1.2 * scale} fill="none">
          {/* 主菱形 */}
          <path d={`M${s/2} ${s*0.1} L${s*0.9} ${s/2} L${s/2} ${s*0.9} L${s*0.1} ${s/2} Z`} />
          {/* 內菱形 */}
          <path d={`M${s/2} ${s*0.3} L${s*0.7} ${s/2} L${s/2} ${s*0.7} L${s*0.3} ${s/2} Z`} fill={color} fillOpacity="0.15" />
          {/* 中心點 */}
          <circle cx={s/2} cy={s/2} r={1.2 * scale} fill={color} />
        </g>
      </pattern>
    </defs>
  );
}

// 整片織紋背景
function TrukuWeaveBg({ color = '#7A1F1A', bg = '#F2E8D5', opacity = 0.5, scale = 1, style = {} }) {
  const id = `weave-${Math.random().toString(36).slice(2, 8)}`;
  return (
    <svg width="100%" height="100%" style={{ position: 'absolute', inset: 0, ...style }}>
      <TrukuWeavePattern id={id} color={color} bg={bg} scale={scale} opacity={opacity} />
      <rect width="100%" height="100%" fill={`url(#${id})`} />
    </svg>
  );
}

// 單一菱形圖樣（裝飾用）
function TrukuDiamond({ size = 24, color = '#7A1F1A', filled = false, stroke = 1.5 }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" style={{ flexShrink: 0 }}>
      <path d="M12 2 L22 12 L12 22 L2 12 Z" fill={filled ? color : 'none'} stroke={color} strokeWidth={stroke} strokeLinejoin="round"/>
      <path d="M12 7 L17 12 L12 17 L7 12 Z" fill={filled ? 'none' : color} fillOpacity={filled ? 1 : 0.3} stroke={filled ? '#fff' : color} strokeWidth="1" strokeLinejoin="round"/>
    </svg>
  );
}

// 菱形鏈（橫向裝飾線）
function TrukuChain({ count = 5, size = 12, color = '#7A1F1A', gap = 4 }) {
  return (
    <div style={{ display: 'flex', gap, alignItems: 'center' }}>
      {Array.from({ length: count }).map((_, i) => (
        <TrukuDiamond key={i} size={size} color={color} filled={i % 2 === 0} stroke={1} />
      ))}
    </div>
  );
}

// 山脈線條（呼應太魯閣峽谷）
function TrukuMountains({ width = 360, height = 80, color = '#7A1F1A', opacity = 1 }) {
  return (
    <svg width={width} height={height} viewBox={`0 0 ${width} ${height}`} style={{ display: 'block' }}>
      <path
        d={`M0 ${height} L${width*0.08} ${height*0.55} L${width*0.18} ${height*0.7} L${width*0.28} ${height*0.25} L${width*0.4} ${height*0.5} L${width*0.5} ${height*0.15} L${width*0.62} ${height*0.55} L${width*0.72} ${height*0.3} L${width*0.82} ${height*0.6} L${width*0.92} ${height*0.4} L${width} ${height*0.65} L${width} ${height} Z`}
        fill={color} opacity={opacity}
      />
    </svg>
  );
}

// 播放按鈕圖示
function PlayIcon({ size = 16, color = '#fff' }) {
  return (
    <svg width={size} height={size} viewBox="0 0 16 16">
      <path d="M4 2.5 L13 8 L4 13.5 Z" fill={color} />
    </svg>
  );
}

// 喇叭圖示
function SpeakerIcon({ size = 18, color = '#7A1F1A' }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke={color} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <polygon points="11 5 6 9 2 9 2 15 6 15 11 19 11 5" fill={color} />
      <path d="M15.54 8.46a5 5 0 0 1 0 7.07" />
      <path d="M19.07 4.93a10 10 0 0 1 0 14.14" />
    </svg>
  );
}

Object.assign(window, {
  TRUKU_COLORS, TRUKU_FONTS,
  TrukuWeavePattern, TrukuWeaveBg, TrukuDiamond, TrukuChain, TrukuMountains,
  PlayIcon, SpeakerIcon,
});
