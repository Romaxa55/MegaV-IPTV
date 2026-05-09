import 'dart:async';

import 'package:flutter/material.dart' hide Chip;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/atoms/atoms.dart';

/// Item descriptor consumed by [CinematicRail].
///
/// Lightweight adapter so the rail isn't tied to a specific data model
/// (e.g. `NowPlayingItem` from `lib/core/playlist/models/now_playing.dart`).
/// Callers — typically the Phase 5 integration layer — translate domain
/// objects into [CinematicRailItem] right before constructing the rail.
class CinematicRailItem {
  const CinematicRailItem({required this.id, required this.title, required this.imageProvider});

  /// Stable identifier for diff / focus restoration. Not rendered.
  final String id;

  /// Title used as semantic label and as fallback `Poster.title` when text
  /// is forced visible by a future caller. The rail itself renders
  /// `hideText: true` per Req 4.2 / 4.3.
  final String title;

  /// Image source. May be a [NetworkImage], [AssetImage], etc. When `null`,
  /// the rail falls back to the bundled `assets/grain_overlay.png` so the
  /// `Poster` atom always receives a non-null `ImageProvider`.
  final ImageProvider? imageProvider;
}

/// Horizontal rail of [Poster] items with focus-scale animation, focus
/// debounce (400 ms — Leanback `lb_card_selected_animation_delay`) for
/// heavy `onItemFocus` side-effects, and TV-tuned `ListView` perf flags
/// (`cacheExtent: 1500`, `addAutomaticKeepAlives: true`,
/// `addRepaintBoundaries: true`, `clipBehavior: Clip.none`).
///
/// Per Req 9.1 / 9.2 the rail uses no runtime gaussian filters, no shader
/// masks, and no shadow blur exceeding `kSafeShadowBlurMax` (`12.0`).
///
/// Maps to Requirements 4.2-4.6, 8.1, 8.3, 8.4, 9.1, 9.2, 9.4, 9.5, 10.2, 10.3.
class CinematicRail extends ConsumerStatefulWidget {
  const CinematicRail({
    super.key,
    required this.items,
    required this.orientation,
    this.onItemTap,
    this.onItemFocus,
    this.height,
  });

  /// Items rendered as a single-row horizontal strip of [Poster] tiles.
  final List<CinematicRailItem> items;

  /// Drives the [Poster] aspect ratio: 16/9 for `landscape` (Req 4.2) and
  /// 2/3 for `portrait` (Req 4.3).
  final PosterOrientation orientation;

  /// Fired synchronously on tap / OK key. Not debounced — the user has
  /// already committed.
  final void Function(CinematicRailItem item)? onItemTap;

  /// Fired only after focus has been stable for 400 ms (Req 9.5). Used for
  /// heavy side-effects like preview-player start or hero swap. Focus
  /// `false` (clear) cancels any pending dispatch synchronously.
  final void Function(CinematicRailItem item)? onItemFocus;

  /// Optional rail height override. Defaults to `180` for landscape and
  /// `270` for portrait — both leave headroom for the 1.08 focus scale
  /// thanks to `clipBehavior: Clip.none`.
  final double? height;

  @override
  ConsumerState<CinematicRail> createState() => _CinematicRailState();
}

class _CinematicRailState extends ConsumerState<CinematicRail> {
  /// Index of the currently focused tile, or `null` when nothing is
  /// focused. Drives the `AnimatedScale.scale` per tile.
  int? _focusedIndex;

  /// Pending stable-focus timer. Cancelled on every focus change so only
  /// the *last* sustained focus fires `onItemFocus` (Req 9.5).
  Timer? _focusDebounce;

  /// 150 ms — Leanback `lb_card_activated_animation_duration` (Req 8.4).
  static const Duration _focusAnimDuration = Duration(milliseconds: 150);

  /// 400 ms — Leanback `lb_card_selected_animation_delay` (Req 9.5).
  static const Duration _focusDebounceDuration = Duration(milliseconds: 400);

  /// Fallback image when an item has no `imageProvider`. Bundled asset
  /// declared in `pubspec.yaml`, so it never 404s.
  static const ImageProvider _fallbackImage = AssetImage('assets/grain_overlay.png');

  @override
  void dispose() {
    _focusDebounce?.cancel();
    super.dispose();
  }

  void _handleFocus(int index, bool hasFocus) {
    setState(() {
      if (hasFocus) {
        _focusedIndex = index;
      } else if (_focusedIndex == index) {
        _focusedIndex = null;
      }
    });
    // Heavy-effect debounce: cancel any pending dispatch, schedule a new
    // one only on focus-gain (Req 9.5). Focus-loss is a *sync* clear by
    // virtue of cancelling without rescheduling.
    _focusDebounce?.cancel();
    if (hasFocus && widget.onItemFocus != null) {
      _focusDebounce = Timer(_focusDebounceDuration, () {
        if (!mounted) return;
        if (index < 0 || index >= widget.items.length) return;
        widget.onItemFocus!(widget.items[index]);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // 16:9 for landscape (Req 4.2), 2:3 for portrait (Req 4.3).
    final aspectRatio = widget.orientation == PosterOrientation.landscape ? 16 / 9 : 2 / 3;
    // Defaults give visible window of ~3-5 tiles on rtd2851a 1280-3840 px,
    // matching `pickColumns` semantics from `_grid_tokens.dart` (Req 4.6).
    final defaultHeight = widget.orientation == PosterOrientation.landscape ? 180.0 : 270.0;
    final height = widget.height ?? defaultHeight;
    final tileWidth = height * aspectRatio;
    const gap = 16.0;

    return SizedBox(
      height: height,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        // TV-tuned perf flags (Req 9.4, flutter-tv-perf.md).
        cacheExtent: 1500,
        addAutomaticKeepAlives: true,
        addRepaintBoundaries: true,
        clipBehavior: Clip.none,
        padding: const EdgeInsets.symmetric(horizontal: 32),
        itemCount: widget.items.length,
        // Stable extent helps the viewport skip layout passes per scroll
        // (Req 9.2 — perf compliance).
        itemExtent: tileWidth + gap,
        itemBuilder: (context, index) {
          final item = widget.items[index];
          final focused = _focusedIndex == index;
          return Padding(
            padding: const EdgeInsets.only(right: gap),
            child: Focus(
              onFocusChange: (has) => _handleFocus(index, has),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => widget.onItemTap?.call(item),
                child: AnimatedScale(
                  // Transform-based scale (Req 8.3) — never resizes layout.
                  scale: focused ? 1.08 : 1.0,
                  duration: _focusAnimDuration,
                  curve: Curves.easeOutCubic,
                  child: SizedBox(
                    width: tileWidth,
                    child: Poster(
                      image: item.imageProvider ?? _fallbackImage,
                      orientation: widget.orientation,
                      title: item.title,
                      // Rail tiles render image-only per Req 4.2 / 4.3 —
                      // titles live in adjacent SectionTitle / hero meta.
                      hideText: true,
                      // Atom-level SafeFocusRing (Req 8.1) is driven from
                      // here so focus visuals are centralized.
                      isFocused: focused,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
