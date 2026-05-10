import 'dart:async';

import 'package:flutter/material.dart' hide Chip;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../core/player/player_engine.dart';
import '../../../core/player/player_manager.dart';
import '../../../core/playlist/models/channel.dart';
import '../../../core/playlist/models/now_playing.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../detail/providers/detail_arguments.dart';
import '../widgets/_grid_tokens.dart';
import '../widgets/cinema_row.dart';
import '../widgets/home_boot_overlay.dart';
import 'cinematic_compact_hero.dart';
import 'cinematic_hero_block.dart';
import 'cinematic_remote_hint_footer.dart';

/// Cinematic home screen — full-bleed layout with complete backend integration
/// mirroring legacy [HomeScreen].
///
/// Data flow is identical to [HomeScreen]:
///   - [featuredNowPlayingProvider] → hero + backdrop + carousel.
///   - [moviesNotifierProvider] → "Фильмы в эфире" row.
///   - [cinemaCategoriesProvider] + [categoryNotifierProvider] → genre rows.
///   - [apiClientProvider] → stream URL for preview player.
///   - [baseUrlProvider] → retry / URL prompt in boot overlay.
///
/// Layout structure (mirrors legacy [HomeScreen]):
///   Stack {
///     Positioned(below hero) → ListView.builder([rails…, footer])
///     AnimatedPositioned(top) → AnimatedCrossFade(expanded↔compact hero)
///   }
///
/// TV-standard hero collapse: D-pad ↓ to first rail → hero shrinks to
/// [CinematicCompactHero] (~110px). D-pad ↑ back to hero → re-expands
/// to full 620px. Carousel pauses while collapsed.
///
/// Keys preserved for smoke tests:
///   cinematic-home-root, cinematic-hero, cinematic-remote-hint.
class CinematicHomeScreen extends ConsumerStatefulWidget {
  const CinematicHomeScreen({super.key});

  @override
  ConsumerState<CinematicHomeScreen> createState() => _CinematicHomeScreenState();
}

class _CinematicHomeScreenState extends ConsumerState<CinematicHomeScreen> {
  // ── Focus ──────────────────────────────────────────────────────────────────
  late final FocusNode _focusNode;
  late final FocusNode _heroWatchFocusNode;

  // ── Hero collapse state (TV-standard) ─────────────────────────────────────
  /// True while focus is inside the hero area; false when focus is on rails.
  bool _heroFocused = true;

  // ── Hero carousel ──────────────────────────────────────────────────────────
  static const Duration _carouselInterval = Duration(seconds: 8);
  int _carouselIndex = 0;
  Timer? _carouselTimer;
  bool _isWatchFocused = false;

  // ── Hover / preview state ──────────────────────────────────────────────────
  NowPlayingItem? _hoveredItem;
  Timer? _previewTimer;
  Timer? _hoveredClearDebounce;
  NowPlayingItem? _previewingItem;
  bool _isPreviewPlaying = false;
  bool _isPreviewVideoReady = false;
  PlayerManager? _previewPlayer;
  StreamSubscription<PlayerState>? _previewStateSub;

  // ── Boot overlay ───────────────────────────────────────────────────────────
  bool _showBootOverlay = true;
  bool _bootFadeOut = false;
  String? _bootError;
  late final TextEditingController _bootUrlController;

  // ── Clock tick for StatusBar ───────────────────────────────────────────────
  late final Timer _clockTimer;
  String _clockTime = _nowTime();

  static String _nowTime() {
    final n = DateTime.now();
    return '${n.hour.toString().padLeft(2, '0')}:${n.minute.toString().padLeft(2, '0')}';
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Lifecycle
  // ──────────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode(debugLabel: 'cinematicHomeShell');
    _heroWatchFocusNode = FocusNode(debugLabel: 'cinematicHeroWatch');
    _bootUrlController = TextEditingController(text: ref.read(baseUrlProvider));
    _clockTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() => _clockTime = _nowTime());
    });
    // Detect when focus leaves/returns to hero watch button → collapse/expand.
    _heroWatchFocusNode.addListener(_onHeroWatchFocusChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_runHomeBootstrap());
    });
  }

  @override
  void dispose() {
    _heroWatchFocusNode.removeListener(_onHeroWatchFocusChanged);
    _previewTimer?.cancel();
    _hoveredClearDebounce?.cancel();
    _carouselTimer?.cancel();
    _clockTimer.cancel();
    _stopPreview();
    _focusNode.dispose();
    _heroWatchFocusNode.dispose();
    _bootUrlController.dispose();
    super.dispose();
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Hero focus collapse / expand
  // ──────────────────────────────────────────────────────────────────────────

  void _onHeroWatchFocusChanged() {
    if (!mounted) return;
    final focused = _heroWatchFocusNode.hasFocus;
    if (focused == _heroFocused) return;
    setState(() => _heroFocused = focused);
    if (!focused) {
      // Pause carousel while hero is collapsed.
      _carouselTimer?.cancel();
      _carouselTimer = null;
    } else {
      // Resume carousel when hero re-expands.
      final featured = ref.read(featuredNowPlayingProvider).valueOrNull ?? [];
      _restartCarousel(featured);
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Carousel
  // ──────────────────────────────────────────────────────────────────────────

  void _restartCarousel(List<NowPlayingItem> featured) {
    _carouselTimer?.cancel();
    _carouselTimer = null;
    if (_hoveredItem != null) return;
    if (featured.length < 2) return;
    _carouselTimer = Timer.periodic(_carouselInterval, (_) {
      if (!mounted || _hoveredItem != null || _isWatchFocused || !_heroFocused) return;
      final list = ref.read(featuredNowPlayingProvider).valueOrNull ?? [];
      if (list.isEmpty) return;
      setState(() => _carouselIndex = (_carouselIndex + 1) % list.length);
    });
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Bootstrap
  // ──────────────────────────────────────────────────────────────────────────

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
        final thumb = item.thumbnailUrl ?? item.program?.icon ?? item.logoUrl;
        if (thumb != null && thumb.isNotEmpty) {
          futures.add(precacheImage(NetworkImage(thumb), context).catchError((_) {}));
        }
      }
      if (futures.isNotEmpty) await Future.wait(futures);
      if (!mounted) return;

      _restartCarousel(featured);
      setState(() => _bootFadeOut = true);
    } catch (e) {
      if (mounted) setState(() => _bootError = 'Не удалось загрузить данные: $e');
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

  /// Запрашивает фокус на кнопке «Смотреть» после того как boot overlay
  /// полностью скрыт.
  ///
  /// Паттерн скопирован из legacy [HomeScreen._scheduleHeroWatchFocus].
  /// Дополнительно: если после двух кадров context ещё null — повторяем
  /// запрос через [WidgetsBinding.endOfFrame], чтобы перехватить кейс
  /// когда AnimatedCrossFade ещё не завершил монтирование firstChild.
  void _scheduleHeroWatchFocus() {
    void request() {
      if (!mounted || _showBootOverlay) return;
      if (_heroWatchFocusNode.context == null) return;
      _heroWatchFocusNode.requestFocus();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      request();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        request();
        // Третий шанс — ждём полного конца кадра (endOfFrame), нужен если
        // AnimatedCrossFade всё ещё строит firstChild в этом же кадре.
        if (mounted && _heroWatchFocusNode.context == null) {
          WidgetsBinding.instance.endOfFrame.then((_) {
            if (mounted) request();
          });
        }
      });
    });
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Hover / preview
  // ──────────────────────────────────────────────────────────────────────────

  void _onHoveredItemChanged(NowPlayingItem? item) {
    _previewTimer?.cancel();
    _hoveredClearDebounce?.cancel();

    if (item != null) {
      if (item.channelId != _hoveredItem?.channelId) _stopPreview();
      if (mounted) {
        final thumb = item.thumbnailUrl ?? item.program?.icon ?? item.logoUrl;
        if (thumb != null && thumb.isNotEmpty) {
          unawaited(precacheImage(NetworkImage(thumb), context));
        }
      }
      _carouselTimer?.cancel();
      setState(() => _hoveredItem = item);
      _previewTimer = Timer(const Duration(milliseconds: 7000), () {
        if (mounted && _hoveredItem?.channelId == item.channelId) _startPreview(item);
      });
    } else {
      _hoveredClearDebounce = Timer(const Duration(milliseconds: 200), () {
        if (!mounted) return;
        setState(() => _hoveredItem = null);
        _stopPreview();
        final featured = ref.read(featuredNowPlayingProvider).valueOrNull ?? [];
        if (_heroFocused) _restartCarousel(featured);
      });
    }
  }

  Future<void> _startPreview(NowPlayingItem item) async {
    final api = ref.read(apiClientProvider);
    final streamUrl = await api.getBestStreamUrl(item.channelId);
    if (streamUrl == null || !mounted) return;
    if (_hoveredItem?.channelId != item.channelId) return;

    _previewPlayer ??= ref.read(playerManagerProvider);
    if (!_previewPlayer!.isInitialized) await _previewPlayer!.initialize();

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
      ref.read(currentChannelProvider.notifier).state = _channelFrom(item);
      ref.read(currentChannelIndexProvider.notifier).state = 0;
      setState(() => _isPreviewPlaying = false);
      context.push(
        '/channel/${item.channelId}',
        extra: DetailArgs(channelId: item.channelId, preloadedNowPlaying: item),
      );
      return;
    }
    _stopPreview();
    ref.read(currentChannelProvider.notifier).state = _channelFrom(item);
    ref.read(currentChannelIndexProvider.notifier).state = 0;
    context.push(
      '/channel/${item.channelId}',
      extra: DetailArgs(channelId: item.channelId, preloadedNowPlaying: item),
    );
  }

  Channel _channelFrom(NowPlayingItem item) => Channel(
    id: item.channelId,
    name: item.channelName,
    logoUrl: item.logoUrl,
    groupTitle: item.groupTitle,
    hasEpg: true,
  );

  // ──────────────────────────────────────────────────────────────────────────
  // Build
  // ──────────────────────────────────────────────────────────────────────────

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

    final featured = ref.watch(featuredNowPlayingProvider).valueOrNull ?? [];
    final categoriesAsync = ref.watch(cinemaCategoriesProvider);
    final moviesAsync = ref.watch(moviesNotifierProvider);
    final movies = moviesAsync.value ?? [];

    final baseCats = categoriesAsync.valueOrNull ?? [];
    final categories = [
      if (movies.isNotEmpty) const CinemaCategory(id: 'live-movies', name: 'Фильмы в эфире'),
      ...baseCats,
    ];

    final safeCarousel = featured.isEmpty ? 0 : _carouselIndex % featured.length;
    final heroItem = _hoveredItem ?? (featured.isNotEmpty ? featured[safeCarousel] : null);

    final backdropUrl = heroItem != null ? (heroItem.thumbnailUrl ?? heroItem.program?.icon ?? heroItem.logoUrl) : null;
    final backdropImage = backdropUrl != null && backdropUrl.isNotEmpty
        ? NetworkImage(backdropUrl) as ImageProvider
        : null;

    final collapsedH = CinematicCompactHero.kCompactHeroHeight;
    const expandedH = 620.0;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          ExcludeFocus(
            excluding: _showBootOverlay,
            child: LayoutBuilder(
              builder: (context, _) => Focus(
                key: const Key('cinematic-home-root'),
                focusNode: _focusNode,
                canRequestFocus: false,
                onKeyEvent: (_, event) {
                  if (event is! KeyDownEvent) return KeyEventResult.ignored;
                  if (event.logicalKey == LogicalKeyboardKey.escape || event.logicalKey == LogicalKeyboardKey.goBack) {
                    if (_isPreviewPlaying) {
                      _stopPreview();
                      return KeyEventResult.handled;
                    }
                  }
                  return KeyEventResult.ignored;
                },
                // FocusTraversalGroup гарантирует, что D-pad стрелки проходят
                // через hero-кнопки → rails-карточки через WidgetOrderTraversalPolicy.
                // Это тот же паттерн что в cinema_row.dart (там внутренний group
                // для горизонтального ряда). Без этого Flutter traversal не знает
                // порядка фокусируемых элементов в смешанном Stack-layout.
                child: FocusTraversalGroup(
                  policy: WidgetOrderTraversalPolicy(),
                  child: Stack(
                    children: [
                      // ── Hero — first in children so WidgetOrderTraversalPolicy
                      // visits hero-buttons BEFORE rails on Tab/D-pad ↓.
                      // Z-order: hero renders below rails (Stack paints first=bottom),
                      // but hero is Positioned(top:0, height:expandedH) and rails
                      // are Positioned(top:expandedH) so they never overlap visually.
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        height: expandedH,
                        child: FocusScope(
                          onFocusChange: (focused) {
                            // Hero re-expands as soon as ANY descendant gains
                            // focus (D-pad ↑ from rail traversal lands on
                            // whichever focusable is closest; not always the
                            // Watch button). Mirrors Watch-only listener so
                            // either path works.
                            if (focused != _heroFocused) {
                              setState(() => _heroFocused = focused);
                              if (focused) {
                                final featured = ref.read(featuredNowPlayingProvider).valueOrNull ?? const [];
                                if (featured.isNotEmpty) _restartCarousel(featured);
                              } else {
                                _carouselTimer?.cancel();
                              }
                            }
                          },
                          child: AnimatedCrossFade(
                            duration: const Duration(milliseconds: 220),
                            crossFadeState: _heroFocused ? CrossFadeState.showFirst : CrossFadeState.showSecond,
                            firstChild: CinematicHeroBlock(
                              backdropImage: backdropImage,
                              heroItem: heroItem,
                              heroWatchFocusNode: _heroWatchFocusNode,
                              isPreviewVideoReady: _isPreviewVideoReady,
                              previewPlayer: _previewPlayer,
                              clockTime: _clockTime,
                              onWatch: heroItem != null ? () => _playNowPlaying(heroItem) : null,
                              onEpg: heroItem != null
                                  ? () => context.push(
                                      '/channel/${heroItem.channelId}',
                                      extra: DetailArgs(channelId: heroItem.channelId, preloadedNowPlaying: heroItem),
                                    )
                                  : null,
                              onFavourite: () {},
                              onWatchFocusChanged: (focused) {
                                if (!mounted) return;
                                setState(() => _isWatchFocused = focused);
                              },
                            ),
                            secondChild: heroItem != null
                                ? Align(
                                    alignment: Alignment.topLeft,
                                    child: CinematicCompactHero(item: heroItem),
                                  )
                                : SizedBox(height: collapsedH),
                          ),
                        ),
                      ),

                      // ── Rails list — positioned below hero (fixed offset) ──
                      // Rails always start at expanded hero height. Hero collapse
                      // animates only via crossfade — NOT via AnimatedPositioned
                      // top change, because animating `top` reparents children
                      // every frame and breaks ScrollController attachment.
                      Positioned(
                        top: expandedH,
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: ListView.builder(
                          clipBehavior: Clip.none,
                          padding: EdgeInsets.zero,
                          // +1 for the remote hint footer slot.
                          itemCount: categories.length + 1,
                          itemBuilder: (context, rowIdx) {
                            if (rowIdx == categories.length) {
                              return const Padding(
                                padding: EdgeInsets.only(top: 8),
                                child: CinematicRemoteHintFooter(),
                              );
                            }
                            final cat = categories[rowIdx];
                            return Padding(
                              padding: EdgeInsets.only(bottom: GridTokens.rowVerticalGapDp.h),
                              child: CategoryRowWrapper(
                                key: ValueKey('cinematic-row-${cat.id}'),
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
                ), // FocusTraversalGroup
              ),
            ),
          ),

          // ── Boot overlay ────────────────────────────────────────────────
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
