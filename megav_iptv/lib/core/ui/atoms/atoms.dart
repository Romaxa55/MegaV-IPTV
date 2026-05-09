/// MegaV atoms barrel — re-exports the 13 design-system atoms.
///
/// Convention: every atom file in `lib/core/ui/atoms/` corresponds to
/// exactly one commented-out export line below, in alphabetical order.
/// Tasks 2.x in `.kiro/specs/design-system-atoms/tasks.md` ONLY uncomment
/// their assigned line — never insert, never reorder, never delete.
///
/// Downstream consumers:
/// ```dart
/// import 'package:megav_iptv/core/ui/atoms/atoms.dart';
/// ```
library;

export 'brand.dart';
export 'chip.dart';
export 'genre_tabs.dart';
export 'mm_logo.dart';
export 'mv_button.dart';
export 'mv_icon_button.dart';
export 'mv_key.dart';

export 'mv_strip.dart';
export 'mv_track.dart';
export 'poster.dart';
// export 'remote_hint.dart';
// export 'section_title.dart';
export 'status_bar.dart';
