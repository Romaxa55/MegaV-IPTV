/* EPG — TV programming grid */

function ScreenEPG() {
  const hours = ["02:00","03:00","04:00","05:00","06:00","07:00","08:00","09:00"];
  const nowPos = 0.6; // 02:36 between 02:00 and 03:00 → first column 60%
  const channels = CHANNELS.slice(0, 9);

  // schedule: per-channel array of {start (column index 0..7), span, title, idx, live}
  const grid = [
    [{s:0, sp:1.5, idx:11, live:true},{s:1.5, sp:2, idx:3},{s:3.5, sp:1.5, idx:7},{s:5, sp:2, idx:14},{s:7, sp:1, idx:0}],
    [{s:0, sp:2, idx:1},{s:2, sp:1, idx:5, live:true},{s:3, sp:2, idx:9},{s:5, sp:2, idx:12},{s:7, sp:1, idx:6}],
    [{s:0, sp:1, idx:4},{s:1, sp:2.5, idx:10, live:true},{s:3.5, sp:1.5, idx:2},{s:5, sp:1.5, idx:8},{s:6.5, sp:1.5, idx:15}],
    [{s:0, sp:2.5, idx:13, live:true},{s:2.5, sp:1.5, idx:0},{s:4, sp:2, idx:11},{s:6, sp:2, idx:7}],
    [{s:0, sp:1.5, idx:6},{s:1.5, sp:1.5, idx:14, live:true},{s:3, sp:2, idx:1},{s:5, sp:1.5, idx:3},{s:6.5, sp:1.5, idx:5}],
    [{s:0, sp:2, idx:2},{s:2, sp:2, idx:9, live:true},{s:4, sp:1, idx:12},{s:5, sp:2, idx:0},{s:7, sp:1, idx:4}],
    [{s:0, sp:1, idx:8},{s:1, sp:2, idx:7, live:true},{s:3, sp:1.5, idx:13},{s:4.5, sp:2, idx:11},{s:6.5, sp:1.5, idx:6}],
    [{s:0, sp:2.5, idx:5},{s:2.5, sp:1, idx:1, live:true},{s:3.5, sp:2.5, idx:14},{s:6, sp:2, idx:9}],
    [{s:0, sp:1.5, idx:10},{s:1.5, sp:1, idx:4, live:true},{s:2.5, sp:2.5, idx:8},{s:5, sp:1.5, idx:2},{s:6.5, sp:1.5, idx:13}],
  ];

  const colW = 175;
  const chW = 220;
  const rowH = 78;

  return (
    <div className="mv-art mv-grain" style={{minHeight: 1000}}>
      <Header />

      <div style={{padding: "8px 56px 16px"}}>
        <div style={{display:"flex", alignItems:"baseline", gap: 18, borderBottom: "1px solid var(--line)", paddingBottom: 16, marginBottom: 16}}>
          <div style={{fontFamily:"var(--font-display)", fontStyle:"italic", fontSize:56, lineHeight:1}}>Программа <em style={{color:"var(--text-dim)"}}>передач</em></div>
          <div style={{flex:1}}></div>
          <div style={{display: "flex", gap: 8, alignItems:"center"}}>
            <button className="mv-btn ghost">9 МАЯ · СБ</button>
            <button className="mv-btn ghost">10 МАЯ · ВС</button>
            <button className="mv-btn primary">Сегодня · 9 МАЯ</button>
            <button className="mv-btn ghost">11 МАЯ · ПН</button>
            <button className="mv-btn ghost">12 МАЯ · ВТ</button>
          </div>
        </div>

        <div style={{display: "flex", gap: 20, alignItems: "center", marginBottom: 14}}>
          <div style={{display:"flex", gap: 8}}>
            <Chip kind="brand">Все</Chip>
            <Chip kind="ghost">Кино</Chip>
            <Chip kind="ghost">Сериалы</Chip>
            <Chip kind="ghost">Спорт</Chip>
            <Chip kind="ghost">Док.</Chip>
            <Chip kind="ghost">Дети</Chip>
          </div>
          <div style={{flex:1}}></div>
          <RemoteHint items={[
            {k:"←→", label:"время"},
            {k:"↑↓", label:"канал"},
            {k:"OK", label:"открыть"},
          ]}/>
        </div>
      </div>

      {/* Grid */}
      <div style={{padding: "0 56px"}}>
        <div style={{
          background: "var(--surface)",
          border: "1px solid var(--line)",
          borderRadius: "var(--r-md)",
          overflow: "hidden"
        }}>
          {/* Time header */}
          <div style={{
            display: "grid",
            gridTemplateColumns: `${chW}px repeat(${hours.length}, ${colW}px)`,
            borderBottom: "1px solid var(--line)",
            position: "relative"
          }}>
            <div style={{padding: "14px 18px", fontFamily: "var(--font-mono)", fontSize: 11, letterSpacing: "0.16em", color: "var(--text-mute)"}}>КАНАЛ</div>
            {hours.map(h => (
              <div key={h} style={{
                padding: "14px 14px",
                fontFamily: "var(--font-mono)", fontSize: 12,
                color: "var(--text-dim)", letterSpacing: "0.1em",
                borderLeft: "1px solid var(--line)"
              }}>{h}</div>
            ))}
          </div>

          {/* Rows */}
          <div style={{position: "relative"}}>
            {channels.map((ch, ri) => (
              <div key={ri} style={{
                display: "grid",
                gridTemplateColumns: `${chW}px 1fr`,
                borderBottom: "1px solid var(--line)",
                minHeight: rowH
              }}>
                <div style={{
                  display: "flex", alignItems: "center", gap: 12,
                  padding: "10px 18px",
                  borderRight: "1px solid var(--line)"
                }}>
                  <div style={{
                    width: 44, height: 44, borderRadius: 6,
                    background: `linear-gradient(135deg, ${POSTER_PALETTES[ri][1]}, ${POSTER_PALETTES[ri][2]})`,
                    display: "grid", placeItems: "center",
                    fontFamily: "var(--font-mono)", fontSize: 11, fontWeight: 700, color: "white"
                  }}>{String(ri+1).padStart(2,"0")}</div>
                  <div style={{minWidth:0}}>
                    <div style={{fontSize: 13, fontWeight: 500, whiteSpace:"nowrap", overflow:"hidden", textOverflow:"ellipsis"}}>{ch.name}</div>
                    <div style={{fontSize: 11, color: "var(--text-mute)"}}>{ch.cat}</div>
                  </div>
                </div>
                <div style={{
                  display: "grid",
                  gridTemplateColumns: `repeat(${hours.length}, ${colW}px)`,
                  position: "relative"
                }}>
                  {/* tick lines */}
                  {hours.map((_, i) => (
                    <div key={i} style={{borderLeft: i ? "1px solid var(--line)" : "none"}}></div>
                  ))}
                  {/* shows positioned absolutely */}
                  {grid[ri].map((sh, si) => {
                    const t = TITLES[sh.idx];
                    const focused = ri === 1 && si === 1;
                    return (
                      <div key={si} style={{
                        position: "absolute",
                        left: sh.s * colW + 4,
                        width: sh.sp * colW - 8,
                        top: 6, bottom: 6,
                        background: sh.live ? "var(--accent-soft)" : "rgba(255,255,255,0.03)",
                        border: `1px solid ${focused ? "var(--accent)" : (sh.live ? "var(--accent-soft)" : "var(--line)")}`,
                        outline: focused ? "2px solid var(--accent)" : "none",
                        outlineOffset: focused ? 1 : 0,
                        borderRadius: 8,
                        padding: "8px 12px",
                        overflow: "hidden",
                        display: "flex", flexDirection: "column", justifyContent: "space-between"
                      }}>
                        <div>
                          <div style={{fontFamily: "var(--font-display)", fontStyle: "italic", fontSize: 15, lineHeight: 1.05, whiteSpace:"nowrap", overflow: "hidden", textOverflow: "ellipsis"}}>{t.t}</div>
                          <div style={{fontFamily: "var(--font-mono)", fontSize: 9, color: "var(--text-mute)", letterSpacing: "0.1em", marginTop: 4, textTransform: "uppercase"}}>{t.g} · {t.d}</div>
                        </div>
                        {sh.live && <Chip kind="live">Live</Chip>}
                      </div>
                    );
                  })}
                </div>
              </div>
            ))}

            {/* NOW marker */}
            <div style={{
              position: "absolute",
              left: chW + nowPos * colW,
              top: 0, bottom: 0, width: 2,
              background: "var(--accent)",
              boxShadow: "0 0 18px var(--accent-glow)",
              zIndex: 5
            }}>
              <div style={{
                position: "absolute", top: -1, left: -22,
                background: "var(--accent)", color: "white",
                fontFamily: "var(--font-mono)", fontSize: 10,
                padding: "3px 8px", borderRadius: 4,
                letterSpacing: "0.1em", whiteSpace: "nowrap"
              }}>СЕЙЧАС · 02:36</div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

window.ScreenEPG = ScreenEPG;
