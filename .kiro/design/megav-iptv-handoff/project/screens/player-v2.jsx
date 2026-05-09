/* Player — full-bleed video with cinematic glass controls.
   D-pad: ←→ scrub / channel-deck, ↓ open controls, OK play/pause, BACK exit. */

const { useState: useStateP, useEffect: useEffectP, useRef: useRefP } = React;

function PlayerScreen({ item, deck = [] }) {
  const [focus, setFocus] = useStateP("play");
  const [showControls, setShowControls] = useStateP(true);
  const [isPlaying, setIsPlaying] = useStateP(true);
  const order = ["back", "play", "next", "audio", "subs", "info", "channels"];

  useEffectP(() => {
    const onKey = (e) => {
      if (e.key === "ArrowRight" || e.key === "ArrowLeft") {
        const i = order.indexOf(focus);
        const next = e.key === "ArrowRight" ? Math.min(order.length-1, i+1) : Math.max(0, i-1);
        setFocus(order[next]); e.preventDefault();
      }
      if (e.key === " " || e.key === "Enter") {
        if (focus === "play") setIsPlaying(v => !v);
        e.preventDefault();
      }
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [focus]);

  const prog = computeProgress(item.program);
  const idx = (item.channelId ?? 0) % 16;
  const poster = item.program?.icon || item.thumbnailUrl || buildBackdrop(idx);
  const fmt = (iso) => new Date(iso).toLocaleTimeString("ru-RU", {hour:"2-digit",minute:"2-digit"});

  return (
    <div style={{position: "relative", width: "100%", aspectRatio: "16/9", overflow: "hidden", background: "#000"}}>
      {/* Video stand-in: poster + slow ken-burns */}
      <img src={poster} style={{
        position: "absolute", inset: 0, width: "100%", height: "100%",
        objectFit: "cover",
        animation: "kenburns 30s ease-in-out infinite alternate"
      }}/>
      <style>{`@keyframes kenburns { 0% {transform: scale(1.05) translate(0,0)} 100% {transform: scale(1.15) translate(-2%,-1%)} }`}</style>

      {/* Top status bar — auto-hide */}
      <div style={{
        position: "absolute", top: 0, left: 0, right: 0, padding: "24px 56px",
        background: "linear-gradient(180deg, rgba(0,0,0,0.7) 0%, transparent 100%)",
        display: "flex", alignItems: "center", gap: 14, zIndex: 5,
        opacity: showControls ? 1 : 0, transition: "opacity 0.4s ease"
      }}>
        <button className="mv-iconbtn" style={focusRing(focus === "back")}>
          <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path d="M15 18l-6-6 6-6"/></svg>
        </button>
        <Chip kind="brand"><MMLogo />&nbsp;{item.channelName}</Chip>
        {prog?.isNow && <Chip kind="live">В эфире</Chip>}
        <span style={{
          fontFamily: "var(--font-display)", fontStyle: "italic",
          fontSize: 22, color: "#fff", marginLeft: 8,
          textShadow: "0 2px 14px rgba(0,0,0,0.7)"
        }}>{item.program?.title}</span>
        <span style={{marginLeft: "auto", fontFamily: "var(--font-mono)", fontSize: 11,
          letterSpacing: "0.16em", color: "rgba(255,255,255,0.5)"}}>HD · 5.1 · 14 Mb/s</span>
      </div>

      {/* Channel deck — slide-in from right when "channels" focused */}
      <div style={{
        position: "absolute", right: 0, top: 0, bottom: 0, width: 360,
        background: "linear-gradient(270deg, rgba(6,8,15,0.92) 0%, rgba(6,8,15,0.7) 70%, transparent 100%)",
        backdropFilter: "blur(20px)",
        padding: "100px 24px 24px",
        zIndex: 6,
        transform: focus === "channels" ? "translateX(0)" : "translateX(100%)",
        transition: "transform 0.4s cubic-bezier(.2,.8,.2,1)",
        overflowY: "auto"
      }}>
        <div style={{
          fontFamily: "var(--font-mono)", fontSize: 10,
          letterSpacing: "0.18em", color: "rgba(255,255,255,0.5)",
          textTransform: "uppercase", marginBottom: 16
        }}>Каналы · что идёт</div>
        <div style={{display: "flex", flexDirection: "column", gap: 8}}>
          {deck.slice(0, 6).map((it, i) => {
            const p = computeProgress(it.program);
            const active = it.channelId === item.channelId;
            return (
              <div key={`${it.channelId}-${i}`} style={{
                display: "flex", gap: 10, padding: 8,
                borderRadius: 8,
                background: active ? "var(--accent-soft)" : "rgba(255,255,255,0.04)",
                border: `1px solid ${active ? "var(--accent)" : "transparent"}`
              }}>
                <div style={{width: 64, height: 40, borderRadius: 4, overflow: "hidden", flexShrink: 0,
                  background: `url(${it.program?.icon || it.thumbnailUrl || buildBackdrop((it.channelId??i)%16)}) center/cover`}}></div>
                <div style={{minWidth: 0, flex: 1}}>
                  <div style={{fontSize: 12, color: "#fff", fontWeight: 600,
                    overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap"}}>{it.channelName}</div>
                  <div style={{fontSize: 11, color: "rgba(255,255,255,0.55)", fontStyle: "italic",
                    overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap"}}>{it.program?.title || "—"}</div>
                  {p?.isNow && (
                    <div style={{height: 2, background: "rgba(255,255,255,0.1)", borderRadius: 1, marginTop: 4}}>
                      <div style={{width: `${Math.round(p.progress*100)}%`, height: "100%", background: "var(--accent)", borderRadius: 1}}></div>
                    </div>
                  )}
                </div>
              </div>
            );
          })}
        </div>
      </div>

      {/* Bottom controls — glass panel */}
      <div style={{
        position: "absolute", bottom: 0, left: 0, right: 0,
        background: "linear-gradient(0deg, rgba(0,0,0,0.85) 0%, rgba(0,0,0,0.4) 60%, transparent 100%)",
        padding: "60px 56px 32px",
        zIndex: 5,
        opacity: showControls ? 1 : 0, transition: "opacity 0.4s ease"
      }}>
        {/* EPG progress with anchor times */}
        {prog?.isNow && item.program && (
          <div style={{marginBottom: 18}}>
            <div style={{
              display: "flex", justifyContent: "space-between",
              fontFamily: "var(--font-mono)", fontSize: 10,
              letterSpacing: "0.14em", color: "rgba(255,255,255,0.6)",
              textTransform: "uppercase", marginBottom: 8
            }}>
              <span>{fmt(item.program.start)} · {item.program.title}</span>
              <span style={{color: "var(--accent)"}}>NOW · {new Date().toLocaleTimeString("ru-RU",{hour:"2-digit",minute:"2-digit"})} · ещё {prog.remainingMin} мин</span>
              <span>{fmt(item.program.end)} · следующий</span>
            </div>
            <div style={{
              position: "relative", height: 4, background: "rgba(255,255,255,0.18)", borderRadius: 2
            }}>
              <div style={{
                position: "absolute", left: 0, top: 0, bottom: 0,
                width: `${Math.round(prog.progress*100)}%`,
                background: "var(--accent)", borderRadius: 2,
                boxShadow: "0 0 12px var(--accent-glow)"
              }}></div>
              <div style={{
                position: "absolute", left: `${Math.round(prog.progress*100)}%`,
                top: "50%", transform: "translate(-50%, -50%)",
                width: 14, height: 14, borderRadius: "50%",
                background: "var(--accent)", border: "2px solid #fff",
                boxShadow: "0 0 16px var(--accent-glow)"
              }}></div>
            </div>
          </div>
        )}

        {/* Control row */}
        <div style={{display: "flex", alignItems: "center", gap: 12, flexWrap: "wrap"}}>
          <button className="mv-btn primary" style={{...focusRing(focus === "play"), padding: "16px 24px"}}>
            {isPlaying ? (
              <svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor"><path d="M6 4h4v16H6zM14 4h4v16h-4z"/></svg>
            ) : (
              <svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor"><path d="M8 5v14l11-7z"/></svg>
            )}
            {isPlaying ? "Пауза (OK)" : "Играть (OK)"}
          </button>
          <button className="mv-btn ghost" style={focusRing(focus === "next")}>
            <svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor"><path d="M6 18l8.5-6L6 6v12zM16 6h2v12h-2z"/></svg>
            Следующий
          </button>
          <button className="mv-btn ghost" style={focusRing(focus === "audio")}>RU · Stereo</button>
          <button className="mv-btn ghost" style={focusRing(focus === "subs")}>Субтитры выкл</button>
          <button className="mv-btn ghost" style={focusRing(focus === "info")}>i Подробно</button>
          <div style={{flex: 1}}></div>
          <button className="mv-btn ghost" style={focusRing(focus === "channels")}>
            <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path d="M3 6h18M3 12h18M3 18h18"/></svg>
            Каналы
          </button>
        </div>

        {/* D-pad hint */}
        <div style={{
          marginTop: 20, display: "flex", gap: 22,
          fontFamily: "var(--font-mono)", fontSize: 10,
          letterSpacing: "0.16em", color: "rgba(255,255,255,0.45)",
          textTransform: "uppercase"
        }}>
          <span><kbd style={kbdSt}>←</kbd> <kbd style={kbdSt}>→</kbd> между кнопок</span>
          <span><kbd style={kbdSt}>OK</kbd> Пауза/Играть</span>
          <span><kbd style={kbdSt}>↑</kbd> Скрыть панель</span>
          <span><kbd style={kbdSt}>BACK</kbd> Выйти</span>
        </div>
      </div>
    </div>
  );
}

window.PlayerScreen = PlayerScreen;
