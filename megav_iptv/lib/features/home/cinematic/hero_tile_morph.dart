// hero_tile_morph.dart — single-widget hero ↔ first-tile morph for
// CinematicHomeScreen. Owned by the `hero-collapse-tile-morph` spec.
//
// Phase 1 of this file (introduced in task 1.1): the `FirstSlotConfig`
// value class. Subsequent tasks (2.x, 3.x) will add `HeroMorphState`,
// `computeNextState`, and the `HeroTileMorph` widget proper. This file
// is the canonical home for all of those public types so downstream
// imports stay stable as the spec lands incrementally.

import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../widgets/_grid_tokens.dart';

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

// ---------------------------------------------------------------------------
// HeroMorphState + computeNextState (hctm task 2.1)
// ---------------------------------------------------------------------------

/// The four observable states of the hero ↔ first-tile morph.
///
/// State machine (single transition table — pure function below):
///
///   idleExpanded       —— collapse         ▶ morphingCollapsing
///   morphingCollapsing —— tickerCompleted  ▶ idleCollapsed
///   morphingCollapsing —— expand           ▶ morphingExpanding (reverse mid-flight)
///   idleCollapsed      —— expand           ▶ morphingExpanding
///   morphingExpanding  —— tickerDismissed  ▶ idleExpanded
///   morphingExpanding  —— collapse         ▶ morphingCollapsing (reverse mid-flight)
///
/// `disableAnimationsCollapse` / `disableAnimationsExpand` are the
/// instant-snap commands fired when `MediaQuery.disableAnimations` is true.
enum HeroMorphState { idleExpanded, morphingCollapsing, idleCollapsed, morphingExpanding }

/// Internal "command" alphabet for the state machine.
@visibleForTesting
enum HeroMorphCommand {
  collapse,
  expand,
  tickerCompleted,
  tickerDismissed,
  disableAnimationsCollapse,
  disableAnimationsExpand,
}

/// Pure transition function: `(current, cmd) → next`. The current state is
/// returned unchanged for any command that has no transition out of that
/// state (idempotent / no-op edges).
@visibleForTesting
HeroMorphState computeNextHeroMorphState(HeroMorphState current, HeroMorphCommand cmd) {
  switch ((current, cmd)) {
    case (HeroMorphState.idleExpanded, HeroMorphCommand.collapse):
      return HeroMorphState.morphingCollapsing;
    case (HeroMorphState.morphingCollapsing, HeroMorphCommand.tickerCompleted):
      return HeroMorphState.idleCollapsed;
    case (HeroMorphState.morphingCollapsing, HeroMorphCommand.expand):
      return HeroMorphState.morphingExpanding;
    case (HeroMorphState.idleCollapsed, HeroMorphCommand.expand):
      return HeroMorphState.morphingExpanding;
    case (HeroMorphState.morphingExpanding, HeroMorphCommand.tickerDismissed):
      return HeroMorphState.idleExpanded;
    case (HeroMorphState.morphingExpanding, HeroMorphCommand.collapse):
      return HeroMorphState.morphingCollapsing;
    // disableAnimations: instant snap.
    case (_, HeroMorphCommand.disableAnimationsCollapse):
      return HeroMorphState.idleCollapsed;
    case (_, HeroMorphCommand.disableAnimationsExpand):
      return HeroMorphState.idleExpanded;
    default:
      return current;
  }
}

// ---------------------------------------------------------------------------
// HeroTileMorph widget (hctm tasks 3.1–3.4)
// ---------------------------------------------------------------------------

/// Single widget that renders the hero ↔ first-tile morph on CinematicHomeScreen.
///
/// In `idleExpanded` (or while morphing-collapsing) it draws `expandedChild`
/// (the full hero with backdrop / title / Watch button) at expanded geometry.
///
/// In `idleCollapsed` (or while morphing-expanding) it draws a compact tile
/// — `collapsedCover` image + `collapsedCaption` text — at the standard
/// CinemaCard slot-0 geometry from `GridTokens.cardHeightDp`.
///
/// State transitions are driven by `widget.collapsed` (set by the parent
/// based on focus). A single AnimationController (300ms, easeInOutCubic)
/// drives both the geometry lerp and a two-half opacity crossfade.
///
/// Accessibility: when `MediaQuery.disableAnimationsOf(context)` is true,
/// the controller snaps to the target value with no animation.
class HeroTileMorph extends StatefulWidget {
  /// The expanded hero subtree (full backdrop + title + Watch button etc.).
  /// Built by the caller — this widget does not assume any specific layout.
  final Widget expandedChild;

  /// Cover image for the collapsed tile. If null, a flat colour fallback
  /// is used.
  final ImageProvider? collapsedCover;

  /// One- or two-line caption shown at the bottom of the collapsed tile.
  final String collapsedCaption;

  /// Persistent FocusNode owned by the parent. HeroTileMorph does NOT
  /// dispose this — the parent does.
  final FocusNode focusNode;

  /// Drives the state machine. `true` → morphing-collapsing → idleCollapsed.
  /// `false` → morphing-expanding → idleExpanded.
  final bool collapsed;

  /// Expanded geometry. Defaults match CinematicHomeScreen's old hero block.
  final double expandedHeightDp;
  final double expandedWidthDp;

  /// Collapsed geometry. If `collapsedHeightDp <= 0` (the default), it is
  /// resolved at build time to `GridTokens.cardHeightDp.h`.
  final double collapsedHeightDp;
  final double collapsedWidthDp;

  const HeroTileMorph({
    super.key,
    required this.expandedChild,
    required this.collapsedCaption,
    required this.focusNode,
    required this.collapsed,
    this.collapsedCover,
    this.expandedHeightDp = 620.0,
    this.expandedWidthDp = 1920.0,
    this.collapsedHeightDp = 0.0,
    this.collapsedWidthDp = 444.0,
  });

  @override
  State<HeroTileMorph> createState() => _HeroTileMorphState();
}

class _HeroTileMorphState extends State<HeroTileMorph> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final CurvedAnimation _curved;
  HeroMorphState _state = HeroMorphState.idleExpanded;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      value: widget.collapsed ? 1.0 : 0.0,
    );
    _curved = CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic);
    _state = widget.collapsed ? HeroMorphState.idleCollapsed : HeroMorphState.idleExpanded;
    _controller.addStatusListener(_onStatusChanged);
  }

  void _onStatusChanged(AnimationStatus status) {
    if (!mounted) return;
    switch (status) {
      case AnimationStatus.forward:
        setState(() => _state = computeNextHeroMorphState(_state, HeroMorphCommand.collapse));
        break;
      case AnimationStatus.reverse:
        setState(() => _state = computeNextHeroMorphState(_state, HeroMorphCommand.expand));
        break;
      case AnimationStatus.completed:
        setState(() => _state = computeNextHeroMorphState(_state, HeroMorphCommand.tickerCompleted));
        break;
      case AnimationStatus.dismissed:
        setState(() => _state = computeNextHeroMorphState(_state, HeroMorphCommand.tickerDismissed));
        break;
    }
  }

  bool _disableAnimationsActive() => MediaQuery.maybeOf(context)?.disableAnimations ?? false;

  @override
  void didUpdateWidget(HeroTileMorph oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.collapsed != widget.collapsed) {
      if (_disableAnimationsActive()) {
        _controller.stop();
        _controller.value = widget.collapsed ? 1.0 : 0.0;
        setState(
          () => _state = computeNextHeroMorphState(
            _state,
            widget.collapsed ? HeroMorphCommand.disableAnimationsCollapse : HeroMorphCommand.disableAnimationsExpand,
          ),
        );
      } else if (widget.collapsed) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // If disable-animations toggled on mid-flight, snap to target.
    if (_controller.isAnimating && _disableAnimationsActive()) {
      _controller.stop();
      _controller.value = widget.collapsed ? 1.0 : 0.0;
      setState(
        () => _state = computeNextHeroMorphState(
          _state,
          widget.collapsed ? HeroMorphCommand.disableAnimationsCollapse : HeroMorphCommand.disableAnimationsExpand,
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller.removeStatusListener(_onStatusChanged);
    _curved.dispose();
    _controller.dispose();
    // NOTE: widget.focusNode is owned by the parent — do not dispose here.
    super.dispose();
  }

  @visibleForTesting
  HeroMorphState get debugState => _state;

  @override
  Widget build(BuildContext context) {
    final collapsedH = widget.collapsedHeightDp > 0 ? widget.collapsedHeightDp.h : GridTokens.cardHeightDp.h;
    final expandedH = widget.expandedHeightDp.h;
    final collapsedW = widget.collapsedWidthDp.w;
    final expandedW = widget.expandedWidthDp.w;

    return AnimatedBuilder(
      animation: _curved,
      builder: (context, _) {
        final t = _curved.value;
        final h = lerpDouble(expandedH, collapsedH, t)!;
        final w = lerpDouble(expandedW, collapsedW, t)!;

        // Two-half crossfade: first 50% of the curve fades the expanded
        // subtree out, the second 50% fades the collapsed tile in. This
        // avoids the "two visible layers" period that a naive single
        // opacity crossfade produces.
        final tsCollapsedOpacity = t < 0.5 ? 0.0 : (t - 0.5) * 2.0;
        final expandedOpacity = 1.0 - tsCollapsedOpacity;

        // IMPORTANT: both subtrees stay mounted at all times so the
        // hero's Focus(focusNode: ...) inside expandedChild never gets
        // unmounted. Earlier code conditionally removed the expanded
        // subtree once its opacity hit 0 — that detached
        // _heroWatchFocusNode from the focus tree, so D-pad ↑ from
        // rails could no longer return focus to the hero, and arrows
        // appeared dead. Keeping the subtree mounted (even at
        // opacity 0) leaves _heroWatchFocusNode as a re-entry target.
        //
        // ExcludeFocus(excluding: idleCollapsed) blocks traversal into
        // the invisible expanded layer ONLY when the morph is fully
        // settled in collapsed state — so the sibling buttons
        // ("Программа", "В избранное") with their internal InkWell
        // FocusNodes don't get focus while invisible. During the
        // morphing transition focus inside expanded is still valid,
        // which keeps the re-entry path open while the hero re-expands.
        return SizedBox(
          width: w,
          height: h,
          child: Stack(
            children: [
              Positioned.fill(
                child: ExcludeFocus(
                  excluding: _state == HeroMorphState.idleCollapsed,
                  child: Opacity(opacity: expandedOpacity, child: widget.expandedChild),
                ),
              ),
              Positioned.fill(
                child: Opacity(opacity: tsCollapsedOpacity, child: _buildCollapsedLayout(context)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCollapsedLayout(BuildContext context) {
    // The collapsed tile owns ONE focusable so D-pad ↑ from rails has a
    // re-entry target. Receiving focus here propagates up to the outer
    // Focus(skipTraversal:true).onFocusChange in cinematic_home_screen.dart,
    // which flips _heroFocused = true → hero re-expands. Note we use a
    // fresh anonymous Focus (no FocusNode), not widget.focusNode —
    // FocusNode can only be attached to one Focus at a time, and
    // widget.focusNode is already attached to the "Смотреть" button
    // inside expandedChild.
    return Focus(
      debugLabel: 'cinematicHeroCollapsedTile',
      child: Builder(
        builder: (ctx) {
          return Stack(
            children: [
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16.r),
                  child: widget.collapsedCover != null
                      ? Image(image: widget.collapsedCover!, fit: BoxFit.cover)
                      : Container(color: const Color(0xFF14161C)),
                ),
              ),
              Positioned(
                bottom: 6.h,
                left: 12.w,
                right: 12.w,
                child: Text(
                  widget.collapsedCaption,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.92),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
