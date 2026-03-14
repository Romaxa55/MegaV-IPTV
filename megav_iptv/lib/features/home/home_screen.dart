import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../core/playlist/models/channel.dart';
import '../../core/playlist/models/now_playing.dart';
import '../../core/providers/providers.dart';
import '../../core/theme/app_colors.dart';
import 'widgets/cinema_row.dart';
import 'widgets/hero_section.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _focusedRow = -1; // -1 = hero
  int _focusedCol = 0;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode()..requestFocus();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _playNowPlaying(NowPlayingItem item) {
    ref.read(currentChannelProvider.notifier).state = Channel(
      id: item.channelId,
      name: item.channelName,
      logoUrl: item.logoUrl,
      categories: item.categories,
      country: item.country,
      hasEpg: true,
    );
    ref.read(currentChannelIndexProvider.notifier).state = 0;
    context.push('/player');
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(cinemaCategoriesProvider);
    final featuredAsync = ref.watch(featuredNowPlayingProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: featuredAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48.sp, color: AppColors.error),
              SizedBox(height: 16.h),
              Text(
                'Error: $error',
                style: TextStyle(fontSize: 14.sp, color: AppColors.error),
              ),
              SizedBox(height: 16.h),
              ElevatedButton(
                onPressed: () {
                  ref.invalidate(featuredNowPlayingProvider);
                  ref.invalidate(cinemaCategoriesProvider);
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (featured) {
          final categories = categoriesAsync.value ?? [];

          return KeyboardListener(
            focusNode: _focusNode,
            onKeyEvent: (event) => _handleKeyEvent(event, categories),
            child: Column(
              children: [
                HeroSection(featuredItems: featured, onPlay: _playNowPlaying),
                Expanded(
                  child: ListView.builder(
                    padding: EdgeInsets.only(bottom: 32.h),
                    itemCount: categories.length,
                    itemBuilder: (context, rowIdx) {
                      final cat = categories[rowIdx];
                      return CinemaRow(
                        title: cat.name,
                        items: cat.items,
                        isFocusedRow: _focusedRow == rowIdx,
                        focusedCol: _focusedRow == rowIdx ? _focusedCol : -1,
                        onItemTap: _playNowPlaying,
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _handleKeyEvent(KeyEvent event, List<CinemaCategory> categories) {
    if (event is! KeyDownEvent) return;

    setState(() {
      switch (event.logicalKey) {
        case LogicalKeyboardKey.arrowUp:
          if (_focusedRow <= 0) {
            _focusedRow = -1;
          } else {
            _focusedRow--;
          }
        case LogicalKeyboardKey.arrowDown:
          if (_focusedRow == -1) {
            _focusedRow = 0;
            _focusedCol = 0;
          } else if (_focusedRow < categories.length - 1) {
            _focusedRow++;
          }
        case LogicalKeyboardKey.arrowLeft:
          if (_focusedRow >= 0) {
            _focusedCol = (_focusedCol - 1).clamp(0, 999);
          }
        case LogicalKeyboardKey.arrowRight:
          if (_focusedRow >= 0 && _focusedRow < categories.length) {
            final maxCol = categories[_focusedRow].items.length - 1;
            _focusedCol = (_focusedCol + 1).clamp(0, maxCol);
          }
        case LogicalKeyboardKey.enter || LogicalKeyboardKey.select:
          if (_focusedRow == -1) {
            final feat = ref.read(featuredNowPlayingProvider).value;
            if (feat != null && feat.isNotEmpty) {
              _playNowPlaying(feat.first);
            }
          } else if (_focusedRow >= 0 && _focusedRow < categories.length) {
            final items = categories[_focusedRow].items;
            final col = _focusedCol.clamp(0, items.length - 1);
            if (items.isNotEmpty) {
              _playNowPlaying(items[col]);
            }
          }
        default:
          break;
      }
    });
  }
}
