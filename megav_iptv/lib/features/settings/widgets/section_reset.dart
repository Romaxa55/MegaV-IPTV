import 'package:flutter/material.dart' hide Chip;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/player/decoder_config.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_palettes.dart';
import '../../../core/theme/megav_text_styles.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/ui/atoms/atoms.dart';

/// Composer for the «Сброс» Settings section: confirm dialog +
/// reset action.
///
/// Reset writes the default palette via [themeProvider] and clears
/// [decoderConfigProvider] back to a fresh [DecoderConfig]. URL
/// remains untouched (Req 9.3 (c)).
class SectionReset extends ConsumerWidget {
  const SectionReset({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final styles = theme.extension<MegaVTextStyles>();
    final body = styles?.bodyDefault ?? theme.textTheme.bodyMedium;

    return SingleChildScrollView(
      padding: EdgeInsets.all(24.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle(title: 'Сброс'),
          SizedBox(height: 16.h),
          Text(
            'Вернёт палитру и настройки декодера к значениям по умолчанию. '
            'URL бэкенда не сбрасывается.',
            style: body,
          ),
          SizedBox(height: 24.h),
          MvButton.accent(label: 'Сбросить настройки', onPressed: () => _confirm(context, ref)),
        ],
      ),
    );
  }

  void _confirm(BuildContext context, WidgetRef ref) {
    final palette = AppColors.activePalette;
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        final styles = theme.extension<MegaVTextStyles>();
        return AlertDialog(
          backgroundColor: palette.surface1,
          title: Text('Подтвердить сброс', style: styles?.bodyDefault),
          content: Text(
            'Палитра вернётся к Noir Cobalt, настройки декодера — к значениям по умолчанию.',
            style: styles?.bodyDim,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text('Отмена', style: TextStyle(color: palette.textDim)),
            ),
            ElevatedButton(
              onPressed: () {
                ref.read(themeProvider.notifier).setPalette(AppPaletteName.noirCobalt);
                ref.read(decoderConfigProvider.notifier).state = const DecoderConfig();
                Navigator.pop(dialogContext);
              },
              style: ElevatedButton.styleFrom(backgroundColor: palette.accent),
              child: const Text('Сбросить'),
            ),
          ],
        );
      },
    );
  }
}
