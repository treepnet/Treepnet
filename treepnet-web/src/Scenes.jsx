// Layered SVG travel "photos" — the Browser CSP blocks external images, so
// these stand in for real user photos. At thumbnail / feed size they read as
// photographs: gradient skies, silhouetted landmarks, water and light.
const defs = (id, stops) => (
  <linearGradient id={id} x1="0" y1="0" x2="0" y2="1">
    {stops.map(([o, c], i) => <stop key={i} offset={o} stopColor={c} />)}
  </linearGradient>
);

const SCENES = {
  // Samarkand — Registan at golden hour (blue-tiled domes + iwan portal)
  registan: (uid) => (
    <svg viewBox="0 0 100 100" preserveAspectRatio="xMidYMid slice" className="scene">
      <defs>
        {defs(uid + "sky", [["0", "#ffd28a"], ["0.55", "#ff9e5e"], ["1", "#e86a4b"]])}
        {defs(uid + "dome", [["0", "#33b6c4"], ["1", "#1c7a97"]])}
      </defs>
      <rect width="100" height="100" fill={`url(#${uid}sky)`} />
      <circle cx="74" cy="30" r="10" fill="#fff3d0" opacity="0.85" />
      <rect y="72" width="100" height="28" fill="#8a6b46" />
      {/* central portal */}
      <path d="M38 72 V40 a12 12 0 0 1 24 0 V72 Z" fill="#2b6d84" />
      <path d="M42 72 V44 a8 8 0 0 1 16 0 V72 Z" fill="#123a4a" />
      {/* domes */}
      <ellipse cx="24" cy="54" rx="9" ry="10" fill={`url(#${uid}dome)`} />
      <rect x="22" y="54" width="4" height="18" fill="#2b6d84" />
      <ellipse cx="76" cy="54" rx="9" ry="10" fill={`url(#${uid}dome)`} />
      <rect x="74" y="54" width="4" height="18" fill="#2b6d84" />
      <path d="M24 44 l0 -6" stroke="#d4a017" strokeWidth="1.4" />
      <path d="M76 44 l0 -6" stroke="#d4a017" strokeWidth="1.4" />
    </svg>
  ),
  // Snow mountains + lake
  mountains: (uid) => (
    <svg viewBox="0 0 100 100" preserveAspectRatio="xMidYMid slice" className="scene">
      <defs>
        {defs(uid + "sky", [["0", "#bcd6f0"], ["1", "#eef4fb"]])}
        {defs(uid + "lake", [["0", "#4f7fa8"], ["1", "#2c516f"]])}
      </defs>
      <rect width="100" height="100" fill={`url(#${uid}sky)`} />
      <path d="M0 58 L20 30 L34 50 L52 22 L70 52 L84 34 L100 60 V72 H0 Z" fill="#6b7f9e" />
      <path d="M52 22 L45 34 L59 34 Z M20 30 L14 42 L26 42 Z M84 34 L78 46 L90 46 Z" fill="#fff" />
      <path d="M0 64 L26 44 L44 60 L64 40 L82 60 L100 48 V72 H0 Z" fill="#41566f" />
      <rect y="72" width="100" height="28" fill={`url(#${uid}lake)`} />
      <path d="M0 72 L26 60 L44 70 L64 56 L82 70 L100 62 V78 H0 Z" fill="#3a5570" opacity="0.7" />
    </svg>
  ),
  // Tropical beach
  beach: (uid) => (
    <svg viewBox="0 0 100 100" preserveAspectRatio="xMidYMid slice" className="scene">
      <defs>
        {defs(uid + "sky", [["0", "#8fd3e8"], ["1", "#fdf3d0"]])}
        {defs(uid + "sea", [["0", "#1f97b8"], ["1", "#3fc2d6"]])}
      </defs>
      <rect width="100" height="100" fill={`url(#${uid}sky)`} />
      <circle cx="70" cy="26" r="11" fill="#fff6cf" />
      <rect y="46" width="100" height="30" fill={`url(#${uid}sea)`} />
      <path d="M0 60 q25 6 50 0 t50 0 V76 H0 Z" fill="#5fd0df" opacity="0.6" />
      <rect y="70" width="100" height="30" fill="#ecd9a6" />
      <path d="M0 70 q50 10 100 0 V72 H0 Z" fill="#fff" opacity="0.5" />
    </svg>
  ),
  // City skyline at night
  city: (uid) => (
    <svg viewBox="0 0 100 100" preserveAspectRatio="xMidYMid slice" className="scene">
      <defs>{defs(uid + "sky", [["0", "#0c1b3a"], ["1", "#26406e"]])}</defs>
      <rect width="100" height="100" fill={`url(#${uid}sky)`} />
      <circle cx="78" cy="22" r="7" fill="#f2f0d8" opacity="0.9" />
      {[[6, 52], [16, 40], [26, 60], [34, 30], [46, 48], [56, 24], [66, 54], [76, 44], [88, 34]].map(([x, y], i) => (
        <rect key={i} x={x} y={y} width="9" height={100 - y} fill="#0a1226" />
      ))}
      {Array.from({ length: 26 }).map((_, i) => (
        <rect key={i} x={7 + (i * 7) % 88} y={34 + (i * 13) % 50} width="1.6" height="1.6" fill="#ffd76a" opacity="0.9" />
      ))}
    </svg>
  ),
  // Desert dunes
  desert: (uid) => (
    <svg viewBox="0 0 100 100" preserveAspectRatio="xMidYMid slice" className="scene">
      <defs>{defs(uid + "sky", [["0", "#ffe1a3"], ["1", "#ffb069"]])}</defs>
      <rect width="100" height="100" fill={`url(#${uid}sky)`} />
      <circle cx="30" cy="30" r="9" fill="#fff1cf" opacity="0.9" />
      <path d="M0 60 q30 -14 60 -2 t40 6 V100 H0 Z" fill="#d99b5a" />
      <path d="M0 74 q40 -16 80 -2 t20 4 V100 H0 Z" fill="#bd7f3f" />
      <path d="M0 88 q50 -12 100 0 V100 H0 Z" fill="#9c6530" />
    </svg>
  ),
  // Green valley
  valley: (uid) => (
    <svg viewBox="0 0 100 100" preserveAspectRatio="xMidYMid slice" className="scene">
      <defs>{defs(uid + "sky", [["0", "#bfe0f2"], ["1", "#e9f6df"]])}</defs>
      <rect width="100" height="100" fill={`url(#${uid}sky)`} />
      <path d="M0 56 q30 -12 60 0 t40 4 V100 H0 Z" fill="#7cae5c" />
      <path d="M0 70 q40 -14 100 -2 V100 H0 Z" fill="#4f8a3d" />
      <path d="M0 84 q50 -10 100 2 V100 H0 Z" fill="#356b2a" />
    </svg>
  ),
};

export const SCENE_NAMES = Object.keys(SCENES);

export default function Scene({ name = "registan", uid = "s" }) {
  const s = SCENES[name] || SCENES.registan;
  return s(uid + name);
}
