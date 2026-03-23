import 'package:flutter/widgets.dart';

/// Returns true if the UI should reduce heavy graphical effects.
/// This happens when the system requests reduced motion, or if the device
/// screen size suggests it might be a TV (using shortestSide >= 720 as a heuristic).
bool effectiveLowPowerUi(BuildContext context) {
  // Check system preferences for reduced motion
  if (MediaQuery.disableAnimationsOf(context)) {
    return true;
  }

  // TV heuristic: if the shortest side of the screen is very large, it's likely a TV.
  // TVs typically have weaker GPUs and heavy effects like large blur shadows can cause lag.
  final size = MediaQuery.sizeOf(context);
  if (size.shortestSide >= 720) {
    return true;
  }

  return false;
}
