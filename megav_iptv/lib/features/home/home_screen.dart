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
import 'widgets/home_boot_overlay.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  NowPlayingItem? _hoveredItem;
  late final FocusNode _focusNode;
  late final FocusNode _heroWatchFocusNode;

  Timer? _previewTimer;

  /// D-pad / focus fires `null` between old and new card; without debounce hero + video preview tear down for one frame → visible blink.
  Timer? _hoveredClearDebounce;
  NowPlayingItem? _previewingItem;
  bool _isPreviewPlaying = false;
  bool _isPreviewVideoReady = false;
  PlayerManager? _previewPlayer;
  StreamSubscription<PlayerState>? _previewStateSub;

  /// Интро поверх уже отрисованного UI; снимаем по факту готовности данных и прекеша.
  bool _showBootOverlay = true;
  bool _bootFadeOut = false;
  String? _bootError;
  late final TextEditingController _bootUrlController;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode(debugLabel: 'homeShell');
    _heroWatchFocusNode = FocusNode(debugLabel: 'heroWatch');
    _bootUrlController = TextEditingController(text: ref.read(baseUrlProvider));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_runHomeBootstrap());
    });
  }

  @override
  void dispose() {
    _previewTimer?.cancel();
    _hoveredClearDebounce?.cancel();
    _stopPreview();
    _focusNode.dispose();
    _heroWatchFocusNode.dispose();
    _bootUrlController.dispose();
    super.dispose();
  }

  Future<void> _runHomeBootstrap() async {
    if (!mounted) return;
    setState(() => _bootError = null);
    try {
      final categories = await ref.read(cinemaCategoriesProvider.future);
      final featured = await ref.read(featuredNowPlayingProvider.future);
      await ref.read(moviesNotifierProvider.notifier).waitForInit();
      for (final cat in categories) {
        await ref.read(categoryNotifierProvider(cat.name).notifier).waitForInit();
      }
      if (!mounted) return;

      const precachePerRow = 28;
      final allItems = <NowPlayingItem>[...featured];
      final moviesList = ref.read(moviesNotifierProvider).valueOrNull ?? [];
      allItems.addAll(moviesList.take(precachePerRow));
      for (final cat in categories) {
        final row = ref.read(categoryNotifierProvider(cat.name)).valueOrNull ?? [];
        allItems.addAll(row.take(precachePerRow));
      }

      final futures = <Future<void>>[];
      for (final item in allItems) {
        final thumb = item.thumbnailUrl ?? item.program.icon ?? item.logoUrl;
        if (thumb != null && thumb.isNotEmpty) {
          futures.add(precacheImage(NetworkImage(thumb), context).catchError((_) {}));
        }
      }
      if (futures.isNotEmpty) {
        await Future.wait(futures);
      }
      if (!mounted) return;
      setState(() => _bootFadeOut = true);
    } catch (e) {
      if (mounted) {
        setState(() => _bootError = 'Не удалось загрузить данные: $e');
      }
    }
  }

  void _onBootRetryConnect() {
    ref.read(baseUrlProvider.notifier).state = _bootUrlController.text.trim();
    ref.invalidate(featuredNowPlayingProvider);
    ref.invalidate(cinemaCategoriesProvider);
    ref.invalidate(moviesNotifierProvider);
    unawaited(_runHomeBootstrap());
  }

  void _onBootFadeOutEnded() {
    if (!mounted || !_bootFadeOut) return;
    setState(() {
      _showBootOverlay = false;
      _bootFadeOut = false;
    });
    _scheduleHeroWatchFocus();
  }

  /// После снятия ExcludeFocus autofocus у «Смотреть» уже не сработает — явно просим фокус.
  /// Два кадра: hero может собраться на следующем frame после featured.
  void _scheduleHeroWatchFocus() {
    void request() {
      if (!mounted || _showBootOverlay) return;
      if (_heroWatchFocusNode.context == null) return;
      _heroWatchFocusNode.requestFocus();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      request();
      WidgetsBinding.instance.addPostFrameCallback((_) => request());
    });
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
    } else {
      _hoveredClearDebounce = Timer(const Duration(milliseconds: 200), () {
        if (!mounted) return;
        setState(() => _hoveredItem = null);
        _stopPreview();
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
    ref.listen<AsyncValue<List<NowPlayingItem>>>(featuredNowPlayingProvider, (previous, next) {
      if (_showBootOverlay) return;
      if (!next.hasValue) return;
      final list = next.valueOrNull;
      if (list == null || list.isEmpty) return;
      final prevList = previous?.valueOrNull;
      if (prevList != null && prevList.isNotEmpty) return;
      _scheduleHeroWatchFocus();
    });

    final categoriesAsync = ref.watch(cinemaCategoriesProvider);
    final featuredAsync = ref.watch(featuredNowPlayingProvider);
    final moviesAsync = ref.watch(moviesNotifierProvider);
    final movies = moviesAsync.value ?? [];

    final featured = featuredAsync.valueOrNull ?? [];
    final baseCats = categoriesAsync.valueOrNull ?? [];
    final categories = [
      if (movies.isNotEmpty) const CinemaCategory(id: 'live-movies', name: 'Фильмы в эфире'),
      ...baseCats,
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          ExcludeFocus(
            excluding: _showBootOverlay,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final screenH = constraints.maxHeight;
                final heroHeight = screenH * 0.42;

                return Focus(
                  focusNode: _focusNode,
                  canRequestFocus: false,
                  onKeyEvent: (node, event) {
                    if (event is! KeyDownEvent) return KeyEventResult.ignored;
                    if (event.logicalKey == LogicalKeyboardKey.escape ||
                        event.logicalKey == LogicalKeyboardKey.goBack) {
                      if (_isPreviewPlaying) {
                        _stopPreview();
                        return KeyEventResult.handled;
                      }
                    }
                    return KeyEventResult.ignored;
                  },
                  child: Stack(
                    children: [
                      Positioned(
                        top: heroHeight,
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: ListView.builder(
                          clipBehavior: Clip.none,
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
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        height: heroHeight,
                        child: HeroSection(
                          featuredItems: featured,
                          overrideItem: _hoveredItem,
                          watchFocusNode: _heroWatchFocusNode,
                          onPlay: _playNowPlaying,
                          videoWidget: _isPreviewVideoReady && _previewPlayer?.activeEngine != null
                              ? _previewPlayer!.activeEngine!.buildVideoWidget(fit: BoxFit.cover)
                              : null,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          if (_showBootOverlay)
            Positioned.fill(
              child: AnimatedOpacity(
                opacity: _bootFadeOut ? 0 : 1,
                duration: const Duration(milliseconds: 420),
                curve: Curves.easeOutCubic,
                onEnd: _onBootFadeOutEnded,
                child: HomeBootOverlay(
                  showError: _bootError != null,
                  errorMessage: _bootError,
                  urlController: _bootUrlController,
                  onRetry: _onBootRetryConnect,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
