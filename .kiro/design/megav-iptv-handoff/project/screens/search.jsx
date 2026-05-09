/* Search & filters */

function ScreenSearch() {
  const query = "север";
  const results = [1, 13, 8, 14, 0, 6];
  const sugg = ["Северный ветер", "Северный полюс · док.", "Север · Иванов", "Северные саги"];

  return (
    <div className="mv-art mv-grain" style={{minHeight: 1080}}>
      <Header />

      {/* Big search input — TV-friendly */}
      <div style={{padding: "12px 56px 28px"}}>
        <div style={{
          display: "flex", alignItems: "center", gap: 16,
          padding: "26px 28px",
          background: "var(--surface)",
          border: "1px solid var(--line)",
          borderRadius: "var(--r-lg)"
        }}>
          <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="var(--text-dim)" strokeWidth="1.6"><circle cx="11" cy="11" r="7"/><path d="M21 21l-4.3-4.3"/></svg>
          <div style={{
            fontFamily: "var(--font-display)", fontStyle: "italic",
            fontSize: 56, lineHeight: 1, flex: 1, letterSpacing: "-0.01em"
          }}>{query}<span style={{
            display: "inline-block", width: 3, height: 50,
            background: "var(--accent)", marginLeft: 8, verticalAlign: "middle",
            animation: "mvblink 1s steps(2) infinite"
          }}></span></div>
          <Chip kind="ghost">12 каналов</Chip>
          <Chip kind="ghost">38 фильмов</Chip>
          <Chip kind="brand">6 совпадений</Chip>
        </div>

        {/* Suggestions */}
        <div style={{display: "flex", gap: 12, marginTop: 18, flexWrap: "wrap"}}>
          {sugg.map((s, i) => (
            <div key={i} style={{
              padding: "10px 16px",
              borderRadius: 999,
              background: i === 0 ? "var(--accent-soft)" : "rgba(255,255,255,0.04)",
              border: `1px solid ${i === 0 ? "var(--accent)" : "var(--line)"}`,
              color: i === 0 ? "#c8b8ff" : "var(--text-dim)",
              fontSize: 14
            }}>{s}</div>
          ))}
        </div>
      </div>

      <div style={{display: "grid", gridTemplateColumns: "260px 1fr", gap: 28, padding: "0 56px"}}>
        {/* Filter sidebar */}
        <aside style={{
          padding: 20,
          background: "var(--surface)",
          border: "1px solid var(--line)",
          borderRadius: "var(--r-md)",
          height: "fit-content"
        }}>
          <div style={{fontFamily: "var(--font-mono)", fontSize: 11, letterSpacing: "0.16em", color: "var(--text-mute)", marginBottom: 16}}>ФИЛЬТРЫ</div>

          {[
            {label: "Жанр", values: ["Все", "Драма", "Триллер", "Артхаус", "Док.", "Спорт"]},
            {label: "Год", values: ["1960-69", "1970-89", "1990-09", "2010+"]},
            {label: "Качество", values: ["HD", "4K UHD", "Dolby Vision"]},
            {label: "Язык", values: ["RU", "EN", "Original"]},
          ].map((f, fi) => (
            <div key={fi} style={{marginBottom: 18}}>
              <div style={{fontSize: 12, color: "var(--text-dim)", marginBottom: 8, letterSpacing: "0.04em"}}>{f.label}</div>
              <div style={{display: "flex", gap: 6, flexWrap: "wrap"}}>
                {f.values.map((v, vi) => {
                  const active = (fi === 0 && vi === 1) || (fi === 1 && vi === 1);
                  return (
                    <span key={vi} style={{
                      padding: "5px 10px", borderRadius: 6, fontSize: 11,
                      background: active ? "var(--accent)" : "rgba(255,255,255,0.04)",
                      color: active ? "white" : "var(--text-dim)",
                      border: `1px solid ${active ? "var(--accent)" : "var(--line)"}`
                    }}>{v}</span>
                  );
                })}
              </div>
            </div>
          ))}

          <div style={{marginTop: 22, paddingTop: 16, borderTop: "1px solid var(--line)"}}>
            <div style={{fontSize: 12, color: "var(--text-dim)", marginBottom: 12}}>Рейтинг IMDb</div>
            <div className="mv-track" style={{height: 4}}><i style={{width: "65%"}}></i></div>
            <div style={{display: "flex", justifyContent: "space-between", marginTop: 6, fontFamily: "var(--font-mono)", fontSize: 10, color: "var(--text-mute)"}}>
              <span>0.0</span><span style={{color: "var(--accent)"}}>6.5+</span><span>10</span>
            </div>
          </div>
        </aside>

        {/* Results grid */}
        <div>
          <div style={{display: "flex", alignItems: "baseline", gap: 14, marginBottom: 16}}>
            <div style={{fontFamily: "var(--font-display)", fontStyle: "italic", fontSize: 28}}>Результаты</div>
            <span style={{fontFamily: "var(--font-mono)", fontSize: 11, color: "var(--text-mute)", letterSpacing: "0.12em"}}>06 СОВПАДЕНИЙ · ОТСОРТИРОВАНО ПО РЕЛЕВАНТНОСТИ</span>
          </div>

          {/* Top result — wide highlight */}
          <div style={{
            display: "grid", gridTemplateColumns: "240px 1fr",
            gap: 22, marginBottom: 24,
            padding: 18,
            border: "1px solid var(--accent)",
            borderRadius: "var(--r-md)",
            background: "var(--accent-soft)",
            outline: "3px solid var(--accent)",
            outlineOffset: 3
          }}>
            <Poster idx={1} w={240} h={340} hideText={true} />
            <div>
              <div style={{display: "flex", gap: 8, marginBottom: 12}}>
                <Chip kind="brand">Лучший результат</Chip>
                <Chip kind="ghost">3 эпизода</Chip>
              </div>
              <div style={{fontFamily: "var(--font-display)", fontStyle: "italic", fontSize: 56, lineHeight: 1}}>
                {TITLES[1].t}
              </div>
              <div style={{fontFamily: "var(--font-mono)", fontSize: 11, color: "var(--text-dim)", letterSpacing: "0.12em", marginTop: 10, textTransform: "uppercase"}}>
                <span style={{color: "var(--gold)"}}>★ 7.9</span> · {TITLES[1].y} · {TITLES[1].g} · {TITLES[1].d}
              </div>
              <p style={{fontSize: 14, color: "var(--text-dim)", lineHeight: 1.55, marginTop: 14, maxWidth: 600}}>
                Северное побережье, тёплая семья и одинокий маяк. История о тишине, которую
                невозможно перевести на чужой язык.
              </p>
              <div style={{display: "flex", gap: 10, marginTop: 18}}>
                <button className="mv-btn primary"><svg width="12" height="12" viewBox="0 0 24 24" fill="currentColor"><path d="M8 5v14l11-7z"/></svg>Смотреть</button>
                <button className="mv-btn ghost">Подробнее</button>
              </div>
            </div>
          </div>

          <div style={{display: "grid", gridTemplateColumns: "repeat(5, 1fr)", gap: 14}}>
            {results.map(i => (
              <Poster key={i} idx={i} w={170} h={240} hideText={true}/>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}

if (!document.getElementById("mv-search-keys")) {
  const s = document.createElement("style");
  s.id = "mv-search-keys";
  s.textContent = `@keyframes mvblink { 50% { opacity: 0; } }`;
  document.head.appendChild(s);
}

window.ScreenSearch = ScreenSearch;
