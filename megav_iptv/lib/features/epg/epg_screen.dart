import 'dart:async';

import 'package:flutter/material.dart' hide Chip;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../core/epg/epg_window_provider.dart';
import '../../core/playlist/models/channel.dart';
import '../../core/playlist/models/epg_program.dart';
import '../../core/providers/providers.dart' show featuredChannelsProvider;
import '../../core/theme/app_colors.dart';
import '../../core/theme/megav_text_styles.dart';
import 'state/epg_focus_controller.dart';
import 'state/epg_screen_state.dart';
import 'widgets/epg_category_filter.dart';
import 'widgets/epg_channel_rail.dart';
import 'widgets/epg_day_picker.dart';
import 'widgets/epg_now_marker.dart';
import 'widgets/epg_preview_strip.dart';
import 'widgets/epg_time_axis.dart';
import 'widgets/epg_time_grid.dart';

/// Full-screen 2D EPG (Electronic Programme Guide).
///
/// Composes the foundation EPG widgets (`EpgDayPicker`,
/// `EpgCategoryFilter`, `EpgChannelRail`, `EpgTimeAxis`, `EpgTimeGrid`,
/// `EpgNowMarker`, `EpgPreviewStrip`) into the layout described in
/// design.md §3 and routes all UI mutations through a single sealed
/// `EpgUiState` + `_transition(...)` pair (Req 12.2, 12.3).
///
/// Data layer: on mount and on day-picker change the screen issues a
/// fetch via `epgWindowProvider(EpgWindowKey(...))`. Category filter is
/// applied client-side without re-fetching (Req 8.2).
///
/// Performance contract:
/// - 0 GPU-blurring widgets in this file (perf grep gate).
/// - All shadows respect `kSafeShadowBlurMax`.
/// - D-pad handler is held in a pure-Dart [EpgFocusController] (Req 9).
class EpgScreen extends ConsumerStatefulWidget {
  const EpgScreen({super.key});

  @override
  ConsumerState<EpgScreen> createState() => _EpgScreenState();
}

class _EpgScreenState extends ConsumerState<EpgScreen> {
  EpgUiState _state = const EpgLoadingState();

  /// Currently selected day relative to "today" (-2 .. +4).
  int _selectedDayOffset = 0;

  /// Currently selected client-side category filter (`null` = «Все»).
  String? _selectedCategory;

  /// Re-entry guard for OK/Enter routing (Req 9.6).
  bool _inFlight = false;

  /// Debounce timer that drives heavy preview-strip refresh (Req 9.5).
  Timer? _focusDebounceTimer;

  /// Channel/programme that the preview strip is currently rendering.
  /// Updated only after `EpgFocusController.onFocusStabilised` fires.
  int? _previewChannelIdx;
  int? _previewProgrammeId;

  late final ScrollController _verticalCtl;
  late final ScrollController _horizontalCtl;
  late final FocusNode _rootFocus;
  late final EpgFocusController _focusController;

  static const int _slotCount = 16; // 8h window @ 30 min/slot
  static const double _slotW = 180; // matches EpgProgramCell.slotW
  static const double _channelRailW = 240; // CH_W in design tokens

  @override
  void initState() {
    super.initState();
    _verticalCtl = ScrollController();
    _horizontalCtl = ScrollController();
    _rootFocus = FocusNode(debugLabel: 'epg-root');
    _focusController = EpgFocusController(
      channelFocusNodes: <int, FocusNode>{},
      programmeFocusNodes: <int, FocusNode>{},
      verticalCtl: _verticalCtl,
      horizontalCtl: _horizontalCtl,
      onTransition: _transition,
      onSelect: _onProgramSelected,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _refetch();
    });
  }

  @override
  void dispose() {
    _focusController.dispose();
    _focusDebounceTimer?.cancel();
    _focusDebounceTimer = null;
    _rootFocus.dispose();
    _verticalCtl.dispose();
    _horizontalCtl.dispose();
    super.dispose();
  }

  /// Single mutation entry-point for [EpgUiState] transitions (Req 12.2).
  ///
  /// Cancels any pending focus-debounce so heavy preview-strip refresh
  /// callbacks queued under the previous state do not fire against the
  /// new one.
  void _transition(EpgUiState newState) {
    _focusDebounceTimer?.cancel();
    _focusDebounceTimer = null;
    if (!mounted) return;
    setState(() => _state = newState);
  }

  /// Issues an EPG window fetch for the currently-selected day and the
  /// resolved channel list. Routes through [_transition] so the loading /
  /// ready / error transitions remain on the single mutation path.
  Future<void> _refetch() async {
    final today = DateTime.now();
    final base = DateTime(today.year, today.month, today.day);
    final from = base.add(Duration(days: _selectedDayOffset));
    final to = from.add(const Duration(hours: 8));

    _transition(const EpgLoadingState());

    final List<Channel> channels;
    try {
      channels = await ref.read(featuredChannelsProvider.future);
    } catch (e, st) {
      _transition(EpgErrorState(error: e, stackTrace: st));
      return;
    }
    if (channels.isEmpty) {
      _transition(
        EpgReadyState(
          channels: const [],
          programmes: const {},
          windowFrom: from,
          windowTo: to,
          selectedCategory: _selectedCategory,
        ),
      );
      return;
    }

    try {
      final windowKey = EpgWindowKey(from: from, to: to, channelIds: channels.map((c) => c.id).toList());
      final programmes = await ref.read(epgWindowProvider(windowKey).future);
      final initialChannelIdx = 0;
      final initialProgrammeId = _findInitialLiveProgrammeId(channels[initialChannelIdx].id, programmes);
      _previewChannelIdx = initialChannelIdx;
      _previewProgrammeId = initialProgrammeId;
      _transition(
        EpgReadyState(
          channels: channels,
          programmes: programmes,
          windowFrom: from,
          windowTo: to,
          selectedCategory: _selectedCategory,
          focusedChannelIndex: initialChannelIdx,
          focusedProgrammeId: initialProgrammeId,
        ),
      );
    } catch (e, st) {
      _transition(EpgErrorState(error: e, stackTrace: st));
    }
  }

  /// Returns the id of the live programme on [channelId] within
  /// [programmes], or the first programme if no live one exists, or
  /// `null` if the channel has no programmes.
  int? _findInitialLiveProgrammeId(int channelId, Map<int, List<EpgProgram>> programmes) {
    final progs = programmes[channelId];
    if (progs == null || progs.isEmpty) return null;
    final liveIdx = progs.indexWhere((p) => p.isNow);
    return liveIdx >= 0 ? progs[liveIdx].id : progs.first.id;
  }

  void _onDaySelected(int offset) {
    if (offset == _selectedDayOffset) return;
    setState(() => _selectedDayOffset = offset);
    _refetch();
  }

  /// Client-side category filter (Req 8.2) — never triggers a re-fetch.
  void _onCategorySelected(String? category) {
    setState(() => _selectedCategory = category);
    final s = _state;
    if (s is EpgReadyState) {
      _transition(s.copyWith(selectedCategory: category));
    }
  }

  /// Routes an OK/Enter activation on a focused programme cell.
  ///
  /// Phase 6.1 wires only the callback plumbing. The real navigation
  /// (e.g. `context.go('/player?...')`) is left as a TODO so it can be
  /// landed alongside the router entry in task 6.3.
  void _onProgramSelected(EpgProgram program) {
    // TODO(6.3): wire context.go('/player?program=${program.id}') once
    // the new /epg → /player route is appended to the existing router.
  }

  /// Updates the preview strip after the D-pad focus has stabilised
  /// (Req 9.5, 10.3). Called from [EpgTimeGrid.onCellFocusChanged] via
  /// [EpgFocusController.onFocusStabilised].
  void _schedulePreviewUpdate(int channelIdx, int programmeId) {
    _focusController.onFocusStabilised(() {
      if (!mounted) return;
      setState(() {
        _previewChannelIdx = channelIdx;
        _previewProgrammeId = programmeId;
      });
    });
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    final s = _state;
    if (s is EpgReadyState) {
      return _focusController.onKey(node, event, s);
    }
    return KeyEventResult.ignored;
  }

  /// Computes the visible slice of [programmes] under the active client-side
  /// category filter (Req 8.2). Returns the same map when no filter is set.
  Map<int, List<EpgProgram>> _filterByCategory(Map<int, List<EpgProgram>> programmes) {
    final cat = _selectedCategory;
    if (cat == null) return programmes;
    return <int, List<EpgProgram>>{
      for (final entry in programmes.entries) entry.key: entry.value.where((p) => p.category == cat).toList(),
    };
  }

  /// Distinct `EpgProgram.category` values across [programmes], excluding
  /// `null` / empty strings. Stable order — first appearance wins.
  List<String> _extractCategories(Map<int, List<EpgProgram>> programmes) {
    final seen = <String>{};
    final out = <String>[];
    for (final list in programmes.values) {
      for (final p in list) {
        final c = p.category;
        if (c == null || c.isEmpty) continue;
        if (seen.add(c)) out.add(c);
      }
    }
    return out;
  }

  EpgProgram? _focusedProgrammeOf(EpgReadyState s) {
    final rowIdx = s.focusedChannelIndex;
    final progId = s.focusedProgrammeId;
    if (rowIdx == null || progId == null) return null;
    if (rowIdx < 0 || rowIdx >= s.channels.length) return null;
    final progs = s.programmes[s.channels[rowIdx].id] ?? const <EpgProgram>[];
    final idx = progs.indexWhere((p) => p.id == progId);
    return idx < 0 ? null : progs[idx];
  }

  Channel? _focusedChannelOf(EpgReadyState s) {
    final rowIdx = s.focusedChannelIndex;
    if (rowIdx == null) return null;
    if (rowIdx < 0 || rowIdx >= s.channels.length) return null;
    return s.channels[rowIdx];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('epg-screen-root'),
      body: SafeArea(
        child: Focus(
          focusNode: _rootFocus,
          autofocus: true,
          onKeyEvent: _onKeyEvent,
          child: switch (_state) {
            EpgLoadingState() => _buildLoading(context),
            EpgErrorState() => _buildError(context),
            EpgReadyState s => _buildReady(context, s),
          },
        ),
      ),
    );
  }

  Widget _buildLoading(BuildContext context) {
    // Loading still surfaces the static chrome keys (day picker, category
    // filter, preview strip) so the smoke test sees them on first paint
    // without depending on async data resolution.
    final today = DateTime.now();
    return Column(
      children: [
        _buildHeader(context, today),
        EpgCategoryFilter(
          categories: const [],
          selectedCategory: _selectedCategory,
          onCategorySelected: _onCategorySelected,
        ),
        const Expanded(child: Center(child: CircularProgressIndicator())),
        const EpgPreviewStrip(),
      ],
    );
  }

  Widget _buildError(BuildContext context) {
    final today = DateTime.now();
    return Column(
      children: [
        _buildHeader(context, today),
        EpgCategoryFilter(
          categories: const [],
          selectedCategory: _selectedCategory,
          onCategorySelected: _onCategorySelected,
        ),
        const Expanded(child: Center(child: Text('Не удалось загрузить EPG'))),
        const EpgPreviewStrip(),
      ],
    );
  }

  Widget _buildHeader(BuildContext context, DateTime today) {
    final theme = Theme.of(context);
    final styles = theme.extension<MegaVTextStyles>();
    final headerStyle = (styles?.displayLarge ?? theme.textTheme.headlineMedium ?? const TextStyle()).copyWith(
      fontStyle: FontStyle.italic,
      fontSize: 56.sp,
    );
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 32.w, vertical: 16.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text('Программа передач', style: headerStyle, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          EpgDayPicker(today: today, selectedOffset: _selectedDayOffset, onDaySelected: _onDaySelected),
        ],
      ),
    );
  }

  Widget _buildReady(BuildContext context, EpgReadyState s) {
    final filteredProgrammes = _filterByCategory(s.programmes);
    final categories = _extractCategories(s.programmes);
    final focusedProgramme = _focusedProgrammeOf(s);
    final focusedChannel = _focusedChannelOf(s);
    // Preview strip is debounced — drive it from the stabilised snapshot
    // rather than the live focus pointer (Req 10.3).
    final previewProgramme = (() {
      final ch = _previewChannelIdx;
      final pid = _previewProgrammeId;
      if (ch == null || pid == null) return focusedProgramme;
      if (ch < 0 || ch >= s.channels.length) return focusedProgramme;
      final progs = s.programmes[s.channels[ch].id] ?? const <EpgProgram>[];
      final idx = progs.indexWhere((p) => p.id == pid);
      return idx < 0 ? focusedProgramme : progs[idx];
    })();
    final previewChannel = (() {
      final ch = _previewChannelIdx;
      if (ch == null) return focusedChannel;
      if (ch < 0 || ch >= s.channels.length) return focusedChannel;
      return s.channels[ch];
    })();

    return Column(
      children: [
        _buildHeader(context, DateTime.now()),
        EpgCategoryFilter(
          categories: categories,
          selectedCategory: _selectedCategory,
          onCategorySelected: _onCategorySelected,
        ),
        Expanded(
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Channel rail column. Top spacer keeps the rail
                  // aligned with the time axis above the grid.
                  SizedBox(
                    width: _channelRailW.w,
                    child: Column(
                      children: [
                        SizedBox(height: 32.h),
                        Expanded(
                          child: EpgChannelRail(
                            channels: s.channels,
                            verticalCtl: _verticalCtl,
                            focusedChannelIndex: s.focusedChannelIndex,
                            onFocusChanged: (idx) {
                              // Sync logical focus into state without re-fetch.
                              _transition(s.copyWith(focusedChannelIndex: idx));
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        EpgTimeAxis(
                          windowFrom: s.windowFrom,
                          horizontalCtl: _horizontalCtl,
                          slotCount: _slotCount,
                          slotW: _slotW,
                        ),
                        Expanded(
                          child: EpgTimeGrid(
                            channels: s.channels,
                            programmes: filteredProgrammes,
                            windowFrom: s.windowFrom,
                            slotCount: _slotCount,
                            verticalCtl: _verticalCtl,
                            horizontalCtl: _horizontalCtl,
                            focusedChannelIndex: s.focusedChannelIndex,
                            focusedProgrammeId: s.focusedProgrammeId,
                            onCellFocusChanged: (rec) {
                              _transition(
                                s.copyWith(focusedChannelIndex: rec.channelIdx, focusedProgrammeId: rec.programmeId),
                              );
                              _schedulePreviewUpdate(rec.channelIdx, rec.programmeId);
                            },
                            onCellTap: _onProgramSelected,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              // NOW marker overlaid only over the time-grid portion.
              // Anchored to the right of the channel rail and below the axis.
              Positioned(
                left: _channelRailW.w,
                top: 32.h,
                bottom: 0,
                right: 0,
                child: IgnorePointer(
                  child: Stack(
                    clipBehavior: Clip.hardEdge,
                    children: [
                      EpgNowMarker(windowFrom: s.windowFrom, slotW: _slotW, gridHeight: 600, accent: AppColors.accent),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        EpgPreviewStrip(
          program: previewProgramme,
          channel: previewChannel,
          onWatch: previewProgramme == null
              ? null
              : () {
                  if (_inFlight) return;
                  _inFlight = true;
                  try {
                    _onProgramSelected(previewProgramme);
                  } finally {
                    _inFlight = false;
                  }
                },
          onDetails: previewProgramme == null
              ? null
              : () {
                  /* TODO(6.3): details route */
                },
        ),
      ],
    );
  }
}
