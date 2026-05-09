/* Home — Variant A: Cinematic full-bleed (hero_layout option 0) */

function HomeCinematic() {
  const heroIdx = 11;
  const continueIdx = [4, 7, 14, 9, 2];
  const newIdx = [0, 1, 12, 6, 3, 15];

  return (
    <div className="mv-art mv-grain mv-vignette" style={{minHeight: 1080, fontSize: 14}}>
      {/* Backdrop */}
      <div className="mv-backdrop">
        <div className="layer" style={{backgroundImage: `url(${buildBackdrop(heroIdx)})`}}></div>
        <div className="grad"></div>
      </div>

      <Header city="Kampala" temp="19°" time="03:04" />

      {/* HERO — full-bleed cinematic */}
      <div style={{padding: "20px 56px 40px", position: "relative", zIndex: 5}}>
        <div style={{display: "flex", gap: 10, marginBottom: 22}}>
          <Chip kind="live">В эфире</Chip>
          <Chip kind="brand"><MMLogo /> &nbsp;MM Classic HD</Chip>
          <Chip>Драма</Chip>
          <Chip kind="ghost">HD · 5.1</Chip>
        </div>

        <div style={{
          fontFamily: "var(--font-display)",
          fontSize: 110, fontWeight: 400, fontStyle: "italic",
          lineHeight: 0.95, letterSpacing: "-0.02em",
          marginBottom: 22, maxWidth: 1100,
          textWrap: "pretty"
        }}>
          {TITLES[heroIdx].t}
        </div>

        <div style={{
          display: "flex", gap: 24, alignItems: "center",
          fontFamily: "var(--font-mono)", fontSize: 12,
          letterSpacing: "0.12em", textTransform: "uppercase",
          color: "var(--text-dim)", marginBottom: 18
        }}>
          <span style={{color: "var(--gold)"}}>★ 8.4</span>
          <span>{TITLES[heroIdx].y}</span>
          <span>{TITLES[heroIdx].g}</span>
          <span>{TITLES[heroIdx].d}</span>
          <span>16+</span>
          <span style={{color: "var(--accent)"}}>● Сейчас идёт</span>
        </div>

        <p style={{
          maxWidth: 720,
          fontSize: 17, lineHeight: 1.55,
          color: "var(--text-dim)",
          marginBottom: 32,
          textWrap: "pretty"
        }}>
          В небольшом приморском городе тревожный сезон штормов застаёт врасплох смотрителя
          маяка и его дочь. Тихая хроника одиночества, написанная тёплым светом и долгими
          паузами между словами.
        </p>

        {/* progress + remaining */}
        <div style={{maxWidth: 720, marginBottom: 26}}>
          <div className="mv-track" style={{marginBottom: 8}}><i style={{width: "62%"}}></i></div>
          <div className="mv-ticks">
            <span>02:45</span>
            <span style={{color: "var(--text-dim)"}}>ещё 55 мин</span>
            <span>03:59</span>
          </div>
        </div>

        <div style={{display: "flex", gap: 14, alignItems: "center"}}>
          <button className="mv-btn primary focus">
            <svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor"><path d="M8 5v14l11-7z"/></svg>
            Смотреть · продолжить
          </button>
          <button className="mv-btn ghost">
            <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path d="M19 14V6a2 2 0 0 0-2-2H7a2 2 0 0 0-2 2v8M5 14h14M5 14l-2 7h18l-2-7"/></svg>
            Программа
          </button>
          <button className="mv-btn ghost">
            <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path d="M19 21l-7-5-7 5V5a2 2 0 0 1 2-2h10a2 2 0 0 1 2 2z"/></svg>
            В избранное
          </button>
          <div style={{flex: 1}}></div>
          <RemoteHint items={[
            {k: "←→", label: "каналы"},
            {k: "OK", label: "смотреть"},
            {k: "≡", label: "EPG"},
          ]}/>
        </div>
      </div>

      {/* Genre tabs */}
      <GenreTabs counts={[12, 30, 18, 9, 14, 6, 8]} active={0} />

      {/* Continue rail */}
      <div style={{padding: "32px 0 24px", position: "relative", zIndex: 4}}>
        <SectionTitle title="Продолжить" italic="смотреть" count={5} />
        <div style={{display: "flex", gap: 18, padding: "0 56px", overflow: "hidden"}}>
          {continueIdx.map((i, k) => (
            <Poster key={i} idx={i} w={300} h={170}
              title={TITLES[i].t} year={TITLES[i].y} genre={TITLES[i].g}
              progress={[18, 45, 72, 8, 90][k]}
              channel={CHANNELS[k % CHANNELS.length].name}
              focus={k === 0}
              hideText={true}
            />
          ))}
        </div>
      </div>

      {/* Now-on-air rail */}
      <div style={{padding: "16px 0 40px", position: "relative", zIndex: 4}}>
        <SectionTitle title="Сейчас в эфире" count={30} />
        <div style={{display: "flex", gap: 18, padding: "0 56px"}}>
          {newIdx.map((i, k) => (
            <div key={i} style={{position: "relative"}}>
              <Poster idx={i} w={220} h={300}
                title={TITLES[i].t} year={TITLES[i].y} genre={TITLES[i].g}
                live={k < 4}
                channel={CHANNELS[(i+2) % CHANNELS.length].name}
                hideText={true}
              />
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}

window.HomeCinematic = HomeCinematic;
