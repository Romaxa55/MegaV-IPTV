/* EPG v2 — TV programming grid with editorial dark style.
   Uses data layer (loadFeatured) for current-program-per-channel and synthesises
   adjacent slots so the grid feels alive. D-pad: ←→ time / ↑↓ channel / OK open. */

const { useState: useStateE, useEffect: useEffectE, useMemo: useMemoE, useRef: useRefE } = React;

/* ---------- Helpers ---------- */

const SLOT_MIN = 30;          // minutes per column
const SLOT_W = 180;           // px per 30-min slot (wider — names readable)
const SLOTS = 10;             // 10 × 30min = 5 hours window
const ROW_H = 88;             // px per channel row
const CH_W  = 240;            // channel column width

const fmtHM = (d) => d.toLocaleTimeString("ru-RU", { hour: "2-digit", minute: "2-digit" });

// Floor to 30-min mark; NOW lands ~10% in (small lookback so прошедшее не теряется).
function gridStart() {
  const d = new Date();
  d.setSeconds(0, 0);
  d.setMinutes(d.getMinutes() < 30 ? 0 : 30);
  d.setMinutes(d.getMinutes() - 30); // back off 30 min
  return d;
}

// Position helpers (within scroll area, NOT including channel column).
function minsFrom(start, t) { return (t - start) / 60_000; }
function xFromMins(m) { return (m / SLOT_MIN) * SLOT_W; }

// Build a row of programs for a channel: anchor with the live program (from data layer),
// then synthesise neighbours from a title pool to fill the visible window.
function buildRow(channel, pool, gStart, gEnd, slotIdx) {
  const out = [];
  const live = channel.program;
  if (!live) return out;
  const liveStart = new Date(live.start);
  const liveEnd   = new Date(live.end);

  // Live block.
  out.push({
    id: `live-${channel.channelId}`,
    title: live.title,
    category: live.category,
    start: liveStart,
    end: liveEnd,
    isLive: true,
    icon: live.icon,
  });

  // Backwards.
  let cursor = new Date(liveStart);
  let i = slotIdx + 1;
  while (cursor > gStart) {
    const dur = 30 + ((i * 7) % 4) * 30;          // 30..120 min
    const s = new Date(cursor.getTime() - dur * 60_000);
    const item = pool[(i * 3 + 1) % pool.length];
    out.unshift({
      id: `b-${channel.channelId}-${i}`,
      title: item.program.title,
      category: item.program.category,
      start: s, end: cursor,
      isLive: false,
      icon: item.program.icon,
    });
    cursor = s;
    i++;
  }

  // Forwards.
  cursor = new Date(liveEnd);
  i = slotIdx + 5;
  while (cursor < gEnd) {
    const dur = 30 + ((i * 11) % 4) * 30;
    const e = new Date(cursor.getTime() + dur * 60_000);
    const item = pool[(i * 5 + 2) % pool.length];
    out.push({
      id: `f-${channel.channelId}-${i}`,
      title: item.program.title,
      category: item.program.category,
      start: cursor, end: e,
      isLive: false,
      icon: item.program.icon,
    });
    cursor = e;
    i++;
  }
  return out;
}

/* ---------- Subcomponents ---------- */

function DayPicker({ value, onChange }) {
  const days = useMemoE(() => {
    const today = new Date(); today.setHours(0,0,0,0);
    return [-2,-1,0,1,2,3,4].map(off => {
      const d = new Date(today);
      d.setDate(d.getDate() + off);
      return d;
    });
  }, []);
  const wd = ["ВС","ПН","ВТ","СР","ЧТ","ПТ","СБ"];
  return (
    <div style={{display: "flex", gap: 6, alignItems: "center"}}>
      {days.map((d, i) => {
        const today = new Date(); today.setHours(0,0,0,0);
        const isToday = d.getTime() === today.getTime();
        const active = i === value;
        return (
          <button
            key={i}
            onClick={() => onChange(i)}
            className={`mv-btn ${active ? "primary" : "ghost"}`}
            style={{
              padding: "10px 14px",
              fontSize: 12, fontWeight: active ? 600 : 500,
              minWidth: 76,
              flexDirection: "column", gap: 2,
              fontFamily: "var(--font-mono)", letterSpacing: "0.1em",
            }}>
            <span style={{fontSize: 10, opacity: 0.7}}>{isToday ? "СЕГОДНЯ" : wd[d.getDay()]}</span>
            <span>{String(d.getDate()).padStart(2,"0")}.{String(d.getMonth()+1).padStart(2,"0")}</span>
          </button>
        );
      })}
    </div>
  );
}

function CategoryFilter({ value, onChange, options }) {
  return (
    <div style={{display: "flex", gap: 8, flexWrap: "wrap"}}>
      {options.map((c) => {
        const active = c === value;
        return (
          <button
            key={c}
            onClick={() => onChange(c)}
            style={{
              padding: "8px 14px",
              borderRadius: 999,
              fontFamily: "var(--font-ui)", fontSize: 12, fontWeight: 500,
              background: active ? "var(--text)" : "transparent",
              color: active ? "var(--bg)" : "var(--text-dim)",
              border: `1px solid ${active ? "var(--text)" : "var(--line)"}`,
              cursor: "pointer", letterSpacing: "0.005em",
            }}>{c}</button>
        );
      })}
    </div>
  );
}

function ProgramCell({ p, gStart, focused, isCurrent }) {
  const x = xFromMins(minsFrom(gStart, p.start));
  const w = xFromMins((p.end - p.start) / 60_000) - 4;
  const live = p.isLive;
  const dur = Math.round((p.end - p.start) / 60_000);
  return (
    <div
      data-program-id={p.id}
      style={{
        position: "absolute",
        left: x + 2, top: 6, bottom: 6,
        width: Math.max(40, w),
        padding: "10px 12px",
        borderRadius: 10,
        overflow: "hidden",
        background: focused
          ? "var(--text)"
          : live
            ? "rgba(110,86,247,0.18)"
            : "rgba(244,241,233,0.04)",
        color: focused ? "var(--bg)" : "var(--text)",
        border: `1px solid ${focused ? "var(--text)" : live ? "rgba(110,86,247,0.55)" : "var(--line)"}`,
        boxShadow: focused
          ? "0 12px 32px rgba(0,0,0,0.45)"
          : live ? "0 0 0 1px rgba(110,86,247,0.10) inset" : "none",
        transition: "background .14s ease, transform .14s ease",
        transform: focused ? "translateY(-1px)" : "none",
        cursor: "pointer",
        display: "flex", flexDirection: "column", justifyContent: "space-between",
      }}>
      <div style={{minWidth: 0}}>
        <div style={{
          fontFamily: "var(--font-ui)", fontWeight: 500,
          fontSize: 14, lineHeight: 1.15, letterSpacing: "-0.005em",
          whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis",
          color: focused ? "var(--bg)" : "var(--text)",
        }}>{p.title}</div>
        <div style={{
          fontFamily: "var(--font-mono)", fontSize: 11,
          letterSpacing: "0.14em", textTransform: "uppercase",
          marginTop: 5,
          color: focused ? "rgba(6,6,10,0.6)" : "var(--text-mute)",
          whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis",
        }}>{fmtHM(p.start)}–{fmtHM(p.end)} · {dur} мин · {p.category}</div>
      </div>
      {live && (
        <div style={{
          alignSelf: "flex-start",
          fontFamily: "var(--font-mono)", fontSize: 9, fontWeight: 600,
          letterSpacing: "0.18em", textTransform: "uppercase",
          padding: "2px 6px", borderRadius: 4,
          background: focused ? "var(--bg)" : "var(--accent)",
          color: focused ? "var(--text)" : "#fff",
        }}>● Live</div>
      )}
    </div>
  );
}

function ChannelCell({ ch, idx, focused }) {
  const cat = ch.groupTitle || "—";
  return (
    <div style={{
      width: CH_W, height: ROW_H,
      borderBottom: "1px solid var(--line)",
      borderRight: "1px solid var(--line)",
      padding: "12px 18px",
      display: "flex", alignItems: "center", gap: 12,
      background: focused ? "rgba(244,241,233,0.04)" : "transparent",
      transition: "background .14s ease",
    }}>
      <div style={{
        width: 38, height: 38, borderRadius: 8,
        flexShrink: 0,
        background: `linear-gradient(135deg, ${POSTER_PALETTES[idx % POSTER_PALETTES.length][1]}, ${POSTER_PALETTES[idx % POSTER_PALETTES.length][2]})`,
        display: "grid", placeItems: "center",
        fontFamily: "var(--font-mono)", fontWeight: 700, fontSize: 11, color: "#fff",
        letterSpacing: "0.04em",
      }}>{String(idx+1).padStart(2,"0")}</div>
      <div style={{minWidth: 0, flex: 1}}>
        <div style={{
          fontSize: 14, fontWeight: 600, color: "var(--text)",
          whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis",
          letterSpacing: "-0.005em",
        }}>{ch.channelName}</div>
        <div style={{
          fontFamily: "var(--font-mono)", fontSize: 11,
          letterSpacing: "0.14em", textTransform: "uppercase",
          color: "var(--text-mute)", marginTop: 4,
        }}>{cat}</div>
      </div>
    </div>
  );
}

/* ---------- Main screen ---------- */

function ScreenEPGv2({ channels, pool }) {
  // Time anchors.
  const gStart = useMemoE(() => gridStart(), []);
  const gEnd   = useMemoE(() => new Date(gStart.getTime() + SLOTS * SLOT_MIN * 60_000), [gStart]);

  // NOW position (recompute on tick).
  const [now, setNow] = useStateE(() => new Date());
  useEffectE(() => {
    const t = setInterval(() => setNow(new Date()), 30_000);
    return () => clearInterval(t);
  }, []);
  const nowX = xFromMins(minsFrom(gStart, now));

  // Build rows.
  const rows = useMemoE(
    () => channels.map((ch, i) => ({ ch, i, items: buildRow(ch, pool, gStart, gEnd, i) })),
    [channels, pool, gStart, gEnd],
  );

  // Focus state — start on the live program of the focused channel.
  const [focusRow, setFocusRow] = useStateE(0);
  const [focusCol, setFocusCol] = useStateE(() => {
    const items = rows[0]?.items || [];
    return Math.max(0, items.findIndex(p => p.isLive));
  });

  // Reset col when row changes — snap to live or nearest to current focus time.
  useEffectE(() => {
    const items = rows[focusRow]?.items || [];
    if (!items.length) return;
    const liveIx = items.findIndex(p => p.isLive);
    setFocusCol((c) => Math.max(0, Math.min(items.length - 1, liveIx >= 0 ? liveIx : c)));
  }, [focusRow]);

  // D-pad navigation.
  useEffectE(() => {
    const onKey = (e) => {
      const items = rows[focusRow]?.items || [];
      if (e.key === "ArrowRight") { setFocusCol(c => Math.min(items.length - 1, c + 1)); e.preventDefault(); }
      if (e.key === "ArrowLeft")  { setFocusCol(c => Math.max(0, c - 1)); e.preventDefault(); }
      if (e.key === "ArrowDown")  { setFocusRow(r => Math.min(rows.length - 1, r + 1)); e.preventDefault(); }
      if (e.key === "ArrowUp")    { setFocusRow(r => Math.max(0, r - 1)); e.preventDefault(); }
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [rows, focusRow]);

  // Auto-scroll to keep focus in view.
  const scrollRef = useRefE(null);
  useEffectE(() => {
    const el = scrollRef.current;
    if (!el) return;
    const items = rows[focusRow]?.items || [];
    const p = items[focusCol];
    if (!p) return;
    const x = xFromMins(minsFrom(gStart, p.start));
    const w = xFromMins((p.end - p.start) / 60_000);
    const pad = 80;
    if (x < el.scrollLeft + pad) el.scrollTo({ left: Math.max(0, x - pad), behavior: "smooth" });
    if (x + w > el.scrollLeft + el.clientWidth - pad)
      el.scrollTo({ left: x + w - el.clientWidth + pad, behavior: "smooth" });
  }, [focusRow, focusCol]);

  // Time tick labels (full hours bold, half hours dim).
  const ticks = useMemoE(() => {
    const arr = [];
    for (let i = 0; i <= SLOTS; i++) {
      const t = new Date(gStart.getTime() + i * SLOT_MIN * 60_000);
      arr.push({ t, isHour: t.getMinutes() === 0 });
    }
    return arr;
  }, [gStart]);

  // Featured strip (focused program preview)
  const fp = rows[focusRow]?.items[focusCol];
  const fch = rows[focusRow]?.ch;
  const fprog = fp ? computeProgress({ start: fp.start.toISOString(), end: fp.end.toISOString() }) : null;

  // Day picker
  const [day, setDay] = useStateE(2); // index 2 = today (since days go -2..+4)
  // Filter
  const cats = useMemoE(() => {
    const set = new Set(["Все"]);
    channels.forEach(c => c.groupTitle && set.add(c.groupTitle));
    return Array.from(set);
  }, [channels]);
  const [cat, setCat] = useStateE("Все");

  return (
    <div style={{
      width: "100%", minHeight: "100%",
      background: "var(--bg)", color: "var(--text)",
      fontFamily: "var(--font-ui)",
      display: "flex", flexDirection: "column",
    }}>
      {/* HEADER */}
      <div style={{padding: "32px 56px 20px", borderBottom: "1px solid var(--line)"}}>
        <div style={{display: "flex", alignItems: "flex-end", gap: 28, marginBottom: 18}}>
          <div>
            <div style={{
              fontFamily: "var(--font-mono)", fontSize: 10,
              letterSpacing: "0.22em", textTransform: "uppercase",
              color: "var(--text-mute)", marginBottom: 8,
            }}>EPG · сетка вещания</div>
            <div style={{
              fontFamily: "var(--font-display)", fontWeight: 600,
              fontSize: 56, lineHeight: 0.95, letterSpacing: "-0.025em",
            }}>Программа <span style={{color: "var(--text-dim)", fontWeight: 400}}>передач</span></div>
          </div>
          <div style={{flex: 1}}></div>
          <DayPicker value={day} onChange={setDay} />
        </div>

        <div style={{display: "flex", alignItems: "center", gap: 20}}>
          <CategoryFilter value={cat} onChange={setCat} options={cats} />
          <div style={{flex: 1}}></div>
          <div style={{
            display: "flex", gap: 18,
            fontFamily: "var(--font-mono)", fontSize: 10,
            letterSpacing: "0.16em", textTransform: "uppercase",
            color: "var(--text-mute)",
          }}>
            <span><kbd style={kbdSt}>←</kbd><kbd style={kbdSt}>→</kbd> время</span>
            <span><kbd style={kbdSt}>↑</kbd><kbd style={kbdSt}>↓</kbd> канал</span>
            <span><kbd style={kbdSt}>OK</kbd> открыть</span>
          </div>
        </div>
      </div>

      {/* GRID */}
      <div style={{display: "flex", flex: 1, position: "relative"}}>
        {/* Channel column */}
        <div style={{
          width: CH_W, flexShrink: 0,
          borderRight: "1px solid var(--line)",
          background: "var(--bg)",
        }}>
          {/* Channel header */}
          <div style={{
            height: 44, padding: "0 18px",
            display: "flex", alignItems: "center",
            borderBottom: "1px solid var(--line)",
            fontFamily: "var(--font-mono)", fontSize: 10,
            letterSpacing: "0.18em", textTransform: "uppercase",
            color: "var(--text-mute)",
          }}>Каналы · {channels.length}</div>
          {rows.map(({ ch, i }) => (
            <ChannelCell key={ch.channelId} ch={ch} idx={i} focused={focusRow === i} />
          ))}
        </div>

        {/* Time + programs scroll */}
        <div ref={scrollRef} style={{
          flex: 1, overflowX: "auto", overflowY: "hidden",
          position: "relative",
        }}>
          <div style={{width: SLOTS * SLOT_W, position: "relative"}}>
            {/* Time ruler */}
            <div style={{
              height: 44, position: "sticky", top: 0, zIndex: 4,
              background: "var(--bg)",
              borderBottom: "1px solid var(--line)",
              display: "flex",
            }}>
              {ticks.map((tk, i) => (
                <div key={i} style={{
                  width: SLOT_W, paddingLeft: 12,
                  display: "flex", alignItems: "center",
                  borderLeft: i === 0 ? "none" : `1px ${tk.isHour ? "solid" : "dashed"} var(--line)`,
                  fontFamily: "var(--font-mono)",
                  fontSize: tk.isHour ? 13 : 11,
                  fontWeight: tk.isHour ? 600 : 400,
                  letterSpacing: "0.08em",
                  color: tk.isHour ? "var(--text)" : "var(--text-mute)",
                }}>{fmtHM(tk.t)}</div>
              ))}
            </div>

            {/* Program rows */}
            {rows.map(({ ch, i, items }) => (
              <div key={ch.channelId} style={{
                position: "relative",
                height: ROW_H,
                borderBottom: "1px solid var(--line)",
                background: focusRow === i ? "rgba(244,241,233,0.025)" : "transparent",
              }}>
                {/* Slot dividers */}
                {ticks.slice(0, -1).map((tk, ti) => (
                  <div key={ti} style={{
                    position: "absolute",
                    left: ti * SLOT_W, top: 0, bottom: 0, width: 1,
                    background: ti === 0 ? "transparent" : (tk.isHour ? "var(--line)" : "transparent"),
                    borderLeft: ti > 0 && !tk.isHour ? "1px dashed rgba(244,241,233,0.04)" : "none",
                  }}></div>
                ))}
                {items.map((p, ci) => (
                  <ProgramCell
                    key={p.id}
                    p={p}
                    gStart={gStart}
                    focused={focusRow === i && focusCol === ci}
                    isCurrent={p.isLive}
                  />
                ))}
              </div>
            ))}

            {/* NOW marker */}
            <div style={{
              position: "absolute",
              left: nowX, top: 0, bottom: 0, width: 0,
              borderLeft: "2px solid var(--accent)",
              boxShadow: "0 0 18px var(--accent-glow)",
              zIndex: 6, pointerEvents: "none",
            }}>
              <div style={{
                position: "absolute", top: 8, left: 8,
                background: "var(--accent)", color: "#fff",
                fontFamily: "var(--font-mono)", fontWeight: 600,
                fontSize: 10, letterSpacing: "0.18em",
                padding: "4px 10px", borderRadius: 4,
                whiteSpace: "nowrap",
                boxShadow: "0 6px 20px var(--accent-glow)",
              }}>● СЕЙЧАС · {fmtHM(now)}</div>
            </div>
          </div>
        </div>
      </div>

      {/* PREVIEW STRIP */}
      {fp && fch && (
        <div style={{
          borderTop: "1px solid var(--line)",
          padding: "20px 56px",
          display: "flex", alignItems: "center", gap: 24,
          background: "rgba(15,15,20,0.8)",
          backdropFilter: "blur(20px)",
        }}>
          <div style={{
            width: 132, height: 76, borderRadius: 8, flexShrink: 0,
            backgroundImage: `url(${fp.icon || buildBackdrop((fch.channelId ?? 0) % 16, 480, 270)})`,
            backgroundSize: "cover", backgroundPosition: "center",
            border: "1px solid var(--line)",
          }}></div>
          <div style={{flex: 1, minWidth: 0}}>
            <div style={{
              fontFamily: "var(--font-mono)", fontSize: 10,
              letterSpacing: "0.18em", textTransform: "uppercase",
              color: "var(--text-mute)", marginBottom: 6,
              display: "flex", alignItems: "center", gap: 10,
            }}>
              <span>{fch.channelName}</span>
              <span style={{color: "var(--text-mute)"}}>·</span>
              <span>{fmtHM(fp.start)}–{fmtHM(fp.end)} · {Math.round((fp.end - fp.start)/60_000)} мин</span>
              {fp.isLive && (
                <span style={{
                  marginLeft: 4,
                  background: "var(--accent)", color: "#fff",
                  padding: "2px 8px", borderRadius: 4,
                  fontWeight: 600,
                }}>● LIVE</span>
              )}
            </div>
            <div style={{
              fontFamily: "var(--font-display)", fontWeight: 600,
              fontSize: 30, lineHeight: 1.05, letterSpacing: "-0.015em",
              whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis",
            }}>{fp.title}</div>
            {fp.isLive && fprog && (
              <div style={{marginTop: 10, display: "flex", alignItems: "center", gap: 12}}>
                <div style={{flex: 1, height: 3, background: "rgba(244,241,233,0.12)", borderRadius: 2, position: "relative"}}>
                  <div style={{
                    position: "absolute", left: 0, top: 0, bottom: 0,
                    width: `${Math.round(fprog.progress * 100)}%`,
                    background: "var(--accent)", borderRadius: 2,
                    boxShadow: "0 0 10px var(--accent-glow)",
                  }}></div>
                </div>
                <span style={{
                  fontFamily: "var(--font-mono)", fontSize: 10,
                  letterSpacing: "0.16em", color: "var(--text-mute)",
                  textTransform: "uppercase", whiteSpace: "nowrap",
                }}>ещё {fprog.remainingMin} мин</span>
              </div>
            )}
          </div>
          <div style={{display: "flex", gap: 10}}>
            <button className="mv-btn primary" style={{padding: "12px 22px"}}>
              {fp.isLive ? "Смотреть (OK)" : "Напомнить"}
            </button>
            <button className="mv-btn ghost" style={{padding: "12px 18px"}}>i Подробно</button>
          </div>
        </div>
      )}
    </div>
  );
}

window.ScreenEPGv2 = ScreenEPGv2;
