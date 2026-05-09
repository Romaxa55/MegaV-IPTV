import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Default state of cinematic home flag.
///
/// Single source of truth for default cinematic state per Req 11.4.
/// Set to `false` so legacy `HomeScreen` remains the default route after
/// this spec lands. Flip to `true` only via Settings UI (issue #11) or
/// dev-only `useCinematicHomeProvider.notifier.state = true` toggle.
const bool kCinematicHomeDefault = false;

/// Toggle between legacy `HomeScreen` and `CinematicHomeScreen`.
///
/// Reads/writes:
/// - read via `ref.watch(useCinematicHomeProvider)` in entry-switch widget
/// - write via `ref.read(useCinematicHomeProvider.notifier).state = true`
///   from Settings UI or dev tools.
///
/// Persistence is OUT OF SCOPE for this spec — selection resets to
/// [kCinematicHomeDefault] on app restart. Settings spec (#11) will add
/// shared_preferences persistence in a follow-up.
final useCinematicHomeProvider = StateProvider<bool>((ref) => kCinematicHomeDefault);
