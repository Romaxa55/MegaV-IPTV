import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../core/player/decoder_config.dart';
import '../../core/providers/providers.dart';
import '../../core/theme/app_colors.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(decoderConfigProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('Settings', style: TextStyle(fontSize: 20.sp)),
      ),
      body: ListView(
        padding: EdgeInsets.all(16.w),
        children: [
          _SectionHeader(title: 'Decoder'),
          SizedBox(height: 8.h),
          RadioGroup<DecoderMode>(
            groupValue: config.decoderMode,
            onChanged: (value) {
              if (value != null) {
                ref.read(decoderConfigProvider.notifier).state =
                    config.copyWith(decoderMode: value);
                ref.read(playerManagerProvider).updateDecoderConfig(
                    config.copyWith(decoderMode: value));
              }
            },
            child: Column(
              children: DecoderMode.values
                  .map((mode) => RadioListTile<DecoderMode>(
                        title: Text(mode.label,
                            style: TextStyle(fontSize: 14.sp)),
                        subtitle: Text(mode.description,
                            style: TextStyle(
                                fontSize: 11.sp,
                                color: AppColors.textHint)),
                        value: mode,
                        activeColor: AppColors.primary,
                      ))
                  .toList(),
            ),
          ),
          SizedBox(height: 24.h),
          _SectionHeader(title: 'Buffer'),
          SizedBox(height: 8.h),
          RadioGroup<BufferMode>(
            groupValue: config.bufferMode,
            onChanged: (value) {
              if (value != null) {
                ref.read(decoderConfigProvider.notifier).state =
                    config.copyWith(bufferMode: value);
              }
            },
            child: Column(
              children: BufferMode.values
                  .map((mode) => RadioListTile<BufferMode>(
                        title: Text(mode.label,
                            style: TextStyle(fontSize: 14.sp)),
                        subtitle: Text('${mode.seconds}s buffer',
                            style: TextStyle(
                                fontSize: 11.sp,
                                color: AppColors.textHint)),
                        value: mode,
                        activeColor: AppColors.primary,
                      ))
                  .toList(),
            ),
          ),
          SizedBox(height: 24.h),
          _SectionHeader(title: 'Playlist'),
          SizedBox(height: 8.h),
          ListTile(
            title: Text('Playlist URL',
                style: TextStyle(fontSize: 14.sp)),
            subtitle: Text(
              ref.watch(playlistUrlProvider),
              style:
                  TextStyle(fontSize: 11.sp, color: AppColors.textHint),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing:
                Icon(Icons.edit, color: AppColors.textHint, size: 20.sp),
            onTap: () => _editPlaylistUrl(context, ref),
          ),
        ],
      ),
    );
  }

  void _editPlaylistUrl(BuildContext context, WidgetRef ref) {
    final controller =
        TextEditingController(text: ref.read(playlistUrlProvider));
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Playlist URL', style: TextStyle(fontSize: 18.sp)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(fontSize: 13.sp),
          decoration: const InputDecoration(
            hintText: 'https://example.com/playlist.m3u',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              ref.read(playlistUrlProvider.notifier).state =
                  controller.text.trim();
              ref.invalidate(channelsProvider);
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 16.sp,
        fontWeight: FontWeight.bold,
        color: AppColors.primary,
      ),
    );
  }
}
