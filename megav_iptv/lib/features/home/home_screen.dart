import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../core/player/player_engine.dart';
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
  NowPlayingItem? _hoveredItem;
  late final FocusNode _focusNode;

  Timer? _previewTimer;

  /// D-pad / focus fires `null` between old and new card; without debounce hero + video preview tear down for one frame → visible blink.
  Timer? _hoveredClearDebounce;
  NowPlayingItem? _previewingItem;
  bool _isPreviewPlaying = false;
  bool _isPreviewVideoReady = false;
  PlayerManager? _previewPlayer;
  StreamSubscription<PlayerState>? _previewStateSub;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode()..requestFocus();
  }

  @override
  void dispose() {
    _previewTimer?.cancel();
    _hoveredClearDebounce?.cancel();
    _stopPreview();
    _focusNode.dispose();
    super.dispose();
  }

  void _onHoveredItemChanged(NowPlayingItem? item) {
    _previewTimer?.cancel();
    _hoveredClearDebounce?.cancel();

    if (item != null) {
      if (item.channelId != _hoveredItem?.channelId) {
        _stopPreview();
      }
      if (mounted) {
        final thumb = item.thumbnailUrl ?? item.program.icon ?? item.logoUrl;
        if (thumb != null && thumb.isNotEmpty) {
          unawaited(precacheImage(NetworkImage(thumb), context));
        }
      }
      setState(() => _hoveredItem = item);
      _previewTimer = Timer(const Duration(milliseconds: 7000), () {
        if (mounted && _hoveredItem?.channelId == item.channelId) {
          _startPreview(item);
        }
      });
      return;
    }

    // Lost focus (often briefly between two cards). Clear hero/preview only if focus doesn't land on another card soon.
    _hoveredClearDebounce = Timer(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      setState(() => _hoveredItem = null);
      _stopPreview();
    });
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

    _previewStateSub?.cancel();
    _previewStateSub = _previewPlayer!.stateStream.listen((state) {
      if (!mounted) return;
      if (state == PlayerState.playing && !_isPreviewVideoReady) {
        setState(() => _isPreviewVideoReady = true);
      }
    });

    await _previewPlayer!.playChannel(streamUrl, channelId: item.channelId.toString());
    if (mounted) {
      setState(() {
        _previewingItem = item;
        _isPreviewPlaying = true;
      });
    }
  }

  void _stopPreview() {
    _previewStateSub?.cancel();
    _previewStateSub = null;
    if (_isPreviewPlaying) {
      _previewPlayer?.stop();
      setState(() {
        _isPreviewPlaying = false;
        _isPreviewVideoReady = false;
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
            if (movies.isNotEmpty) const CinemaCategory(id: 'live-movies', name: '🔴  Фильмы в эфире'),
            ...baseCats,
          ];

          return LayoutBuilder(
            builder: (context, constraints) {
              final screenH = constraints.maxHeight;
              final heroHeight = screenH * 0.42;
              final cardsHeight = screenH - heroHeight;

              return Focus(
                focusNode: _focusNode,
                autofocus: true,
                onKeyEvent: (node, event) {
                  if (event is! KeyDownEvent) return KeyEventResult.ignored;
                  if (event.logicalKey == LogicalKeyboardKey.escape || event.logicalKey == LogicalKeyboardKey.goBack) {
                    if (_isPreviewPlaying) {
                      _stopPreview();
                      return KeyEventResult.handled;
                    }
                  }
                  return KeyEventResult.ignored;
                },
                child: Column(
                  children: [
                    SizedBox(
                      height: heroHeight,
                      child: HeroSection(
                        featuredItems: featured,
                        overrideItem: _hoveredItem,
                        onPlay: _playNowPlaying,
                        videoWidget: _isPreviewVideoReady && _previewPlayer?.activeEngine != null
                            ? _previewPlayer!.activeEngine!.buildVideoWidget(fit: BoxFit.cover)
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
                          return Padding(
                            padding: EdgeInsets.only(bottom: 20.h),
                            child: CategoryRowWrapper(
                              category: cat,
                              onItemTap: _playNowPlaying,
                              onItemFocus: _onHoveredItemChanged,
                            ),
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
}
