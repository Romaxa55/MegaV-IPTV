import 'package:flutter/material.dart' hide Chip;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/playlist/models/channel.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../mobile/widgets/m_icon_btn.dart';

/// Mobile-only channel detail screen.
///
/// Rendered by [DetailRootScreen] via [AdaptiveScaffold] for narrow
/// viewports (Phase 4 task 4.1 of the mobile-adaptive-layout spec).
///
/// Composition:
///  - Top hero strip with channel logo (or `surface2` fallback on missing /
///    failed image) and a back chevron overlay anchored to the safe area.
///  - Title block with channel name (22 px / w600), group title and a row
///    of [MIconBtn] action chips (Watch / Add / Share — all stubs).
///  - Description block with placeholder copy.
///
/// Reads channel data from [featuredChannelsProvider] (read-only) — same
/// pattern used by the TV [DetailScreen]. Falls back to a placeholder
/// `Channel` when the list is empty so the screen always renders during
/// the smoke test.
class DetailMobileScreen extends ConsumerWidget {
  const DetailMobileScreen({super.key, required this.channelId});

  final int channelId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final channels = ref.watch(featuredChannelsProvider).valueOrNull ?? const <Channel>[];
    final channel = channels.firstWhere(
      (c) => c.id == channelId,
      orElse: () => channels.isEmpty ? const Channel(id: -1, name: 'Loading…') : channels.first,
    );
    final palette = AppColors.activePalette;
    final logoUrl = channel.logoUrl ?? '';

    return Scaffold(
      key: const Key('detail-mobile-root'),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          Stack(
            children: [
              SizedBox(
                height: 320,
                width: double.infinity,
                child: logoUrl.isNotEmpty
                    ? Image(
                        image: NetworkImage(logoUrl),
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => ColoredBox(color: palette.surface2),
                      )
                    : ColoredBox(color: palette.surface2),
              ),
              Positioned(
                top: MediaQuery.viewPaddingOf(context).top + 8,
                left: 16,
                child: MIconBtn(icon: Icons.arrow_back, onTap: () => Navigator.of(context).maybePop()),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(channel.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600), maxLines: 2),
                const SizedBox(height: 8),
                Text(channel.groupTitle, style: TextStyle(fontSize: 12, color: palette.textDim)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    MIconBtn(icon: Icons.play_arrow, label: 'Смотреть', onTap: () {}),
                    const SizedBox(width: 12),
                    MIconBtn(icon: Icons.add, label: 'В список', onTap: () {}),
                    const SizedBox(width: 12),
                    MIconBtn(icon: Icons.share, label: 'Поделиться', onTap: () {}),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  'Описание канала "${channel.name}". Здесь будет подробная информация.',
                  style: const TextStyle(fontSize: 16, height: 1.5),
                ),
                const SizedBox(height: 96),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
