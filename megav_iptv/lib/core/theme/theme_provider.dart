import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_palette.dart';
import 'app_palettes.dart';

/// Optional persistence adapter for the active palette preference.
///
/// The interface intentionally exposes only two async methods so that any
/// concrete storage backend (`shared_preferences`, secure storage, a remote
/// settings service, an in-memory test fake) can satisfy it without leaking
/// implementation details into this layer.
///
/// Per Requirement 6, the [ThemeNotifier] accepts an optional
/// [PaletteStore]:
///  * 6.1 — adapter is injected at provider construction.
///  * 6.2 — when no adapter is provided the notifier is in-memory only and
///    resets to [AppPaletteName.noirCobalt] on every app restart.
///  * 6.3 — when an adapter is provided the notifier reads the persisted
///    palette during initialization, falling back to Noir Cobalt if the
///    stored value is missing, invalid, or the read fails.
///  * 6.4 — when the user changes the active palette the notifier calls
///    [write] on the adapter to persist the new choice.
///
/// Read failures must surface as either `null` (no preference yet) or a
/// thrown error — both cases are non-fatal and resolve to the default palette.
abstract class PaletteStore {
  /// Returns the persisted [AppPaletteName] or `null` if no preference has
  /// been saved yet (or the saved value cannot be decoded).
  Future<AppPaletteName?> read();

  /// Persists [name] as the active palette preference.
  Future<void> write(AppPaletteName name);
}

/// Convenience accessor: resolve a palette name to its [AppPalette] instance.
///
/// Lets consumers write `ref.watch(themeProvider).palette` instead of
/// `ref.watch(themeProvider).resolve()`. Functionally equivalent to the
/// `AppPaletteResolver.resolve()` extension defined in `app_palettes.dart`,
/// but reads more naturally at call-sites that already think in terms of
/// "the current palette".
extension ThemeProviderResolve on AppPaletteName {
  /// The [AppPalette] instance that backs this enum value.
  AppPalette get palette => resolve();
}

/// Riverpod notifier that holds the currently active [AppPaletteName] and
/// exposes a public API for switching it.
///
/// Design rationale (see `design.md` § ThemeNotifier + themeProvider):
///  * State is the [AppPaletteName] enum, not the [AppPalette] instance —
///    enums are trivially serialisable and the resolver in
///    `app_palettes.dart` keeps the mapping authoritative.
///  * [build] returns [AppPaletteName.noirCobalt] **synchronously** so the
///    very first frame renders with a valid palette (Req 1.5, 5.4). When
///    a [PaletteStore] is injected, hydration runs as a fire-and-forget
///    async side effect; if the persisted value differs from the default
///    the state is updated and `ref.watch` consumers rebuild on the next
///    frame (Req 1.4, 6.3).
///  * [setPalette] updates `state` **before** awaiting persistence so that
///    UI consumers re-render immediately even if the store is slow or
///    fails (Req 1.4, 5.2). Persistence errors are swallowed because the
///    in-memory state is already correct.
class ThemeNotifier extends Notifier<AppPaletteName> {
  /// Constructs a notifier with an optional persistence adapter.
  ///
  /// The default [themeProvider] passes no store (Riverpod's
  /// [NotifierProvider] only accepts a no-arg factory). To wire a real
  /// store, override the provider at the [ProviderScope] root — see the
  /// doc comment on [themeProvider].
  ThemeNotifier({PaletteStore? store}) : _store = store;

  final PaletteStore? _store;

  @override
  AppPaletteName build() {
    // Synchronous default per Req 1.5 / 5.4. If a store was injected,
    // hydrate asynchronously without blocking the initial render — the
    // first frame uses Noir Cobalt and any persisted preference replaces
    // it on the next frame (Req 1.4 / 6.3).
    if (_store != null) {
      // Fire-and-forget: errors are swallowed inside _hydrateFromStore.
      _hydrateFromStore();
    }
    return AppPaletteName.noirCobalt;
  }

  Future<void> _hydrateFromStore() async {
    try {
      final saved = await _store!.read();
      if (saved != null && saved != state) {
        state = saved;
      }
    } catch (_) {
      // Store errors are non-fatal: keep the default palette (Req 6.3
      // fallback). Intentionally no logging here — this layer is pure
      // state plumbing; observability belongs to the persistence impl.
    }
  }

  /// Switches the active palette to [name] and persists the choice when
  /// a [PaletteStore] adapter is configured.
  ///
  /// Per Req 5.2 and Req 1.4, `state` is updated before awaiting the
  /// store so that consumers reading `ref.watch(themeProvider)` rebuild
  /// on the next frame regardless of how slow (or failing) the persistence
  /// backend is. Per Req 6.4, the persisted name is written when (and only
  /// when) an adapter is present.
  Future<void> setPalette(AppPaletteName name) async {
    state = name;
    final store = _store;
    if (store != null) {
      try {
        await store.write(name);
      } catch (_) {
        // Persistence errors are non-fatal — the in-memory state is
        // already updated, so the UI reflects the user's choice for the
        // remainder of the session even if it cannot be persisted.
      }
    }
  }
}

/// Riverpod provider exposing the active [AppPaletteName].
///
/// Default usage (no persistence — Req 6.2):
///
/// ```dart
/// final paletteName = ref.watch(themeProvider);
/// final palette = paletteName.palette; // AppPalette instance
/// ```
///
/// To inject a real [PaletteStore] (Req 6.1), override the provider at the
/// [ProviderScope] root. The default factory takes no arguments because
/// [NotifierProvider] requires a no-arg constructor reference, so the
/// store must be supplied via override:
///
/// ```dart
/// ProviderScope(
///   overrides: [
///     themeProvider.overrideWith(
///       () => ThemeNotifier(store: SharedPrefsPaletteStore()),
///     ),
///   ],
///   child: const MyApp(),
/// )
/// ```
final themeProvider = NotifierProvider<ThemeNotifier, AppPaletteName>(ThemeNotifier.new);
