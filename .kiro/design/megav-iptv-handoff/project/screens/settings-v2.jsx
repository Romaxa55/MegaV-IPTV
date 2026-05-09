/* Settings v2 — clean, cobalt, Golos Text */

const { useMemo: useMS, useState: useSS } = React;

const SETTINGS_NAV = [
  { id: "playback",  label: "Воспроизведение",      sub: "плеер · кодеки · переходы" },
  { id: "playlists", label: "Плейлисты M3U",         sub: "источники · обновления" },
  { id: "perf",      label: "Производительность",    sub: "GPU · буфер · энергия" },
  { id: "remote",    label: "Жесты и пульт",         sub: "D-pad · свайпы · хоткеи" },
  { id: "account",   label: "Подписки и аккаунт",    sub: "MM Plus · профили" },
  { id: "about",     label: "Об устройстве",         sub: "сборка · версии · правовое" },
];

// ─── Atoms ────────────────────────────────────────────────────────────────
function SLabel({ children, count }) {
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

function StatTile({ label, value, sub, trend, trendColor = "var(--good, #2ecf6f)" }) {
  return (
    <div style={{
      padding: "20px 22px",
      background: "rgba(255,255,255,0.02)",
      border: "1px solid var(--line)",
      borderRadius: 10,
      position: "relative", zIndex: 1,
    }}>
      <div style={{
        fontFamily: "var(--font-mono)", fontSize: 10,
        letterSpacing: "0.18em", textTransform: "uppercase",
        color: "var(--text-mute)",
      }}>{label}</div>
      <div style={{
        fontFamily: "var(--font-display)", fontWeight: 600,
        fontSize: 44, lineHeight: 1.0, letterSpacing: "-0.03em",
        margin: "10px 0 8px",
        color: "var(--text)",
      }}>{value}</div>
      <div style={{display: "flex", justifyContent: "space-between", alignItems: "center", gap: 8}}>
        <span style={{fontFamily: "var(--font-ui)", fontSize: 12, color: "var(--text-dim)"}}>{sub}</span>
        <span style={{
          display: "inline-flex", alignItems: "center", gap: 5,
          fontFamily: "var(--font-mono)", fontSize: 10,
          letterSpacing: "0.1em", fontWeight: 600,
          color: trendColor,
        }}>
          <span style={{
            width: 6, height: 6, borderRadius: 3, background: trendColor,
          }}></span>
          {trend}
        </span>
      </div>
    </div>
  );
}

function Toggle({ label, sub, on, accent, focused }) {
  return (
    <div style={{
      display: "flex", alignItems: "center", gap: 18,
      padding: "18px 16px",
      margin: "0 -16px",
      borderRadius: 8,
      background: focused ? "rgba(36,80,222,0.06)" : "transparent",
      border: focused ? "1px solid var(--accent)" : "1px solid transparent",
      borderBottom: focused ? "1px solid var(--accent)" : "1px solid var(--line)",
    }}>
      <div style={{flex: 1, minWidth: 0}}>
        <div style={{
          fontFamily: "var(--font-ui)", fontSize: 15, fontWeight: 500,
          color: "var(--text)",
        }}>{label}</div>
        <div style={{
          fontFamily: "var(--font-ui)", fontSize: 12,
          color: "var(--text-mute)", marginTop: 4, lineHeight: 1.4,
        }}>{sub}</div>
      </div>
      <div style={{
        width: 44, height: 24, borderRadius: 12,
        background: on
          ? (accent ? "var(--accent)" : "rgba(255,255,255,0.22)")
          : "rgba(255,255,255,0.06)",
        position: "relative",
        transition: "background 200ms ease",
        boxShadow: on && accent ? "0 0 14px rgba(36,80,222,0.35)" : "none",
        flexShrink: 0,
      }}>
        <div style={{
          position: "absolute", top: 3, left: on ? 23 : 3,
          width: 18, height: 18, borderRadius: "50%",
          background: "#fff",
          transition: "left 200ms ease",
          boxShadow: "0 1px 3px rgba(0,0,0,0.4)",
        }}></div>
      </div>
    </div>
  );
}

function Picker({ label, sub, options, active }) {
  return (
    <div style={{
      display: "flex", alignItems: "center", gap: 18,
      padding: "18px 0",
      borderBottom: "1px solid var(--line)",
    }}>
      <div style={{flex: 1, minWidth: 0}}>
        <div style={{
          fontFamily: "var(--font-ui)", fontSize: 15, fontWeight: 500,
          color: "var(--text)",
        }}>{label}</div>
        {sub && <div style={{
          fontFamily: "var(--font-ui)", fontSize: 12,
          color: "var(--text-mute)", marginTop: 4,
        }}>{sub}</div>}
      </div>
      <div style={{display: "flex", gap: 6, flexWrap: "wrap", justifyContent: "flex-end"}}>
        {options.map((o, i) => (
          <span key={i} style={{
            padding: "7px 12px",
            borderRadius: 6,
            fontFamily: "var(--font-ui)", fontSize: 12, fontWeight: 500,
            background: i === active ? "var(--accent)" : "rgba(255,255,255,0.04)",
            color:      i === active ? "#fff"          : "var(--text-dim)",
            border: `1px solid ${i === active ? "var(--accent)" : "var(--line)"}`,
            whiteSpace: "nowrap",
          }}>{o}</span>
        ))}
      </div>
    </div>
  );
}

// ─── Sections ─────────────────────────────────────────────────────────────
function PerformanceHero() {
  return (
    <div style={{
      position: "relative", overflow: "hidden",
      padding: 24,
      background: "linear-gradient(135deg, rgba(36,80,222,0.10) 0%, rgba(36,80,222,0.02) 60%)",
      border: "1px solid var(--accent)",
      borderRadius: 14,
      marginBottom: 36,
    }}>
      {/* subtle radial glow */}
      <div style={{
        position: "absolute", inset: 0,
        background: "radial-gradient(60% 80% at 0% 0%, rgba(36,80,222,0.18), transparent 60%)",
        pointerEvents: "none",
      }}></div>

      <div style={{
        display: "flex", alignItems: "baseline", gap: 14, marginBottom: 18,
        position: "relative", zIndex: 1,
      }}>
        <span style={{
          padding: "4px 10px", borderRadius: 4,
          background: "var(--accent)", color: "#fff",
          fontFamily: "var(--font-mono)", fontWeight: 600,
          fontSize: 10, letterSpacing: "0.18em",
        }}>LIVE METRICS</span>
        <span style={{
          fontFamily: "var(--font-mono)", fontSize: 10,
          letterSpacing: "0.18em", textTransform: "uppercase",
          color: "var(--text-mute)",
        }}>обновляется каждые 2 секунды</span>
      </div>

      <div style={{
        display: "grid", gridTemplateColumns: "repeat(4, 1fr)", gap: 12,
        position: "relative", zIndex: 1,
      }}>
        <StatTile label="GPU FPS"           value="119"     sub="средний за сессию" trend="+18%"     />
        <StatTile label="Кадры пропущены"   value="0.4%"    sub="последние 60s"     trend="STABLE"   />
        <StatTile label="Память"            value="184 МБ"  sub="кэш + пул"         trend="−22 МБ"  />
        <StatTile label="Сетевой буфер"     value="3.2s"    sub="adaptive HLS"      trend="OK"      />
      </div>
    </div>
  );
}

// ─── Sidebar ──────────────────────────────────────────────────────────────
function Sidebar({ active }) {
  return (
    <aside style={{
      borderRight: "1px solid var(--line)",
      padding: "32px 0",
      background: "var(--bg)",
    }}>
      <div style={{padding: "0 32px 16px"}}>
        <SLabel count={SETTINGS_NAV.length}>Разделы</SLabel>
      </div>
      {SETTINGS_NAV.map((s) => {
        const isActive = s.id === active;
        return (
          <div key={s.id} style={{
            padding: "16px 32px",
            borderLeft: isActive ? "2px solid var(--accent)" : "2px solid transparent",
            background: isActive ? "rgba(36,80,222,0.08)" : "transparent",
            cursor: "pointer",
          }}>
            <div style={{
              fontFamily: "var(--font-ui)", fontSize: 15, fontWeight: isActive ? 600 : 500,
              color: isActive ? "var(--text)" : "var(--text-dim)",
            }}>{s.label}</div>
            <div style={{
              fontFamily: "var(--font-mono)", fontSize: 10,
              letterSpacing: "0.14em", textTransform: "uppercase",
              color: "var(--text-mute)", marginTop: 4,
            }}>{s.sub}</div>
          </div>
        );
      })}
    </aside>
  );
}

// ─── Account card ─────────────────────────────────────────────────────────
function AccountCard() {
  return (
    <div style={{
      display: "flex", alignItems: "center", gap: 18,
      padding: 20,
      background: "var(--surface)",
      border: "1px solid var(--line)",
      borderRadius: 12,
      marginTop: 36,
    }}>
      <div style={{
        width: 56, height: 56, borderRadius: "50%",
        background: "linear-gradient(135deg, #2450de, #1230a8)",
        display: "grid", placeItems: "center",
        fontFamily: "var(--font-display)", fontWeight: 600,
        fontSize: 22, color: "#fff", letterSpacing: "-0.02em",
      }}>МС</div>
      <div style={{flex: 1, minWidth: 0}}>
        <div style={{
          fontFamily: "var(--font-ui)", fontSize: 16, fontWeight: 600,
          color: "var(--text)",
        }}>Марко Степанов</div>
        <div style={{
          fontFamily: "var(--font-mono)", fontSize: 10,
          letterSpacing: "0.18em", textTransform: "uppercase",
          color: "var(--text-mute)", marginTop: 4,
        }}>MM Plus · до 14.04.2026 · профиль 1 из 4</div>
      </div>
      <button style={{
        padding: "10px 18px",
        background: "transparent", color: "var(--text)",
        border: "1px solid var(--line)", borderRadius: 6,
        fontFamily: "var(--font-ui)", fontSize: 13, fontWeight: 500,
        cursor: "pointer",
      }}>Управление</button>
    </div>
  );
}

// ─── Main screen ──────────────────────────────────────────────────────────
function ScreenSettingsV2() {
  return (
    <div style={{
      width: "100%", minHeight: 900,
      background: "var(--bg)", color: "var(--text)",
      fontFamily: "var(--font-ui)",
    }}>
      {/* HEADER */}
      <div style={{padding: "32px 56px 28px", borderBottom: "1px solid var(--line)"}}>
        <div style={{display: "flex", alignItems: "flex-end", gap: 28}}>
          <div>
            <div style={{
              fontFamily: "var(--font-mono)", fontSize: 10,
              letterSpacing: "0.22em", textTransform: "uppercase",
              color: "var(--text-mute)", marginBottom: 8,
            }}>Настройки · MegaV IPTV</div>
            <div style={{
              fontFamily: "var(--font-display)", fontWeight: 600,
              fontSize: 56, lineHeight: 0.95, letterSpacing: "-0.025em",
            }}>Под <span style={{color: "var(--text-dim)", fontWeight: 400}}>себя</span></div>
          </div>
          <div style={{flex: 1}}></div>
          <div style={{
            fontFamily: "var(--font-mono)", fontSize: 10,
            letterSpacing: "0.18em", textTransform: "uppercase",
            color: "var(--text-mute)",
            display: "flex", gap: 22,
          }}>
            <span><span style={{color: "var(--text-dim)"}}>сборка</span> &nbsp;<span style={{color: "var(--text)"}}>2.6.0 · 4814</span></span>
            <span><span style={{color: "var(--text-dim)"}}>flutter</span> &nbsp;<span style={{color: "var(--text)"}}>3.22 · Impeller</span></span>
            <span><span style={{color: "var(--text-dim)"}}>устройство</span> &nbsp;<span style={{color: "var(--text)"}}>Apple TV 4K · tvOS 17.4</span></span>
          </div>
        </div>
      </div>

      {/* BODY: sidebar + content */}
      <div style={{display: "grid", gridTemplateColumns: "300px 1fr"}}>
        <Sidebar active="playback" />

        <div style={{padding: "32px 56px 56px"}}>
          <PerformanceHero />

          {/* Воспроизведение */}
          <div style={{marginBottom: 36}}>
            <SLabel>Воспроизведение</SLabel>
            <div style={{
              fontFamily: "var(--font-display)", fontWeight: 600,
              fontSize: 28, lineHeight: 1.1, letterSpacing: "-0.02em",
              margin: "10px 0 18px",
            }}>Плеер и переходы</div>

            <Toggle label="Аппаратное ускорение (Impeller)"
                    sub="Flutter Impeller backend, +30% FPS на TV-устройствах"
                    on={true} accent focused />
            <Toggle label="Предзагрузка превью каналов"
                    sub="плавный swipe между каналами без чёрных кадров"
                    on={true} />
            <Toggle label="Параллакс на постерах"
                    sub="мягкий blur и сдвиг при фокусе элемента"
                    on={true} />
            <Toggle label="Hero shared element transitions"
                    sub="постер плавно переходит из ленты в детальный экран"
                    on={true} />
            <Toggle label="Тактильная обратная связь"
                    sub="вибро-отклик при смене фокуса (только мобильные)"
                    on={true} />
            <Toggle label="Авто-качество (ABR)"
                    sub="подстраивается под канал · ручное доступно в плеере"
                    on={true} />
            <Toggle label="Энергосбережение"
                    sub="кадровая частота до 30 FPS · отключает blur · серый акцент"
                    on={false} />
          </div>

          {/* Кодеки */}
          <div style={{marginBottom: 36}}>
            <SLabel>Декодирование</SLabel>
            <div style={{
              fontFamily: "var(--font-display)", fontWeight: 600,
              fontSize: 28, lineHeight: 1.1, letterSpacing: "-0.02em",
              margin: "10px 0 12px",
            }}>Кодеки и цвет</div>

            <Picker label="Кодек по умолчанию"
                    sub="приоритет при множественных потоках"
                    options={["AV1", "H.265", "H.264"]} active={1} />
            <Picker label="Декодирование"
                    sub="GPU обычно даёт +40% FPS"
                    options={["GPU", "CPU", "Hybrid"]} active={0} />
            <Picker label="Цветовое пространство"
                    sub="HDR-источники определяются автоматически"
                    options={["BT.2020 HDR", "BT.709", "Auto"]} active={2} />
            <Picker label="Раскладка пульта"
                    sub="как реагировать на стрелки и колёсико"
                    options={["←/→ канал", "Apple TV", "Свой"]} active={0} />
          </div>

          <AccountCard />
        </div>
      </div>
    </div>
  );
}

window.ScreenSettingsV2 = ScreenSettingsV2;
