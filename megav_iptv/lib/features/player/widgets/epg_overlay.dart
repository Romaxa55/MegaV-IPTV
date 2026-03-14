import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/playlist/models/epg_program.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/app_colors.dart';

class EpgOverlay extends ConsumerStatefulWidget {
  final String channelName;
  final String? tvgId;
  final VoidCallback onClose;

  const EpgOverlay({super.key, required this.channelName, this.tvgId, required this.onClose});

  @override
  ConsumerState<EpgOverlay> createState() => _EpgOverlayState();
}

class _EpgOverlayState extends ConsumerState<EpgOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _slideController;
  late final Animation<Offset> _slideAnimation;
  List<EpgProgram> _programs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: const _SpringCurve(damping: 30, stiffness: 300)));
    _slideController.forward();
    _loadPrograms();
  }

  Future<void> _loadPrograms() async {
    final repo = ref.read(epgRepositoryProvider);
    final resolvedId = await repo.resolveChannelId(tvgId: widget.tvgId, channelName: widget.channelName);
    if (resolvedId == null || resolvedId.isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final programs = await repo.getProgramsForChannel(resolvedId);
    if (mounted) {
      setState(() {
        _programs = programs;
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ClipRRect(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              constraints: BoxConstraints(maxHeight: 0.55.sh),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.8),
                border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildHeader(),
                  if (_loading)
                    Padding(
                      padding: EdgeInsets.all(32.w),
                      child: const CircularProgressIndicator(color: AppColors.primary),
                    )
                  else if (_programs.isEmpty)
                    Padding(
                      padding: EdgeInsets.all(32.w),
                      child: Text(
                        'Нет данных EPG',
                        style: TextStyle(fontSize: 13.sp, color: Colors.white.withValues(alpha: 0.3)),
                      ),
                    )
                  else
                    Flexible(child: _buildTimeline()),
                  _buildFooter(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 0),
      child: Column(
        children: [
          Container(
            width: 40.w,
            height: 4.h,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2.r),
            ),
          ),
          SizedBox(height: 16.h),
          Row(
            children: [
              Icon(Icons.calendar_month, size: 16.sp, color: AppColors.primary),
              SizedBox(width: 8.w),
              Text(
                'Программа передач',
                style: TextStyle(fontSize: 14.sp, color: Colors.white),
              ),
              const Spacer(),
              Text(
                widget.channelName,
                style: TextStyle(fontSize: 12.sp, color: Colors.white.withValues(alpha: 0.3)),
              ),
              SizedBox(width: 8.w),
              _CloseButton(onTap: widget.onClose),
            ],
          ),
          SizedBox(height: 12.h),
        ],
      ),
    );
  }

  Widget _buildTimeline() {
    return ListView.separated(
      shrinkWrap: true,
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      itemCount: _programs.length,
      separatorBuilder: (context, index) => SizedBox(height: 2.h),
      itemBuilder: (context, index) {
        final prog = _programs[index];
        final isCurrent = prog.isNow;
        final isPast = prog.end.isBefore(DateTime.now());

        return Container(
          padding: EdgeInsets.all(12.w),
          decoration: BoxDecoration(
            color: isCurrent ? AppColors.primary.withValues(alpha: 0.1) : Colors.transparent,
            border: isCurrent ? Border.all(color: AppColors.primary.withValues(alpha: 0.2)) : null,
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 44.w,
                child: Text(
                  _formatTime(prog.start),
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontFamily: 'monospace',
                    color: isCurrent ? AppColors.primaryLight : Colors.white.withValues(alpha: 0.3),
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      prog.title,
                      style: TextStyle(
                        fontSize: 13.sp,
                        color: isCurrent
                            ? Colors.white
                            : isPast
                            ? Colors.white.withValues(alpha: 0.3)
                            : Colors.white.withValues(alpha: 0.6),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (isCurrent) ...[
                      SizedBox(height: 6.h),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2.r),
                        child: LinearProgressIndicator(
                          value: prog.progress,
                          minHeight: 3.h,
                          backgroundColor: Colors.white.withValues(alpha: 0.1),
                          valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(width: 8.w),
              Text(
                '${prog.duration.inMinutes} мин',
                style: TextStyle(fontSize: 10.sp, color: Colors.white.withValues(alpha: 0.15)),
              ),
              if (isCurrent) ...[
                SizedBox(width: 8.w),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                  decoration: BoxDecoration(
                    color: AppColors.liveBadge.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(4.r),
                  ),
                  child: Text(
                    'LIVE',
                    style: TextStyle(fontSize: 9.sp, color: Colors.white),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: EdgeInsets.all(12.w),
      child: Container(
        padding: EdgeInsets.only(top: 12.h),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
        ),
        child: Center(
          child: Text(
            'EPG данные обновляются автоматически',
            style: TextStyle(fontSize: 10.sp, color: Colors.white.withValues(alpha: 0.15)),
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final l = dt.toLocal();
    return '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
  }
}

class _CloseButton extends StatelessWidget {
  final VoidCallback onTap;
  const _CloseButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28.w,
        height: 28.w,
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8.r)),
        child: Icon(Icons.close, size: 14.sp, color: Colors.white.withValues(alpha: 0.4)),
      ),
    );
  }
}

class _SpringCurve extends Curve {
  final double damping;
  final double stiffness;
  const _SpringCurve({required this.damping, required this.stiffness});

  @override
  double transformInternal(double t) {
    final omega = (stiffness).clamp(1.0, 1000.0);
    final zeta = (damping / (2 * omega)).clamp(0.0, 1.0);
    return 1 - (1 - t) * (1 + zeta * t * omega * 0.01);
  }
}
