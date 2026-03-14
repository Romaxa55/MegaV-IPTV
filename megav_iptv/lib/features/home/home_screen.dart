import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:responsive_builder/responsive_builder.dart';

import '../../core/providers/providers.dart';
import '../../core/theme/app_colors.dart';
import 'widgets/channel_card.dart';
import 'widgets/group_sidebar.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupsAsync = ref.watch(groupsProvider);
    final filteredAsync = ref.watch(filteredChannelsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'MegaV IPTV',
          style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: groupsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48.sp, color: AppColors.error),
              SizedBox(height: 16.h),
              Text('Error: $error',
                  style: TextStyle(fontSize: 14.sp, color: AppColors.error)),
              SizedBox(height: 16.h),
              ElevatedButton(
                onPressed: () => ref.invalidate(channelsProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (groups) => ResponsiveBuilder(
          builder: (context, sizingInfo) {
            if (sizingInfo.deviceScreenType == DeviceScreenType.mobile) {
              return _buildMobileLayout(context, ref, groups, filteredAsync);
            }
            return _buildTvLayout(context, ref, groups, filteredAsync);
          },
        ),
      ),
    );
  }

  Widget _buildMobileLayout(
    BuildContext context,
    WidgetRef ref,
    dynamic groups,
    AsyncValue filteredAsync,
  ) {
    return Column(
      children: [
        SizedBox(
          height: 50.h,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 8.w),
            itemCount: groups.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                final isSelected = ref.watch(selectedGroupProvider) == null;
                return Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4.w),
                  child: ChoiceChip(
                    label: Text('All', style: TextStyle(fontSize: 12.sp)),
                    selected: isSelected,
                    selectedColor: AppColors.primary,
                    onSelected: (_) =>
                        ref.read(selectedGroupProvider.notifier).state = null,
                  ),
                );
              }
              final group = groups[index - 1];
              final isSelected =
                  ref.watch(selectedGroupProvider) == group.name;
              return Padding(
                padding: EdgeInsets.symmetric(horizontal: 4.w),
                child: ChoiceChip(
                  label: Text('${group.name} (${group.channelCount})',
                      style: TextStyle(fontSize: 12.sp)),
                  selected: isSelected,
                  selectedColor: AppColors.primary,
                  onSelected: (_) => ref
                      .read(selectedGroupProvider.notifier)
                      .state = isSelected ? null : group.name,
                ),
              );
            },
          ),
        ),
        Expanded(
          child: filteredAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (channels) => ListView.builder(
              padding: EdgeInsets.all(8.w),
              itemCount: channels.length,
              itemBuilder: (context, index) => ChannelCard(
                channel: channels[index],
                onTap: () => _openChannel(context, ref, channels, index),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTvLayout(
    BuildContext context,
    WidgetRef ref,
    dynamic groups,
    AsyncValue filteredAsync,
  ) {
    return Row(
      children: [
        SizedBox(
          width: 280.w,
          child: GroupSidebar(groups: groups),
        ),
        VerticalDivider(width: 1, color: AppColors.cardBorder),
        Expanded(
          child: filteredAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (channels) => GridView.builder(
              padding: EdgeInsets.all(16.w),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                childAspectRatio: 2.5,
                crossAxisSpacing: 12.w,
                mainAxisSpacing: 12.h,
              ),
              itemCount: channels.length,
              itemBuilder: (context, index) => ChannelCard(
                channel: channels[index],
                isGrid: true,
                onTap: () => _openChannel(context, ref, channels, index),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _openChannel(
      BuildContext context, WidgetRef ref, List channels, int index) {
    ref.read(currentChannelProvider.notifier).state = channels[index];
    ref.read(currentChannelIndexProvider.notifier).state = index;
    context.push('/player');
  }
}
