# Final Regression Report — epg-screen

Дата прогона: 2026-05-10
Spec base commit: `250157d` (chore(settings-redesign): close spec — validation GO)
HEAD commit: `1c4d995` (test(epg-screen): player-overlay invariant regression, Phase 6 task 6.2)

## Test суите

- Baseline (spec-base `250157d`, ровно перед началом эпика): **154 passing**.
- After spec (HEAD `1c4d995`): **189 passing**.
- Дельта: **+35 новых тестов** в **11 новых тестовых файлах**.
- Все green: ✅ (`flutter test` — last line: `00:14 +189: All tests passed!`)

Новые файлы тестов (11):
- `megav_iptv/test/core/epg/epg_repository_test.dart`
- `megav_iptv/test/core/epg/epg_window_provider_test.dart`
- `megav_iptv/test/features/epg/epg_category_filter_test.dart`
- `megav_iptv/test/features/epg/epg_channel_rail_test.dart`
- `megav_iptv/test/features/epg/epg_day_picker_test.dart`
- `megav_iptv/test/features/epg/epg_now_marker_test.dart`
- `megav_iptv/test/features/epg/epg_player_overlay_invariant_test.dart`
- `megav_iptv/test/features/epg/epg_preview_strip_test.dart`
- `megav_iptv/test/features/epg/epg_program_cell_test.dart`
- `megav_iptv/test/features/epg/epg_screen_smoke_test.dart`
- `megav_iptv/test/features/epg/epg_time_grid_test.dart`

Замечание: ожидаемая в `tasks.md` оценка ~36 новых тестов, фактическая дельта +35 — в пределах прогноза.

## Analyze (Req 14.6)

`flutter analyze megav_iptv/lib/features/epg/ megav_iptv/lib/core/epg/`:
```
Analyzing 2 items...
No issues found! (ran in 2.6s)
```
✅ 0 issues.

## Perf gates (Req 13.1, 13.2, 13.6)

### Запрет GPU-blurring примитивов в коде

`grep -rnE "BackdropFilter|ShaderMask|ImageFilter\.blur" megav_iptv/lib/features/epg/ megav_iptv/lib/core/epg/`

**6 hits, все в `///` doc comments** (verified line-by-line):

| Файл:строка | Содержимое |
|---|---|
| `epg_now_marker.dart:46` | `/// - No \`BackdropFilter\` / \`ShaderMask\` / \`ImageFilter.blur\` in this tree.` |
| `epg_preview_strip.dart:30` | `/// - No GPU-blurring widgets in the build tree (no \`BackdropFilter\`,` |
| `epg_preview_strip.dart:31` | `///   \`ShaderMask\`, \`ImageFilter.blur\`).` |
| `epg_category_filter.dart:19` | `/// (Req 8.3). \`ShaderMask\` is forbidden by the spec and the` |
| `epg_category_filter.dart:21` | `/// avoid the saveLayer cost that \`ShaderMask\` would impose every frame.` |
| `epg_category_filter.dart:31` | `/// - No \`BackdropFilter\` / \`ShaderMask\` / \`ImageFilter.blur\` anywhere in` |

✅ В исполняемом коде использований blur-примитивов нет.

### BoxShadow.blurRadius > 12

`grep -rnE "blurRadius:\s*([2-9][0-9]+|1[3-9])" megav_iptv/lib/features/epg/ megav_iptv/lib/core/epg/`

✅ 0 hits.

## pubspec.yaml (Req 14.5)

`git diff 250157d -- megav_iptv/pubspec.yaml`: **пустой**.
✅ Новых пакетов не добавлено.

## Closed-spec invariants (Req 11.1, 11.6, 11.7, 11.8, 14.4)

Сравнение со spec-base (`250157d`):

| Файл / директория | Изменения | Статус |
|---|---|---|
| `lib/features/player/widgets/epg_overlay.dart` | пустой diff | ✅ |
| `lib/core/playlist/models/epg_program.dart` | пустой diff | ✅ |
| `lib/features/home/` (вся директория) | пустой diff | ✅ |
| `lib/features/home/home_screen.dart` | пустой diff | ✅ |
| `lib/core/providers/providers.dart` | пустой diff | ✅ (новые провайдеры — в `lib/core/epg/epg_window_provider.dart`) |
| `lib/core/api/api_client.dart` | пустой diff | ✅ (Req 11.6 batch endpoint deferred — repository падает на dynamic dispatch + per-channel fan-out с in-flight de-dup; задокументировано в Phase 1 commit `2bc7bc9`) |

## Router (Req 11.7)

`git diff 250157d -- megav_iptv/lib/app.dart`: **+2 -0**.

```diff
 import 'features/detail/providers/detail_arguments.dart';
+import 'features/epg/epg_screen.dart';
 import 'features/home/cinematic/cinematic_home_screen.dart';
...
         GoRoute(path: '/settings', builder: (context, state) => const SettingsScreen()),
+        GoRoute(path: '/epg', builder: (context, state) => const EpgScreen()),
```

✅ Ровно одна добавленная строка импорта + одна добавленная `GoRoute` для `/epg`. Существующие маршруты не тронуты.

## Manual TV smoke (rtd2851a) — Req 13.6

- **Status: NOT_PERFORMED** (устройство rtd2851a недоступно в текущем dev-цикле).
- **Recommendation**: выполнить ручной VM Service smoke pass перед запуском следующего epic'а (`mobile-adaptive-layout` по roadmap), при наличии устройства проверить avg `GPURasterizer::Draw ≤ 16.7 ms` во время EPG scroll.
- Spec'овые статические гейты (запрет `BackdropFilter`/`ShaderMask`/`ImageFilter.blur`, `blurRadius ≤ 12`, virtualized 2-axis grid с TV-tuned cacheExtent) дают высокую доверительную оценку, что 60 fps цель достижима — но контроль на реальном железе требуется отдельно.

## Coverage of Req 14.7 (regression suite)

Suite покрывает все ключевые поверхности:
- Data layer: TTL-cache, batch fallback, in-flight de-dup, window-filtering.
- UI components: rail, time-axis, programme cell, time-grid, now-marker, day-picker, category-filter, preview-strip.
- Focus controller: D-pad через все колонки/строки.
- Smoke/integration: `EpgScreen` end-to-end pump.
- Closed-spec invariant: `EpgOverlay` в `PlayerScreen` всё ещё доступен независимо от EpgScreen.

## Итого

| Гейт | Результат |
|---|---|
| `flutter test` | ✅ 189/189 (baseline 154 + 35 new) |
| `flutter analyze` (epg + core/epg) | ✅ 0 issues |
| Blur primitive grep | ✅ 0 в коде, 6 в doc-комментах |
| `blurRadius > 12` grep | ✅ 0 hits |
| pubspec.yaml diff | ✅ empty |
| Closed-spec diff | ✅ all empty |
| Router diff | ✅ +2 -0 (single route + import) |
| Manual TV smoke | ⚠️ NOT_PERFORMED (no device) |

**Готовность к закрытию spec'а: GO** (с рекомендацией провести manual TV smoke перед следующим epic'ом).
