/* Search v2 — TV-grade search with on-screen keyboard, live results, recents */

const { useMemo: useM, useState: useS, useRef: useR, useEffect: useE } = React;

// Cyrillic alphabet keyboard — 6×6 grid (33 RU letters + punctuation/utility cells)
const KB_ROWS = [
  ["А","Б","В","Г","Д","Е"],
  ["Ё","Ж","З","И","Й","К"],
  ["Л","М","Н","О","П","Р"],
  ["С","Т","У","Ф","Х","Ц"],
  ["Ч","Ш","Щ","Ъ","Ы","Ь"],
  ["Э","Ю","Я","-",".","␣"],
];

// Series fixtures (search needs more breadth than featured channels)
const SEARCH_POOL = [
  { kind: "movie",   idx: 1,  title: "Северный ветер",      sub: "1985 · Триллер · 2ч 12м",   score: 7.9 },
  { kind: "series",  idx: 8,  title: "Северные саги",       sub: "Сериал · 8 эпизодов",       score: 8.2 },
  { kind: "movie",   idx: 13, title: "Северный полюс",      sub: "Док. · 2019 · 1ч 32м",      score: 7.4 },
  { kind: "movie",   idx: 14, title: "Север · Иванов",      sub: "Драма · 2003 · 1ч 56м",     score: 6.8 },
  { kind: "channel", idx: 0,  title: "MM Север Live",       sub: "Канал · 24/7 · в эфире",    score: null },
  { kind: "movie",   idx: 6,  title: "Северное побережье",  sub: "Артхаус · 1992",            score: 7.1 },
  { kind: "series",  idx: 4,  title: "Соседи",              sub: "Сериал · 24 эпизода",       score: 7.6 },
  { kind: "movie",   idx: 11, title: "Полуночное эхо",      sub: "Драма · 1979",              score: 7.0 },
];

const RECENTS = [
  "Пуаро",
  "Док. фильм",
  "Спорт сегодня",
  "Кино 90-х",
];

const SUGGESTIONS = [
  "Северный ветер",
  "Северный полюс",
  "Север · Иванов",
  "Северные саги",
  "Северное побережье",
];

// ─── Search bar ───────────────────────────────────────────────────────────
function SearchBar({ query, counts }) {
  return (
    <div style={{
      display: "flex", alignItems: "center", gap: 20,
      padding: "22px 28px",
      background: "var(--surface)",
      border: "1px solid var(--line)",
      borderRadius: 12,
    }}>
      <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="var(--text-dim)" strokeWidth="1.6">
        <circle cx="11" cy="11" r="7"/><path d="M21 21l-4.3-4.3"/>
      </svg>
      <div style={{
        flex: 1, minWidth: 0,
        fontFamily: "var(--font-ui)", fontWeight: 500,
        fontSize: 32, letterSpacing: "-0.02em",
        whiteSpace: "nowrap", overflow: "hidden",
        color: query ? "var(--text)" : "var(--text-mute)",
      }}>
        {query || "Введите запрос…"}
        <span style={{
          display: "inline-block", width: 2, height: 28,
          background: "var(--accent)", marginLeft: 4, verticalAlign: "middle",
          animation: "mvblink 1s steps(2) infinite",
        }}></span>
      </div>
      {counts.total > 0 && (
        <div style={{display: "flex", gap: 8}}>
          <CountChip n={counts.movies}   label="фильмов"  />
          <CountChip n={counts.series}   label="сериалов" />
          <CountChip n={counts.channels} label="каналов"  />
        </div>
      )}
    </div>
  );
}

function CountChip({ n, label }) {
  if (!n) return null;
  return (
    <span style={{
      display: "inline-flex", gap: 6, alignItems: "baseline",
      padding: "8px 12px",
      borderRadius: 6,
      background: "rgba(255,255,255,0.04)",
      border: "1px solid var(--line)",
      fontFamily: "var(--font-mono)", fontSize: 11,
      letterSpacing: "0.08em",
      color: "var(--text-dim)",
    }}>
      <span style={{color: "var(--text)", fontWeight: 600}}>{n}</span>
      <span style={{textTransform: "uppercase", letterSpacing: "0.16em", fontSize: 10}}>{label}</span>
    </span>
  );
}

// ─── On-screen keyboard ──────────────────────────────────────────────────
function Keyboard({ focusRow, focusCol, onKey }) {
  return (
    <div>
      <SectionLabel>Клавиатура</SectionLabel>
      <div style={{
        display: "grid",
        gridTemplateColumns: "repeat(6, 1fr)",
        gap: 6,
        marginTop: 12,
      }}>
        {KB_ROWS.flatMap((row, r) => row.map((k, c) => {
          const focused = r === focusRow && c === focusCol;
          return (
            <button key={`${r}-${c}`} onClick={() => onKey(k)} style={{
              aspectRatio: "1.15 / 1",
              border: focused ? "1px solid var(--accent)" : "1px solid var(--line)",
              outline: focused ? "2px solid var(--accent)" : "none",
              outlineOffset: focused ? 2 : 0,
              background: focused ? "var(--accent)" : "rgba(255,255,255,0.03)",
              color: focused ? "#fff" : "var(--text)",
              borderRadius: 8,
              fontFamily: "var(--font-ui)", fontWeight: 500,
              fontSize: 18, letterSpacing: "-0.005em",
              cursor: "pointer",
              transition: "all 80ms ease",
            }}>{k === "␣" ? "—" : k}</button>
          );
        }))}
      </div>

      {/* Utility row */}
      <div style={{
        display: "grid",
        gridTemplateColumns: "1fr 1fr 1fr",
        gap: 6,
        marginTop: 6,
      }}>
        <UtilKey label="Пробел" hint="0" big />
        <UtilKey label="Стереть" hint="⌫" />
        <UtilKey label="RU / EN" hint="A" />
      </div>

      {/* Hints under keyboard */}
      <div style={{
        marginTop: 16,
        display: "flex", gap: 14, flexWrap: "wrap",
        fontFamily: "var(--font-mono)", fontSize: 10,
        letterSpacing: "0.16em", textTransform: "uppercase",
        color: "var(--text-mute)",
      }}>
        <span><kbd style={kbdSt}>←↑↓→</kbd> навигация</span>
        <span><kbd style={kbdSt}>OK</kbd> ввести</span>
      </div>
    </div>
  );
}

function UtilKey({ label, hint }) {
  return (
    <div style={{
      padding: "12px 10px",
      border: "1px solid var(--line)",
      background: "rgba(255,255,255,0.02)",
      borderRadius: 8,
      display: "flex", alignItems: "center", justifyContent: "space-between",
      gap: 10,
    }}>
      <span style={{
        fontFamily: "var(--font-ui)", fontSize: 12, fontWeight: 500,
        color: "var(--text-dim)",
      }}>{label}</span>
      <span style={{
        fontFamily: "var(--font-mono)", fontSize: 12, fontWeight: 600,
        padding: "2px 8px", borderRadius: 4,
        background: "rgba(255,255,255,0.05)", color: "var(--text)",
      }}>{hint}</span>
    </div>
  );
}

// ─── Section label ───────────────────────────────────────────────────────
function SectionLabel({ children, count }) {
  return (
    <div style={{
      display: "flex", alignItems: "baseline", gap: 12,
      fontFamily: "var(--font-mono)", fontSize: 10,
      letterSpacing: "0.22em", textTransform: "uppercase",
      color: "var(--text-mute)",
    }}>
      <span>{children}</span>
      {count !== undefined && (
        <span style={{color: "var(--text-dim)", fontWeight: 600}}>{String(count).padStart(2, "0")}</span>
      )}
    </div>
  );
}

// ─── Top result (large highlighted card) ─────────────────────────────────
function TopResult({ item, focused }) {
  const t = TITLES[item.idx % TITLES.length];
  return (
    <div style={{
      display: "grid", gridTemplateColumns: "180px 1fr",
      gap: 22, padding: 18,
      background: focused ? "rgba(36,80,222,0.1)" : "var(--surface)",
      border: focused ? "1px solid var(--accent)" : "1px solid var(--line)",
      outline: focused ? "2px solid var(--accent)" : "none",
      outlineOffset: focused ? 2 : 0,
      borderRadius: 12,
    }}>
      <img src={buildPoster(item.idx, {showText: false})} alt=""
        style={{width: 180, height: 256, objectFit: "cover", borderRadius: 8, display: "block"}}/>
      <div style={{minWidth: 0, display: "flex", flexDirection: "column", gap: 10}}>
        <div style={{display: "flex", gap: 8}}>
          <span style={{
            padding: "4px 10px", borderRadius: 4,
            background: "var(--accent)", color: "#fff",
            fontFamily: "var(--font-mono)", fontWeight: 600,
            fontSize: 10, letterSpacing: "0.18em",
          }}>ЛУЧШИЙ РЕЗУЛЬТАТ</span>
          <span style={{
            padding: "4px 10px", borderRadius: 4,
            background: "rgba(255,255,255,0.05)", color: "var(--text-dim)",
            fontFamily: "var(--font-mono)", fontWeight: 600,
            fontSize: 10, letterSpacing: "0.18em", textTransform: "uppercase",
          }}>{item.kind === "series" ? "Сериал" : item.kind === "channel" ? "Канал" : "Фильм"}</span>
        </div>
        <div style={{
          fontFamily: "var(--font-display)", fontWeight: 600,
          fontSize: 36, lineHeight: 1.0, letterSpacing: "-0.025em",
        }}>{item.title}</div>
        <div style={{
          fontFamily: "var(--font-mono)", fontSize: 11,
          letterSpacing: "0.12em", textTransform: "uppercase",
          color: "var(--text-dim)",
        }}>
          {item.score && <span style={{color: "var(--gold, #d4a559)"}}>★ {item.score}</span>}
          {item.score && <span style={{margin: "0 8px", opacity: 0.4}}>·</span>}
          {item.sub}
        </div>
        <p style={{
          fontFamily: "var(--font-ui)", fontSize: 13, lineHeight: 1.55,
          color: "var(--text-dim)", margin: "4px 0 0", maxWidth: 480,
          textWrap: "pretty",
        }}>
          {t.t.includes("Север")
            ? "Северное побережье, тёплая семья и одинокий маяк. История о тишине, которую невозможно перевести на чужой язык."
            : "Полнометражная картина, найденная по запросу. Атмосферный сюжет и глубокие персонажи в одном кадре."}
        </p>
        <div style={{display: "flex", gap: 10, marginTop: 4}}>
          <button style={btnPrimarySt}>
            <svg width="11" height="11" viewBox="0 0 24 24" fill="currentColor"><path d="M8 5v14l11-7z"/></svg>
            Смотреть
          </button>
          <button style={btnGhostSt}>Подробнее</button>
        </div>
      </div>
    </div>
  );
}

// ─── Result row (poster + meta) ──────────────────────────────────────────
function ResultRow({ item, focused }) {
  return (
    <div style={{
      display: "flex", alignItems: "center", gap: 14,
      padding: "10px 12px",
      background: focused ? "rgba(36,80,222,0.08)" : "transparent",
      border: focused ? "1px solid var(--accent)" : "1px solid transparent",
      borderRadius: 8,
    }}>
      <img src={buildPoster(item.idx, {showText: false})} alt=""
        style={{width: 60, height: 84, objectFit: "cover", borderRadius: 4, display: "block"}}/>
      <div style={{flex: 1, minWidth: 0}}>
        <div style={{
          fontFamily: "var(--font-ui)", fontWeight: 500,
          fontSize: 15, color: "var(--text)",
          whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis",
        }}>{item.title}</div>
        <div style={{
          fontFamily: "var(--font-mono)", fontSize: 10,
          letterSpacing: "0.14em", textTransform: "uppercase",
          color: "var(--text-mute)", marginTop: 4,
        }}>
          {item.score && <span style={{color: "var(--gold, #d4a559)"}}>★ {item.score} · </span>}
          {item.sub}
        </div>
      </div>
      <span style={{
        fontFamily: "var(--font-mono)", fontSize: 10,
        letterSpacing: "0.16em", color: "var(--text-mute)",
        padding: "4px 8px", borderRadius: 4,
        background: "rgba(255,255,255,0.04)",
        border: "1px solid var(--line)",
      }}>{item.kind === "series" ? "СЕРИАЛ" : item.kind === "channel" ? "КАНАЛ" : "ФИЛЬМ"}</span>
    </div>
  );
}

// ─── Empty state (no query) — recents + suggestions ──────────────────────
function EmptyState() {
  return (
    <div style={{display: "flex", flexDirection: "column", gap: 32}}>
      <div>
        <SectionLabel count={RECENTS.length}>Недавние запросы</SectionLabel>
        <div style={{display: "flex", flexDirection: "column", gap: 4, marginTop: 14}}>
          {RECENTS.map((r, i) => (
            <button key={i} style={{
              display: "flex", alignItems: "center", gap: 14,
              padding: "12px 14px",
              background: "transparent",
              border: "1px solid transparent",
              borderRadius: 8,
              cursor: "pointer",
              textAlign: "left",
            }}>
              <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="var(--text-mute)" strokeWidth="1.5">
                <circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/>
              </svg>
              <span style={{
                flex: 1,
                fontFamily: "var(--font-ui)", fontSize: 15,
                color: "var(--text-dim)",
              }}>{r}</span>
              <span style={{
                fontFamily: "var(--font-mono)", fontSize: 10,
                letterSpacing: "0.16em", color: "var(--text-mute)",
              }}>{i === 0 ? "ВЧЕРА" : `${(i+1)*2} ДНЯ`}</span>
            </button>
          ))}
        </div>
      </div>

      <div>
        <SectionLabel>Популярное сейчас</SectionLabel>
        <div style={{
          display: "grid",
          gridTemplateColumns: "repeat(4, 1fr)",
          gap: 12,
          marginTop: 14,
        }}>
          {[2, 5, 7, 9].map((idx, i) => (
            <div key={i} style={{display: "flex", flexDirection: "column", gap: 6}}>
              <img src={buildPoster(idx, {showText: false})} alt=""
                style={{width: "100%", aspectRatio: "0.7 / 1", objectFit: "cover", borderRadius: 6}}/>
              <div style={{
                fontFamily: "var(--font-ui)", fontSize: 12, fontWeight: 500,
                color: "var(--text-dim)",
                whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis",
              }}>{TITLES[idx % TITLES.length].t}</div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}

// ─── Main screen ─────────────────────────────────────────────────────────
function ScreenSearchV2() {
  const [query]    = useS("север");
  const [kbR]      = useS(3);  // С row
  const [kbC]      = useS(0);  // С col

  const filtered = useM(() => {
    if (!query) return [];
    const q = query.toLowerCase();
    return SEARCH_POOL.filter(p => p.title.toLowerCase().includes(q));
  }, [query]);

  const counts = useM(() => ({
    total:    filtered.length,
    movies:   filtered.filter(x => x.kind === "movie").length,
    series:   filtered.filter(x => x.kind === "series").length,
    channels: filtered.filter(x => x.kind === "channel").length,
  }), [filtered]);

  const top   = filtered[0];
  const rest  = filtered.slice(1);
  const movies  = rest.filter(x => x.kind === "movie");
  const series  = rest.filter(x => x.kind === "series");
  const channels= rest.filter(x => x.kind === "channel");

  return (
    <div style={{
      width: "100%", minHeight: 900,
      background: "var(--bg)", color: "var(--text)",
      fontFamily: "var(--font-ui)",
    }}>
      {/* HEADER */}
      <div style={{padding: "32px 56px 20px", borderBottom: "1px solid var(--line)"}}>
        <div style={{display: "flex", alignItems: "flex-end", gap: 28, marginBottom: 22}}>
          <div>
            <div style={{
              fontFamily: "var(--font-mono)", fontSize: 10,
              letterSpacing: "0.22em", textTransform: "uppercase",
              color: "var(--text-mute)", marginBottom: 8,
            }}>Поиск · по всему каталогу</div>
            <div style={{
              fontFamily: "var(--font-display)", fontWeight: 600,
              fontSize: 56, lineHeight: 0.95, letterSpacing: "-0.025em",
            }}>Найти <span style={{color: "var(--text-dim)", fontWeight: 400}}>что-то стоящее</span></div>
          </div>
          <div style={{flex: 1}}></div>
          <div style={{
            display: "flex", gap: 10,
            fontFamily: "var(--font-mono)", fontSize: 10,
            letterSpacing: "0.18em", textTransform: "uppercase",
            color: "var(--text-mute)",
          }}>
            <span style={{padding: "8px 12px", border: "1px solid var(--line)", borderRadius: 6}}>Все</span>
            <span style={{padding: "8px 12px", border: "1px solid var(--accent)", color: "var(--accent)", borderRadius: 6, background: "rgba(36,80,222,0.08)"}}>Фильмы</span>
            <span style={{padding: "8px 12px", border: "1px solid var(--line)", borderRadius: 6}}>Сериалы</span>
            <span style={{padding: "8px 12px", border: "1px solid var(--line)", borderRadius: 6}}>Каналы</span>
          </div>
        </div>

        <SearchBar query={query} counts={counts} />
      </div>

      {/* BODY */}
      <div style={{
        display: "grid",
        gridTemplateColumns: "360px 1fr",
        gap: 40,
        padding: "32px 56px 56px",
      }}>
        {/* LEFT — keyboard + recents */}
        <div style={{display: "flex", flexDirection: "column", gap: 32}}>
          <Keyboard focusRow={kbR} focusCol={kbC} onKey={() => {}} />

          <div>
            <SectionLabel count={RECENTS.length}>Недавние</SectionLabel>
            <div style={{display: "flex", flexDirection: "column", gap: 2, marginTop: 12}}>
              {RECENTS.slice(0, 4).map((r, i) => (
                <div key={i} style={{
                  display: "flex", alignItems: "center", gap: 10,
                  padding: "8px 10px",
                  borderRadius: 6,
                }}>
                  <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="var(--text-mute)" strokeWidth="1.6">
                    <circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/>
                  </svg>
                  <span style={{
                    flex: 1,
                    fontFamily: "var(--font-ui)", fontSize: 13,
                    color: "var(--text-dim)",
                  }}>{r}</span>
                </div>
              ))}
            </div>
          </div>
        </div>

        {/* RIGHT — results */}
        <div style={{display: "flex", flexDirection: "column", gap: 28}}>
          {!query ? (
            <EmptyState />
          ) : (
            <>
              {/* Suggestions chips */}
              <div style={{display: "flex", gap: 8, flexWrap: "wrap"}}>
                {SUGGESTIONS.map((s, i) => (
                  <span key={i} style={{
                    padding: "8px 14px",
                    borderRadius: 999,
                    background: i === 0 ? "var(--accent)" : "rgba(255,255,255,0.04)",
                    color: i === 0 ? "#fff" : "var(--text-dim)",
                    border: i === 0 ? "1px solid var(--accent)" : "1px solid var(--line)",
                    fontFamily: "var(--font-ui)", fontSize: 13, fontWeight: 500,
                    cursor: "pointer",
                  }}>{s}</span>
                ))}
              </div>

              {/* Top result */}
              {top && <TopResult item={top} focused={false} />}

              {/* Channels */}
              {channels.length > 0 && (
                <div>
                  <SectionLabel count={channels.length}>Каналы</SectionLabel>
                  <div style={{
                    display: "flex", flexDirection: "column", gap: 4,
                    marginTop: 14,
                  }}>
                    {channels.map((it, i) => (
                      <ResultRow key={i} item={it} focused={false} />
                    ))}
                  </div>
                </div>
              )}

              {/* Movies */}
              {movies.length > 0 && (
                <div>
                  <SectionLabel count={movies.length}>Фильмы</SectionLabel>
                  <div style={{
                    display: "flex", flexDirection: "column", gap: 4,
                    marginTop: 14,
                  }}>
                    {movies.map((it, i) => (
                      <ResultRow key={i} item={it} focused={false} />
                    ))}
                  </div>
                </div>
              )}

              {/* Series */}
              {series.length > 0 && (
                <div>
                  <SectionLabel count={series.length}>Сериалы</SectionLabel>
                  <div style={{
                    display: "flex", flexDirection: "column", gap: 4,
                    marginTop: 14,
                  }}>
                    {series.map((it, i) => (
                      <ResultRow key={i} item={it} focused={false} />
                    ))}
                  </div>
                </div>
              )}

              {filtered.length === 0 && (
                <div style={{
                  padding: 60, textAlign: "center",
                  border: "1px dashed var(--line)", borderRadius: 12,
                  color: "var(--text-mute)",
                }}>
                  <div style={{
                    fontFamily: "var(--font-display)", fontWeight: 600,
                    fontSize: 24, color: "var(--text-dim)", marginBottom: 8,
                  }}>Ничего не нашлось</div>
                  <div style={{fontFamily: "var(--font-ui)", fontSize: 14}}>
                    Попробуйте изменить запрос или один из недавних
                  </div>
                </div>
              )}
            </>
          )}
        </div>
      </div>
    </div>
  );
}

// ─── style helpers ───────────────────────────────────────────────────────
const kbdSt = {
  display: "inline-flex", alignItems: "center", justifyContent: "center",
  minWidth: 18, height: 18, padding: "0 5px",
  background: "rgba(255,255,255,0.06)",
  border: "1px solid var(--line)", borderRadius: 3,
  fontFamily: "var(--font-mono)", fontSize: 10, color: "var(--text-dim)",
  marginRight: 6, fontWeight: 500,
};

const btnPrimarySt = {
  display: "inline-flex", alignItems: "center", gap: 8,
  padding: "10px 18px",
  background: "var(--accent)", color: "#fff",
  border: "none", borderRadius: 6,
  fontFamily: "var(--font-ui)", fontSize: 13, fontWeight: 600,
  letterSpacing: "0.02em",
  cursor: "pointer",
};
const btnGhostSt = {
  display: "inline-flex", alignItems: "center", gap: 8,
  padding: "10px 18px",
  background: "transparent", color: "var(--text)",
  border: "1px solid var(--line)", borderRadius: 6,
  fontFamily: "var(--font-ui)", fontSize: 13, fontWeight: 500,
  cursor: "pointer",
};

if (!document.getElementById("mv-search-v2-keys")) {
  const s = document.createElement("style");
  s.id = "mv-search-v2-keys";
  s.textContent = `@keyframes mvblink { 50% { opacity: 0; } }`;
  document.head.appendChild(s);
}

window.ScreenSearchV2 = ScreenSearchV2;
