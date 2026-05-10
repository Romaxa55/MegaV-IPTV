import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Variants of the Home surface — three concurrent implementations exposed
/// via separate routes / entry switch.
///
/// - [cinematic]: glass-blurred, motion-rich `CinematicHomeScreen`
///   (owned by `home-cinematic-redesign` spec).
/// - [editorial]: print-magazine-styled `EditorialHomeScreen`
///   (owned by `home-editorial-redesign` spec).
/// - [legacy]: the original tile-based `HomeScreen`.
enum HomeVariant { cinematic, editorial, legacy }

/// Single source of truth for the default Home variant on first launch
/// (Req 11.6). Selection is then persisted via [HomeVariantNotifier].
const HomeVariant kHomeVariantDefault = HomeVariant.cinematic;

/// SharedPreferences key for the persisted [HomeVariant] selection.
const String _kHomeVariantPrefsKey = 'home_variant';

/// Reads the stored variant from [SharedPreferences] and writes new
/// selections back. Falls back to [kHomeVariantDefault] when no value is
/// stored or when the stored value cannot be decoded.
class HomeVariantNotifier extends StateNotifier<HomeVariant> {
  HomeVariantNotifier(this._prefs) : super(kHomeVariantDefault) {
    _load();
  }

  final SharedPreferences _prefs;

  void _load() {
    final raw = _prefs.getString(_kHomeVariantPrefsKey);
    if (raw == null) return;
    for (final variant in HomeVariant.values) {
      if (variant.name == raw) {
        state = variant;
        return;
      }
    }
    // Unknown stored value — keep default.
  }

  /// Persists [variant] and updates state. Caller awaits the future when
  /// it needs to ensure the write hit disk before continuing.
  Future<void> set(HomeVariant variant) async {
    state = variant;
    await _prefs.setString(_kHomeVariantPrefsKey, variant.name);
  }
}

/// Override in `main()` with `await SharedPreferences.getInstance()` so
/// downstream providers can resolve the concrete instance synchronously.
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('Override in main() with await SharedPreferences.getInstance()');
});

/// Persistent [HomeVariant] selection. Reads through
/// [sharedPreferencesProvider]; mutate via `ref.read(homeVariantProvider.notifier).set(...)`.
final homeVariantProvider = StateNotifierProvider<HomeVariantNotifier, HomeVariant>((ref) {
  return HomeVariantNotifier(ref.watch(sharedPreferencesProvider));
});

/// Derived bool that mirrors `useCinematicHomeProvider` semantics from
/// the cinematic spec, but sourced from the persistent
/// [homeVariantProvider]. Lives here (NOT in the cinematic spec file) to
/// avoid touching the closed cinematic-spec boundary while still letting
/// editorial-spec callers reason in terms of "is cinematic active?".
final useCinematicHomeProviderEditorial = Provider<bool>(
  (ref) => ref.watch(homeVariantProvider) == HomeVariant.cinematic,
);
