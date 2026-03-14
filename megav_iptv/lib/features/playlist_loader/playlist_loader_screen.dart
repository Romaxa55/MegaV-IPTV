import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/providers.dart';
import '../../core/theme/app_colors.dart';

class PlaylistLoaderScreen extends ConsumerStatefulWidget {
  const PlaylistLoaderScreen({super.key});

  @override
  ConsumerState<PlaylistLoaderScreen> createState() => _PlaylistLoaderScreenState();
}

class _PlaylistLoaderScreenState extends ConsumerState<PlaylistLoaderScreen> {
  late final TextEditingController _urlController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: ref.read(playlistUrlProvider));
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _loadPlaylist() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    setState(() => _isLoading = true);

    ref.read(playlistUrlProvider.notifier).state = url;

    try {
      final repo = ref.read(playlistRepositoryProvider);
      await repo.loadPlaylist(url, force: true);
      if (mounted) {
        ref.read(epgRefreshProvider);
        context.go('/home');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading playlist: $e'), backgroundColor: AppColors.error));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 48.w),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.live_tv_rounded, size: 80.sp, color: AppColors.primary),
                SizedBox(height: 24.h),
                Text(
                  'MegaV IPTV',
                  style: TextStyle(fontSize: 36.sp, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                SizedBox(height: 8.h),
                Text(
                  'Enter playlist URL to start',
                  style: TextStyle(fontSize: 16.sp, color: AppColors.textSecondary),
                ),
                SizedBox(height: 48.h),
                SizedBox(
                  width: 600.w,
                  child: TextField(
                    controller: _urlController,
                    autofocus: true,
                    style: TextStyle(fontSize: 14.sp),
                    decoration: InputDecoration(
                      hintText: 'https://example.com/playlist.m3u',
                      prefixIcon: const Icon(Icons.link),
                      suffixIcon: IconButton(icon: const Icon(Icons.clear), onPressed: () => _urlController.clear()),
                    ),
                    onSubmitted: (_) => _loadPlaylist(),
                  ),
                ),
                SizedBox(height: 24.h),
                SizedBox(
                  width: 300.w,
                  height: 50.h,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _loadPlaylist,
                    child: _isLoading
                        ? SizedBox(
                            width: 24.w,
                            height: 24.h,
                            child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text('Load Playlist', style: TextStyle(fontSize: 16.sp)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
