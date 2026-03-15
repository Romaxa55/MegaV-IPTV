import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../core/player/player_manager.dart';
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
  NowPlayingItem? _hoveredItem;
  late final FocusNode _focusNode;

  Timer? _previewTimer;
  NowPlayingItem? _previewingItem;
  bool _isPreviewPlaying = false;
  PlayerManager? _previewPlayer;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode()..requestFocus();
  }

  @override
  void dispose() {
    _previewTimer?.cancel();
    _stopPreview();
    _focusNode.dispose();
    super.dispose();
  }

  void _onHoveredItemChanged(NowPlayingItem? item) {
    _previewTimer?.cancel();
    if (item == null || item.channelId != _hoveredItem?.channelId) {
      _stopPreview();
    }
    setState(() => _hoveredItem = item);
    if (item != null) {
      _previewTimer = Timer(const Duration(milliseconds: 2000), () {
        if (mounted && _hoveredItem?.channelId == item.channelId) {
          _startPreview(item);
        }
      });
    }
  }

  Future<void> _startPreview(NowPlayingItem item) async {
    final api = ref.read(apiClientProvider);
    final streamUrl = await api.getBestStreamUrl(item.channelId);
    if (streamUrl == null || !mounted) return;
    if (_hoveredItem?.channelId != item.channelId) return;

    _previewPlayer ??= ref.read(playerManagerProvider);
    if (!_previewPlayer!.isInitialized) {
      await _previewPlayer!.initialize();
    }
    await _previewPlayer!.playChannel(streamUrl, channelId: item.channelId.toString());
    if (mounted) {
      setState(() {
        _previewingItem = item;
        _isPreviewPlaying = true;
      });
    }
  }

  void _stopPreview() {
    if (_isPreviewPlaying) {
      _previewPlayer?.stop();
      setState(() {
        _isPreviewPlaying = false;
        _previewingItem = null;
      });
    }
  }

  void _playNowPlaying(NowPlayingItem item) {
    _previewTimer?.cancel();
    if (_isPreviewPlaying && _previewingItem?.channelId == item.channelId) {
      ref.read(currentChannelProvider.notifier).state = Channel(
        id: item.channelId,
        name: item.channelName,
        logoUrl: item.logoUrl,
        groupTitle: item.groupTitle,
        hasEpg: true,
      );
      ref.read(currentChannelIndexProvider.notifier).state = 0;
      setState(() => _isPreviewPlaying = false);
      context.push('/player');
      return;
    }
    _stopPreview();
    ref.read(currentChannelProvider.notifier).state = Channel(
      id: item.channelId,
      name: item.channelName,
      logoUrl: item.logoUrl,
      groupTitle: item.groupTitle,
      hasEpg: true,
    );
    ref.read(currentChannelIndexProvider.notifier).state = 0;
    context.push('/player');
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(cinemaCategoriesProvider);
    final featuredAsync = ref.watch(featuredNowPlayingProvider);
    final moviesAsync = ref.watch(moviesNotifierProvider);
    final movies = moviesAsync.value ?? [];

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
          final baseCats = categoriesAsync.value ?? [];
          final categories = [
            if (movies.isNotEmpty) CinemaCategory(id: 'live-movies', name: '🔴  Фильмы в эфире', items: movies),
            ...baseCats,
          ];

          return LayoutBuilder(
            builder: (context, constraints) {
              final screenH = constraints.maxHeight;
              final heroHeight = screenH * 0.40;
              final cardsHeight = screenH - heroHeight;
              final rowHeight = cardsHeight / 2;

              return KeyboardListener(
                focusNode: _focusNode,
                onKeyEvent: (event) => _handleKeyEvent(event, categories),
                child: Column(
                  children: [
                    SizedBox(
                      height: heroHeight,
                      child: HeroSection(
                        featuredItems: featured,
                        overrideItem: _hoveredItem,
                        onPlay: _playNowPlaying,
                        videoWidget: _isPreviewPlaying && _previewPlayer?.mediaKitEngine != null
                            ? _previewPlayer!.mediaKitEngine!.buildVideoWidget(fit: BoxFit.cover)
                            : null,
                      ),
                    ),
                    SizedBox(
                      height: cardsHeight,
                      child: ListView.builder(
                        padding: EdgeInsets.zero,
                        itemCount: categories.length,
                        itemBuilder: (context, rowIdx) {
                          final cat = categories[rowIdx];
                          final isMoviesRow = cat.id == 'live-movies';
                          return CinemaRow(
                            title: cat.name,
                            items: cat.items,
                            isFocusedRow: _focusedRow == rowIdx,
                            focusedCol: _focusedRow == rowIdx ? _focusedCol : -1,
                            availableHeight: rowHeight,
                            onLoadMore: isMoviesRow ? () => ref.read(moviesNotifierProvider.notifier).loadMore() : null,
                            wrapAround: isMoviesRow,
                            onItemTap: _playNowPlaying,
                            onItemFocus: (item) => _onHoveredItemChanged(item),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  NowPlayingItem? _resolveHoveredItem(List<CinemaCategory> categories) {
    if (_focusedRow < 0 || _focusedRow >= categories.length) return null;
    final items = categories[_focusedRow].items;
    if (items.isEmpty) return null;
    final col = _focusedCol.clamp(0, items.length - 1);
    return items[col];
  }

  void _handleKeyEvent(KeyEvent event, List<CinemaCategory> categories) {
    if (event is! KeyDownEvent) return;

    if (event.logicalKey == LogicalKeyboardKey.escape || event.logicalKey == LogicalKeyboardKey.goBack) {
      if (_isPreviewPlaying) {
        _stopPreview();
        return;
      }
      if (_focusedRow >= 0) {
        setState(() {
          _focusedRow = -1;
          _onHoveredItemChanged(null);
        });
        return;
      }
    }

    setState(() {
      switch (event.logicalKey) {
        case LogicalKeyboardKey.arrowUp:
          if (_focusedRow <= 0) {
            _focusedRow = -1;
            _onHoveredItemChanged(null);
          } else {
            _focusedRow--;
            _onHoveredItemChanged(_resolveHoveredItem(categories));
          }
        case LogicalKeyboardKey.arrowDown:
          if (_focusedRow == -1) {
            _focusedRow = 0;
            _focusedCol = 0;
          } else if (_focusedRow < categories.length - 1) {
            _focusedRow++;
          }
          _onHoveredItemChanged(_resolveHoveredItem(categories));
        case LogicalKeyboardKey.arrowLeft:
          if (_focusedRow >= 0 && _focusedRow < categories.length) {
            if (_focusedCol <= 0) {
              _focusedCol = categories[_focusedRow].items.length - 1;
            } else {
              _focusedCol--;
            }
            _onHoveredItemChanged(_resolveHoveredItem(categories));
          }
        case LogicalKeyboardKey.arrowRight:
          if (_focusedRow >= 0 && _focusedRow < categories.length) {
            final cat = categories[_focusedRow];
            final maxCol = cat.items.length - 1;
            if (_focusedCol >= maxCol) {
              if (cat.id == 'live-movies') {
                final notifier = ref.read(moviesNotifierProvider.notifier);
                if (notifier.hasMore) {
                  _focusedCol++;
                } else {
                  _focusedCol = 0;
                }
              } else {
                _focusedCol = 0;
              }
            } else {
              _focusedCol++;
            }
            _onHoveredItemChanged(_resolveHoveredItem(categories));
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
