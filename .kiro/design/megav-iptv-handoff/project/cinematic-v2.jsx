/* Cinematic v2 — focused single-screen exploration with theme tweaks */

const { useState, useEffect } = React;

const PALETTES = [
  { id: "cobalt",  label: "Noir Cobalt",     swatches: ["#06080f", "#3D5DFF", "#9ec5ff", "#E8EEFB"] },
  { id: "crimson", label: "Crimson Reel",    swatches: ["#0a0608", "#E5424A", "#F2A65A", "#F6EDE9"] },
  { id: "plum",    label: "Midnight Plum",   swatches: ["#06060a", "#6E56F7", "#E8B96A", "#F4F1E9"] },
  { id: "ivory",   label: "Ivory Cinema",    swatches: ["#f3eee3", "#C9612C", "#8a5a1c", "#1a0f08"] },
  { id: "pitch",   label: "Pitch & Ink",     swatches: ["#000",    "#FF3B41", "#fff",    "#fff"]    },
];

const FONTS = [
  { id: "russian",   label: "Russian Editorial", sample: "Bitter · Onest" },
  { id: "editorial", label: "Editorial",         sample: "Instrument Serif · DM Sans" },
  { id: "brutalist", label: "Brutalist",         sample: "Unbounded · Manrope" },
  { id: "geologica", label: "Cinema Mono",       sample: "Geologica" },
];

const TWEAK_DEFAULTS = /*EDITMODE-BEGIN*/{
  "palette": "cobalt",
  "font": "russian",
  "italicTitle": true
}/*EDITMODE-END*/;

function CinematicV2App() {
  const [t, setTweak] = useTweaks(TWEAK_DEFAULTS);
  return (
    <>
      <div className={`theme-host theme-${t.palette} font-${t.font}`} style={{
        minHeight: "100vh",
        background: "var(--bg)",
        color: "var(--text)"
      }}>
        <HomeCinematicV2 italicTitle={t.italicTitle} />
      </div>

      <TweaksPanel title="Tweaks">
        <TweakSection title="Палитра">
          <div style={{display: "grid", gridTemplateColumns: "1fr 1fr", gap: 8}}>
            {PALETTES.map(p => (
              <div key={p.id}
                onClick={() => setTweak("palette", p.id)}
                style={{
                  cursor: "pointer",
                  padding: 10,
                  borderRadius: 10,
                  border: t.palette === p.id ? "2px solid #6E56F7" : "1px solid rgba(255,255,255,0.1)",
                  background: t.palette === p.id ? "rgba(110,86,247,0.12)" : "rgba(255,255,255,0.03)"
                }}>
                <div style={{display:"flex", height: 28, borderRadius: 6, overflow:"hidden", marginBottom: 6}}>
                  {p.swatches.map((s,i) => <div key={i} style={{flex:1, background: s}}></div>)}
                </div>
                <div style={{fontSize: 11, color: "rgba(255,255,255,0.85)"}}>{p.label}</div>
              </div>
            ))}
          </div>
        </TweakSection>

        <TweakSection title="Шрифты">
          {FONTS.map(f => (
            <div key={f.id}
              onClick={() => setTweak("font", f.id)}
              style={{
                cursor: "pointer", padding: "10px 12px", marginBottom: 6,
                borderRadius: 8,
                border: t.font === f.id ? "1px solid #6E56F7" : "1px solid rgba(255,255,255,0.1)",
                background: t.font === f.id ? "rgba(110,86,247,0.12)" : "transparent"
              }}>
              <div style={{fontSize: 13, fontWeight: 600, color: "rgba(255,255,255,0.92)"}}>{f.label}</div>
              <div style={{fontSize: 11, color: "rgba(255,255,255,0.55)", marginTop: 2}}>{f.sample}</div>
            </div>
          ))}
        </TweakSection>

        <TweakSection title="Стиль титра">
          <TweakToggle label="Курсив на заголовках" value={t.italicTitle} onChange={(v) => setTweak("italicTitle", v)} />
        </TweakSection>
      </TweaksPanel>
    </>
  );
}

/* —— v2 of HomeCinematic: refined, theme-aware, wired to production API shape ——
   Data flows through window.loadFeatured / loadCategories / loadCategory / loadMovies
   from data.jsx. Falls back to fixtures when prod is CORS-blocked. Items match the
   NowPlayingItem schema (channelId, channelName, groupTitle, thumbnailUrl, program{...}). */

// Map a NowPlayingItem onto our Poster atom (onPoster URL, channel, computed progress).
function ItemPoster({ item, w, h, focus, hideMeta = true, fallbackIdx = 0, showProgress = true, badge }) {
  const prog = computeProgress(item.program);
  const poster = item.program?.icon || item.thumbnailUrl || null;
  const idx = (item.channelId ?? fallbackIdx) % TITLES.length;
  return (
    <Poster
      idx={idx}
      onPoster={poster}
      title={item.program?.title || item.channelName || "Нет данных EPG"}
      year={parseYear(item.program?.description) || ""}
      genre={item.program?.category || item.groupTitle || ""}
      channel={item.channelName}
      live={prog?.isNow}
      progress={showProgress && prog?.isNow ? Math.round(prog.progress * 100) : undefined}
      focus={focus}
      badge={badge}
      hideText={hideMeta}
      w={w} h={h}
    />
  );
}

function HomeCinematicV2({ italicTitle = true }) {
  const [featured, setFeatured] = useState(FIXTURE_FEATURED);
  const [categories, setCategories] = useState(FIXTURE_CATEGORIES);
  const [movies, setMovies] = useState(FIXTURE_MOVIES);
  const [activeCat, setActiveCat] = useState(0);
  const [activeRail, setActiveRail] = useState([]); // items for selected category
  const [source, setSource] = useState("…");
  const [tick, setTick] = useState(0);

  // initial load (parallel) + tick clock for progress recompute
  useEffect(() => {
    let mounted = true;
    Promise.all([loadFeatured(10), loadCategories(), loadMovies(20)]).then(([f, c, m]) => {
      if (!mounted) return;
      setFeatured(f.data); setCategories(c.data); setMovies(m.data);
      setSource(f.source === "live" ? "live" : "fixture");
    });
    const id = setInterval(() => setTick(t => t + 1), 30_000);
    return () => { mounted = false; clearInterval(id); };
  }, []);

  // load active category's items when changed
  useEffect(() => {
    const cat = categories[activeCat];
    if (!cat) return;
    loadCategory(cat.name, 12).then(r => {
      const arr = Array.isArray(r.data) ? r.data : (r.data?.items || []);
      setActiveRail(arr);
    });
  }, [activeCat, categories]);

  const hero = featured[0] || FIXTURE_FEATURED[0];
  const heroProg = computeProgress(hero.program);
  const heroSynopsis = parseSynopsis(hero.program?.description);
  const heroYear = parseYear(hero.program?.description);
  const fmtTime = (iso) => {
    if (!iso) return "—";
    const d = new Date(iso);
    return d.toLocaleTimeString("ru-RU", { hour: "2-digit", minute: "2-digit" });
  };
  const heroIdx = (hero.channelId ?? 0) % 16;

  return (
    <div className="mv-art mv-grain mv-vignette" style={{minHeight: "100vh", fontSize: 14, background: "var(--bg)"}}>
      <div className="mv-backdrop">
        <div className="layer" style={{backgroundImage: `url(${buildBackdrop(heroIdx)})`}}></div>
        <div className="grad" style={{
          background: "linear-gradient(180deg, color-mix(in oklab, var(--bg) 40%, transparent) 0%, color-mix(in oklab, var(--bg) 88%, transparent) 70%, var(--bg) 100%), radial-gradient(60% 50% at 30% 30%, var(--accent-soft), transparent 70%)"
        }}></div>
      </div>

      <Header />

      <div style={{padding: "20px 56px 40px", position: "relative", zIndex: 5}}>
        <div style={{display: "flex", gap: 10, marginBottom: 24, alignItems: "center"}}>
          {heroProg?.isNow && <Chip kind="live">В эфире</Chip>}
          <Chip kind="brand"><MMLogo />&nbsp;{hero.channelName}</Chip>
          {(hero.program?.category || hero.groupTitle) && <Chip>{hero.program?.category || hero.groupTitle}</Chip>}
          <Chip kind="ghost">HD · 5.1</Chip>
          <span style={{
            marginLeft: 8, fontFamily: "var(--font-mono)", fontSize: 10,
            letterSpacing: "0.12em", textTransform: "uppercase",
            color: source === "live" ? "var(--accent)" : "var(--text-mute)"
          }}>● {source === "live" ? "live api" : "fixture"}</span>
        </div>

        <div style={{
          fontFamily: "var(--font-display)",
          fontSize: "clamp(56px, 8vw, 120px)",
          fontWeight: 400,
          fontStyle: italicTitle ? "italic" : "normal",
          lineHeight: 0.92,
          letterSpacing: "var(--display-letter, -0.02em)",
          marginBottom: 22, maxWidth: 1100,
          textWrap: "pretty"
        }}>
          {(hero.program?.title || hero.channelName || "Нет данных EPG")
            .replace(/\s+(и|в|с|у|о|к|на|за|не|по|до|из|от|для)\s+/gi, "\u00a0$1\u00a0")}
        </div>

        <div style={{
          display: "flex", gap: 24, alignItems: "center", flexWrap: "wrap",
          fontFamily: "var(--font-mono)", fontSize: 12,
          letterSpacing: "0.12em", textTransform: "uppercase",
          color: "var(--text-dim)", marginBottom: 18
        }}>
          {heroYear && <span>{heroYear}</span>}
          {hero.program?.category && <span>{hero.program.category}</span>}
          {hero.program && <span>{Math.round(((new Date(hero.program.end) - new Date(hero.program.start))/60_000))} мин</span>}
          <span>16+</span>
          {heroProg?.isNow && <span style={{color: "var(--accent)"}}>● Сейчас идёт</span>}
        </div>

        {heroSynopsis && (
          <p style={{
            maxWidth: 720,
            fontFamily: "var(--font-ui)",
            fontSize: 17, lineHeight: 1.55,
            color: "var(--text-dim)",
            marginBottom: 32, textWrap: "pretty",
            display: "-webkit-box", WebkitLineClamp: 3, WebkitBoxOrient: "vertical", overflow: "hidden"
          }}>
            {heroSynopsis}
          </p>
        )}

        {heroProg?.isNow && hero.program && (
          <div style={{maxWidth: 720, marginBottom: 26}}>
            <div className="mv-track" style={{marginBottom: 8}}><i style={{width: `${Math.round(heroProg.progress*100)}%`}}></i></div>
            <div className="mv-ticks">
              <span>{fmtTime(hero.program.start)}</span>
              <span style={{color: "var(--text-dim)"}}>ещё {heroProg.remainingMin} мин</span>
              <span>{fmtTime(hero.program.end)}</span>
            </div>
          </div>
        )}

        <div style={{display: "flex", gap: 14, alignItems: "center", flexWrap: "wrap"}}>
          <button className="mv-btn primary focus">
            <svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor"><path d="M8 5v14l11-7z"/></svg>
            Включить эфир
          </button>
          <button className="mv-btn ghost">Программа канала</button>
          <button className="mv-btn ghost">+ Избранное</button>
        </div>
      </div>

      {/* Categories — from /api/categories. Click to swap the active rail. */}
      <div style={{
        padding: "8px 56px 0",
        position: "relative", zIndex: 5,
        display: "flex", alignItems: "center", gap: 28,
        borderTop: "1px solid var(--line)",
        borderBottom: "1px solid var(--line)",
        overflow: "hidden",
      }}>
        <span style={{
          fontFamily: "var(--font-mono)", fontSize: 10,
          letterSpacing: "0.18em", textTransform: "uppercase",
          color: "var(--text-mute)", flexShrink: 0,
        }}>Жанры /</span>
        <div style={{
          display: "flex", gap: 4, overflowX: "auto",
          flex: 1, padding: "12px 0",
          maskImage: "linear-gradient(90deg, transparent, #000 24px, #000 calc(100% - 60px), transparent)"
        }}>
          {categories.map((c, i) => {
            const active = i === activeCat;
            return (
              <div key={`${c.name}-${i}`}
                   onClick={() => setActiveCat(i)}
                   style={{
                     display: "flex", alignItems: "baseline", gap: 8,
                     padding: "10px 18px",
                     cursor: "pointer", whiteSpace: "nowrap",
                     borderRadius: 999,
                     fontFamily: "var(--font-ui)",
                     fontSize: 14, fontWeight: active ? 600 : 500,
                     color: active ? "var(--text)" : "var(--text-dim)",
                     background: active ? "var(--accent-soft)" : "transparent",
                     border: active ? "1px solid color-mix(in oklab, var(--accent) 60%, transparent)" : "1px solid transparent",
                     transition: "all 0.18s ease",
                   }}>
                {c.name === "18+" && <span style={{fontSize: 10, color: "var(--accent)"}}>⌬</span>}
                <span>{c.name}</span>
                <span style={{
                  fontFamily: "var(--font-mono)", fontSize: 10,
                  color: active ? "var(--accent)" : "var(--text-mute)",
                  letterSpacing: "0.05em",
                }}>{c.count}</span>
              </div>
            );
          })}
        </div>
        <span style={{
          fontFamily: "var(--font-mono)", fontSize: 10,
          letterSpacing: "0.18em", textTransform: "uppercase",
          color: "var(--text-mute)", flexShrink: 0,
        }}>{categories.reduce((a,c)=>a+c.count,0)} ch · m3u</span>
      </div>

      {/* Активная категория — bento-микс: один большой + лента */}
      <div style={{padding: "32px 0 28px"}}>
        <SectionTitle
          title={categories[activeCat]?.name || "Категория"}
          italic={italicTitle ? "сейчас в эфире" : null}
          count={activeRail.length}
          more="Все каналы" />
        <div style={{display: "flex", gap: 18, padding: "0 56px", overflow: "hidden", alignItems: "stretch"}}>
          {(Array.isArray(activeRail) ? activeRail : []).slice(0, 6).map((it, k) => {
            const prog = computeProgress(it.program);
            const remaining = prog?.remainingMin;
            const isFeat = k === 0;
            return (
              <div key={`${it.channelId}-${k}`} style={{position: "relative", flex: isFeat ? "0 0 460px" : "0 0 240px"}}>
                <ItemPoster item={it} w={isFeat ? 460 : 240} h={isFeat ? 300 : 300} focus={k === 0} fallbackIdx={k+3} />
                <div style={{
                  position: "absolute", bottom: -26, left: 4, right: 4,
                  display: "flex", justifyContent: "space-between",
                  fontFamily: "var(--font-mono)", fontSize: 10,
                  color: remaining != null && remaining <= 5 ? "var(--live)" : "var(--text-dim)",
                  letterSpacing: "0.12em", textTransform: "uppercase"
                }}>
                  <span>{it.channelName}</span>
                  {prog?.isNow && remaining != null && <span>−{remaining}м</span>}
                </div>
              </div>
            );
          })}
        </div>
      </div>

      {/* Фильмы — отдельная полка с total из /api/epg/movies */}
      <div style={{padding: "44px 0 60px"}}>
        <SectionTitle
          title="Фильмы"
          italic={italicTitle ? "в эфире" : null}
          count={movies.total}
          more="Все" />
        <div style={{display: "flex", gap: 18, padding: "0 56px"}}>
          {movies.items.slice(0, 6).map((it, k) => {
            const prog = computeProgress(it.program);
            return (
              <div key={`${it.channelId}-m-${k}`} style={{position: "relative"}}>
                <ItemPoster item={it} w={220} h={300} fallbackIdx={k+8}
                  badge={prog?.isNow ? `−${prog.remainingMin}м` : (it.program?.start ? fmtTime(it.program.start) : null)} />
              </div>
            );
          })}
        </div>
      </div>
    </div>
  );
}

ReactDOM.createRoot(document.getElementById("root")).render(<CinematicV2App />);
