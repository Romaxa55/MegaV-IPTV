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
import '../../onboarding/onboarding_overlay.dart';
import '../../onboarding/onboarding_provider.dart';
import '../widgets/_grid_tokens.dart';
import '../widgets/cinema_row.dart';
import '../widgets/home_boot_overlay.dart';
import 'cinematic_hero_block.dart';
import 'cinematic_remote_hint_footer.dart';
import 'unified_home_grid_scroller.dart';

/// Cinematic home screen — default main screen since Wave 5
/// (home-unified-grid-scroll). Legacy `HomeScreen` widget deleted;
/// `/home` route redirects here.
///
/// Data flow (Riverpod, unchanged from Wave 1):
///   - [featuredNowPlayingProvider] → hero + backdrop + carousel.
///   - [moviesNotifierProvider] → "Фильмы в эфире" row.
///   - [cinemaCategoriesProvider] + [categoryNotifierProvider] → genre rows.
///   - [apiClientProvider] → stream URL for preview player.
///   - [baseUrlProvider] → retry / URL prompt in error-only boot overlay.
///
/// Layout (Wave 5 architecture):
///   Stack {
///     Focus(escape handler) →
///       FocusTraversalGroup(WidgetOrderTraversalPolicy) →
///         UnifiedHomeGridScroller {
///           heroBuilder      → CinematicHeroBlock (row-0)
///           rows             → CategoryRowWrapper × N
///           footer           → CinematicRemoteHintFooter
///         }
///     if (bootError)   → HomeBootOverlay
///     if (!onboarding) → OnboardingOverlay (first-run)
///   }
///
/// Vertical Pinned-Slot Invariant from `UnifiedHomeGridScroller`
/// guarantees the focused row stays at screen-Y of
/// [GridTokens.verticalPinnedSlotIdx]; D-pad ↑/↓ moves the grid under
/// the focus, never the focus. Hero scrolls off the top when the user
/// goes below row-1.
///
/// Boot UX (Wave 6 home-skeleton-placeholders): no full-screen
/// loading gate — `_HeroSkeletonContent` and `CinemaRowLoadingPlaceholder`
/// surface immediately; boot overlay raises only on error.
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
  // home-skeleton-placeholders: дефолт false. Overlay поднимается ТОЛЬКО
  // если bootstrap провалился (есть _bootError). Иначе экран сразу
  // показывает skeleton placeholders, без чёрного fade-in момента.
  bool _showBootOverlay = false;
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
  // Hero focus (driven by UnifiedHomeGridScroller)
  // ──────────────────────────────────────────────────────────────────────────

  /// Called by `UnifiedHomeGridScroller.onHeroFocusChanged` when focus
  /// crosses the hero ↔ rails boundary. Pauses / resumes the hero
  /// carousel (отдельная hero-row не имеет своей anim — carousel timer
  /// просто меняет `_carouselIndex`).
  void _onHeroFocusChanged(bool focused) {
    if (!mounted) return;
    if (focused == _heroFocused) return;
    setState(() => _heroFocused = focused);
    if (focused) {
      final featured = ref.read(featuredNowPlayingProvider).valueOrNull ?? const [];
      if (featured.isNotEmpty) _restartCarousel(featured);
    } else {
      _carouselTimer?.cancel();
      _carouselTimer = null;
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
      if (!mounted || _hoveredItem != null || !_heroFocused) return;
      final list = ref.read(featuredNowPlayingProvider).valueOrNull ?? [];
      if (list.isEmpty) return;
      setState(() => _carouselIndex = (_carouselIndex + 1) % list.length);
    });
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Bootstrap (home-skeleton-placeholders spec, Wave 6)
  // ──────────────────────────────────────────────────────────────────────────
  //
  // Skeleton-first: убираем eager-await loop по всем категориям и full-screen
  // boot overlay. Экран рисуется сразу с UnifiedHomeGridScroller и skeleton
  // placeholders в hero/rows; Riverpod сам триггерит rebuild каждой row
  // когда её provider возвращает данные.
  //
  // boot overlay показывается ТОЛЬКО при наличии ошибки (e.g. неверный
  // baseUrl). Никакого артификального ожидания "пока всё прогрузится" —
  // юзер видит UI мгновенно.

  Future<void> _runHomeBootstrap() async {
    if (!mounted) return;
    setState(() {
      _bootError = null;
      // Скрываем boot overlay сразу: skeleton placeholders в hero+rows
      // покажут что данные грузятся. Overlay вернётся (с error UI) только
      // если categories/featured упадут с exception.
      _showBootOverlay = false;
      _bootFadeOut = false;
    });

    try {
      // Параллельный fetch — categories и featured независимы; неudачa
      // любого даёт _bootError UI поверх skeleton'ов.
      final results = await Future.wait([
        ref.read(cinemaCategoriesProvider.future),
        ref.read(featuredNowPlayingProvider.future),
        ref.read(moviesNotifierProvider.notifier).waitForInit(),
      ]);
      if (!mounted) return;

      final categories = results[0] as List;
      final featured = results[1] as List<NowPlayingItem>;

      // Fire-and-forget per-category init — это позволяет первой row
      // отрендериться сразу, не дожидаясь хвоста списка категорий.
      // Riverpod ref.watch внутри CategoryRowWrapper сам зарисует
      // skeleton до прибытия данных.
      for (final cat in categories) {
        unawaited(ref.read(categoryNotifierProvider(cat.name).notifier).waitForInit());
      }

      _scheduleHeroWatchFocus();
      if (featured.isNotEmpty) _restartCarousel(featured);

      // Lazy precache — рендерится из off-frame callback, не блокирует
      // UI. Берём только первые 8 элементов featured + первой row
      // чтобы не забить network канал на rtd2851a; остальные precache
      // подъедут через onItemFocus debounce внутри CategoryRowWrapper.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        for (final item in featured.take(8)) {
          final thumb = item.thumbnailUrl ?? item.program?.icon ?? item.logoUrl;
          if (thumb != null && thumb.isNotEmpty) {
            unawaited(precacheImage(NetworkImage(thumb), context).catchError((_) {}));
          }
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _bootError = 'Не удалось загрузить данные: $e';
        _showBootOverlay = true;
      });
    }
  }

  void _onBootRetryConnect() {
    ref.read(baseUrlProvider.notifier).state = _bootUrlController.text.trim();
    ref.invalidate(featuredNowPlayingProvider);
    ref.invalidate(cinemaCategoriesProvider);
    ref.invalidate(moviesNotifierProvider);
    unawaited(_runHomeBootstrap());
  }

  /// Called after the error overlay's AnimatedOpacity fade-out completes
  /// (юзер нажал retry → bootstrap прошёл успешно → `_bootFadeOut=true`
  /// → fade animation отыграла → этот callback её снимает с экрана
  /// и ставит focus на hero).
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
              // traverses children in declaration order so D-pad ↓ from
              // hero (row-0) consistently reaches the first rail (row-1)
              // across macOS desktop and Android TV.
              //
              // home-unified-grid-scroll spec (Wave 5):
              // Hero перестаёт быть отдельной Positioned-секцией и
              // становится row-0 единого `UnifiedHomeGridScroller`.
              // Vertical Pinned-Slot Invariant обеспечивает что фокус
              // остаётся в screen-space строке `verticalPinnedSlotIdx`
              // при D-pad ↑/↓.
              child: FocusTraversalGroup(
                policy: WidgetOrderTraversalPolicy(),
                child: UnifiedHomeGridScroller(
                  heroFocusNode: _heroWatchFocusNode,
                  onHeroFocusChanged: _onHeroFocusChanged,
                  heroBuilder: (_) => CinematicHeroBlock(
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
                  categories: categories,
                  rowBuilder: (_, cat) => CategoryRowWrapper(
                    key: ValueKey('cinematic-row-${cat.id}'),
                    category: cat,
                    onItemTap: _playNowPlaying,
                    onItemFocus: _onHoveredItemChanged,
                    availableHeight: GridTokens.unifiedRowHeightDp.h,
                  ),
                  footer: const Padding(padding: EdgeInsets.only(top: 8), child: CinematicRemoteHintFooter()),
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

          // ── Onboarding overlay (first-run only) ─────────────────────────
          // onboarding-remote-cheatsheet spec (Wave 6): показывается ровно
          // один раз. После dismiss — `markShown()` → persistent в
          // SharedPreferences → больше не появляется.
          if (!_showBootOverlay && !ref.watch(onboardingShownProvider))
            Positioned.fill(
              child: OnboardingOverlay(
                onDismiss: () {
                  ref.read(onboardingShownProvider.notifier).markShown();
                },
              ),
            ),
        ],
      ),
    );
  }
}
