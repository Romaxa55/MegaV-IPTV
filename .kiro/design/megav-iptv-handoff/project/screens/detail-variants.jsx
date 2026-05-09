/* Channel Detail — 3 focus-aware variants.
   All wired to live API via window.loadFeatured + computeProgress.
   Focus state lives in this component (D-pad sim with arrow keys). */

const { useState: useStateDV, useEffect: useEffectDV, useCallback: useCallbackDV } = React;

// Variant A — Full-bleed cinema: massive backdrop, info bottom-left, controls bottom
function DetailFullBleed({ item }) {
  const [focus, setFocus] = useStateDV("play");
  const order = ["play", "fav", "trailer", "epg", "more"];
  useEffectDV(() => {
    const onKey = (e) => {
      if (e.key === "ArrowRight" || e.key === "ArrowLeft") {
        const i = order.indexOf(focus);
        const next = e.key === "ArrowRight" ? Math.min(order.length-1, i+1) : Math.max(0, i-1);
        setFocus(order[next]); e.preventDefault();
      }
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [focus]);

  const prog = computeProgress(item.program);
  const year = parseYear(item.program?.description);
  const synopsis = parseSynopsis(item.program?.description);
  const idx = (item.channelId ?? 0) % 16;
  const poster = item.program?.icon || item.thumbnailUrl || buildBackdrop(idx);

  return (
    <div style={{position: "relative", width: "100%", aspectRatio: "16/9", overflow: "hidden", background: "#000"}}>
      {/* Backdrop — обложка на весь экран как в проде */}
      <img src={poster} style={{
        position: "absolute", inset: 0, width: "100%", height: "100%",
        objectFit: "cover", filter: "brightness(0.55)"
      }}/>
      <div style={{
        position: "absolute", inset: 0,
        background: "linear-gradient(180deg, transparent 0%, transparent 30%, rgba(6,8,15,0.85) 75%, rgba(6,8,15,0.98) 100%), linear-gradient(90deg, rgba(6,8,15,0.92) 0%, transparent 60%)"
      }}></div>
      {/* Grain */}
      <div className="mv-grain" style={{position: "absolute", inset: 0}}></div>

      {/* Top: back + breadcrumb */}
      <div style={{
        position: "absolute", top: 32, left: 56, right: 56,
        display: "flex", alignItems: "center", gap: 14, zIndex: 5
      }}>
        <button className="mv-iconbtn" style={focusRing(focus === "back")}>
          <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path d="M15 18l-6-6 6-6"/></svg>
        </button>
        <span style={{
          fontFamily: "var(--font-mono)", fontSize: 11,
          letterSpacing: "0.16em", color: "rgba(255,255,255,0.6)", textTransform: "uppercase"
        }}>Главная / {item.groupTitle || "Канал"} / {item.channelName}</span>
        <span style={{marginLeft: "auto", fontFamily: "var(--font-mono)", fontSize: 11,
          letterSpacing: "0.16em", color: "var(--accent)"}}>● ВАРИАНТ A — full-bleed</span>
      </div>

      {/* Body — hero meta bottom-left */}
      <div style={{
        position: "absolute", left: 56, right: 56, bottom: 48,
        zIndex: 5, maxWidth: 920
      }}>
        <div style={{display: "flex", gap: 8, marginBottom: 18}}>
          {prog?.isNow && <Chip kind="live">В эфире</Chip>}
          <Chip kind="brand"><MMLogo />&nbsp;{item.channelName}</Chip>
          {item.program?.category && <Chip>{item.program.category}</Chip>}
          <Chip kind="ghost">HD · 5.1</Chip>
        </div>

        <div style={{
          fontFamily: "var(--font-display)", fontStyle: "italic",
          fontSize: 96, lineHeight: 0.92, letterSpacing: "-0.02em",
          color: "#fff", marginBottom: 22, textShadow: "0 4px 30px rgba(0,0,0,0.8)"
        }}>{item.program?.title || item.channelName}</div>

        <div style={{
          display: "flex", gap: 22,
          fontFamily: "var(--font-mono)", fontSize: 12,
          letterSpacing: "0.14em", color: "rgba(255,255,255,0.7)",
          textTransform: "uppercase", marginBottom: 18
        }}>
          {year && <span>{year}</span>}
          {item.program && <span>{Math.round(((new Date(item.program.end)-new Date(item.program.start))/60_000))} мин</span>}
          <span>16+</span>
          {prog?.isNow && <span style={{color: "var(--accent)"}}>● осталось {prog.remainingMin} мин</span>}
        </div>

        {synopsis && (
          <p style={{
            maxWidth: 720, fontFamily: "var(--font-ui)",
            fontSize: 17, lineHeight: 1.55, color: "rgba(255,255,255,0.82)",
            marginBottom: 28, textWrap: "pretty",
            display: "-webkit-box", WebkitLineClamp: 3, WebkitBoxOrient: "vertical", overflow: "hidden"
          }}>{synopsis}</p>
        )}

        {prog?.isNow && (
          <div style={{maxWidth: 600, marginBottom: 26}}>
            <div className="mv-track" style={{marginBottom: 8}}><i style={{width: `${Math.round(prog.progress*100)}%`}}></i></div>
            <div className="mv-ticks">
              <span>{new Date(item.program.start).toLocaleTimeString("ru-RU",{hour:"2-digit",minute:"2-digit"})}</span>
              <span>{new Date(item.program.end).toLocaleTimeString("ru-RU",{hour:"2-digit",minute:"2-digit"})}</span>
            </div>
          </div>
        )}

        <div style={{display: "flex", gap: 12, alignItems: "center", flexWrap: "wrap"}}>
          <button className="mv-btn primary" style={focusRing(focus === "play")}>
            <svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor"><path d="M8 5v14l11-7z"/></svg>
            Включить (OK)
          </button>
          <button className="mv-btn ghost" style={focusRing(focus === "fav")}>+ Избранное</button>
          <button className="mv-btn ghost" style={focusRing(focus === "trailer")}>Трейлер</button>
          <button className="mv-btn ghost" style={focusRing(focus === "epg")}>Программа канала</button>
          <button className="mv-btn ghost" style={focusRing(focus === "more")}>Ещё</button>
        </div>

        {/* D-pad hint */}
        <div style={{
          marginTop: 28, display: "flex", gap: 18,
          fontFamily: "var(--font-mono)", fontSize: 10,
          letterSpacing: "0.16em", color: "rgba(255,255,255,0.45)",
          textTransform: "uppercase"
        }}>
          <span><kbd style={kbdSt}>←</kbd> <kbd style={kbdSt}>→</kbd> между кнопок</span>
          <span><kbd style={kbdSt}>OK</kbd> Включить</span>
          <span><kbd style={kbdSt}>BACK</kbd> Назад</span>
        </div>
      </div>
    </div>
  );
}

const kbdSt = {
  fontFamily: "var(--font-mono)", fontSize: 10,
  padding: "2px 6px", border: "1px solid rgba(255,255,255,0.25)",
  borderRadius: 4, marginRight: 4
};

// Variant B — Split: poster left, EPG timeline right (now/next/later)
function DetailSplit({ item, todayPrograms }) {
  const [focus, setFocus] = useStateDV("play");
  const order = ["play", "fav", "epg0", "epg1", "epg2", "epg3"];
  useEffectDV(() => {
    const onKey = (e) => {
      if (e.key === "ArrowRight" || e.key === "ArrowLeft" || e.key === "ArrowDown" || e.key === "ArrowUp") {
        const i = order.indexOf(focus);
        let next = i;
        if (e.key === "ArrowRight") next = focus === "play" ? order.indexOf("epg0") : Math.min(order.length-1, i+1);
        else if (e.key === "ArrowLeft") next = focus.startsWith("epg") ? order.indexOf("play") : Math.max(0, i-1);
        else if (e.key === "ArrowDown") next = focus.startsWith("epg") ? Math.min(order.length-1, i+1) : order.indexOf("fav");
        else if (e.key === "ArrowUp") next = focus.startsWith("epg") ? Math.max(order.indexOf("epg0"), i-1) : order.indexOf("play");
        setFocus(order[next]); e.preventDefault();
      }
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [focus]);

  const prog = computeProgress(item.program);
  const idx = (item.channelId ?? 0) % 16;
  const poster = item.program?.icon || item.thumbnailUrl || buildBackdrop(idx);

  return (
    <div style={{position: "relative", width: "100%", aspectRatio: "16/9", overflow: "hidden", background: "var(--bg)"}}>
      {/* Soft backdrop */}
      <div style={{
        position: "absolute", inset: 0,
        backgroundImage: `url(${poster})`,
        backgroundSize: "cover", filter: "blur(60px) brightness(0.35)", transform: "scale(1.2)"
      }}></div>
      <div style={{position: "absolute", inset: 0, background: "rgba(6,8,15,0.6)"}}></div>

      <div style={{
        position: "absolute", inset: 0, padding: "32px 56px",
        display: "grid", gridTemplateColumns: "1fr 1fr", gap: 56,
        zIndex: 5
      }}>
        {/* Left — poster + actions */}
        <div style={{display: "flex", flexDirection: "column", justifyContent: "space-between"}}>
          <div style={{display: "flex", alignItems: "center", gap: 14}}>
            <button className="mv-iconbtn" style={focusRing(focus === "back")}>
              <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path d="M15 18l-6-6 6-6"/></svg>
            </button>
            <span style={{
              fontFamily: "var(--font-mono)", fontSize: 11,
              letterSpacing: "0.14em", color: "var(--text-dim)", textTransform: "uppercase"
            }}>{item.groupTitle} / {item.channelName}</span>
            <span style={{marginLeft: "auto", fontFamily: "var(--font-mono)", fontSize: 11,
              letterSpacing: "0.16em", color: "var(--accent)"}}>● ВАРИАНТ B — split</span>
          </div>

          <div>
            <div style={{display: "flex", gap: 8, marginBottom: 14}}>
              {prog?.isNow && <Chip kind="live">В эфире</Chip>}
              {item.program?.category && <Chip>{item.program.category}</Chip>}
            </div>
            <div style={{
              fontFamily: "var(--font-display)", fontStyle: "italic",
              fontSize: 64, lineHeight: 0.95, letterSpacing: "-0.02em",
              color: "var(--text)", marginBottom: 16
            }}>{item.program?.title || item.channelName}</div>
            {parseSynopsis(item.program?.description) && (
              <p style={{
                fontSize: 15, lineHeight: 1.5, color: "var(--text-dim)",
                marginBottom: 24, maxWidth: 540,
                display: "-webkit-box", WebkitLineClamp: 4, WebkitBoxOrient: "vertical", overflow: "hidden"
              }}>{parseSynopsis(item.program?.description)}</p>
            )}
            <div style={{display: "flex", gap: 12}}>
              <button className="mv-btn primary" style={focusRing(focus === "play")}>
                <svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor"><path d="M8 5v14l11-7z"/></svg>
                Смотреть
              </button>
              <button className="mv-btn ghost" style={focusRing(focus === "fav")}>+ Избранное</button>
            </div>
          </div>
        </div>

        {/* Right — EPG timeline (today's programs) */}
        <div>
          <div style={{
            fontFamily: "var(--font-mono)", fontSize: 10,
            letterSpacing: "0.18em", color: "var(--text-mute)",
            textTransform: "uppercase", marginBottom: 14
          }}>Сегодня в эфире →</div>
          <div style={{display: "flex", flexDirection: "column", gap: 6, position: "relative"}}>
            {todayPrograms.map((p, i) => {
              const f = focus === `epg${i}`;
              const isNow = p.state === "now";
              const isPast = p.state === "past";
              return (
                <div key={i} style={{
                  display: "grid", gridTemplateColumns: "60px 4px 1fr auto",
                  gap: 14, alignItems: "center",
                  padding: "12px 16px",
                  background: f ? "rgba(61,93,255,0.18)" : isNow ? "rgba(61,93,255,0.08)" : "transparent",
                  border: `1px solid ${f ? "var(--accent)" : isNow ? "color-mix(in oklab, var(--accent) 40%, transparent)" : "transparent"}`,
                  borderRadius: 8,
                  opacity: isPast ? 0.4 : 1,
                  transform: f ? "translateX(4px)" : "translateX(0)",
                  transition: "all 0.18s ease",
                }}>
                  <span style={{
                    fontFamily: "var(--font-mono)", fontSize: 12,
                    color: isNow ? "var(--accent)" : "var(--text-mute)",
                    letterSpacing: "0.06em"
                  }}>{p.time}</span>
                  <div style={{
                    height: 28, background: isNow ? "var(--accent)" : isPast ? "var(--text-mute)" : "var(--line-strong)",
                    borderRadius: 2
                  }}></div>
                  <div style={{
                    fontFamily: "var(--font-display)", fontSize: 18,
                    fontStyle: isNow ? "italic" : "normal",
                    color: isNow ? "var(--text)" : "var(--text-dim)",
                    lineHeight: 1.2,
                    overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap"
                  }}>{p.title}</div>
                  {isNow && (
                    <span style={{
                      fontFamily: "var(--font-mono)", fontSize: 10,
                      color: "var(--accent)", letterSpacing: "0.1em"
                    }}>NOW</span>
                  )}
                </div>
              );
            })}
          </div>
        </div>
      </div>
    </div>
  );
}

// Variant C — Minimal poster card with surrounding metadata (focus-first, TV-grid feel)
function DetailMinimal({ item }) {
  const [focus, setFocus] = useStateDV("play");
  const order = ["play", "fav", "back"];
  useEffectDV(() => {
    const onKey = (e) => {
      if (e.key === "ArrowRight" || e.key === "ArrowLeft") {
        const i = order.indexOf(focus);
        const next = e.key === "ArrowRight" ? Math.min(order.length-1, i+1) : Math.max(0, i-1);
        setFocus(order[next]); e.preventDefault();
      }
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [focus]);

  const prog = computeProgress(item.program);
  const year = parseYear(item.program?.description);
  const idx = (item.channelId ?? 0) % 16;
  const poster = item.program?.icon || item.thumbnailUrl || buildBackdrop(idx);

  return (
    <div style={{
      position: "relative", width: "100%", aspectRatio: "16/9",
      background: "var(--bg)", overflow: "hidden",
      display: "grid", placeItems: "center"
    }}>
      <div style={{
        position: "absolute", inset: 0,
        backgroundImage: `url(${poster})`,
        backgroundSize: "cover", filter: "blur(80px) brightness(0.3) saturate(1.4)", transform: "scale(1.3)"
      }}></div>

      <div style={{
        position: "absolute", top: 32, left: 56, right: 56, zIndex: 5,
        display: "flex", alignItems: "center", gap: 14
      }}>
        <button className="mv-iconbtn" style={focusRing(focus === "back")}>
          <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path d="M15 18l-6-6 6-6"/></svg>
        </button>
        <span style={{
          fontFamily: "var(--font-mono)", fontSize: 11,
          letterSpacing: "0.14em", color: "var(--text-dim)", textTransform: "uppercase"
        }}>{item.channelName}</span>
        <span style={{marginLeft: "auto", fontFamily: "var(--font-mono)", fontSize: 11,
          letterSpacing: "0.16em", color: "var(--accent)"}}>● ВАРИАНТ C — minimal</span>
      </div>

      <div style={{position: "relative", zIndex: 5, display: "flex", gap: 56, alignItems: "center", maxWidth: 1200}}>
        {/* Big floating poster */}
        <div style={{
          width: 360, height: 510, borderRadius: 12, overflow: "hidden",
          boxShadow: "0 60px 100px rgba(0,0,0,0.7), 0 0 0 1px var(--line)",
          flexShrink: 0
        }}>
          <img src={poster} style={{width: "100%", height: "100%", objectFit: "cover"}}/>
        </div>

        {/* Side info */}
        <div style={{maxWidth: 540}}>
          <div style={{display: "flex", gap: 8, marginBottom: 22}}>
            {prog?.isNow && <Chip kind="live">В эфире</Chip>}
            {item.program?.category && <Chip>{item.program.category}</Chip>}
            <Chip kind="ghost">HD</Chip>
          </div>

          <div style={{
            fontFamily: "var(--font-display)", fontStyle: "italic",
            fontSize: 56, lineHeight: 0.95, letterSpacing: "-0.02em",
            color: "var(--text)", marginBottom: 14
          }}>{item.program?.title || item.channelName}</div>

          <div style={{
            fontFamily: "var(--font-mono)", fontSize: 12,
            letterSpacing: "0.14em", color: "var(--text-mute)",
            textTransform: "uppercase", marginBottom: 22,
            display: "flex", gap: 16
          }}>
            {year && <span>{year}</span>}
            <span>{item.channelName}</span>
            {prog?.isNow && <span style={{color: "var(--accent)"}}>● NOW</span>}
          </div>

          {prog?.isNow && item.program && (
            <div style={{marginBottom: 28, maxWidth: 420}}>
              <div className="mv-track" style={{marginBottom: 8}}><i style={{width: `${Math.round(prog.progress*100)}%`}}></i></div>
              <div className="mv-ticks">
                <span>{new Date(item.program.start).toLocaleTimeString("ru-RU",{hour:"2-digit",minute:"2-digit"})}</span>
                <span style={{color: "var(--text-dim)"}}>ещё {prog.remainingMin} мин</span>
                <span>{new Date(item.program.end).toLocaleTimeString("ru-RU",{hour:"2-digit",minute:"2-digit"})}</span>
              </div>
            </div>
          )}

          <div style={{display: "flex", gap: 12}}>
            <button className="mv-btn primary" style={focusRing(focus === "play")}>
              <svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor"><path d="M8 5v14l11-7z"/></svg>
              Смотреть
            </button>
            <button className="mv-btn ghost" style={focusRing(focus === "fav")}>+ Избранное</button>
          </div>
        </div>
      </div>
    </div>
  );
}

window.DetailFullBleed = DetailFullBleed;
window.DetailSplit = DetailSplit;
window.DetailMinimal = DetailMinimal;
