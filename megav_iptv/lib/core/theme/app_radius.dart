import 'package:flutter/material.dart';

/// Radius scale token class — single source of truth for corner radii used
/// across MegaV IPTV screens.
///
/// Values are in logical pixels and match the design's `--r-*` tokens
/// (see `.kiro/design/megav-iptv-handoff/project/themes.css`):
/// `xs = 6`, `sm = 10`, `md = 14`, `lg = 20`, `xl = 28`.
///
/// For `BorderRadius` consumers prefer the pre-built `brXs`/`brSm`/`brMd`/
/// `brLg`/`brXl` constants — they are `const` and identical to
/// `BorderRadius.all(Radius.circular(<value>))`.
///
/// Utility class — cannot be instantiated.
abstract class AppRadius {
  AppRadius._();

  static const double xs = 6;
  static const double sm = 10;
  static const double md = 14;
  static const double lg = 20;
  static const double xl = 28;

  static const BorderRadius brXs = BorderRadius.all(Radius.circular(xs));
  static const BorderRadius brSm = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius brMd = BorderRadius.all(Radius.circular(md));
  static const BorderRadius brLg = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius brXl = BorderRadius.all(Radius.circular(xl));
}
