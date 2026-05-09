import 'package:flutter/material.dart' hide Chip;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/providers/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/megav_text_styles.dart';
import '../../../core/ui/atoms/atoms.dart';

/// Composer for the «Сеть» Settings section: backend URL row +
/// playlist cache reset action.
///
/// Reads [baseUrlProvider]; on edit, writes the new value and invalidates
/// [categoriesProvider] so the playlist refetches against the new server.
class SectionNetwork extends ConsumerWidget {
  const SectionNetwork({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final url = ref.watch(baseUrlProvider);
    final theme = Theme.of(context);
    final styles = theme.extension<MegaVTextStyles>();
    final monoStyle = styles?.metaMono ?? theme.textTheme.bodyMedium;

    return SingleChildScrollView(
      padding: EdgeInsets.all(24.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle(title: 'Бэкенд'),
          SizedBox(height: 16.h),
          Row(
            children: [
              Expanded(
                child: Text(url, style: monoStyle, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              SizedBox(width: 12.w),
              MvIconButton(icon: const Icon(Icons.edit), onPressed: () => _editUrl(context, ref)),
            ],
          ),
          SizedBox(height: 32.h),
          const SectionTitle(title: 'Кэш плейлистов'),
          SizedBox(height: 16.h),
          MvButton.ghost(label: 'Сброс кэша', onPressed: () => ref.invalidate(categoriesProvider)),
        ],
      ),
    );
  }

  void _editUrl(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController(text: ref.read(baseUrlProvider));
    final palette = AppColors.activePalette;
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        final styles = theme.extension<MegaVTextStyles>();
        return AlertDialog(
          backgroundColor: palette.surface1,
          title: Text('URL бэкенда', style: styles?.bodyDefault),
          content: TextField(
            controller: controller,
            autofocus: true,
            style: TextStyle(color: palette.text),
            decoration: InputDecoration(
              hintText: 'https://example.com',
              hintStyle: TextStyle(color: palette.textMute),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text('Отмена', style: TextStyle(color: palette.textDim)),
            ),
            ElevatedButton(
              onPressed: () {
                ref.read(baseUrlProvider.notifier).state = controller.text.trim();
                ref.invalidate(categoriesProvider);
                Navigator.pop(dialogContext);
              },
              style: ElevatedButton.styleFrom(backgroundColor: palette.accent),
              child: const Text('Сохранить'),
            ),
          ],
        );
      },
    );
  }
}
