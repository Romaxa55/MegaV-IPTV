/* Mobile (Flutter) adaptation — vertical phone-shaped artboard */

function ScreenMobile() {
  const idx = 5;
  const t = TITLES[idx];

  return (
    <div className="mv-art mv-grain" style={{
      width: 390, height: 844, fontSize: 14,
      borderRadius: 36, overflow: "hidden",
      border: "12px solid #1a1a1f",
      boxShadow: "0 40px 80px rgba(0,0,0,0.7)"
    }}>
      {/* Backdrop */}
      <div className="mv-backdrop">
        <div className="layer" style={{backgroundImage: `url(${buildBackdrop(idx)})`}}></div>
        <div className="grad"></div>
      </div>

      {/* iOS status bar */}
      <div style={{
        display:"flex", justifyContent:"space-between", alignItems:"center",
        padding: "16px 24px 4px",
        position:"relative", zIndex:5,
        fontFamily:"-apple-system", fontWeight:600, fontSize:14
      }}>
        <span>03:04</span>
        <span style={{display:"flex", gap:6, alignItems:"center"}}>
          <svg width="18" height="12" viewBox="0 0 18 12" fill="white"><path d="M9 9l3 3 6-6-1.5-1.5L12 9 10.5 7.5z"/></svg>
          <svg width="14" height="12" viewBox="0 0 14 12" fill="white"><rect x="0" y="8" width="2" height="4"/><rect x="4" y="6" width="2" height="6"/><rect x="8" y="3" width="2" height="9"/><rect x="12" y="0" width="2" height="12"/></svg>
        </span>
      </div>

      <div style={{padding: "12px 20px 0", position: "relative", zIndex: 5, display:"flex", justifyContent:"space-between"}}>
        <Brand />
        <button className="mv-iconbtn" style={{width:32, height:32}}>
          <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><circle cx="11" cy="11" r="7"/><path d="M21 21l-4.3-4.3"/></svg>
        </button>
      </div>

      {/* Hero featured poster card with pan/parallax hint */}
      <div style={{padding: "20px 20px 16px", position: "relative", zIndex: 5}}>
        <div style={{
          position: "relative",
          borderRadius: 20, overflow: "hidden",
          height: 360,
          boxShadow: "0 24px 56px rgba(0,0,0,0.6)"
        }}>
          <img src={buildPoster(idx)} style={{
            position: "absolute", inset: 0, width: "100%", height: "100%", objectFit: "cover"
          }} alt=""/>
          <div style={{
            position: "absolute", inset: 0,
            background: "linear-gradient(180deg, transparent 40%, rgba(0,0,0,0.85) 100%)"
          }}></div>
          <div style={{position: "absolute", top: 14, left: 14, display: "flex", gap: 6}}>
            <Chip kind="live">Live</Chip>
            <Chip kind="brand"><MMLogo />&nbsp;MM Romance HD</Chip>
          </div>
          <div style={{position: "absolute", left: 18, right: 18, bottom: 16}}>
            <div style={{fontFamily:"var(--font-display)", fontStyle:"italic", fontSize: 36, lineHeight: 1, marginBottom: 8}}>{t.t}</div>
            <div style={{fontFamily:"var(--font-mono)", fontSize: 10, color: "rgba(255,255,255,0.7)", letterSpacing: "0.14em", textTransform:"uppercase", marginBottom: 14}}>
              <span style={{color: "var(--gold)"}}>★ 8.7</span> · {t.y} · {t.g} · ещё 55 мин
            </div>
            <div className="mv-track" style={{height: 3, marginBottom: 14}}><i style={{width: "62%"}}></i></div>
            <button className="mv-btn primary" style={{padding: "12px 18px", fontSize: 14, width: "100%", justifyContent:"center"}}>
              <svg width="12" height="12" viewBox="0 0 24 24" fill="currentColor"><path d="M8 5v14l11-7z"/></svg>
              Смотреть
            </button>
          </div>
          {/* swipe gesture hint */}
          <div style={{
            position: "absolute", bottom: 8, right: 12,
            fontFamily: "var(--font-mono)", fontSize: 9,
            color: "rgba(255,255,255,0.5)", letterSpacing: "0.1em"
          }}>SWIPE ↔ КАНАЛ</div>
        </div>

        {/* dot indicator */}
        <div style={{display:"flex", justifyContent:"center", gap:6, marginTop:12}}>
          {[0,1,2,3,4].map(i => (
            <div key={i} style={{
              width: i === 0 ? 16 : 5, height: 5, borderRadius: 3,
              background: i === 0 ? "var(--accent)" : "rgba(255,255,255,0.2)"
            }}></div>
          ))}
        </div>
      </div>

      {/* Tabs slim */}
      <div style={{
        padding: "0 20px",
        display: "flex", gap: 18,
        fontFamily: "var(--font-ui)", fontSize: 13,
        position: "relative", zIndex: 5
      }}>
        {["В эфире", "Кино", "Сериалы", "Док."].map((tab, i) => (
          <span key={i} style={{
            padding: "8px 0",
            color: i === 0 ? "var(--text)" : "var(--text-dim)",
            borderBottom: i === 0 ? "2px solid var(--accent)" : "2px solid transparent",
            fontWeight: i === 0 ? 600 : 400,
            letterSpacing: "0.02em"
          }}>{tab}</span>
        ))}
      </div>

      {/* Mini cards */}
      <div style={{padding: "16px 20px", display: "flex", gap: 12, overflow: "hidden", position: "relative", zIndex: 5}}>
        {[1, 11, 7, 14].map(i => (
          <div key={i} style={{position:"relative", width: 110, height: 156, borderRadius: 12, overflow: "hidden", flexShrink: 0}}>
            <img src={buildPoster(i, {showText: false})} alt="" style={{position:"absolute", inset:0, width:"100%", height:"100%", objectFit:"cover"}}/>
            <div style={{position:"absolute", inset:0, background:"linear-gradient(180deg, transparent 50%, rgba(0,0,0,0.85) 100%)"}}></div>
            <div style={{position:"absolute", bottom:8, left:10, right:10}}>
              <div style={{fontFamily:"var(--font-display)", fontStyle:"italic", fontSize: 14, lineHeight: 1.05}}>{TITLES[i].t}</div>
              <div style={{fontFamily:"var(--font-mono)", fontSize: 8, color:"rgba(255,255,255,0.65)", letterSpacing:"0.1em", marginTop: 4}}>{TITLES[i].y} · {TITLES[i].g.toUpperCase()}</div>
            </div>
          </div>
        ))}
      </div>

      {/* Bottom blur tab bar — Flutter feel */}
      <div style={{
        position: "absolute", bottom: 14, left: 20, right: 20,
        padding: "12px 16px",
        background: "rgba(15,15,20,0.55)",
        backdropFilter: "blur(28px)",
        border: "1px solid var(--line)",
        borderRadius: 26,
        display: "flex", justifyContent: "space-around", alignItems: "center",
        zIndex: 20
      }}>
        {[
          {n: "home", a: true, ic: "M3 11l9-8 9 8v10a2 2 0 0 1-2 2h-4v-7h-6v7H5a2 2 0 0 1-2-2z"},
          {n: "tv", ic: "M3 5h18v12H3zM7 21h10"},
          {n: "search", ic: "M11 18a7 7 0 1 1 0-14 7 7 0 0 1 0 14zM21 21l-4.3-4.3"},
          {n: "saved", ic: "M19 21l-7-5-7 5V5a2 2 0 0 1 2-2h10a2 2 0 0 1 2 2z"},
          {n: "user", ic: "M12 12a4 4 0 1 0 0-8 4 4 0 0 0 0 8zM4 22a8 8 0 0 1 16 0"},
        ].map((b, i) => (
          <div key={i} style={{
            display: "grid", placeItems: "center",
            width: 40, height: 40, borderRadius: 14,
            background: b.a ? "var(--accent)" : "transparent",
            color: b.a ? "white" : "var(--text-dim)"
          }}>
            <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinejoin="round" strokeLinecap="round"><path d={b.ic}/></svg>
          </div>
        ))}
      </div>
    </div>
  );
}

window.ScreenMobile = ScreenMobile;
