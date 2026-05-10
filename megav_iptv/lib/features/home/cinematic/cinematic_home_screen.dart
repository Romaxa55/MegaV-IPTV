import 'dart:async';

import 'package:flutter/material.dart' hide Chip;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../core/perf/perf_safe_widgets.dart';
import '../../../core/player/player_engine.dart';
import '../../../core/player/player_manager.dart';
import '../../../core/playlist/models/channel.dart';
import '../../../core/playlist/models/now_playing.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/ui/atoms/atoms.dart';
import '../../detail/providers/detail_arguments.dart';
import '../widgets/_grid_tokens.dart';
import '../widgets/cinema_row.dart';
import '../widgets/home_boot_overlay.dart';
import 'cinematic_genre_tabs_bar.dart';
import 'cinematic_hero_content.dart';
import 'cinematic_live_strip.dart';
import 'cinematic_remote_hint_footer.dart';

/// Cinematic home screen — full-bleed JSX-faithful layout with complete
/// backend integration mirroring legacy [HomeScreen].
///
/// Data flow is identical to [HomeScreen]:
///   - [featuredNowPlayingProvider] → hero + backdrop + carousel.
///   - [moviesNotifierProvider] → "Фильмы в эфире" row.
///   - [cinemaCategoriesProvider] + [categoryNotifierProvider] → genre rows.
///   - [apiClientProvider] → stream URL for preview player.
///   - [baseUrlProvider] → retry / URL prompt in boot overlay.
///
/// Visual design: home-cinematic.jsx (.kiro/design/megav-iptv-handoff/).
///
/// Keys preserved for smoke tests:
///   cinematic-home-root, cinematic-genre-tabs, cinematic-hero,
///   cinematic-live-strip, cinematic-remote-hint.
class CinematicHomeScreen extends ConsumerStatefulWidget {
  const CinematicHomeScreen({super.key});

  @override
  ConsumerState<CinematicHomeScreen> createState() => _CinematicHomeScreenState();
}

class _CinematicHomeScreenState extends ConsumerState<CinematicHomeScreen> {
  // ── Focus ──────────────────────────────────────────────────────────────────
  late final FocusNode _focusNode;
  late final FocusNode _heroWatchFocusNode;

  // ── Hero carousel (mirrors HeroSection._carouselTimer in legacy) ───────────
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

  // ── Genre tabs state ───────────────────────────────────────────────────────
  int _activeGenreTab = 0;

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_runHomeBootstrap());
    });
  }

  @override
  void dispose() {
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
  // Carousel (mirrors HeroSection._restartCarousel / _carouselTimer)
  // ──────────────────────────────────────────────────────────────────────────

  void _restartCarousel(List<NowPlayingItem> featured) {
    _carouselTimer?.cancel();
    _carouselTimer = null;
    // Carousel pauses when override (hovered item) is active or when the
    // "Смотреть" button has focus — same contract as legacy HeroSection.
    if (_hoveredItem != null) return;
    if (featured.length < 2) return;
    _carouselTimer = Timer.periodic(_carouselInterval, (_) {
      if (!mounted || _hoveredItem != null || _isWatchFocused) return;
      final list = ref.read(featuredNowPlayingProvider).valueOrNull ?? [];
      if (list.isEmpty) return;
      setState(() => _carouselIndex = (_carouselIndex + 1) % list.length);
    });
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Bootstrap (mirrored from HomeScreen._runHomeBootstrap)
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

      // Start hero carousel now that data is ready.
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

  // ──────────────────────────────────────────────────────────────────────────
  // Hover / preview (mirrored from HomeScreen)
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
      // Pause carousel while hovering a rail card.
      _carouselTimer?.cancel();
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
        // Resume carousel when hover clears.
        final featured = ref.read(featuredNowPlayingProvider).valueOrNull ?? [];
        _restartCarousel(featured);
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
    // Mirrors legacy: prepend "Фильмы в эфире" when movies row has data.
    final categories = [
      if (movies.isNotEmpty) const CinemaCategory(id: 'live-movies', name: 'Фильмы в эфире'),
      ...baseCats,
    ];

    // Genre tab labels from real backend categories.
    final tabLabels = ['Все', ...baseCats.map((c) => c.name).take(6)];

    // Hero item: hovered card takes priority, otherwise carousel through featured.
    final safeCarousel = featured.isEmpty ? 0 : _carouselIndex % featured.length;
    final heroItem = _hoveredItem ?? (featured.isNotEmpty ? featured[safeCarousel] : null);

    // Backdrop image for hero.
    final backdropUrl = heroItem != null ? (heroItem.thumbnailUrl ?? heroItem.program?.icon ?? heroItem.logoUrl) : null;
    final backdropImage = backdropUrl != null && backdropUrl.isNotEmpty
        ? NetworkImage(backdropUrl) as ImageProvider
        : null;

    // Live strip data driven by current hero item program.
    final heroProg = heroItem?.program;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          ExcludeFocus(
            excluding: _showBootOverlay,
            child: Focus(
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
              child: SizedBox.expand(
                key: const Key('cinematic-home-root'),
                child: ListView(
                  cacheExtent: 1500,
                  addAutomaticKeepAlives: true,
                  addRepaintBoundaries: true,
                  clipBehavior: Clip.none,
                  padding: EdgeInsets.zero,
                  children: [
                    // ── Full-bleed hero block ─────────────────────────────
                    _HeroBlock(
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

                    // ── Genre tabs (real labels from cinemaCategoriesProvider) ──
                    CinematicGenreTabsBar(
                      labels: tabLabels,
                      activeIndex: _activeGenreTab.clamp(0, tabLabels.length - 1),
                      onTabChanged: (i) => setState(() => _activeGenreTab = i),
                    ),

                    // ── Live strip — driven by current hero item EPG ────────
                    CinematicLiveStrip(
                      currentTitle: heroProg?.title ?? heroItem?.channelName,
                      nextLabel: heroProg != null ? 'ещё ${heroProg.remaining.inMinutes} мин' : null,
                      progress: heroProg?.progress ?? 0.0,
                    ),

                    // ── Category rows — same logic as legacy HomeScreen ──────
                    // Each CategoryRowWrapper self-subscribes to its own provider
                    // (moviesNotifierProvider or categoryNotifierProvider(cat.name))
                    // and handles loading/error/pagination internally.
                    ...categories.map(
                      (cat) => Padding(
                        padding: EdgeInsets.only(bottom: GridTokens.rowVerticalGapDp.h),
                        child: CategoryRowWrapper(
                          key: ValueKey('cinematic-row-${cat.id}'),
                          category: cat,
                          onItemTap: _playNowPlaying,
                          onItemFocus: _onHoveredItemChanged,
                        ),
                      ),
                    ),

                    // ── Remote hint footer ─────────────────────────────────
                    const SizedBox(height: 24),
                    const CinematicRemoteHintFooter(),
                    const SizedBox(height: 16),
                  ],
                ),
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

// ─────────────────────────────────────────────────────────────────────────────
// _HeroBlock — full-bleed cinematic hero with backdrop + gradient + content.
// Extracted to stay within 600-line limit for cinematic_home_screen.dart.
// ─────────────────────────────────────────────────────────────────────────────

class _HeroBlock extends StatelessWidget {
  const _HeroBlock({
    required this.backdropImage,
    required this.heroItem,
    required this.heroWatchFocusNode,
    required this.isPreviewVideoReady,
    required this.previewPlayer,
    required this.clockTime,
    required this.onWatch,
    required this.onEpg,
    required this.onFavourite,
    required this.onWatchFocusChanged,
  });

  final ImageProvider? backdropImage;
  final NowPlayingItem? heroItem;
  final FocusNode heroWatchFocusNode;
  final bool isPreviewVideoReady;
  final PlayerManager? previewPlayer;
  final String clockTime;
  final VoidCallback? onWatch;
  final VoidCallback? onEpg;
  final VoidCallback onFavourite;

  /// Called when the "Смотреть" button gains / loses focus — used to pause
  /// the carousel while the user is focused on the CTA (mirrors legacy
  /// HeroSection._isWatchFocused guard).
  final ValueChanged<bool> onWatchFocusChanged;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.activePalette;

    return SizedBox(
      key: const Key('cinematic-hero'),
      height: 620,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Layer 0: blurred backdrop / preview video.
          if (isPreviewVideoReady && previewPlayer?.activeEngine != null)
            Positioned.fill(child: previewPlayer!.activeEngine!.buildVideoWidget(fit: BoxFit.cover))
          else
            SafeBackdrop(imageProvider: backdropImage, fallbackBackground: palette.background, blurSigma: 40),

          // Layer 1: combined vignette + bottom-shade gradient.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.0, 0.35, 0.7, 1.0],
                  colors: [
                    Colors.black.withValues(alpha: 0.15),
                    Colors.black.withValues(alpha: 0.30),
                    Colors.black.withValues(alpha: 0.60),
                    Colors.black.withValues(alpha: 0.85),
                  ],
                ),
              ),
            ),
          ),

          // Layer 2: film grain (static layer, Req 9.4).
          const Positioned.fill(
            child: IgnorePointer(child: SafeFilmGrain(opacity: 0.06, child: SizedBox.expand())),
          ),

          // Layer 3: header row (Brand + Spacer + StatusBar).
          Positioned(
            top: 0,
            left: 56,
            right: 56,
            child: Padding(
              padding: const EdgeInsets.only(top: 24),
              child: Row(
                children: [
                  const Brand(size: 36),
                  const Spacer(),
                  StatusBar(time: clockTime),
                ],
              ),
            ),
          ),

          // Layer 4: hero foreground content.
          if (heroItem != null)
            CinematicHeroContent(
              item: heroItem!,
              watchFocusNode: heroWatchFocusNode,
              onWatch: onWatch ?? () {},
              onEpg: onEpg ?? () {},
              onFavourite: onFavourite,
              onWatchFocusChanged: onWatchFocusChanged,
            )
          else
            const Positioned(
              left: 56,
              right: 56,
              bottom: 40,
              child: SizedBox(height: 4, child: LinearProgressIndicator()),
            ),
        ],
      ),
    );
  }
}
