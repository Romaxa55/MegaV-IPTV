import 'package:flutter/material.dart';

import 'screen_kind.dart';

/// Picks one of three child trees based on the current [ScreenKind].
///
/// The [tablet] builder is optional — when omitted, tablet viewports fall
/// through to the [tv] builder. This keeps adoption cheap: a feature can
/// ship with just the mobile + TV variants and add tablet later.
class AdaptiveScaffold extends StatelessWidget {
  const AdaptiveScaffold({super.key, required this.mobile, required this.tv, this.tablet});

  final WidgetBuilder mobile;
  final WidgetBuilder tv;
  final WidgetBuilder? tablet;

  @override
  Widget build(BuildContext context) {
    switch (screenKindOf(context)) {
      case ScreenKind.mobile:
        return mobile(context);
      case ScreenKind.tablet:
        return (tablet ?? tv)(context);
      case ScreenKind.tv:
        return tv(context);
    }
  }
}
