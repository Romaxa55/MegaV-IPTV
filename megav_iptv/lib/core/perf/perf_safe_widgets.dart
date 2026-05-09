import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_palette.dart';
import '../theme/app_radius.dart';

/// Maximum BoxShadow / Shadow blurRadius safe on TV-Mali (rtd2851a).
/// Anything beyond this triggers per-frame gaussian re-rasterize.
/// Cross-cutting constant — also referenced by task 3.1 (shadow audit)
/// and Req 7.3.
const double kSafeShadowBlurMax = 12.0;

/// Translucent pill / chip / status badge with opaque tint background.
///
/// Replaces CSS `backdrop-filter: blur(20px)` over video on TV target,
/// where runtime gaussian blur over a Texture layer is catastrophic.
///
/// Visual trade-off: opaque tint loses the "frosted glass" effect but
/// remains palette-aware via [tint] (defaults to active palette surface).
///
/// Usage:
/// ```dart
/// SafePill(
///   child: Text('LIVE', style: theme.megavText.metaMono),
///   tint: AppColors.liveBadge,
///   alpha: 0.85,
/// )
/// ```
class SafePill extends StatelessWidget {
  const SafePill({
    super.key,
    required this.child,
    this.tint,
    this.alpha = 0.85,
    this.borderRadius,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
  });

  final Widget child;
  final Color? tint;
  final double alpha;
  final BorderRadius? borderRadius;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final base = tint ?? AppColors.surface;
    final filled = Color.fromRGBO(
      (base.r * 255.0).round() & 0xFF,
      (base.g * 255.0).round() & 0xFF,
      (base.b * 255.0).round() & 0xFF,
      alpha,
    );
    return Container(
      padding: padding,
      decoration: BoxDecoration(color: filled, borderRadius: borderRadius ?? AppRadius.brSm),
      child: child,
    );
  }
}

/// Solid-color focus ring drawn outside child bounds via stacked
/// BoxShadow with `blurRadius: 0`.
///
/// Replaces CSS `outline: 3px solid var(--accent); outline-offset: 3px;`
/// — Flutter `Border` paints inside the box, not outside, so we use
/// two solid BoxShadow layers: inner one matches background (creates
/// the 3px gap), outer one is the ring color.
///
/// Transition between focused/unfocused completes within 150 ms
/// (Leanback `lb_card_activated_animation_duration`) via AnimatedContainer.
/// GPU-only animation — no relayout of siblings.
///
/// Usage:
/// ```dart
/// SafeFocusRing(
///   isFocused: focusNode.hasFocus,
///   child: PosterCard(...),
/// )
/// ```
class SafeFocusRing extends StatelessWidget {
  const SafeFocusRing({
    super.key,
    required this.child,
    this.isFocused = false,
    this.ringColor,
    this.gap = 3.0,
    this.thickness = 3.0,
    this.duration = const Duration(milliseconds: 150),
  });

  final Widget child;
  final bool isFocused;
  final Color? ringColor;
  final double gap;
  final double thickness;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final color = ringColor ?? AppColors.primary;
    return AnimatedContainer(
      duration: duration,
      curve: Curves.fastOutSlowIn,
      decoration: BoxDecoration(
        boxShadow: isFocused
            ? <BoxShadow>[
                // Outer: ring color (visible).
                BoxShadow(color: color, spreadRadius: gap + thickness, blurRadius: 0),
                // Inner: background color (creates the gap, simulates outline-offset).
                BoxShadow(color: AppColors.background, spreadRadius: gap, blurRadius: 0),
              ]
            : const <BoxShadow>[],
      ),
      child: child,
    );
  }
}

/// Baked-PNG film grain overlay applied via Opacity.
///
/// Replaces CSS `mix-blend-mode: overlay` + SVG turbulence which
/// would force a saveLayer per frame. The PNG (`assets/grain_overlay.png`)
/// has noise + light tone pre-applied; we just composite it over the
/// child with a low alpha. `BlendMode.srcOver` (default) is the only
/// blend used.
///
/// **Apply ONLY to static layers** (boot overlay, hero backdrop,
/// detail-screen background). NEVER on scrolling content — even
/// the cheap composite cost adds up across many frames.
///
/// Opacity is clamped to [0, 0.20] on construction; recommended
/// default 0.08.
///
/// Usage:
/// ```dart
/// SafeFilmGrain(
///   opacity: 0.08,
///   child: HeroBackdropImage(...),
/// )
/// ```
class SafeFilmGrain extends StatelessWidget {
  const SafeFilmGrain({
    super.key,
    required this.child,
    this.opacity = 0.08,
    this.assetPath = 'assets/grain_overlay.png',
  });

  final Widget child;
  final double opacity;
  final String assetPath;

  @override
  Widget build(BuildContext context) {
    final clamped = opacity.clamp(0.0, 0.20);
    return Stack(
      fit: StackFit.passthrough,
      children: [
        child,
        Positioned.fill(
          child: IgnorePointer(
            child: Opacity(
              opacity: clamped,
              child: Image.asset(
                assetPath,
                fit: BoxFit.cover,
                repeat: ImageRepeat.repeat,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Hero-backdrop showing a pre-rendered blurred copy of artwork without
/// per-frame BackdropFilter cost.
///
/// CSS analog: `filter: blur(40px) saturate(1.2)` applied per frame.
/// On TV-Mali GPU, runtime ImageFilter.blur in build() is catastrophic;
/// instead we pre-render once via offscreen PictureRecorder, cache the
/// resulting ui.Image, and display it as a static raster via RawImage.
///
/// First-render latency: ~200-400ms while the blurred copy renders
/// asynchronously. During that window we display [fallbackBackground]
/// solid fill. Subsequent frames are 0ms steady-state.
///
/// Usage:
/// ```dart
/// SafeBackdrop(
///   imageProvider: NetworkImage(channel.heroUrl),
///   fallbackBackground: AppColors.background,
///   blurSigma: 40,
/// )
/// ```
class SafeBackdrop extends StatefulWidget {
  const SafeBackdrop({
    super.key,
    required this.imageProvider,
    required this.fallbackBackground,
    this.blurSigma = 40,
    this.semanticLabel,
  });

  final ImageProvider? imageProvider;
  final Color fallbackBackground;
  final double blurSigma;
  final String? semanticLabel;

  @override
  State<SafeBackdrop> createState() => _SafeBackdropState();
}

class _SafeBackdropState extends State<SafeBackdrop> {
  ui.Image? _blurredImage;
  Object? _activeKey;
  bool _renderInFlight = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _maybeRebuildBlur();
  }

  @override
  void didUpdateWidget(SafeBackdrop oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageProvider != widget.imageProvider || oldWidget.blurSigma != widget.blurSigma) {
      _maybeRebuildBlur();
    }
  }

  @override
  void dispose() {
    _blurredImage?.dispose();
    _blurredImage = null;
    super.dispose();
  }

  Future<void> _maybeRebuildBlur() async {
    final provider = widget.imageProvider;
    if (provider == null || _renderInFlight) return;
    _renderInFlight = true;
    try {
      const cfg = ImageConfiguration.empty;
      final key = await provider.obtainKey(cfg);
      if (!mounted) return;
      if (key == _activeKey) return;
      _activeKey = key;

      // Resolve image bytes via standard ImageStream.
      final completer = Completer<ui.Image>();
      final stream = provider.resolve(cfg);
      late ImageStreamListener listener;
      listener = ImageStreamListener(
        (info, _) {
          if (!completer.isCompleted) completer.complete(info.image);
          stream.removeListener(listener);
        },
        onError: (err, st) {
          if (!completer.isCompleted) completer.completeError(err, st);
          stream.removeListener(listener);
        },
      );
      stream.addListener(listener);
      final src = await completer.future;
      if (!mounted) return;

      // Render image into offscreen PictureRecorder with ImageFilter.blur.
      // The blur happens here, ONCE per source change — never in build().
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final paint = Paint()
        ..imageFilter = ui.ImageFilter.blur(
          sigmaX: widget.blurSigma,
          sigmaY: widget.blurSigma,
          tileMode: TileMode.clamp,
        );
      canvas.saveLayer(null, paint);
      canvas.drawImage(src, Offset.zero, Paint());
      canvas.restore();
      final picture = recorder.endRecording();
      final blurred = await picture.toImage(src.width, src.height);
      picture.dispose();

      if (!mounted) {
        blurred.dispose();
        return;
      }
      // Swap and free old.
      final old = _blurredImage;
      _blurredImage = blurred;
      old?.dispose();
      setState(() {});
    } catch (_) {
      // Swallow — widget falls back to solid color via build.
    } finally {
      _renderInFlight = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final blurred = _blurredImage;
    Widget content = ColoredBox(
      color: widget.fallbackBackground,
      child: blurred == null ? const SizedBox.expand() : RawImage(image: blurred, fit: BoxFit.cover),
    );
    final label = widget.semanticLabel;
    if (label != null) {
      content = Semantics(label: label, image: true, child: content);
    }
    return RepaintBoundary(child: content);
  }
}

/// Single radial gradient combining vignette + bottom-shade in one
/// render pass.
///
/// Replaces the 3 stacked gradients from the design handoff (vignette
/// radial + bottom-shade linear + side-fade linear). On TV-Mali GPU,
/// each full-screen gradient layer over hero video costs ~1-2 ms;
/// 3 stacked = 3-5 ms. This combined gradient is one pass.
///
/// Side-fade is intentionally NOT included — caller relies on natural
/// padding + matching parent background color (Req 5.5).
///
/// Usage:
/// ```dart
/// DecoratedBox(
///   decoration: BoxDecoration(gradient: combinedHeroGradient(palette)),
///   child: ...,
/// )
/// ```
RadialGradient combinedHeroGradient(AppPalette palette) {
  return RadialGradient(
    center: Alignment.bottomCenter,
    radius: 1.4,
    stops: const [0.0, 0.45, 0.85, 1.0],
    colors: [
      palette.background,
      palette.background.withValues(alpha: 0.85),
      palette.background.withValues(alpha: 0.40),
      palette.background.withValues(alpha: 0.0),
    ],
  );
}
