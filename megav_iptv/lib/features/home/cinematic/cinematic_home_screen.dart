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
import '../widgets/home_boot_overlay.dart';
import 'cinematic_dual_rail.dart';
import 'cinematic_genre_tabs_bar.dart';
import 'cinematic_hero_content.dart';
import 'cinematic_live_strip.dart';
import 'cinematic_rail.dart';
import 'cinematic_remote_hint_footer.dart';
import 'cinematic_section_title.dart';

/// Cinematic home screen — full-bleed JSX-faithful layout with complete
/// backend integration ported from legacy [HomeScreen].
///
/// Visual design: home-cinematic.jsx (.kiro/design/megav-iptv-handoff/).
/// Functional parity: all providers, preview player, boot overlay, retry,
/// focus management, navigation — mirroring home_screen.dart.
///
/// Keys preserved for smoke test:
///   cinematic-home-root, cinematic-genre-tabs, cinematic-hero,
///   cinematic-dual-rail-landscape, cinematic-live-strip,
///   cinematic-dual-rail-portrait, cinematic-remote-hint.
class CinematicHomeScreen extends ConsumerStatefulWidget {
  const CinematicHomeScreen({super.key});

  @override
  ConsumerState<CinematicHomeScreen> createState() => _CinematicHomeScreenState();
}

class _CinematicHomeScreenState extends ConsumerState<CinematicHomeScreen> {
  // ── Focus ──────────────────────────────────────────────────────────────────
  late final FocusNode _focusNode;
  late final FocusNode _heroWatchFocusNode;

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
    _clockTimer.cancel();
    _stopPreview();
    _focusNode.dispose();
    _heroWatchFocusNode.dispose();
    _bootUrlController.dispose();
    super.dispose();
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Bootstrap (mirrored from HomeScreen._runHomeBootstrap)
  // ──────────────────────────────────────────────────────────────────────────

  Future<void> _runHomeBootstrap() async {
    if (!mounted) return;
    setState(() => _bootError = null);
    try {
      final categories = await ref.read(cinemaCategoriesProvider.future);
      await ref.read(featuredNowPlayingProvider.future);
      await ref.read(moviesNotifierProvider.notifier).waitForInit();
      for (final cat in categories) {
        await ref.read(categoryNotifierProvider(cat.name).notifier).waitForInit();
      }
      if (!mounted) return;

      const precachePerRow = 28;
      final featured = ref.read(featuredNowPlayingProvider).valueOrNull ?? [];
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
  // Rail item helpers
  // ──────────────────────────────────────────────────────────────────────────

  CinematicRailItem _toRailItem(NowPlayingItem item) {
    final thumb = item.thumbnailUrl ?? item.program?.icon ?? item.logoUrl;
    return CinematicRailItem(
      id: item.channelId.toString(),
      title: item.program?.title.isNotEmpty == true ? item.program!.title : item.channelName,
      imageProvider: thumb != null && thumb.isNotEmpty ? NetworkImage(thumb) : null,
    );
  }

  void _onRailItemTap(CinematicRailItem rail, List<NowPlayingItem> source) {
    final match = source.where((i) => i.channelId.toString() == rail.id).firstOrNull;
    if (match != null) _playNowPlaying(match);
  }

  void _onRailItemFocus(CinematicRailItem rail, List<NowPlayingItem> source) {
    final match = source.where((i) => i.channelId.toString() == rail.id).firstOrNull;
    _onHoveredItemChanged(match);
  }

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
    final categories = categoriesAsync.valueOrNull ?? [];

    // Hero item: hovered (from rail) takes priority, else first featured.
    final heroItem = _hoveredItem ?? featured.firstOrNull;

    // Backdrop image
    final backdropUrl = heroItem != null ? (heroItem.thumbnailUrl ?? heroItem.program?.icon ?? heroItem.logoUrl) : null;
    final backdropImage = backdropUrl != null && backdropUrl.isNotEmpty
        ? NetworkImage(backdropUrl) as ImageProvider
        : null;

    // Continue rail: first 5 featured (no true "continue" provider yet).
    final continueItems = featured.take(5).map(_toRailItem).toList();
    final continueSource = featured.take(5).toList();

    // Now-on-air rail: next 6 from featured, or wrap around.
    final nowOnAirSource = featured.length > 5 ? featured.skip(5).take(6).toList() : featured.take(6).toList();
    final nowOnAirItems = nowOnAirSource.map(_toRailItem).toList();

    // Genre tab labels from categories.
    final tabLabels = ['Все', ...categories.map((c) => c.name).take(6)];

    // Live strip data from hero.
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
                    ),

                    // ── Genre tabs ────────────────────────────────────────
                    CinematicGenreTabsBar(
                      labels: tabLabels,
                      activeIndex: _activeGenreTab.clamp(0, tabLabels.length - 1),
                      onTabChanged: (i) => setState(() => _activeGenreTab = i),
                    ),

                    // ── Continue watching rail ─────────────────────────────
                    if (continueItems.isNotEmpty) ...[
                      Padding(
                        padding: EdgeInsets.fromLTRB(32.w, 32.h, 32.w, 12.h),
                        child: CinematicSectionTitle(
                          label: 'Продолжить',
                          emphasis: 'смотреть',
                          count: continueItems.length,
                        ),
                      ),
                      CinematicDualRail.landscape(
                        items: continueItems,
                        onItemTap: (r) => _onRailItemTap(r, continueSource),
                        onItemFocus: (r) => _onRailItemFocus(r, continueSource),
                      ),
                    ],

                    // ── Live strip separator ───────────────────────────────
                    CinematicLiveStrip(
                      currentTitle: heroProg?.title ?? heroItem?.channelName,
                      nextLabel: heroProg != null ? 'ещё ${heroProg.remaining.inMinutes} мин' : null,
                      progress: heroProg?.progress ?? 0.0,
                    ),

                    // ── Now-on-air rail ────────────────────────────────────
                    if (nowOnAirItems.isNotEmpty) ...[
                      Padding(
                        padding: EdgeInsets.fromLTRB(32.w, 16.h, 32.w, 12.h),
                        child: CinematicSectionTitle(label: 'Сейчас в эфире', count: nowOnAirItems.length),
                      ),
                      CinematicDualRail.portrait(
                        items: nowOnAirItems,
                        onItemTap: (r) => _onRailItemTap(r, nowOnAirSource),
                        onItemFocus: (r) => _onRailItemFocus(r, nowOnAirSource),
                      ),
                    ],

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
// Extracted to stay within 600-line limit.
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
