/* Channel Detail v2 — 3 focus-aware variants for D-pad/mouse navigation.
   All variants share: cobalt theme, focus ring on currently-selected element,
   OK opens player, BACK returns to home. */

const { useState: useStateD, useEffect: useEffectD } = React;

// Focus ring helper — visible 3px outline + scale on focused element
const focusRing = (isFocused) => ({
  outline: isFocused ? "3px solid var(--accent)" : "3px solid transparent",
  outlineOffset: isFocused ? 4 : 0,
  transform: isFocused ? "scale(1.04)" : "scale(1)",
  transition: "all 0.18s cubic-bezier(.2,.8,.2,1)",
  boxShadow: isFocused ? "0 24px 60px var(--accent-glow)" : "none",
});

// Vertical D-pad column. Buttons stack, focus stays inside ring.
function FocusList({ items, focused, prefix = "" }) {
  return (
    <div style={{display: "flex", flexDirection: "column", gap: 10}}>
      {items.map((it, i) => {
        const f = focused === `${prefix}${i}`;
        const primary = it.primary;
        return (
          <button key={i} className={`mv-btn ${primary ? "primary" : "ghost"}`}
            style={{
              ...focusRing(f),
              justifyContent: "flex-start",
              padding: "14px 18px",
              fontSize: 15,
              minWidth: 280,
            }}>
            {it.icon && <span style={{marginRight: 10}}>{it.icon}</span>}
            {it.label}
            {it.shortcut && (
              <span style={{
                marginLeft: "auto",
                fontFamily: "var(--font-mono)", fontSize: 10,
                opacity: 0.55, letterSpacing: "0.1em"
              }}>{it.shortcut}</span>
            )}
          </button>
        );
      })}
    </div>
  );
}

const kbdSt = {
  fontFamily: "var(--font-mono)", fontSize: 10,
  padding: "2px 6px", border: "1px solid rgba(255,255,255,0.25)",
  borderRadius: 4, marginRight: 4
};

window.focusRing = focusRing;
window.FocusList = FocusList;
window.kbdSt = kbdSt;
