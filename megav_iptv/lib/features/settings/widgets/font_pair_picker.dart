import 'package:flutter/material.dart' hide Chip;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'mv_picker.dart';

/// Extension-ready stub picker for the typography pair. Per Open Question 3
/// only the `font-cinema` pair ships today; the picker is rendered disabled
/// until a second pair is added.
class FontPairPicker extends ConsumerWidget {
  const FontPairPicker({super.key});

  static const List<String> _availablePairs = ['font-cinema'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MvPicker<String>(
      options: _availablePairs,
      value: _availablePairs.first,
      labelOf: (s) => s == 'font-cinema' ? 'Cinematic' : s,
      onChanged: (_) {},
      enabled: _availablePairs.length > 1,
      disabledHint: 'Доступна только Cinematic',
    );
  }
}
