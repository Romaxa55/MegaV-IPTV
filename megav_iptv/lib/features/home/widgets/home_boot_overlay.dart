import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/theme/app_colors.dart';

/// Полноэкранная «загрузка» поверх уже отрисованного главного экрана.
class HomeBootOverlay extends StatelessWidget {
  final bool showError;
  final String? errorMessage;
  final TextEditingController urlController;
  final VoidCallback onRetry;

  const HomeBootOverlay({
    super.key,
    required this.showError,
    required this.errorMessage,
    required this.urlController,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.background,
      child: Center(
        child: showError
            ? _ErrorPanel(message: errorMessage, urlController: urlController, onRetry: onRetry)
            : _IntroBranding(),
      ),
    );
  }
}

class _IntroBranding extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.tv, size: 120.sp, color: AppColors.primary),
        SizedBox(height: 32.h),
        Text(
          'MegaV IPTV',
          style: TextStyle(color: Colors.white, fontSize: 48.sp, fontWeight: FontWeight.bold, letterSpacing: 2),
        ),
        SizedBox(height: 48.h),
        SizedBox(
          width: 40.w,
          height: 40.w,
          child: const CircularProgressIndicator(color: AppColors.primary, strokeWidth: 3),
        ),
        SizedBox(height: 24.h),
        Text(
          'Загрузка…',
          style: TextStyle(color: Colors.white70, fontSize: 18.sp, letterSpacing: 1),
        ),
      ],
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  final String? message;
  final TextEditingController urlController;
  final VoidCallback onRetry;

  const _ErrorPanel({required this.message, required this.urlController, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 400.w,
      padding: EdgeInsets.all(32.w),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16.r)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 64.sp, color: AppColors.error),
          SizedBox(height: 24.h),
          if (message != null)
            Text(
              message!,
              style: TextStyle(color: AppColors.error, fontSize: 14.sp),
              textAlign: TextAlign.center,
            ),
          SizedBox(height: 24.h),
          TextField(
            controller: urlController,
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
              onPressed: onRetry,
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
      ),
    );
  }
}
