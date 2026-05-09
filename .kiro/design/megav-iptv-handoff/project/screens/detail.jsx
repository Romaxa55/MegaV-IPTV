/* Channel/Movie detail — hero shared element transition */

function ScreenDetail() {
  const idx = 11;
  const t = TITLES[idx];
  const cast = ["Анна Колесник", "Игорь Птицын", "Мариа Ло", "Симон Беккет", "Юна Кано"];
  const recoIdx = [3, 7, 1, 14, 0, 9];

  return (
    <div className="mv-art mv-grain mv-vignette" style={{minHeight: 1080}}>
      <div className="mv-backdrop">
        <div className="layer" style={{backgroundImage: `url(${buildBackdrop(idx)})`}}></div>
        <div className="grad"></div>
      </div>

      <Header />

      {/* Back nav */}
      <div style={{padding: "0 56px 12px", display: "flex", alignItems: "center", gap: 14, position: "relative", zIndex: 5}}>
        <button className="mv-iconbtn">
          <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path d="M15 18l-6-6 6-6"/></svg>
        </button>
        <span style={{
          fontFamily: "var(--font-mono)", fontSize: 11,
          letterSpacing: "0.14em", color: "var(--text-dim)", textTransform: "uppercase"
        }}>Главная / Кино / {t.t}</span>
      </div>

      {/* Detail body */}
      <div style={{
        padding: "20px 56px 60px", position: "relative", zIndex: 5,
        display: "grid", gridTemplateColumns: "auto 1fr", gap: 48
      }}>
        {/* Big poster (shared element) */}
        <div style={{position: "relative"}}>
          <Poster idx={idx} w={460} h={680} hideText={true} />
          <div style={{
            position: "absolute", left: -14, bottom: 24,
            background: "var(--accent)", color: "white",
            fontFamily: "var(--font-mono)", fontSize: 10,
            letterSpacing: "0.16em", fontWeight: 700,
            padding: "8px 12px", borderRadius: 4,
            transform: "rotate(-90deg)", transformOrigin: "left bottom"
          }}>HERO TRANSITION ↗</div>
        </div>

        <div style={{display: "flex", flexDirection: "column", gap: 24}}>
          <div style={{display: "flex", gap: 8}}>
            <Chip kind="live">Live</Chip>
            <Chip kind="brand"><MMLogo /> &nbsp;MM Classic HD</Chip>
            <Chip>4K · Dolby</Chip>
            <Chip kind="ghost">16+</Chip>
          </div>

          <div>
            <div style={{
              fontFamily: "var(--font-display)", fontStyle: "italic",
              fontSize: 96, lineHeight: 0.95, letterSpacing: "-0.02em"
            }}>{t.t}</div>
            <div style={{
              display: "flex", gap: 20,
              fontFamily: "var(--font-mono)", fontSize: 12,
              letterSpacing: "0.14em", color: "var(--text-dim)",
              textTransform: "uppercase", marginTop: 14
            }}>
              <span style={{color: "var(--gold)"}}>★ 8.4</span>
              <span>{t.y}</span>
              <span>{t.g}</span>
              <span>{t.d}</span>
              <span>3 сезона</span>
            </div>
          </div>

          <p style={{
            fontSize: 18, lineHeight: 1.55, color: "var(--text)",
            maxWidth: 720, margin: 0, textWrap: "pretty"
          }}>
            Зимние диалоги в комнате с одним окном. Старый часовщик и его племянница
            заново учатся слышать друг друга — пока за стеной идут поезда, везущие
            кого-то домой и кого-то прочь.
          </p>

          <div>
            <div style={{
              fontFamily: "var(--font-mono)", fontSize: 11,
              letterSpacing: "0.16em", color: "var(--text-mute)",
              marginBottom: 10, textTransform: "uppercase"
            }}>В ролях</div>
            <div style={{display: "flex", gap: 18, flexWrap: "wrap"}}>
              {cast.map((c, i) => (
                <div key={i} style={{display: "flex", alignItems: "center", gap: 10}}>
                  <div style={{
                    width: 36, height: 36, borderRadius: "50%",
                    background: `linear-gradient(135deg, ${POSTER_PALETTES[i][1]}, ${POSTER_PALETTES[i][2]})`,
                    border: "1px solid var(--line)"
                  }}></div>
                  <span style={{fontSize: 14, color: "var(--text)"}}>{c}</span>
                </div>
              ))}
            </div>
          </div>

          <div style={{maxWidth: 600}}>
            <div className="mv-track" style={{marginBottom: 8}}><i style={{width: "62%"}}></i></div>
            <div className="mv-ticks">
              <span>02:45 / 03:59</span>
              <span style={{color: "var(--accent)"}}>● Идёт сейчас</span>
            </div>
          </div>

          <div style={{display: "flex", gap: 12, alignItems: "center"}}>
            <button className="mv-btn primary focus">
              <svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor"><path d="M8 5v14l11-7z"/></svg>
              Смотреть
            </button>
            <button className="mv-btn ghost">+ В избранное</button>
            <button className="mv-btn ghost">Трейлер</button>
            <button className="mv-btn ghost">Поделиться</button>
          </div>
        </div>
      </div>

      {/* EPG strip */}
      <div style={{padding: "16px 56px 24px"}}>
        <SectionTitle title="Сегодня" italic="на канале" count={6} more="Вся программа" />
        <div style={{display: "grid", gridTemplateColumns: "repeat(6, 1fr)", gap: 12}}>
          {[
            {t: "01:30", n: "Утренний выпуск", live: false, past: true},
            {t: "02:45", n: t.t, live: true, past: false},
            {t: "04:00", n: TITLES[3].t, live: false},
            {t: "05:30", n: TITLES[7].t, live: false},
            {t: "07:00", n: TITLES[12].t, live: false},
            {t: "08:30", n: TITLES[14].t, live: false},
          ].map((s, i) => (
            <div key={i} style={{
              padding: 14,
              background: s.live ? "var(--accent-soft)" : "rgba(20,20,26,0.55)",
              border: `1px solid ${s.live ? "var(--accent)" : "var(--line)"}`,
              borderRadius: "var(--r-sm)",
              opacity: s.past ? 0.4 : 1
            }}>
              <div style={{
                fontFamily: "var(--font-mono)", fontSize: 11,
                color: s.live ? "var(--accent)" : "var(--text-mute)",
                letterSpacing: "0.1em"
              }}>{s.t}</div>
              <div style={{
                fontFamily: "var(--font-display)", fontStyle: "italic",
                fontSize: 18, marginTop: 6, lineHeight: 1.15
              }}>{s.n}</div>
            </div>
          ))}
        </div>
      </div>

      {/* Recommendations */}
      <div style={{padding: "20px 0 40px"}}>
        <SectionTitle title="Похожие" italic="по настроению" count={recoIdx.length} />
        <div style={{display: "flex", gap: 16, padding: "0 56px"}}>
          {recoIdx.map(i => (
            <Poster key={i} idx={i} w={200} h={290} hideText={true} />
          ))}
        </div>
      </div>
    </div>
  );
}

window.ScreenDetail = ScreenDetail;
