// hero_tile_morph.dart — single-widget hero ↔ first-tile morph for
// CinematicHomeScreen. Owned by the `hero-collapse-tile-morph` spec.
//
// Phase 1 of this file (introduced in task 1.1): the `FirstSlotConfig`
// value class. Subsequent tasks (2.x, 3.x) will add `HeroMorphState`,
// `computeNextState`, and the `HeroTileMorph` widget proper. This file
// is the canonical home for all of those public types so downstream
// imports stay stable as the spec lands incrementally.

import 'package:flutter/widgets.dart';

/// Replaces the rendered widget at index 0 of a `CinemaRow` and exposes
/// a `FocusNode` that the row listens to (so a focus change inside the
/// custom widget can drive the same scroll/pinned-slot logic the regular
/// tiles use).
///
/// Use this to mount a `HeroTileMorph` as the first slot of the first
/// rail on `CinematicHomeScreen`: the hero and the tile-in-slot-0 then
/// share one widget instance, which is the prerequisite for the
/// single-source-of-truth contract from the spec.
///
/// All fields are `final` and the class is `const`-constructible.
///
/// Backwards compatibility: when the row's `firstSlot` is `null` (the
/// default), the row renders normally with no behaviour change. Existing
/// callers do not need to pass anything.
class FirstSlotConfig {
  /// The widget rendered in place of tile 0. Must be focusable on its own
  /// terms — the row does not wrap it in a `Focus` of its own.
  final Widget child;

  /// Optional `FocusNode` the row will listen to. When this node gains
  /// focus, `CinemaRow` treats it as "tile 0 focused" and re-runs its
  /// pinned-slot scroll math (`_scrollFocusedTileToLeadingEdge(0)`)
  /// without any further coordination from the parent.
  final FocusNode? focusNode;

  /// Optional callback fired once the row has mounted and bound the
  /// custom widget. Useful when the hero needs to know "I'm now the
  /// first slot" to start a timer or pre-cache an image.
  final VoidCallback? onMounted;

  const FirstSlotConfig({required this.child, this.focusNode, this.onMounted});
}
