/* Mobile v2 — 3 phone screens (Home, Detail, Player), iOS frame, cobalt + Golos */

const { useMemo: useMM } = React;

// ─── Shared mobile bits ───────────────────────────────────────────────────
function MTopBar({ title, right }) {
  return (
    <div style={{
      display: "flex", alignItems: "center", justifyContent: "space-between",
      padding: "60px 20px 8px",  // reserve room for status bar
      position: "relative", zIndex: 5,
    }}>
      <div>
        <div style={{
          fontFamily: "var(--font-mono)", fontSize: 9,
          letterSpacing: "0.22em", textTransform: "uppercase",
          color: "rgba(255,255,255,0.55)",
        }}>MegaV IPTV</div>
        <div style={{
          fontFamily: "var(--font-display)", fontWeight: 600,
          fontSize: 22, lineHeight: 1.1, letterSpacing: "-0.02em",
          color: "#fff", marginTop: 2,
        }}>{title}</div>
      </div>
      {right}
    </div>
  );
}

function MIcon({ d, size = 18, stroke = 1.7 }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none"
         stroke="currentColor" strokeWidth={stroke}
         strokeLinecap="round" strokeLinejoin="round">
      <path d={d}/>
    </svg>
  );
}

function MIconBtn({ children }) {
  return (
    <button style={{
      width: 36, height: 36, borderRadius: 18,
      background: "rgba(255,255,255,0.08)",
      border: "1px solid rgba(255,255,255,0.12)",
      display: "grid", placeItems: "center",
      color: "#fff", cursor: "pointer",
      backdropFilter: "blur(12px)",
    }}>{children}</button>
  );
}

function MTabBar({ active = 0 }) {
  const tabs = [
    {n: "Главная", ic: "M3 11l9-8 9 8v10a2 2 0 0 1-2 2h-4v-7h-6v7H5a2 2 0 0 1-2-2z"},
    {n: "ТВ",      ic: "M3 7h18v11H3z M8 21h8 M12 3l4 4M12 3L8 7"},
    {n: "Поиск",   ic: "M11 18a7 7 0 1 1 0-14 7 7 0 0 1 0 14z M21 21l-4.3-4.3"},
    {n: "Гид",     ic: "M4 5h16 M4 12h16 M4 19h16"},
    {n: "Профиль", ic: "M12 12a4 4 0 1 0 0-8 4 4 0 0 0 0 8z M4 22a8 8 0 0 1 16 0"},
  ];
  return (
    <div style={{
      position: "absolute", left: 14, right: 14, bottom: 18,
      padding: "10px 8px",
      background: "rgba(20,20,28,0.62)",
      backdropFilter: "blur(28px)",
      WebkitBackdropFilter: "blur(28px)",
      border: "1px solid rgba(255,255,255,0.1)",
      borderRadius: 24,
      display: "flex", justifyContent: "space-around", alignItems: "center",
      zIndex: 30,
    }}>
      {tabs.map((b, i) => (
        <div key={i} style={{
          display: "flex", flexDirection: "column",
          alignItems: "center", gap: 2,
          padding: "4px 10px",
          color: i === active ? "#fff" : "rgba(255,255,255,0.55)",
        }}>
          <div style={{
            width: 32, height: 32, borderRadius: 12,
            background: i === active ? "var(--accent)" : "transparent",
            display: "grid", placeItems: "center",
            boxShadow: i === active ? "0 0 18px rgba(36,80,222,0.5)" : "none",
          }}>
            <MIcon d={b.ic} size={16} />
          </div>
          <span style={{
            fontFamily: "var(--font-ui)", fontSize: 9, fontWeight: i === active ? 600 : 500,
            letterSpacing: "-0.005em",
          }}>{b.n}</span>
        </div>
      ))}
    </div>
  );
}

// ─── Screen 1: Home ───────────────────────────────────────────────────────
function MobileHome() {
  const heroIdx = 5;
  const t = TITLES[heroIdx];
  const rowIdx = [1, 11, 7, 14, 6];
  const continueIdx = [2, 9, 13];

  return (
    <div style={{
      width: "100%", minHeight: "100%",
      background: "#06060a", color: "#fff",
      fontFamily: "var(--font-ui)",
      paddingBottom: 100,
      position: "relative",
    }}>
      {/* Backdrop fade behind hero */}
      <div style={{
        position: "absolute", inset: "0 0 auto 0", height: 540,
        backgroundImage: `url(${buildBackdrop(heroIdx, 800, 700)})`,
        backgroundSize: "cover", backgroundPosition: "center",
        opacity: 0.4,
      }}></div>
      <div style={{
        position: "absolute", inset: "0 0 auto 0", height: 540,
        background: "linear-gradient(180deg, rgba(6,6,10,0.4) 0%, #06060a 90%)",
      }}></div>

      <MTopBar title="Главная" right={
        <div style={{display: "flex", gap: 8}}>
          <MIconBtn><MIcon d="M11 18a7 7 0 1 1 0-14 7 7 0 0 1 0 14z M21 21l-4.3-4.3" /></MIconBtn>
          <MIconBtn><MIcon d="M12 12a4 4 0 1 0 0-8 4 4 0 0 0 0 8z M4 22a8 8 0 0 1 16 0" /></MIconBtn>
        </div>
      } />

      {/* Featured hero card */}
      <div style={{padding: "16px 18px", position: "relative", zIndex: 5}}>
        <div style={{
          position: "relative",
          height: 380, borderRadius: 20, overflow: "hidden",
          border: "1px solid rgba(255,255,255,0.06)",
          boxShadow: "0 24px 48px rgba(0,0,0,0.55)",
        }}>
          <img src={buildPoster(heroIdx)} alt="" style={{
            position: "absolute", inset: 0,
            width: "100%", height: "100%", objectFit: "cover",
          }}/>
          <div style={{
            position: "absolute", inset: 0,
            background: "linear-gradient(180deg, rgba(6,6,10,0) 35%, rgba(6,6,10,0.92) 100%)",
          }}></div>

          {/* live badge */}
          <div style={{position: "absolute", top: 14, left: 14, display: "flex", gap: 6}}>
            <span style={{
              display: "inline-flex", alignItems: "center", gap: 5,
              padding: "5px 9px", borderRadius: 4,
              background: "var(--accent)", color: "#fff",
              fontFamily: "var(--font-mono)", fontWeight: 600,
              fontSize: 9, letterSpacing: "0.18em",
            }}>
              <span style={{
                width: 5, height: 5, borderRadius: 3, background: "#fff",
                animation: "mvpulse 1.5s ease-in-out infinite",
              }}></span>
              LIVE
            </span>
            <span style={{
              padding: "5px 9px", borderRadius: 4,
              background: "rgba(0,0,0,0.5)", backdropFilter: "blur(8px)",
              color: "#fff", border: "1px solid rgba(255,255,255,0.12)",
              fontFamily: "var(--font-mono)", fontWeight: 600,
              fontSize: 9, letterSpacing: "0.16em",
            }}>MM ROMANCE HD</span>
          </div>

          {/* Bottom content */}
          <div style={{position: "absolute", left: 16, right: 16, bottom: 16}}>
            <div style={{
              fontFamily: "var(--font-display)", fontWeight: 600,
              fontSize: 28, lineHeight: 1.0, letterSpacing: "-0.025em",
              color: "#fff", marginBottom: 6,
            }}>{t.t}</div>
            <div style={{
              fontFamily: "var(--font-mono)", fontSize: 9,
              letterSpacing: "0.14em", textTransform: "uppercase",
              color: "rgba(255,255,255,0.7)", marginBottom: 12,
            }}>
              <span style={{color: "#d4a559"}}>★ 8.7</span> · {t.y} · {t.g} · ещё 55 мин
            </div>

            {/* Progress */}
            <div style={{
              height: 3, background: "rgba(255,255,255,0.18)",
              borderRadius: 2, marginBottom: 12,
            }}>
              <div style={{width: "62%", height: "100%", background: "var(--accent)", borderRadius: 2}}></div>
            </div>

            <button style={{
              width: "100%", padding: "12px 16px",
              background: "var(--accent)", color: "#fff",
              border: "none", borderRadius: 10,
              display: "flex", justifyContent: "center", alignItems: "center", gap: 8,
              fontFamily: "var(--font-ui)", fontSize: 14, fontWeight: 600,
              cursor: "pointer",
            }}>
              <svg width="11" height="11" viewBox="0 0 24 24" fill="currentColor"><path d="M8 5v14l11-7z"/></svg>
              Смотреть
            </button>
          </div>

          {/* swipe hint */}
          <div style={{
            position: "absolute", bottom: 8, right: 12,
            fontFamily: "var(--font-mono)", fontSize: 8,
            letterSpacing: "0.1em",
            color: "rgba(255,255,255,0.4)",
          }}>SWIPE ↔ КАНАЛ</div>
        </div>

        {/* Dot indicator */}
        <div style={{display: "flex", justifyContent: "center", gap: 5, marginTop: 12}}>
          {[0,1,2,3,4].map(i => (
            <div key={i} style={{
              width: i === 0 ? 14 : 4, height: 4, borderRadius: 2,
              background: i === 0 ? "var(--accent)" : "rgba(255,255,255,0.22)",
            }}></div>
          ))}
        </div>
      </div>

      {/* Continue Watching */}
      <MSection title="Продолжить" count={3} />
      <div style={{
        display: "flex", gap: 10, padding: "0 18px",
        overflowX: "auto",
      }}>
        {continueIdx.map((i, k) => {
          const tt = TITLES[i % TITLES.length];
          return (
            <div key={k} style={{
              flexShrink: 0, width: 200,
              background: "rgba(255,255,255,0.04)",
              borderRadius: 12, overflow: "hidden",
              border: "1px solid rgba(255,255,255,0.06)",
            }}>
              <div style={{position: "relative", height: 110}}>
                <img src={buildPoster(i, {showText: false})} alt=""
                     style={{position: "absolute", inset: 0, width: "100%", height: "100%", objectFit: "cover"}}/>
                <div style={{
                  position: "absolute", left: 0, right: 0, bottom: 0, height: 3,
                  background: "rgba(255,255,255,0.18)",
                }}>
                  <div style={{
                    width: `${[42, 75, 28][k]}%`, height: "100%",
                    background: "var(--accent)",
                  }}></div>
                </div>
                <div style={{
                  position: "absolute", top: 6, right: 6,
                  width: 28, height: 28, borderRadius: 14,
                  background: "rgba(0,0,0,0.6)", backdropFilter: "blur(8px)",
                  display: "grid", placeItems: "center", color: "#fff",
                }}>
                  <svg width="10" height="10" viewBox="0 0 24 24" fill="currentColor"><path d="M8 5v14l11-7z"/></svg>
                </div>
              </div>
              <div style={{padding: "8px 10px"}}>
                <div style={{
                  fontFamily: "var(--font-ui)", fontSize: 12, fontWeight: 600,
                  color: "#fff",
                  whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis",
                }}>{tt.t}</div>
                <div style={{
                  fontFamily: "var(--font-mono)", fontSize: 8,
                  letterSpacing: "0.14em", textTransform: "uppercase",
                  color: "rgba(255,255,255,0.5)", marginTop: 3,
                }}>{[18, 3, 32][k]} мин осталось</div>
              </div>
            </div>
          );
        })}
      </div>

      {/* Channel chips */}
      <MSection title="Категории" />
      <div style={{display: "flex", gap: 8, padding: "0 18px", flexWrap: "wrap"}}>
        {["В эфире", "Кино", "Сериалы", "Док.", "Спорт", "Дети"].map((c, i) => (
          <span key={i} style={{
            padding: "8px 14px",
            borderRadius: 999,
            background: i === 1 ? "var(--accent)" : "rgba(255,255,255,0.06)",
            color: i === 1 ? "#fff" : "rgba(255,255,255,0.85)",
            border: i === 1 ? "1px solid var(--accent)" : "1px solid rgba(255,255,255,0.08)",
            fontFamily: "var(--font-ui)", fontSize: 12, fontWeight: 500,
          }}>{c}</span>
        ))}
      </div>

      {/* Trending row */}
      <MSection title="В тренде" count={5} />
      <div style={{
        display: "flex", gap: 10, padding: "0 18px",
        overflowX: "auto",
      }}>
        {rowIdx.map((i, k) => {
          const tt = TITLES[i % TITLES.length];
          return (
            <div key={k} style={{
              flexShrink: 0, width: 110,
            }}>
              <div style={{
                position: "relative",
                width: 110, height: 156,
                borderRadius: 10, overflow: "hidden",
                border: "1px solid rgba(255,255,255,0.06)",
              }}>
                <img src={buildPoster(i, {showText: false})} alt=""
                     style={{width: "100%", height: "100%", objectFit: "cover", display: "block"}}/>
                <div style={{
                  position: "absolute", top: 6, left: 6,
                  fontFamily: "var(--font-display)", fontWeight: 600,
                  fontSize: 28, lineHeight: 1, letterSpacing: "-0.04em",
                  color: "#fff",
                  textShadow: "0 2px 4px rgba(0,0,0,0.6)",
                }}>{k+1}</div>
              </div>
              <div style={{
                fontFamily: "var(--font-ui)", fontSize: 11, fontWeight: 500,
                color: "#fff", marginTop: 6,
                whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis",
              }}>{tt.t}</div>
              <div style={{
                fontFamily: "var(--font-mono)", fontSize: 8,
                letterSpacing: "0.14em", textTransform: "uppercase",
                color: "rgba(255,255,255,0.5)", marginTop: 2,
              }}>{tt.y} · {tt.g}</div>
            </div>
          );
        })}
      </div>

      <MTabBar active={0} />
    </div>
  );
}

function MSection({ title, count, all = "Все" }) {
  return (
    <div style={{
      display: "flex", alignItems: "baseline", justifyContent: "space-between",
      padding: "28px 18px 12px",
    }}>
      <div style={{display: "flex", alignItems: "baseline", gap: 10}}>
        <div style={{
          fontFamily: "var(--font-display)", fontWeight: 600,
          fontSize: 17, color: "#fff", letterSpacing: "-0.015em",
        }}>{title}</div>
        {count !== undefined && (
          <span style={{
            fontFamily: "var(--font-mono)", fontSize: 9,
            letterSpacing: "0.18em", color: "rgba(255,255,255,0.4)",
          }}>{String(count).padStart(2, "0")}</span>
        )}
      </div>
      <span style={{
        fontFamily: "var(--font-mono)", fontSize: 10,
        letterSpacing: "0.14em", color: "var(--accent)",
        textTransform: "uppercase",
      }}>{all} →</span>
    </div>
  );
}

// ─── Screen 2: Detail ─────────────────────────────────────────────────────
function MobileDetail() {
  const idx = 1;
  const t = TITLES[idx];
  const cast = ["Елена С.", "Максим Р.", "Анна Б.", "Олег Д."];

  return (
    <div style={{
      width: "100%", minHeight: "100%",
      background: "#06060a", color: "#fff",
      fontFamily: "var(--font-ui)",
      paddingBottom: 100,
    }}>
      {/* Hero poster, bleed under status bar */}
      <div style={{position: "relative", height: 480}}>
        <img src={buildPoster(idx)} alt="" style={{
          position: "absolute", inset: 0,
          width: "100%", height: "100%", objectFit: "cover",
        }}/>
        <div style={{
          position: "absolute", inset: 0,
          background: "linear-gradient(180deg, rgba(6,6,10,0.5) 0%, rgba(6,6,10,0) 25%, rgba(6,6,10,0) 50%, #06060a 100%)",
        }}></div>

        {/* Top controls */}
        <div style={{
          position: "absolute", top: 60, left: 18, right: 18,
          display: "flex", justifyContent: "space-between",
        }}>
          <MIconBtn><MIcon d="M15 18l-6-6 6-6" /></MIconBtn>
          <div style={{display: "flex", gap: 8}}>
            <MIconBtn><MIcon d="M19 21l-7-5-7 5V5a2 2 0 0 1 2-2h10a2 2 0 0 1 2 2z" /></MIconBtn>
            <MIconBtn><MIcon d="M4 12v.01 M12 12v.01 M20 12v.01" /></MIconBtn>
          </div>
        </div>

        {/* Bottom info */}
        <div style={{position: "absolute", left: 18, right: 18, bottom: 18}}>
          <div style={{display: "flex", gap: 6, marginBottom: 10}}>
            <span style={{
              padding: "4px 8px", borderRadius: 4,
              background: "rgba(0,0,0,0.55)", backdropFilter: "blur(8px)",
              border: "1px solid rgba(255,255,255,0.1)",
              fontFamily: "var(--font-mono)", fontWeight: 600,
              fontSize: 9, letterSpacing: "0.16em", color: "#fff",
            }}>4K · DOLBY VISION</span>
            <span style={{
              padding: "4px 8px", borderRadius: 4,
              background: "rgba(36,80,222,0.18)",
              border: "1px solid var(--accent)",
              fontFamily: "var(--font-mono)", fontWeight: 600,
              fontSize: 9, letterSpacing: "0.16em", color: "#fff",
            }}>MM PLUS</span>
          </div>

          <div style={{
            fontFamily: "var(--font-display)", fontWeight: 600,
            fontSize: 32, lineHeight: 1.0, letterSpacing: "-0.025em",
            color: "#fff", marginBottom: 6,
          }}>{t.t}</div>
          <div style={{
            fontFamily: "var(--font-mono)", fontSize: 10,
            letterSpacing: "0.14em", textTransform: "uppercase",
            color: "rgba(255,255,255,0.7)",
          }}>
            <span style={{color: "#d4a559"}}>★ 7.9</span> · {t.y} · {t.g} · {t.d}
          </div>
        </div>
      </div>

      {/* CTA buttons */}
      <div style={{padding: "0 18px", display: "flex", gap: 8}}>
        <button style={{
          flex: 1, padding: "13px 16px",
          background: "var(--accent)", color: "#fff",
          border: "none", borderRadius: 10,
          display: "flex", justifyContent: "center", alignItems: "center", gap: 8,
          fontFamily: "var(--font-ui)", fontSize: 14, fontWeight: 600,
          cursor: "pointer",
        }}>
          <svg width="11" height="11" viewBox="0 0 24 24" fill="currentColor"><path d="M8 5v14l11-7z"/></svg>
          Смотреть
        </button>
        <button style={{
          padding: "13px 14px",
          background: "rgba(255,255,255,0.06)", color: "#fff",
          border: "1px solid rgba(255,255,255,0.1)", borderRadius: 10,
          display: "grid", placeItems: "center",
          cursor: "pointer",
        }}>
          <MIcon d="M12 5v14 M5 12h14" />
        </button>
        <button style={{
          padding: "13px 14px",
          background: "rgba(255,255,255,0.06)", color: "#fff",
          border: "1px solid rgba(255,255,255,0.1)", borderRadius: 10,
          display: "grid", placeItems: "center",
          cursor: "pointer",
        }}>
          <MIcon d="M4 12v8a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2v-8 M16 6l-4-4-4 4 M12 2v14" />
        </button>
      </div>

      {/* Synopsis */}
      <div style={{padding: "24px 18px 0"}}>
        <p style={{
          fontFamily: "var(--font-ui)", fontSize: 14, lineHeight: 1.55,
          color: "rgba(255,255,255,0.85)",
          margin: 0, textWrap: "pretty",
        }}>
          Северное побережье, тёплая семья и одинокий маяк. История о тишине,
          которую невозможно перевести на чужой язык. Фильм-настроение от мастера
          скандинавского реализма.
        </p>
      </div>

      {/* Cast row */}
      <div style={{padding: "20px 0 0"}}>
        <div style={{padding: "0 18px 12px",
          fontFamily: "var(--font-mono)", fontSize: 10,
          letterSpacing: "0.22em", textTransform: "uppercase",
          color: "rgba(255,255,255,0.5)",
        }}>В ролях · 4</div>
        <div style={{display: "flex", gap: 12, padding: "0 18px", overflowX: "auto"}}>
          {cast.map((c, i) => (
            <div key={i} style={{
              flexShrink: 0,
              display: "flex", flexDirection: "column", alignItems: "center", gap: 8,
              width: 70,
            }}>
              <div style={{
                width: 60, height: 60, borderRadius: "50%",
                background: `linear-gradient(135deg, ${POSTER_PALETTES[i][1]}, ${POSTER_PALETTES[i][2]})`,
                display: "grid", placeItems: "center",
                fontFamily: "var(--font-display)", fontWeight: 600,
                fontSize: 20, color: "#fff", letterSpacing: "-0.02em",
                border: "1px solid rgba(255,255,255,0.08)",
              }}>{c[0]}</div>
              <div style={{
                fontFamily: "var(--font-ui)", fontSize: 11, fontWeight: 500,
                color: "rgba(255,255,255,0.85)", textAlign: "center",
                whiteSpace: "nowrap",
              }}>{c}</div>
            </div>
          ))}
        </div>
      </div>

      {/* Episodes */}
      <div style={{padding: "24px 18px 0"}}>
        <div style={{
          display: "flex", alignItems: "baseline", justifyContent: "space-between",
          marginBottom: 10,
        }}>
          <div style={{
            fontFamily: "var(--font-display)", fontWeight: 600,
            fontSize: 17, color: "#fff", letterSpacing: "-0.015em",
          }}>Похожее</div>
          <span style={{
            fontFamily: "var(--font-mono)", fontSize: 10,
            letterSpacing: "0.14em", color: "var(--accent)",
            textTransform: "uppercase",
          }}>Все →</span>
        </div>
        <div style={{display: "flex", gap: 10, overflowX: "auto"}}>
          {[6, 11, 8, 13].map((i, k) => (
            <div key={k} style={{flexShrink: 0, width: 120}}>
              <img src={buildPoster(i, {showText: false})} alt=""
                   style={{width: 120, height: 170, objectFit: "cover", borderRadius: 8, display: "block"}}/>
              <div style={{
                fontFamily: "var(--font-ui)", fontSize: 11, fontWeight: 500,
                color: "#fff", marginTop: 6,
                whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis",
              }}>{TITLES[i].t}</div>
            </div>
          ))}
        </div>
      </div>

      <MTabBar active={-1} />
    </div>
  );
}

// ─── Screen 3: Player ─────────────────────────────────────────────────────
function MobilePlayer() {
  const idx = 5;
  const t = TITLES[idx];

  return (
    <div style={{
      width: "100%", minHeight: "100%",
      background: "#06060a", color: "#fff",
      fontFamily: "var(--font-ui)",
      position: "relative",
      paddingBottom: 0,
    }}>
      {/* Full-bleed video */}
      <div style={{position: "absolute", inset: 0}}>
        <img src={buildBackdrop(idx, 600, 1100)} alt="" style={{
          width: "100%", height: "100%", objectFit: "cover",
        }}/>
        <div style={{
          position: "absolute", inset: 0,
          background: "linear-gradient(180deg, rgba(0,0,0,0.55) 0%, rgba(0,0,0,0.2) 30%, rgba(0,0,0,0.2) 60%, rgba(0,0,0,0.85) 100%)",
        }}></div>
      </div>

      {/* Top controls */}
      <div style={{
        position: "relative", zIndex: 5,
        padding: "60px 18px 0",
        display: "flex", justifyContent: "space-between", alignItems: "flex-start",
      }}>
        <MIconBtn><MIcon d="M19 14l-7-7-7 7" /></MIconBtn>
        <div style={{
          flex: 1, textAlign: "center", padding: "4px 12px 0",
        }}>
          <div style={{
            fontFamily: "var(--font-mono)", fontSize: 9,
            letterSpacing: "0.22em", textTransform: "uppercase",
            color: "rgba(255,255,255,0.5)",
          }}>СЕЙЧАС НА · MM ROMANCE HD</div>
          <div style={{
            fontFamily: "var(--font-display)", fontWeight: 600,
            fontSize: 16, color: "#fff", marginTop: 2, letterSpacing: "-0.015em",
            whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis",
          }}>{t.t}</div>
        </div>
        <MIconBtn><MIcon d="M4 12v.01 M12 12v.01 M20 12v.01" /></MIconBtn>
      </div>

      {/* Live Pill */}
      <div style={{
        position: "relative", zIndex: 5,
        display: "flex", justifyContent: "center", marginTop: 20,
      }}>
        <span style={{
          display: "inline-flex", alignItems: "center", gap: 6,
          padding: "5px 11px", borderRadius: 999,
          background: "var(--accent)", color: "#fff",
          fontFamily: "var(--font-mono)", fontWeight: 600,
          fontSize: 9, letterSpacing: "0.18em",
        }}>
          <span style={{
            width: 5, height: 5, borderRadius: 3, background: "#fff",
            animation: "mvpulse 1.5s ease-in-out infinite",
          }}></span>
          LIVE · 4K
        </span>
      </div>

      {/* Center play button */}
      <div style={{
        position: "absolute", inset: 0,
        display: "grid", placeItems: "center",
        zIndex: 6,
      }}>
        <button style={{
          width: 76, height: 76, borderRadius: "50%",
          background: "rgba(0,0,0,0.5)", backdropFilter: "blur(20px)",
          border: "1px solid rgba(255,255,255,0.18)",
          color: "#fff",
          display: "grid", placeItems: "center",
          cursor: "pointer",
          boxShadow: "0 8px 32px rgba(0,0,0,0.6)",
        }}>
          <svg width="26" height="26" viewBox="0 0 24 24" fill="currentColor">
            <rect x="6" y="5" width="4" height="14"/>
            <rect x="14" y="5" width="4" height="14"/>
          </svg>
        </button>
      </div>

      {/* Bottom controls */}
      <div style={{
        position: "absolute", bottom: 28, left: 18, right: 18,
        zIndex: 10,
      }}>
        {/* Time + remaining */}
        <div style={{
          display: "flex", justifyContent: "space-between",
          fontFamily: "var(--font-mono)", fontSize: 10,
          letterSpacing: "0.14em", color: "rgba(255,255,255,0.85)",
          marginBottom: 6,
        }}>
          <span>21:24</span>
          <span style={{color: "rgba(255,255,255,0.5)"}}>осталось 55 мин</span>
        </div>

        {/* Scrubber */}
        <div style={{
          height: 4, background: "rgba(255,255,255,0.18)",
          borderRadius: 2, marginBottom: 18,
          position: "relative",
        }}>
          <div style={{width: "62%", height: "100%", background: "var(--accent)", borderRadius: 2}}></div>
          <div style={{
            position: "absolute", left: "62%", top: "50%",
            transform: "translate(-50%, -50%)",
            width: 14, height: 14, borderRadius: 7,
            background: "#fff",
            boxShadow: "0 0 12px var(--accent), 0 2px 6px rgba(0,0,0,0.6)",
          }}></div>
        </div>

        {/* Action row */}
        <div style={{
          display: "flex", justifyContent: "space-between", alignItems: "center",
          padding: "12px 18px",
          background: "rgba(20,20,28,0.65)", backdropFilter: "blur(28px)",
          border: "1px solid rgba(255,255,255,0.08)",
          borderRadius: 18,
        }}>
          {[
            {ic: "M12 5v14 M5 12h14", lbl: "Список"},
            {ic: "M5 12h14 M12 5l7 7-7 7", lbl: "Эпизоды"},
            {ic: "M12 1v22 M5 8l7-7 7 7 M5 16l7 7 7-7", lbl: "Качество"},
            {ic: "M3 5h18 M3 12h18 M3 19h18", lbl: "Сабы"},
            {ic: "M16 8a3 3 0 0 1 0 8 M12 4v16 M8 8a5 5 0 0 1 0 8", lbl: "Звук"},
          ].map((b, i) => (
            <div key={i} style={{
              display: "flex", flexDirection: "column", alignItems: "center", gap: 4,
              color: "rgba(255,255,255,0.85)",
            }}>
              <MIcon d={b.ic} size={16} />
              <span style={{
                fontFamily: "var(--font-mono)", fontSize: 8,
                letterSpacing: "0.14em", textTransform: "uppercase",
                color: "rgba(255,255,255,0.55)",
              }}>{b.lbl}</span>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}

window.MobileHome = MobileHome;
window.MobileDetail = MobileDetail;
window.MobilePlayer = MobilePlayer;
