import 'dart:io' show Platform;

import 'package:flutter/material.dart' hide Chip;
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/megav_text_styles.dart';
import '../../../core/ui/atoms/atoms.dart';

/// Composer for the «О приложении» Settings section: version row, device
/// info, account placeholder, legal stubs.
///
/// Pure presentation — no provider reads, no auth/HTTP infrastructure
/// (Req 8.5).
class SectionAbout extends StatelessWidget {
  const SectionAbout({super.key});

  static const String _version = '1.0.0';

  @override
  Widget build(BuildContext context) {
    final deviceName = _safe(() => Platform.localHostname);
    final osVersion = _safe(() => Platform.operatingSystemVersion);

    return SingleChildScrollView(
      padding: EdgeInsets.all(24.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle(title: 'О приложении'),
          SizedBox(height: 16.h),
          const _InfoRow(label: 'Версия', value: _version),
          SizedBox(height: 8.h),
          _InfoRow(label: 'Устройство', value: deviceName),
          SizedBox(height: 8.h),
          _InfoRow(label: 'ОС', value: osVersion),
          SizedBox(height: 32.h),
          const SectionTitle(title: 'Аккаунт'),
          SizedBox(height: 16.h),
          const _InfoRow(label: 'Статус', value: 'Не выполнен вход'),
          SizedBox(height: 32.h),
          const SectionTitle(title: 'Юридическая информация'),
          SizedBox(height: 16.h),
          MvButton.ghost(label: 'Политика конфиденциальности', onPressed: () {}),
          SizedBox(height: 12.h),
          MvButton.ghost(label: 'Условия использования', onPressed: () {}),
        ],
      ),
    );
  }

  static String _safe(String Function() fn) {
    try {
      return fn();
    } catch (_) {
      return '—';
    }
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final styles = theme.extension<MegaVTextStyles>();
    final labelStyle = styles?.bodyDim ?? theme.textTheme.bodyMedium;
    final valueStyle = (styles?.bodyDefault ?? theme.textTheme.bodyMedium)?.copyWith(
      color: AppColors.activePalette.text,
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 240.w,
          child: Text(label, style: labelStyle),
        ),
        Expanded(
          child: Text(value, style: valueStyle, maxLines: 2, overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}
