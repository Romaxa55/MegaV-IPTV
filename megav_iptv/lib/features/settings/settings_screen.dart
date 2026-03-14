import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/player/decoder_config.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Settings',
          style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
      ),
      body: ListView(
        padding: EdgeInsets.all(24.w),
        children: [
          _buildSectionTitle('Backend Server'),
          _buildApiServerSetting(context, ref),
          SizedBox(height: 32.h),
          _buildSectionTitle('Player Engine'),
          _buildPlayerEngineSetting(ref),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16.h, left: 8.w),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.bold, color: AppColors.primary, letterSpacing: 1.2),
      ),
    );
  }

  Widget _buildApiServerSetting(BuildContext context, WidgetRef ref) {
    final baseUrl = ref.watch(baseUrlProvider);

    return Container(
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12.r)),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h),
        leading: Container(
          padding: EdgeInsets.all(10.w),
          decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), shape: BoxShape.circle),
          child: Icon(Icons.dns_outlined, color: AppColors.primary, size: 24.sp),
        ),
        title: Text(
          'API Server URL',
          style: TextStyle(fontSize: 16.sp, color: Colors.white),
        ),
        subtitle: Text(
          baseUrl,
          style: TextStyle(fontSize: 13.sp, color: Colors.white.withValues(alpha: 0.5)),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Icon(Icons.edit, size: 20.sp, color: Colors.white.withValues(alpha: 0.3)),
        onTap: () => _editApiUrl(context, ref),
      ),
    );
  }

  void _editApiUrl(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController(text: ref.read(baseUrlProvider));
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          'API Server URL',
          style: TextStyle(fontSize: 18.sp, color: Colors.white),
        ),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'http://192.168.x.x:8000',
            hintStyle: TextStyle(color: Colors.grey),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.white.withValues(alpha: 0.5))),
          ),
          ElevatedButton(
            onPressed: () {
              ref.read(baseUrlProvider.notifier).state = controller.text.trim();
              Navigator.pop(context);
              // Invalidate groups to reload data from new server
              ref.invalidate(groupsProvider);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerEngineSetting(WidgetRef ref) {
    final config = ref.watch(decoderConfigProvider);

    return Container(
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12.r)),
      child: SwitchListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h),
        activeThumbColor: AppColors.primary,
        secondary: Container(
          padding: EdgeInsets.all(10.w),
          decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.1), shape: BoxShape.circle),
          child: Icon(Icons.movie_creation_outlined, color: Colors.blue, size: 24.sp),
        ),
        title: Text(
          'Use Native Media3 Player',
          style: TextStyle(fontSize: 16.sp, color: Colors.white),
        ),
        subtitle: Text(
          'Uses Android Media3 instead of media_kit. Better for older devices.',
          style: TextStyle(fontSize: 13.sp, color: Colors.white.withValues(alpha: 0.5)),
        ),
        value: config.usesMedia3,
        onChanged: (val) {
          ref.read(decoderConfigProvider.notifier).state = config.copyWith(
            decoderMode: val ? DecoderMode.system : DecoderMode.auto,
          );
        },
      ),
    );
  }
}
