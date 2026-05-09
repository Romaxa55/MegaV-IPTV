/* Wires all screens into a design canvas */

const { useEffect } = React;

function App() {
  return (
    <DesignCanvas
      title="MegaV IPTV"
      subtitle="Cinematic + editorial — hi-fi разведка по 4 направлениям"
    >
      <DCSection id="home" title="Главная" subtitle="2 направления — cinematic full-bleed и editorial bento">
        <DCArtboard id="home-cinematic" label="A · Cinematic full-bleed" width={1600} height={1180}>
          <HomeCinematic />
        </DCArtboard>
        <DCArtboard id="home-editorial" label="B · Editorial bento (Apple TV / Criterion)" width={1600} height={1280}>
          <HomeEditorial />
        </DCArtboard>
      </DCSection>

      <DCSection id="detail" title="Карточка / превью" subtitle="hero shared element transition с главной">
        <DCArtboard id="detail-1" label="Channel detail · hero transition" width={1600} height={1240}>
          <ScreenDetail />
        </DCArtboard>
      </DCSection>

      <DCSection id="player" title="Плеер">
        <DCArtboard id="player-1" label="Player · in-stream controls" width={1600} height={1080}>
          <ScreenPlayer />
        </DCArtboard>
      </DCSection>

      <DCSection id="epg" title="ТВ-программа (EPG)">
        <DCArtboard id="epg-1" label="EPG · сегодня · NOW marker" width={1700} height={950}>
          <ScreenEPG />
        </DCArtboard>
      </DCSection>

      <DCSection id="search" title="Поиск и фильтры">
        <DCArtboard id="search-1" label="Search · TV-friendly" width={1600} height={1120}>
          <ScreenSearch />
        </DCArtboard>
      </DCSection>

      <DCSection id="settings" title="Настройки" subtitle="с фокусом на performance — Impeller, FPS, ABR">
        <DCArtboard id="settings-1" label="Settings · performance" width={1600} height={1080}>
          <ScreenSettings />
        </DCArtboard>
      </DCSection>

      <DCSection id="mobile" title="Mobile (Flutter)" subtitle="адаптация для телефона — bottom blur tab bar, swipe жесты">
        <DCArtboard id="mobile-1" label="Mobile · home" width={414} height={868}>
          <ScreenMobile />
        </DCArtboard>
      </DCSection>
    </DesignCanvas>
  );
}

ReactDOM.createRoot(document.getElementById("root")).render(<App />);
