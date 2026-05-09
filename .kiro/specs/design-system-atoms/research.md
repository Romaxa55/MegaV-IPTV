# Research Log — design-system-atoms

## Discovery scope

**Type**: Extension (existing system).

**Sources consulted**:
- `.kiro/design/megav-iptv-handoff/project/atoms.jsx` — 149 lines, all base atoms.
- `.kiro/design/megav-iptv-handoff/project/styles.css` — `.mv-btn` (3 variants), `.mv-iconbtn`, `.mv-chip`, `.mv-poster`, `.mv-track`, `.mv-strip`, `.mv-key`, `.mv-grain`, `.mv-vignette`, `.mv-backdrop`.
- Closed kiro specs `design-system-foundation` (#4) — provides AppPalette/AppRadius/MegaVTextStyles/AppColors.
- Closed kiro spec `perf-safe-widgets` (#13) — provides SafePill, SafeFocusRing, SafeFilmGrain, SafeBackdrop, combinedHeroGradient, ComputedColors, kSafeShadowBlurMax, assets/grain_overlay.png.
- Existing widgets to refactor: `glass_button.dart`, `hero_badges.dart`, `_card_poster.dart`, `channel_quality_badge.dart`.

## Key findings

1. **Atoms are pure presentation** — no Riverpod state, no providers, no async. They consume Theme + AppColors only.
2. **Foundation handoff is fully ready**: AppPalette has all needed tokens (text, accent, accentSoft, accentGlow, gold, goldSoft, live, surface1, surface2, lineStrong, etc.). No new palette tokens required.
3. **Perf-safe primitives cover all blur/translucent/grain needs**: atoms compose them, never reach for raw `BackdropFilter` or `BoxShadow.blurRadius > 12`.
4. **CSS-to-Flutter mapping is straightforward** for most atoms. The trickiest are:
   - `Chip.live` pulse — needs `AnimationController` + `RepaintBoundary` to isolate.
   - `Poster` focus state — `SafeFocusRing` does the work.
   - `MvTrack` progress animation — `AnimatedFractionallySizedBox` or custom `AnimatedBuilder` driving `widthFactor`.
5. **Backward-compat refactor is non-trivial for `glass_button.dart`** — its public API is `class GlassButton({required onPressed, required label, ...})`. New `MvButton.ghost` may have different parameter order/optional behavior. Solution: keep `GlassButton` as a one-line proxy `extends StatelessWidget; build → return MvButton.ghost(...)`. No call-site changes.
6. **Golden tests are optional but high-value** for atoms — they catch unintended visual drift across palettes / fonts. Recommend adding for `Chip` (5 variants), `MvButton` (3 variants), `Poster` (with/without text/progress).

## Architecture pattern decision

**Chosen**: Pure leaf-package `lib/core/ui/atoms/` mirroring the pattern from `lib/core/perf/`. One file per atom (or one logical group). Public barrel at `atoms.dart`.

**Why**:
- Mirrors successful pattern from #13.
- One-file-per-atom = easy grep / discoverability.
- Barrel = single import for downstream consumers.
- No Riverpod = pure unit tests via `pumpWidget`.
- `const` constructors where possible.

**Rejected alternatives**:
- **Single mega-file** with all 13 atoms — would exceed 600-line lint limit (project rule); harder to navigate.
- **Riverpod-managed atoms** — atoms are pure presentation; injecting state framework would couple them to consumers and break testability.
- **Splitting into sub-directories** (`buttons/`, `chips/`, `posters/`) — overkill for 13 atoms; adds import path noise.

## Existing widget refactor strategy

For each of the 4 existing widgets:

| Existing widget | Refactor approach | Risk |
|---|---|---|
| `glass_button.dart` | Keep file, replace internal build with `MvButton.ghost(...)`. Original public API preserved. | Low — drop-in proxy. |
| `hero_badges.dart` | Keep file, replace internal build with composed `Chip` + `MMLogo` atoms. | Low — same behavior. |
| `_card_poster.dart` | Inspect first; if visual-equivalent to `Poster` atom, leave alone (NOT refactor). If divergent, ALSO leave alone — closed spec `home-grid-visual-polish` owns it. | Avoid refactor; OUT of scope per Req 15.3. |
| `channel_quality_badge.dart` | Keep file, replace internal build with `Chip` atom. | Low — same render. |

**Decision: refactor only `glass_button.dart`, `hero_badges.dart`, `channel_quality_badge.dart`. Skip `_card_poster.dart`** (closed spec ownership).

## Risks

- **Risk**: Visual drift if atom rendering differs from existing widget by a few pixels. **Mitigation**: visual regression caught by 65 existing widget tests + manual TV smoke. If a test breaks, fix the atom to match (NOT modify the test).
- **Risk**: `Chip.live` pulse animation runs forever, consuming CPU even when off-screen. **Mitigation**: `RepaintBoundary` (Req 4.3); also document «do not place > 5 live Chips on a single screen» as steering guidance.
- **Risk**: 13 atoms × 3-5 tests each = 40-65 new tests, suite size grows. **Mitigation**: tests are cheap (no I/O, no Riverpod); current 65 pass in 3-4 seconds, expect 100-130 after this spec — still fast.
- **Risk**: `MvButton` size scale — design hints at `size` param but doesn't specify exact dimensions. **Mitigation**: pick reasonable defaults (small=32px height, medium=44px height) and document in atom doc-comment; downstream specs can request additional sizes via follow-up issue.
- **Risk**: Font sizes in `MegaVTextStyles` may not have a perfect match for atom needs (e.g., button label needs medium-weight 14px sans). **Mitigation**: add `MegaVTextStyles.cinema` already exposes `bodyDefault` / `bodyDim` / `metaMono` — atoms compose from these; if needed, atom can pass `fontSize` override via copyWith.

## Synthesis outcomes

- **Generalization found**: All «pill»-shaped atoms (`Chip`, `StatusBar`, `MvButton.ghost`, `MvKey`) share a common shell: rounded rectangle + opaque-tint background + padded inner row. Could extract `_PillShell` private helper widget. **Decision**: not now — premature abstraction. If 3+ atoms duplicate ≥ 80% of the shell logic after impl, extract in follow-up.
- **Build vs adopt**: 100% build. No third-party Flutter atom library targets TV-Mali constraints with palette swappability + Russian Cyrillic typography.
- **Simplifications**:
  - Drop golden tests from mandatory scope (Req 17.7) — they're nice-to-have but Wave 3 specs can add their own.
  - Skip `_card_poster.dart` refactor — closed spec, low value, high risk.
  - Don't introduce focus-tree primitives — atoms expose `isFocused: bool` parameter; focus-tree management is screen-spec responsibility.
