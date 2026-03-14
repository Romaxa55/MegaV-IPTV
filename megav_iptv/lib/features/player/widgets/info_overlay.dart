import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/playlist/models/channel.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/app_colors.dart';

class InfoOverlay extends ConsumerStatefulWidget {
  final Channel channel;
  final VoidCallback onClose;

  const InfoOverlay({super.key, required this.channel, required this.onClose});

  @override
  ConsumerState<InfoOverlay> createState() => _InfoOverlayState();
}

class _InfoOverlayState extends ConsumerState<InfoOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
    _fadeAnimation = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic));
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ch = widget.channel;
    final key = ch.id;

    return Positioned(
      bottom: 80.h,
      left: 20.w,
      right: 20.w,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16.r),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
              child: Container(
                padding: EdgeInsets.all(20.w),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLogo(ch),
                    SizedBox(width: 16.w),
                    Expanded(child: _buildInfo(ch, key)),
                    GestureDetector(
                      onTap: widget.onClose,
                      child: Container(
                        width: 28.w,
                        height: 28.w,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        child: Icon(Icons.close, size: 14.sp, color: Colors.white.withValues(alpha: 0.4)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo(Channel ch) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12.r),
      child: Container(
        width: 64.w,
        height: 64.w,
        color: Colors.white.withValues(alpha: 0.1),
        child: ch.logoUrl != null && ch.logoUrl!.isNotEmpty
            ? Image.network(ch.logoUrl!, fit: BoxFit.cover, errorBuilder: (ctx, err, st) => _placeholder())
            : _placeholder(),
      ),
    );
  }

  Widget _placeholder() => Center(
    child: Icon(Icons.tv, size: 28.sp, color: Colors.white.withValues(alpha: 0.2)),
  );

  Widget _buildInfo(Channel ch, String key) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                ch.name,
                style: TextStyle(fontSize: 20.sp, color: Colors.white, fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        SizedBox(height: 8.h),
        Wrap(
          spacing: 6.w,
          runSpacing: 4.h,
          children: [
            if (ch.groupTitle != null)
              _InfoBadge(
                text: ch.groupTitle!,
                color: AppColors.primary.withValues(alpha: 0.2),
                textColor: AppColors.primaryLight,
              ),
          ],
        ),
        SizedBox(height: 12.h),
        Consumer(
          builder: (context, ref, _) {
            final nowAsync = ref.watch(currentProgramProvider(key));
            final upcomingAsync = ref.watch(upcomingProgramsProvider(key));
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                nowAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (e, st) => const SizedBox.shrink(),
                  data: (prog) {
                    if (prog == null) return const SizedBox.shrink();
                    return Row(
                      children: [
                        Icon(Icons.access_time, size: 12.sp, color: AppColors.primaryLight),
                        SizedBox(width: 6.w),
                        Text(
                          'Сейчас: ${prog.title}',
                          style: TextStyle(fontSize: 12.sp, color: AppColors.primaryLight),
                        ),
                      ],
                    );
                  },
                ),
                SizedBox(height: 4.h),
                upcomingAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (e, st) => const SizedBox.shrink(),
                  data: (progs) {
                    if (progs.isEmpty) return const SizedBox.shrink();
                    final prog = progs.first;
                    return Row(
                      children: [
                        Icon(Icons.access_time, size: 12.sp, color: Colors.white.withValues(alpha: 0.2)),
                        SizedBox(width: 6.w),
                        Text(
                          'Далее: ${prog.title}',
                          style: TextStyle(fontSize: 12.sp, color: Colors.white.withValues(alpha: 0.2)),
                        ),
                      ],
                    );
                  },
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _InfoBadge extends StatelessWidget {
  final String text;
  final Color color;
  final Color textColor;

  const _InfoBadge({required this.text, required this.color, required this.textColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6.r)),
      child: Text(
        text,
        style: TextStyle(fontSize: 11.sp, color: textColor),
      ),
    );
  }
}
