import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/playlist/models/channel.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/app_colors.dart';

class SimilarOverlay extends ConsumerStatefulWidget {
  final Channel currentChannel;
  final void Function(Channel) onSelectChannel;
  final VoidCallback onClose;

  const SimilarOverlay({super.key, required this.currentChannel, required this.onSelectChannel, required this.onClose});

  @override
  ConsumerState<SimilarOverlay> createState() => _SimilarOverlayState();
}

class _SimilarOverlayState extends ConsumerState<SimilarOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _slideController;
  late final Animation<Offset> _slideAnimation;
  List<Channel> _similar = [];

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic));
    _slideController.forward();
    _loadSimilar();
  }

  Future<void> _loadSimilar() async {
    final group = widget.currentChannel.groupTitle;
    if (group == null) return;
    try {
      final api = ref.read(apiClientProvider);
      final channels = await api.getChannels(group: group, limit: 30);
      if (mounted) {
        setState(() {
          _similar = channels.where((c) => c.id != widget.currentChannel.id).toList();
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final similar = _similar;

    return SlideTransition(
      position: _slideAnimation,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ClipRRect(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              constraints: BoxConstraints(maxHeight: 0.50.sh),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.8),
                border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildHeader(),
                  _buildHint(),
                  if (similar.isEmpty) _buildEmpty() else _buildGrid(similar),
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
              Icon(Icons.auto_awesome, size: 16.sp, color: AppColors.soonBadge),
              SizedBox(width: 8.w),
              Text(
                'Похожее по жанру',
                style: TextStyle(fontSize: 14.sp, color: Colors.white),
              ),
              SizedBox(width: 8.w),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6.r),
                ),
                child: Text(
                  widget.currentChannel.groupTitle ?? 'TV',
                  style: TextStyle(fontSize: 11.sp, color: AppColors.primaryLight),
                ),
              ),
              const Spacer(),
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
          SizedBox(height: 12.h),
        ],
      ),
    );
  }

  Widget _buildHint() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: Container(
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.soonBadge.withValues(alpha: 0.1), AppColors.primary.withValues(alpha: 0.1)],
          ),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: AppColors.soonBadge.withValues(alpha: 0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.bolt, size: 16.sp, color: AppColors.soonBadge),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    'Каналы в категории "${widget.currentChannel.groupTitle ?? 'TV'}"',
                    style: TextStyle(fontSize: 12.sp, color: Colors.white.withValues(alpha: 0.4)),
                  ),
                ),
              ],
            ),
            Padding(
              padding: EdgeInsets.only(left: 24.w, top: 4.h),
              child: Text(
                'AI-рекомендации скоро — подключим бекенд',
                style: TextStyle(fontSize: 10.sp, color: AppColors.soonBadge.withValues(alpha: 0.3)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 24.h),
      child: Column(
        children: [
          Icon(Icons.movie_outlined, size: 32.sp, color: Colors.white.withValues(alpha: 0.1)),
          SizedBox(height: 8.h),
          Text(
            'Нет похожих каналов',
            style: TextStyle(fontSize: 13.sp, color: Colors.white.withValues(alpha: 0.2)),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid(List<Channel> similar) {
    return SizedBox(
      height: 140.h,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
        itemCount: similar.length,
        itemBuilder: (context, index) {
          final ch = similar[index];
          return GestureDetector(
            onTap: () {
              widget.onSelectChannel(ch);
              widget.onClose();
            },
            child: Container(
              width: 160.w,
              margin: EdgeInsets.only(right: 12.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12.r),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Container(
                            color: Colors.white.withValues(alpha: 0.1),
                            child: ch.logoUrl != null && ch.logoUrl!.isNotEmpty
                                ? Image.network(ch.logoUrl!, fit: BoxFit.cover, errorBuilder: (ctx, err, st) => _ph())
                                : _ph(),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    ch.name,
                    style: TextStyle(fontSize: 12.sp, color: Colors.white),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    ch.groupTitle ?? '',
                    style: TextStyle(fontSize: 10.sp, color: Colors.white.withValues(alpha: 0.25)),
                    maxLines: 1,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _ph() => Center(
    child: Icon(Icons.tv, size: 20.sp, color: Colors.white.withValues(alpha: 0.2)),
  );

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
            'Скоро: AI-рекомендации на базе EPG',
            style: TextStyle(fontSize: 10.sp, color: Colors.white.withValues(alpha: 0.1)),
          ),
        ),
      ),
    );
  }
}
