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
import 'hero_tile_morph.dart';

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
    // Hero collapse/expand is driven by Focus(skipTraversal:true).onFocusChange
    // on the hero subtree (see build()) — single source of truth. We do NOT
    // listen to _heroWatchFocusNode individually any more, because that
    // listener fires when focus moves to sibling buttons ("Программа",
    // "В избранное") INSIDE the hero, falsely collapsing the hero while
    // focus is still in its subtree.
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
  // Carousel
  // ──────────────────────────────────────────────────────────────────────────

  void _restartCarousel(List<NowPlayingItem> featured) {
    _carouselTimer?.cancel();
    _carouselTimer = null;
    if (_hoveredItem != null) return;
    if (featured.length < 2) return;
    _carouselTimer = Timer.periodic(_carouselInterval, (_) {
      if (!mounted || _hoveredItem != null || !_heroFocused) return;
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
  /// скрыт. Один post-frame callback — этого достаточно: к моменту его
  /// вызова rebuild после `setState(_showBootOverlay = false)` уже
  /// произошёл, `ExcludeFocus(excluding: false)` снят, и контекст
  /// _heroWatchFocusNode гарантированно есть.
  void _scheduleHeroWatchFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _heroWatchFocusNode.requestFocus();
    });
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Hover / preview
  // ──────────────────────────────────────────────────────────────────────────

  /// Netflix-style hover behaviour:
  ///   * When user moves through rail items, do NOT swap hero immediately —
  ///     wait [_hoverSettleDelay] (≈600ms) so the hero only updates when
  ///     focus actually settles on a card. Without this the backdrop
  ///     "flickers" through every card during arrow-key sweeps.
  ///   * On settle: precache thumbnail, swap hero, start preview-player
  ///     timer 7s later.
  ///   * On focus loss (item == null): keep current backdrop briefly
  ///     (200ms debounce) to bridge the gap between cards / row transitions.
  static const Duration _hoverSettleDelay = Duration(milliseconds: 600);

  void _onHoveredItemChanged(NowPlayingItem? item) {
    // Always cancel the in-flight settle timer so the user's most recent
    // movement wins (rapid arrow-key sweep → only the last card matters).
    _hoveredClearDebounce?.cancel();
    _previewTimer?.cancel();

    if (item != null) {
      // Precache thumbnail eagerly so once it lands the AnimatedSwitcher
      // crossfade has the bitmap ready.
      if (mounted) {
        final thumb = item.thumbnailUrl ?? item.program?.icon ?? item.logoUrl;
        if (thumb != null && thumb.isNotEmpty) {
          unawaited(precacheImage(NetworkImage(thumb), context));
        }
      }
      // Settle delay: only swap hero / stop carousel after the user
      // has actually rested on this card.
      _hoveredClearDebounce = Timer(_hoverSettleDelay, () {
        if (!mounted) return;
        if (item.channelId != _hoveredItem?.channelId) _stopPreview();
        _carouselTimer?.cancel();
        setState(() => _hoveredItem = item);
        _previewTimer = Timer(const Duration(milliseconds: 7000), () {
          if (mounted && _hoveredItem?.channelId == item.channelId) _startPreview(item);
        });
      });
    } else {
      // Focus left a card — give 200ms grace before clearing hero so a
      // quick row-transition (down arrow leaving and immediately re-entering
      // a focusable) doesn't visibly reset the backdrop.
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
            child: Focus(
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
              // TV-grade directional traversal: WidgetOrderTraversalPolicy
              // traverses children in declaration order (hero first, rails
              // second). On macOS the default ReadingOrderTraversalPolicy
              // doesn't guarantee ↓ from hero hits the first rail; with this
              // wrapper the ordering is deterministic across desktop and TV.
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
                      // Hero expand/collapse: listen to focus changes in
                      // the hero subtree via Focus(skipTraversal:true) +
                      // onFocusChange. skipTraversal removes this node
                      // from the traversal chain (no arrow-trap), but
                      // onFocusChange still fires when any descendant
                      // gains/loses focus. Works whether D-pad ↑ lands
                      // on Watch button or any other focusable in hero.
                      child: Focus(
                        skipTraversal: true,
                        canRequestFocus: false,
                        onFocusChange: (focused) {
                          if (focused == _heroFocused) return;
                          setState(() => _heroFocused = focused);
                          if (focused) {
                            final featured = ref.read(featuredNowPlayingProvider).valueOrNull ?? const [];
                            if (featured.isNotEmpty) _restartCarousel(featured);
                          } else {
                            _carouselTimer?.cancel();
                          }
                        },
                        // hero-collapse-tile-morph: replace the old
                        // AnimatedCrossFade(expanded↔compact) with HeroTileMorph
                        // — single widget that morphs geometry+opacity in 300ms
                        // easeInOutCubic via one AnimationController.
                        //
                        // DESIGN NOTE (deviation from spec § 4.x):
                        // The spec design suggested mounting HeroTileMorph as the
                        // firstSlot of the first rail (hero and tile-0 as one
                        // widget). That doesn't fit the actual CinematicHomeScreen:
                        // the hero owns a full-bleed backdrop image (1920×1080)
                        // and StatusBar, which extends BEYOND any tile geometry.
                        // Forcing it inside a row-height container would clip the
                        // backdrop. Instead we keep hero as the Positioned slot
                        // (top:0, height:expandedH) and swap only the inner
                        // expanded↔compact crossfade for HeroTileMorph — the
                        // user's main pain (cross-fade flicker into black) is
                        // solved without restructuring layout.
                        //
                        // The Positioned wrapper still gives the row underneath
                        // enough vertical clearance; collapsed HeroTileMorph
                        // (cardHeightDp = 720) and expanded (620) both fit
                        // visually because the parent Positioned has
                        // height: expandedH = 620 which clips at the bottom —
                        // collapsed tile within the morph has its own caption
                        // and cover; the row beneath at top: expandedH starts
                        // exactly where the hero ends.
                        child: HeroTileMorph(
                          focusNode: _heroWatchFocusNode,
                          collapsed: !_heroFocused,
                          // Hero's compact caption — channel name when focused
                          // on a card, else current hero item title.
                          collapsedCaption: heroItem?.channelName ?? '',
                          // Collapsed cover: same backdrop image, but rendered
                          // at tile geometry by HeroTileMorph's ClipRRect.
                          collapsedCover: backdropImage,
                          // Match the hero's actual rendered geometry — the
                          // Positioned wrapper gives us 1920×expandedH.
                          expandedHeightDp: expandedH,
                          expandedWidthDp: 1920.0,
                          // Collapsed sits at one tile's width — but in the
                          // hero slot we cap at the compact hero height so the
                          // row underneath has untouched layout.
                          collapsedHeightDp: collapsedH,
                          collapsedWidthDp: 1920.0,
                          expandedChild: CinematicHeroBlock(
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
                            return const Padding(padding: EdgeInsets.only(top: 8), child: CinematicRemoteHintFooter());
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
