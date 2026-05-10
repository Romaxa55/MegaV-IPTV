import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Coarse classification of the current viewport, used by the adaptive
/// layout layer to pick between mobile/tablet/TV widget trees.
///
/// Breakpoints (width-only, see `screenKindOf`):
///  * `< 600`  → [mobile]
///  * `< 1280` → [tablet]
///  * else     → [tv]
enum ScreenKind { mobile, tablet, tv }

/// Resolves the [ScreenKind] for the current [BuildContext] from
/// `MediaQuery.sizeOf(context).width`.
///
/// The boundaries are inclusive on the upper bound: width `600` lands in
/// [ScreenKind.tablet], width `1280` lands in [ScreenKind.tv].
ScreenKind screenKindOf(BuildContext context) {
  final w = MediaQuery.sizeOf(context).width;
  if (w < 600) return ScreenKind.mobile;
  if (w < 1280) return ScreenKind.tablet;
  return ScreenKind.tv;
}

/// Provider exposing the current [ScreenKind].
///
/// Defaults to [ScreenKind.tv] — call sites that need a context-aware value
/// should override this provider in a `ProviderScope` near a widget that
/// has access to a `BuildContext`, or use [screenKindOf] directly.
final screenKindProvider = Provider.autoDispose<ScreenKind>((ref) => ScreenKind.tv);
