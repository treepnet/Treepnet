// Code-drawn recreations of REAL TreepNet screens — no screenshots, and only
// features that actually ship: Feed, Profile (with travel-map tab), the travel
// map, and direct chat. App icons render green, matching the Figma icon set.
import "./Mockups.css";

function StatusBar() {
  return (
    <div className="mk-status">
      <span>9:41</span>
      <span className="mk-status-icons"><i className="mk-sig" /><i className="mk-wifi" /><i className="mk-bat" /></span>
    </div>
  );
}

/* Small green icon set matching the app's Figma icons. */
const Ico = {
  heart: <path d="M12 20s-7-4.35-9.5-8.5C1 8.5 2.5 5.5 5.7 5.5c1.9 0 3.1 1.1 3.8 2.2.7-1.1 1.9-2.2 3.8-2.2 3.2 0 4.7 3 3.2 6C19 15.65 12 20 12 20z" />,
  comment: <path d="M4 5h16v11H9l-4 4v-4H4z" />,
  share: <path d="M4 12l16-8-6 16-3-6z" />,
  bookmark: <path d="M6 3h12v18l-6-4-6 4z" />,
  home: <path d="M4 11l8-7 8 7v9a1 1 0 0 1-1 1h-4v-6h-6v6H5a1 1 0 0 1-1-1z" />,
  flame: <path d="M12 2c1 3-1 4-1 7 0-1-1-2-2-2-1 2-3 3-3 7a6 6 0 0 0 12 0c0-4-4-5-6-12z" />,
  send: <path d="M4 12l16-8-6 16-3-6z" />,
  globe: <path d="M12 2a10 10 0 1 0 0 20 10 10 0 0 0 0-20zM2.5 12h19M12 2.5c3 3 3 16 0 19M12 2.5c-3 3-3 16 0 19" />,
  grid: <path d="M4 4h6v6H4zM14 4h6v6h-6zM4 14h6v6H4zM14 14h6v6h-6z" />,
  tag: <path d="M12 3l2.5 6H21l-5 4 2 7-6-4-6 4 2-7-5-4h6.5z" />,
  plus: <path d="M12 4v16M4 12h16" />,
  bell: <path d="M6 9a6 6 0 0 1 12 0c0 5 2 6 2 6H4s2-1 2-6zM10 20a2 2 0 0 0 4 0" />,
};

function Avatar({ letter, from, to, size = 62, border = 3 }) {
  return (
    <div className="mk-avatar" style={{ width: size, height: size, borderWidth: border, background: `linear-gradient(135deg,${from},${to})`, fontSize: size * 0.42 }}>{letter}</div>
  );
}

/* --------------------------------------------------------------- Feed ----- */
export function FeedScreen({ t }) {
  const stories = [
    { n: t.m_yourstory, own: true, from: "#728fce", to: "#6d35c0" },
    { n: "dilnoza", from: "#f535aa", to: "#6d35c0" },
    { n: "sardor", from: "#3898ec", to: "#2f539b" },
    { n: "kamola", from: "#ffc93d", to: "#f535aa" },
    { n: "jasur", from: "#35c6f4", to: "#2f539b" },
  ];
  return (
    <div className="mk-screen">
      <StatusBar />
      <div className="mk-feed-top">
        <span className="mk-wordmark">Treep<b>Net</b></span>
        <span className="mk-feed-actions">
          <svg viewBox="0 0 24 24" className="mk-ico-g">{Ico.bell}</svg>
          <svg viewBox="0 0 24 24" className="mk-ico-g">{Ico.send}</svg>
        </span>
      </div>

      <div className="mk-stories">
        {stories.map((s, i) => (
          <div className="mk-story" key={i}>
            <span className={"mk-story-ring" + (s.own ? " own" : "")}>
              <Avatar letter={s.n[0].toUpperCase()} from={s.from} to={s.to} size={52} border={2} />
              {s.own && <i className="mk-story-add">+</i>}
            </span>
            <span className="mk-story-n">{s.n}</span>
          </div>
        ))}
      </div>

      <div className="mk-post">
        <div className="mk-post-head">
          <Avatar letter="D" from="#f535aa" to="#6d35c0" size={34} border={2} />
          <div className="mk-post-id">
            <b>dilnoza</b>
            <span className="mk-post-loc"><svg viewBox="0 0 24 24" className="mk-loc-ico"><path d="M12 2C8 2 5 5 5 9c0 5 7 13 7 13s7-8 7-13c0-4-3-7-7-7z" /><circle cx="12" cy="9" r="2.4" fill="#1a1b1e" /></svg>{t.mk_post_loc}</span>
          </div>
          <span className="mk-dots"><i /><i /><i /></span>
        </div>
        <div className="mk-post-img"><img src="/photos/registan.jpg" alt="Registon" /></div>
        <div className="mk-post-actions">
          <svg viewBox="0 0 24 24" className="mk-ico-g fill">{Ico.heart}</svg>
          <svg viewBox="0 0 24 24" className="mk-ico-g">{Ico.comment}</svg>
          <svg viewBox="0 0 24 24" className="mk-ico-g">{Ico.share}</svg>
          <svg viewBox="0 0 24 24" className="mk-ico-g last">{Ico.bookmark}</svg>
        </div>
        <div className="mk-post-meta">
          <b>1,240 {t.m_likes}</b>
          <span className="mk-post-cap"><b>dilnoza</b> {t.mk_post_cap}</span>
          <span className="mk-post-cmt">{t.m_viewcomments}</span>
        </div>
      </div>
      <BottomNav active="home" />
    </div>
  );
}

/* ------------------------------------------------------------- Profile ---- */
export function ProfileScreen({ t }) {
  return (
    <div className="mk-screen">
      <StatusBar />
      <div className="mk-topbar">
        <span className="mk-username">@aziz.travels</span>
        <span className="mk-burger"><i /><i /><i /></span>
      </div>

      <div className="mk-profile-head">
        <span className="mk-story-ring own big"><Avatar letter="A" from="#728fce" to="#6d35c0" size={64} /></span>
        <div className="mk-stats">
          <div><b>128</b><span>{t.m_post}</span></div>
          <div><b>3,412</b><span>{t.m_followers}</span></div>
          <div><b>289</b><span>{t.m_subs}</span></div>
        </div>
      </div>

      <div className="mk-bio">
        <div className="mk-fullname">Aziz Karimov <span className="mk-verify">✓</span></div>
        <div className="mk-bio-text">{t.mk_bio_1}<br />{t.mk_bio_2}</div>
        <div className="mk-bio-link">🔗 t.me/aziz</div>
      </div>

      <div className="mk-actions">
        <button className="mk-btn mk-btn-primary">{t.m_edit}</button>
        <button className="mk-btn mk-btn-ghost">{t.m_share}</button>
      </div>

      <div className="mk-tabs">
        <span className="mk-tab"><svg viewBox="0 0 24 24" className="mk-tab-ico">{Ico.globe}</svg></span>
        <span className="mk-tab active"><svg viewBox="0 0 24 24" className="mk-tab-ico">{Ico.grid}</svg></span>
        <span className="mk-tab"><svg viewBox="0 0 24 24" className="mk-tab-ico">{Ico.tag}</svg></span>
      </div>

      <div className="mk-grid">
        {["istanbul", "tokyo", "paris", "rio", "colosseum", "taj", "nyc", "barcelona", "greatwall"].map((s, i) => (
          <div className="mk-cell" key={i}><img src={`/photos/${s}.jpg`} alt="" loading="lazy" /></div>
        ))}
      </div>
      <BottomNav active="profile" />
    </div>
  );
}

/* ----------------------------------------------------------- Travel map --- */
export function MapScreen({ t }) {
  // Density legend mirrors the app's _colorForCount buckets.
  const legend = [
    ["1–20", "#5bb8e8"], ["21–40", "#1e7fe0"], ["41–60", "#a020c7"], ["61–80", "#ed2a93"], ["80+", "#e01b24"],
  ];
  return (
    <div className="mk-screen">
      <StatusBar />
      <div className="mk-map-search">
        <svg viewBox="0 0 24 24" className="mk-search-ico"><circle cx="11" cy="11" r="7" /><path d="M20 20l-3.5-3.5" /></svg>
        <span>{t.m_search}</span>
      </div>
      <div className="mk-map-wrap">
        <div className="mk-map-globe">
          {/* colored visited regions + blue location pins are baked into the SVG */}
          <img src="/world-map.svg" alt="" className="mk-map-img" />
          <div className="mk-map-glow" />
        </div>
        <div className="mk-map-legend">
          {legend.map(([lbl, c]) => (
            <span key={lbl}><i style={{ background: c }} />{lbl}</span>
          ))}
        </div>
        <div className="mk-map-card">
          <div className="mk-map-card-l">
            <svg viewBox="0 0 24 24" className="mk-loc-ico big"><path d="M12 2C8 2 5 5 5 9c0 5 7 13 7 13s7-8 7-13c0-4-3-7-7-7z" /><circle cx="12" cy="9" r="2.4" fill="#201e1e" /></svg>
            <div><b>{t.mk_map_toshkent}</b><span>{t.m_here} · 12</span></div>
          </div>
          <span className="mk-map-go">›</span>
        </div>
      </div>
      <BottomNav active="profile" />
    </div>
  );
}

/* --------------------------------------------------------------- Chat ----- */
export function ChatScreen({ t }) {
  return (
    <div className="mk-screen">
      <StatusBar />
      <div className="mk-chat-top">
        <span className="mk-chat-back">‹</span>
        <Avatar letter="S" from="#3898ec" to="#2f539b" size={34} border={2} />
        <div className="mk-chat-id"><b>sardor</b><span>{t.m_online}</span></div>
      </div>
      <div className="mk-chat-body">
        <div className="mk-msg in">{t.mk_chat_1}</div>
        <div className="mk-msg out">{t.mk_chat_2}</div>
        <div className="mk-msg in">{t.mk_chat_3}</div>
        <div className="mk-msg out reply">
          <span className="mk-reply-q">{t.mk_chat_reply_q}</span>
          {t.mk_chat_4}
        </div>
        <div className="mk-msg in short">{t.mk_chat_5}</div>
      </div>
      <div className="mk-chat-input">
        <span className="mk-chat-field">{t.m_typemsg}</span>
        <span className="mk-chat-send"><svg viewBox="0 0 24 24">{Ico.send}</svg></span>
      </div>
    </div>
  );
}

/* ------------------------------------------------------------ Bottom nav -- */
function BottomNav({ active }) {
  const items = [
    ["home", Ico.home], ["flame", Ico.flame], ["add", Ico.plus], ["send", Ico.send], ["profile", null],
  ];
  return (
    <div className="mk-nav">
      {items.map(([k, path]) => (
        <span key={k} className={"mk-nav-i" + (k === active ? " active" : "") + (k === "add" ? " add" : "")}>
          {k === "profile"
            ? <span className={"mk-nav-ava" + (active === "profile" ? " on" : "")}><Avatar letter="A" from="#728fce" to="#6d35c0" size={24} border={0} /></span>
            : <svg viewBox="0 0 24 24">{path}</svg>}
        </span>
      ))}
    </div>
  );
}

/* ----------------------------------------------------------- Phone shell --- */
export function Phone({ children, className = "", tilt = 0 }) {
  return (
    <div className={"mk-phone " + className} style={{ "--tilt": `${tilt}deg` }}>
      <div className="mk-phone-notch" />
      <div className="mk-phone-inner">{children}</div>
    </div>
  );
}
