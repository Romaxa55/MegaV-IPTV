// onboarding-remote-cheatsheet spec (Wave 6).
//
// Persistent flag для перворазового overlay tour: показывается один
// раз, dismissable, запоминается через SharedPreferences.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../home/home_variant_provider.dart' show sharedPreferencesProvider;

const String _kOnboardingShownKey = 'onboarding-shown';

class OnboardingNotifier extends StateNotifier<bool> {
  OnboardingNotifier(this._prefs) : super(_prefs.getBool(_kOnboardingShownKey) ?? false);

  final SharedPreferences _prefs;

  /// Помечает onboarding как "viewed" и больше не показывает.
  Future<void> markShown() async {
    state = true;
    await _prefs.setBool(_kOnboardingShownKey, true);
  }

  /// Reset для тестирования / debug-режима. Показывает onboarding
  /// заново при следующем запуске.
  Future<void> reset() async {
    state = false;
    await _prefs.setBool(_kOnboardingShownKey, false);
  }
}

/// Persistent onboarding flag. `state == true` → tour уже видели, не
/// показываем. `state == false` → надо показать overlay при mount
/// главного экрана.
final onboardingShownProvider = StateNotifierProvider<OnboardingNotifier, bool>((ref) {
  return OnboardingNotifier(ref.watch(sharedPreferencesProvider));
});
