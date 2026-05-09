/* Home — Variant B: Editorial bento (hero_layout option 3 — portrait poster + side cards) */

function HomeEditorial() {
  const featured = 5;
  const sideTop = 13;
  const sideBot = 9;
  const bento = [0, 7, 11, 2, 14, 4, 17, 1];

  return (
    <div className="mv-art mv-grain" style={{minHeight: 1180, paddingBottom: 60}}>
      {/* faint backdrop */}
      <div className="mv-backdrop">
        <div className="layer" style={{backgroundImage: `url(${buildBackdrop(featured)})`, opacity: 0.35}}></div>
        <div className="grad"></div>
      </div>

      <Header city="Kampala" temp="19°" time="03:04" />

      {/* Editorial masthead */}
      <div style={{padding: "8px 56px 28px", position: "relative", zIndex: 5}}>
        <div style={{
          display: "flex", justifyContent: "space-between", alignItems: "baseline",
          borderBottom: "1px solid var(--line)", paddingBottom: 16, marginBottom: 24
        }}>
          <div style={{
            fontFamily: "var(--font-display)", fontStyle: "italic",
            fontSize: 56, lineHeight: 1, letterSpacing: "-0.01em"
          }}>Главная <em style={{color:"var(--text-dim)"}}>сегодня</em></div>
          <div style={{
            fontFamily: "var(--font-mono)", fontSize: 11,
            letterSpacing: "0.16em", color: "var(--text-mute)"
          }}>9 МАЯ 2026 · ВЫПУСК №127</div>
        </div>
      </div>

      {/* Hero row — portrait poster + 2 side cards (option 3) */}
      <div style={{
        padding: "0 56px 40px", position: "relative", zIndex: 5,
        display: "grid", gridTemplateColumns: "auto 1fr", gap: 36
      }}>
        {/* Portrait hero poster */}
        <div style={{position: "relative"}}>
          <Poster idx={featured} w={420} h={620} hideText={true} />
          <div style={{
            position: "absolute", left: -10, top: 20,
            background: "var(--gold)", color: "#1a1208",
            fontFamily: "var(--font-mono)", fontSize: 10,
            padding: "6px 10px", letterSpacing: "0.16em",
            fontWeight: 700, transform: "rotate(-90deg)", transformOrigin: "left top"
          }}>EDITORS' PICK · {String(featured+1).padStart(2,"0")}</div>
        </div>

        {/* Hero metadata */}
        <div style={{display:"flex", flexDirection:"column", gap: 24}}>
          <div>
            <div style={{display: "flex", gap: 8, marginBottom: 16}}>
              <Chip kind="live">В эфире</Chip>
              <Chip kind="brand"><MMLogo /> &nbsp;MM Romance HD</Chip>
              <Chip kind="gold">Premiere</Chip>
            </div>
            <div style={{
              fontFamily: "var(--font-display)", fontStyle: "italic",
              fontSize: 84, fontWeight: 400, lineHeight: 0.95,
              letterSpacing: "-0.02em", marginBottom: 18
            }}>{TITLES[featured].t}</div>
            <div style={{
              fontFamily: "var(--font-mono)", fontSize: 12,
              letterSpacing: "0.14em", color: "var(--text-dim)",
              textTransform: "uppercase", marginBottom: 20,
              display: "flex", gap: 20
            }}>
              <span style={{color: "var(--gold)"}}>★ 8.7</span>
              <span>{TITLES[featured].y}</span>
              <span>{TITLES[featured].g}</span>
              <span>{TITLES[featured].d}</span>
            </div>
            <p style={{
              fontSize: 17, lineHeight: 1.55, color: "var(--text-dim)",
              maxWidth: 540, textWrap: "pretty", margin: 0
            }}>Долгая история двух почтальонов, которые всю жизнь обменивались письмами,
            но так и не встретились. Камера гуляет по Праге медленно — как читают письма.</p>
          </div>

          <div>
            <div className="mv-track" style={{marginBottom: 8, maxWidth: 480}}><i style={{width: "62%"}}></i></div>
            <div className="mv-ticks" style={{maxWidth: 480}}>
              <span>02:45</span>
              <span style={{color:"var(--text-dim)"}}>ещё 55 мин · до 03:59</span>
            </div>
          </div>

          <div style={{display: "flex", gap: 12}}>
            <button className="mv-btn primary focus">
              <svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor"><path d="M8 5v14l11-7z"/></svg>
              Смотреть
            </button>
            <button className="mv-btn ghost">+ В избранное</button>
            <button className="mv-btn ghost">EPG</button>
          </div>

          {/* Two side mini-cards stacked */}
          <div style={{display: "grid", gridTemplateColumns: "1fr 1fr", gap: 14, marginTop: 8}}>
            <SideCard idx={sideTop} kind="next" label="Далее в эфире" remaining="через 55 мин" />
            <SideCard idx={sideBot} kind="featured" label="Рекомендуем" remaining="2ч 06м" />
          </div>
        </div>
      </div>

      {/* Genre tabs */}
      <GenreTabs counts={[12, 30, 18, 9, 14, 6, 8]} active={1} />

      {/* Bento grid — different sized cards */}
      <div style={{padding: "32px 56px"}}>
        <SectionTitle title="Кино" italic="без расписания" count={30} />
        <div style={{
          display: "grid",
          gridTemplateColumns: "repeat(6, 1fr)",
          gridAutoRows: 220,
          gap: 16
        }}>
          {/* Mixed sizes for bento feel */}
          <BentoCard idx={bento[0]} cols={2} rows={2} live focus />
          <BentoCard idx={bento[1]} cols={2} rows={1} />
          <BentoCard idx={bento[2]} cols={2} rows={1} />
          <BentoCard idx={bento[3]} cols={1} rows={1} />
          <BentoCard idx={bento[4]} cols={1} rows={1} />
          <BentoCard idx={bento[5]} cols={2} rows={1} live />
          <BentoCard idx={bento[6]} cols={2} rows={1} />
          <BentoCard idx={bento[7]} cols={2} rows={1} />
        </div>
      </div>

      {/* Channel strip — film reel */}
      <div style={{padding: "12px 56px 0", display: "flex", alignItems: "center", gap: 18}}>
        <span style={{
          fontFamily: "var(--font-mono)", fontSize: 11,
          letterSpacing: "0.16em", color: "var(--text-mute)"
        }}>КАНАЛЫ ↓</span>
        <div className="mv-strip">
          {Array.from({length: 18}).map((_, i) => (
            <div key={i} className={`frame ${i === 4 ? "active" : ""}`} style={{
              backgroundImage: `url(${buildPoster(i, {showText: false})})`,
              backgroundSize: "cover"
            }}></div>
          ))}
        </div>
        <div style={{marginLeft: "auto", color: "var(--text-mute)",
          fontFamily: "var(--font-mono)", fontSize: 11,
          letterSpacing: "0.12em"
        }}>05 / 124</div>
      </div>
    </div>
  );
}

function SideCard({ idx, kind, label, remaining }) {
  const t = TITLES[idx];
  return (
    <div style={{
      display: "flex", gap: 14, padding: 14,
      background: "rgba(20,20,26,0.55)",
      border: "1px solid var(--line)",
      borderRadius: "var(--r-md)",
      backdropFilter: "blur(12px)"
    }}>
      <Poster idx={idx} w={84} h={112} hideText={true} />
      <div style={{display: "flex", flexDirection: "column", justifyContent: "space-between", flex: 1, minWidth: 0}}>
        <div>
          <div style={{
            fontFamily: "var(--font-mono)", fontSize: 10,
            letterSpacing: "0.14em", color: "var(--text-mute)", textTransform: "uppercase"
          }}>{label}</div>
          <div style={{
            fontFamily: "var(--font-display)", fontStyle: "italic",
            fontSize: 22, lineHeight: 1.1, marginTop: 6
          }}>{t.t}</div>
          <div style={{fontSize: 12, color: "var(--text-dim)", marginTop: 4}}>{t.y} · {t.g}</div>
        </div>
        <div style={{
          fontFamily: "var(--font-mono)", fontSize: 10,
          color: "var(--accent)", letterSpacing: "0.1em"
        }}>{remaining}</div>
      </div>
    </div>
  );
}

function BentoCard({ idx, cols, rows, live, focus }) {
  const t = TITLES[idx];
  const big = cols >= 2 && rows >= 2;
  return (
    <div style={{
      gridColumn: `span ${cols}`,
      gridRow: `span ${rows}`,
      position: "relative",
      borderRadius: "var(--r-md)",
      overflow: "hidden",
      outline: focus ? "3px solid var(--accent)" : "none",
      outlineOffset: focus ? 3 : 0,
      boxShadow: focus ? "0 24px 60px var(--accent-glow)" : "0 16px 40px rgba(0,0,0,0.5)",
      background: "var(--surface-2)",
    }}>
      <img src={buildPoster(idx, {showText: false})} alt="" style={{
        position: "absolute", inset: 0, width: "100%", height: "100%", objectFit: "cover"
      }}/>
      <div style={{
        position: "absolute", inset: 0,
        background: "linear-gradient(180deg, rgba(0,0,0,0.05) 30%, rgba(0,0,0,0.85) 100%)"
      }}></div>
      <div style={{position: "absolute", top: 12, left: 12, display: "flex", gap: 6}}>
        {live && <Chip kind="live">Live</Chip>}
      </div>
      <div style={{position: "absolute", left: 16, right: 16, bottom: 14}}>
        <div style={{
          fontFamily: "var(--font-display)", fontStyle: "italic",
          fontSize: big ? 36 : 20, lineHeight: 1.05, fontWeight: 400
        }}>{t.t}</div>
        <div style={{
          fontFamily: "var(--font-mono)", fontSize: 10,
          letterSpacing: "0.12em", color: "rgba(255,255,255,0.65)",
          marginTop: 6, textTransform: "uppercase"
        }}>{t.y} · {t.g} · {t.d}</div>
      </div>
    </div>
  );
}

window.HomeEditorial = HomeEditorial;
