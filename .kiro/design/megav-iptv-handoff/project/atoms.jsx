/* Shared atoms used by all artboards */

const Brand = () => (
  <div className="mv-brand">
    <div className="mv-brand-mark"></div>
    <div className="mv-brand-name">
      MegaV<em>&nbsp;</em><span>IPTV</span>
    </div>
  </div>
);

const StatusBar = ({ city = "Kampala", temp = "19°", time = "03:04" }) => (
  <div style={{display: "flex", gap: 10, alignItems: "center"}}>
    <div className="mv-statusbar">
      <span className="flag"><i style={{background:"#000"}}></i><i style={{background:"#FCDC04"}}></i><i style={{background:"#D90000"}}></i></span>
      <span>{city}</span>
      <span className="dot"></span>
      <span>☁ {temp}</span>
      <span className="dot"></span>
      <span style={{color:"var(--text)"}}>{time}</span>
    </div>
    <button className="mv-iconbtn" aria-label="settings">
      <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.6">
        <circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.7 1.7 0 0 0 .3 1.8l.1.1a2 2 0 1 1-2.8 2.8l-.1-.1a1.7 1.7 0 0 0-1.8-.3 1.7 1.7 0 0 0-1 1.5V21a2 2 0 1 1-4 0v-.1a1.7 1.7 0 0 0-1.1-1.5 1.7 1.7 0 0 0-1.8.3l-.1.1a2 2 0 1 1-2.8-2.8l.1-.1a1.7 1.7 0 0 0 .3-1.8 1.7 1.7 0 0 0-1.5-1H3a2 2 0 1 1 0-4h.1a1.7 1.7 0 0 0 1.5-1.1 1.7 1.7 0 0 0-.3-1.8l-.1-.1a2 2 0 1 1 2.8-2.8l.1.1a1.7 1.7 0 0 0 1.8.3H9a1.7 1.7 0 0 0 1-1.5V3a2 2 0 1 1 4 0v.1a1.7 1.7 0 0 0 1 1.5 1.7 1.7 0 0 0 1.8-.3l.1-.1a2 2 0 1 1 2.8 2.8l-.1.1a1.7 1.7 0 0 0-.3 1.8V9a1.7 1.7 0 0 0 1.5 1H21a2 2 0 1 1 0 4h-.1a1.7 1.7 0 0 0-1.5 1z"/>
      </svg>
    </button>
  </div>
);

const Header = (props) => (
  <div className="mv-header">
    <Brand />
    <StatusBar {...props} />
  </div>
);

const Chip = ({ kind = "default", children, glyph }) => (
  <span className={`mv-chip ${kind}`}>
    {kind === "live" && <span className="pulse" style={{
      animation: "mvpulse 1.5s ease-in-out infinite"
    }}></span>}
    {glyph}
    {children}
  </span>
);

const Poster = ({ idx, w = 280, h = 380, title, year, genre, channel, live, focus, progress, badge, onPoster, hideText = true }) => {
  const t = TITLES[idx % TITLES.length];
  const showTitle = title || t.t;
  const showYear = year || t.y;
  const showGenre = genre || t.g;
  return (
    <div className={`mv-poster ${focus ? "focus" : ""}`} style={{width: w, height: h}}>
      <img className="pr-img" src={onPoster || buildPoster(idx, {showText: !hideText})} alt="" />
      <div className="pr-shade"></div>
      <div className="pr-tl">
        {live && <Chip kind="live">Live</Chip>}
        {badge && <Chip kind="ghost" >{badge}</Chip>}
      </div>
      {progress !== undefined && (
        <div className="progress"><i style={{width: `${progress}%`}}></i></div>
      )}
      <div className="pr-meta">
        <div className="pr-title" style={{
          fontFamily: "var(--font-display)", fontStyle: "italic",
          fontSize: w > 220 ? 22 : 16, fontWeight: 400
        }}>{showTitle}</div>
        <div className="pr-sub">
          <span>{showYear}</span>
          <span style={{opacity:0.5}}>·</span>
          <span>{String(showGenre).toUpperCase()}</span>
          {channel && <><span style={{opacity:0.5}}>·</span><span style={{color:"#c8b8ff"}}>{channel}</span></>}
        </div>
      </div>
    </div>
  );
};

// Tiny channel-logo "MM" mark
const MMLogo = ({ accent = "var(--accent)" }) => (
  <span style={{
    display: "inline-flex", alignItems: "center", justifyContent: "center",
    width: 18, height: 18, borderRadius: 4,
    background: accent, color: "white",
    fontSize: 9, fontWeight: 700, letterSpacing: 0.5,
    fontFamily: "var(--font-ui)"
  }}>M</span>
);

// Genre tabs
const GenreTabs = ({ tabs = ["В эфире", "Кино", "Сериалы", "Док.", "Спорт", "Дети", "Музыка"], counts, active = 0 }) => (
  <div className="mv-tabs">
    {tabs.map((t, i) => (
      <div key={i} className={`tab ${i === active ? "active" : ""}`}>
        {t}{counts && counts[i] ? <span className="num">{counts[i]}</span> : null}
      </div>
    ))}
    <div style={{marginLeft: "auto", display:"flex", gap:10, alignItems:"center", color:"var(--text-mute)"}}>
      <span style={{fontFamily:"var(--font-mono)", fontSize:11, letterSpacing:"0.1em"}}>FILTER</span>
      <span className="mv-key">⏷</span>
    </div>
  </div>
);

const SectionTitle = ({ title, italic, count, more = "Все" }) => (
  <div className="mv-section-title">
    <h3>{title} {italic && <em>{italic}</em>}</h3>
    {count !== undefined && <span className="count">{String(count).padStart(2, "0")}</span>}
    <span className="more">{more} →</span>
  </div>
);

// Remote/keyboard hint pill
const RemoteHint = ({ items }) => (
  <div style={{
    display: "flex", gap: 18, alignItems: "center",
    padding: "10px 16px",
    background: "rgba(20,20,26,0.6)",
    border: "1px solid var(--line)",
    borderRadius: 999,
    backdropFilter: "blur(20px)",
    fontSize: 12, color: "var(--text-dim)",
    fontFamily: "var(--font-ui)"
  }}>
    {items.map((it, i) => (
      <div key={i} style={{display:"flex", gap:8, alignItems:"center"}}>
        <span className="mv-key">{it.k}</span>
        <span>{it.label}</span>
      </div>
    ))}
  </div>
);

Object.assign(window, {
  Brand, StatusBar, Header, Chip, Poster, MMLogo, GenreTabs, SectionTitle, RemoteHint
});

// inject pulse keyframes once
if (!document.getElementById("mv-keyframes")) {
  const s = document.createElement("style");
  s.id = "mv-keyframes";
  s.textContent = `
    @keyframes mvpulse {
      0%, 100% { box-shadow: 0 0 0 0 rgba(255,255,255,0.7); }
      50% { box-shadow: 0 0 0 6px rgba(255,255,255,0); }
    }
  `;
  document.head.appendChild(s);
}
