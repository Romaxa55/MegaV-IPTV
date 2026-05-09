/* Settings — performance focus */

function ScreenSettings() {
  const sections = [
    { label: "Воспроизведение",  active: true },
    { label: "Плейлисты M3U" },
    { label: "Производительность" },
    { label: "Жесты и пульт" },
    { label: "Подписки и акк." },
    { label: "Об устройстве" },
  ];

  return (
    <div className="mv-art mv-grain" style={{minHeight: 1080}}>
      <Header />

      <div style={{padding: "8px 56px 28px", borderBottom:"1px solid var(--line)"}}>
        <div style={{fontFamily:"var(--font-display)", fontStyle:"italic", fontSize:56, lineHeight:1}}>
          Настройки
        </div>
        <div style={{fontFamily:"var(--font-mono)", fontSize:11, color:"var(--text-mute)", letterSpacing:"0.16em", marginTop:8, textTransform:"uppercase"}}>
          MegaV IPTV · v 2.6.0 · Flutter Engine 3.22 · Impeller ON
        </div>
      </div>

      <div style={{display:"grid", gridTemplateColumns:"260px 1fr", gap: 0, padding: 0}}>
        {/* Sidebar nav */}
        <aside style={{borderRight:"1px solid var(--line)", padding: "28px 0"}}>
          {sections.map((s, i) => (
            <div key={i} style={{
              padding: "14px 56px",
              fontSize: 14,
              color: s.active ? "var(--text)" : "var(--text-dim)",
              borderLeft: s.active ? "2px solid var(--accent)" : "2px solid transparent",
              background: s.active ? "var(--accent-soft)" : "transparent",
              fontWeight: s.active ? 500 : 400
            }}>{s.label}</div>
          ))}
        </aside>

        {/* Body */}
        <div style={{padding: "32px 56px"}}>
          {/* Hero "Performance card" */}
          <div style={{
            padding: 24,
            background: "var(--surface)",
            border: "1px solid var(--accent)",
            borderRadius: "var(--r-md)",
            marginBottom: 28,
            display: "grid", gridTemplateColumns: "1fr 1fr 1fr 1fr", gap: 24,
            position: "relative", overflow: "hidden"
          }}>
            <div style={{
              position: "absolute", inset: 0,
              background: "radial-gradient(60% 80% at 0% 0%, var(--accent-soft), transparent 70%)",
              pointerEvents: "none"
            }}></div>
            <Stat label="GPU FPS" value="119" sub="средний за сессию" trend="+18%"/>
            <Stat label="Кадры пропущ." value="0.4%" sub="последние 60s" trend="ok"/>
            <Stat label="Память" value="184 МБ" sub="кэш + пул" trend="−22 МБ"/>
            <Stat label="Сетевой буфер" value="3.2s" sub="adaptive HLS" trend="ok"/>
          </div>

          <h4 style={{fontFamily:"var(--font-display)", fontStyle:"italic", fontSize:30, fontWeight:400, margin:"0 0 18px"}}>Воспроизведение</h4>

          <Toggle label="Аппаратное ускорение (Impeller)" sub="Flutter Impeller backend, +30% FPS на TV" on={true} accent />
          <Toggle label="Предзагрузка превью каналов" sub="плавный swipe между каналами без чёрных кадров" on={true} />
          <Toggle label="Параллакс на постерах" sub="мягкий blur+скролл при фокусе" on={true} />
          <Toggle label="Hero shared element transitions" sub="постер плавно переходит из ленты в детальный экран" on={true} />
          <Toggle label="Тактильная обратная связь" sub="вибро-отклик при смене фокуса (телефон)" on={true} />
          <Toggle label="Авто-качество (ABR)" sub="подстраивается под канал; ручное в плеере" on={true} />
          <Toggle label="Энергосбережение" sub="падение FPS до 30, выкл. blur, серый акцент" on={false} />

          <Picker label="Кодек по умолчанию" options={["AV1", "H.265", "H.264"]} active={1}/>
          <Picker label="Декодирование" options={["GPU", "CPU", "Hybrid"]} active={0}/>
          <Picker label="Цветовое пространство" options={["BT.2020 HDR", "BT.709", "Auto"]} active={2}/>
          <Picker label="Жесты" options={["←/→ канал, ↑/↓ громкость", "Apple TV Remote", "Custom"]} active={0}/>
        </div>
      </div>
    </div>
  );
}

function Stat({ label, value, sub, trend }) {
  return (
    <div>
      <div style={{fontFamily:"var(--font-mono)", fontSize:10, letterSpacing:"0.16em", color:"var(--text-mute)", textTransform:"uppercase"}}>{label}</div>
      <div style={{fontFamily:"var(--font-display)", fontStyle:"italic", fontSize:48, lineHeight:1, margin:"6px 0"}}>{value}</div>
      <div style={{display:"flex", gap:8, alignItems:"center"}}>
        <span style={{fontSize:11, color:"var(--text-dim)"}}>{sub}</span>
        <span style={{fontFamily:"var(--font-mono)", fontSize:10, color: trend === "ok" ? "var(--good)" : "var(--good)", letterSpacing:"0.08em"}}>● {trend}</span>
      </div>
    </div>
  );
}

function Toggle({ label, sub, on, accent }) {
  return (
    <div style={{
      display:"flex", alignItems:"center", gap: 18,
      padding: "16px 0",
      borderBottom: "1px solid var(--line)"
    }}>
      <div style={{flex:1}}>
        <div style={{fontSize:15, color:"var(--text)"}}>{label}</div>
        <div style={{fontSize:12, color:"var(--text-mute)", marginTop:4}}>{sub}</div>
      </div>
      <div style={{
        width: 46, height: 26, borderRadius: 13,
        background: on ? (accent ? "var(--accent)" : "rgba(255,255,255,0.18)") : "rgba(255,255,255,0.06)",
        position: "relative",
        transition: "background 0.2s",
        boxShadow: on && accent ? "0 0 18px var(--accent-glow)" : "none"
      }}>
        <div style={{
          position: "absolute", top: 3, left: on ? 23 : 3,
          width: 20, height: 20, borderRadius: "50%",
          background: "white",
          transition: "left 0.2s"
        }}></div>
      </div>
    </div>
  );
}

function Picker({ label, options, active }) {
  return (
    <div style={{display:"flex", alignItems:"center", padding: "16px 0", borderBottom: "1px solid var(--line)"}}>
      <div style={{fontSize:15, flex: 1}}>{label}</div>
      <div style={{display:"flex", gap: 6}}>
        {options.map((o, i) => (
          <span key={i} style={{
            padding: "6px 12px", borderRadius: 6, fontSize: 12,
            background: i === active ? "var(--accent)" : "rgba(255,255,255,0.04)",
            color: i === active ? "white" : "var(--text-dim)",
            border: `1px solid ${i === active ? "var(--accent)" : "var(--line)"}`
          }}>{o}</span>
        ))}
      </div>
    </div>
  );
}

window.ScreenSettings = ScreenSettings;
