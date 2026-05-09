/* Player with controls overlay + side channel deck */

function ScreenPlayer() {
  const idx = 11;
  const t = TITLES[idx];

  return (
    <div className="mv-art" style={{minHeight: 1080, background: "#000"}}>
      {/* "Video" plate */}
      <div style={{
        position: "absolute", inset: 0,
        backgroundImage: `url(${buildBackdrop(idx, 1920, 1080)})`,
        backgroundSize: "cover", backgroundPosition: "center"
      }}></div>
      <div style={{
        position: "absolute", inset: 0,
        background: "radial-gradient(70% 60% at 50% 45%, transparent 30%, rgba(0,0,0,0.7) 100%)"
      }}></div>

      {/* Top overlay */}
      <div style={{
        position: "relative", zIndex: 10,
        display: "flex", justifyContent: "space-between", alignItems: "center",
        padding: "28px 56px"
      }}>
        <div style={{display: "flex", alignItems: "center", gap: 14}}>
          <button className="mv-iconbtn">
            <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path d="M15 18l-6-6 6-6"/></svg>
          </button>
          <Chip kind="live">В эфире</Chip>
          <Chip kind="brand"><MMLogo /> &nbsp;MM Classic HD</Chip>
          <span style={{fontFamily: "var(--font-mono)", fontSize: 12, color: "var(--text-dim)", letterSpacing: "0.12em"}}>HD · 5.1 · RU</span>
        </div>
        <div style={{display: "flex", gap: 10}}>
          <button className="mv-iconbtn"><svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path d="M11 5L6 9H2v6h4l5 4V5zM19 12a4 4 0 0 0-4-4M22 12a7 7 0 0 0-7-7"/></svg></button>
          <button className="mv-iconbtn"><svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><rect x="2" y="6" width="14" height="12" rx="2"/><path d="M22 8l-6 4 6 4z"/></svg></button>
          <button className="mv-iconbtn"><svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path d="M3 7V3h4M21 7V3h-4M3 17v4h4M21 17v4h-4"/></svg></button>
        </div>
      </div>

      {/* Center spacer */}
      <div style={{flex: 1, height: 380}}></div>

      {/* Bottom: title bar + Up-Next rail (no buttons) */}
      <div style={{
        position: "absolute", left: 56, right: 56, bottom: 36,
        zIndex: 10,
        display: "flex", flexDirection: "column", gap: 22
      }}>
        {/* Title strip with thin scrubber */}
        <div>
          <div style={{display: "flex", justifyContent: "space-between", alignItems: "flex-end", marginBottom: 14}}>
            <div>
              <div style={{display: "flex", gap: 8, marginBottom: 10}}>
                <Chip kind="live">Live</Chip>
                <Chip kind="ghost">Эпизод 04 · S03</Chip>
              </div>
              <div style={{fontFamily: "var(--font-display)", fontStyle: "italic", fontSize: 44, lineHeight: 1, letterSpacing: "-0.01em"}}>{t.t}</div>
              <div style={{fontFamily: "var(--font-mono)", fontSize: 11, color: "var(--text-dim)", letterSpacing: "0.14em", marginTop: 10, textTransform: "uppercase"}}>{t.y} · {t.g} · ОСТАЛОСЬ 55 МИН · ДО 03:59</div>
            </div>
            <div style={{display: "flex", flexDirection: "column", alignItems: "flex-end", gap: 10}}>
              <span style={{fontFamily: "var(--font-mono)", fontSize: 12, color: "var(--text)", letterSpacing: "0.12em"}}>02:45 <span style={{color:"var(--text-mute)"}}>/ 03:59</span></span>
              <RemoteHint items={[
                {k: "OK", label: "пауза"},
                {k: "←→", label: "−10 / +10"},
                {k: "↑↓", label: "канал"},
              ]}/>
            </div>
          </div>
          <div className="mv-track" style={{height: 3}}><i style={{width: "62%"}}></i></div>
        </div>

        {/* Channels tile — switch to another channel without leaving */}
        <div>
          <div style={{
            display: "flex", justifyContent: "space-between", alignItems: "baseline",
            marginBottom: 12
          }}>
            <div style={{fontFamily: "var(--font-mono)", fontSize: 11, letterSpacing: "0.16em", color: "var(--text-dim)", textTransform: "uppercase"}}>Сейчас на других каналах</div>
            <div style={{fontFamily: "var(--font-mono)", fontSize: 10, letterSpacing: "0.14em", color: "var(--text-mute)"}}><span className="mv-key">↔</span>&nbsp;&nbsp;OK — переключить&nbsp;&nbsp;·&nbsp;&nbsp;<span className="mv-key">▦</span>&nbsp;&nbsp;все 124</div>
          </div>
          <div style={{display: "grid", gridTemplateColumns: "repeat(5, 1fr)", gap: 12}}>
            {[
              {ch: "MM Drama",   t: 14, prog: 0.42, focused: true},
              {ch: "MM Noir",    t: 18, prog: 0.78, focused: false},
              {ch: "MM Pulse",   t:  7, prog: 0.15, focused: false},
              {ch: "MM Doku",    t: 22, prog: 0.61, focused: false},
              {ch: "MM Late",    t:  3, prog: 0.30, focused: false},
            ].map((c, i) => {
              const tu = TITLES[c.t % TITLES.length];
              return (
                <div key={i} style={{
                  border: c.focused ? "1px solid rgba(244,241,233,0.45)" : "1px solid var(--line)",
                  borderRadius: 12,
                  background: "rgba(10,10,14,0.55)",
                  backdropFilter: "blur(28px)",
                  WebkitBackdropFilter: "blur(28px)",
                  overflow: "hidden",
                  outline: c.focused ? "3px solid rgba(244,241,233,0.18)" : "none",
                  outlineOffset: 2
                }}>
                  {/* Poster cover */}
                  <div style={{
                    aspectRatio: "16/9",
                    backgroundImage: `url(${buildBackdrop(c.t, 480, 270)})`,
                    backgroundSize: "cover", backgroundPosition: "center",
                    position: "relative"
                  }}>
                    <div style={{
                      position: "absolute", inset: 0,
                      background: "linear-gradient(180deg, rgba(0,0,0,0.0) 40%, rgba(0,0,0,0.78) 100%)"
                    }}></div>
                    <div style={{
                      position: "absolute", left: 10, top: 10,
                      display: "inline-flex", alignItems: "center", gap: 6,
                      padding: "3px 8px",
                      background: "rgba(0,0,0,0.55)",
                      backdropFilter: "blur(10px)",
                      border: "1px solid rgba(255,255,255,0.14)",
                      borderRadius: 999,
                      fontFamily: "var(--font-mono)", fontSize: 9, letterSpacing: "0.14em", textTransform: "uppercase"
                    }}>
                      <MMLogo />&nbsp;{c.ch}
                    </div>
                    <div style={{
                      position: "absolute", left: 10, right: 10, bottom: 8
                    }}>
                      <div style={{height: 2, background: "rgba(255,255,255,0.16)", borderRadius: 2, overflow: "hidden"}}>
                        <div style={{height: "100%", width: `${c.prog*100}%`, background: c.focused ? "var(--text)" : "rgba(244,241,233,0.62)"}}></div>
                      </div>
                    </div>
                  </div>
                  {/* Meta */}
                  <div style={{padding: "10px 12px 12px"}}>
                    <div style={{fontFamily: "var(--font-display)", fontStyle: "italic", fontSize: 16, lineHeight: 1.1, whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis"}}>{tu.t}</div>
                    <div style={{fontFamily: "var(--font-mono)", fontSize: 9, color: "var(--text-mute)", letterSpacing: "0.12em", marginTop: 6, textTransform: "uppercase", whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis"}}>{tu.y} · {tu.g}</div>
                  </div>
                </div>
              );
            })}
          </div>
        </div>
      </div>
    </div>
  );
}

window.ScreenPlayer = ScreenPlayer;
