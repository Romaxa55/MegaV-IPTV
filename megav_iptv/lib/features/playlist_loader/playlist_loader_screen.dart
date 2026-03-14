import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/providers.dart';
import '../../core/theme/app_colors.dart';

class SplashLoaderScreen extends ConsumerStatefulWidget {
  const SplashLoaderScreen({super.key});

  @override
  ConsumerState<SplashLoaderScreen> createState() => _SplashLoaderScreenState();
}

class _SplashLoaderScreenState extends ConsumerState<SplashLoaderScreen> {
  bool _isLoading = true;
  String? _error;
  late final TextEditingController _urlController;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: ref.read(baseUrlProvider));
    _checkServer();
  }

  Future<void> _checkServer() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final api = ref.read(apiClientProvider);
      // Just try to fetch groups to verify connection
      await api.getGroups();
      if (mounted) context.go('/home');
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Не удалось подключиться к серверу';
          _isLoading = false;
        });
      }
    }
  }

  void _saveAndRetry() {
    ref.read(baseUrlProvider.notifier).state = _urlController.text.trim();
    _checkServer();
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Container(
          width: 400.w,
          padding: EdgeInsets.all(32.w),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16.r)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.tv, size: 64.sp, color: AppColors.primary),
              SizedBox(height: 24.h),
              if (_isLoading) ...[
                const CircularProgressIndicator(color: AppColors.primary),
                SizedBox(height: 16.h),
                Text(
                  'Подключение к серверу...',
                  style: TextStyle(color: Colors.white, fontSize: 16.sp),
                ),
              ] else ...[
                if (_error != null)
                  Text(
                    _error!,
                    style: TextStyle(color: AppColors.error, fontSize: 14.sp),
                    textAlign: TextAlign.center,
                  ),
                SizedBox(height: 16.h),
                TextField(
                  controller: _urlController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'API Server URL',
                    labelStyle: TextStyle(color: AppColors.textHint),
                    filled: true,
                    fillColor: Colors.black.withValues(alpha: 0.3),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r), borderSide: BorderSide.none),
                  ),
                ),
                SizedBox(height: 24.h),
                SizedBox(
                  width: double.infinity,
                  height: 48.h,
                  child: ElevatedButton(
                    onPressed: _saveAndRetry,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
                    ),
                    child: Text(
                      'Подключиться',
                      style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
