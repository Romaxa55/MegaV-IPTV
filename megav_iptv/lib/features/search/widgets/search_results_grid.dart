// SearchResultsGrid — exhaustive sealed-state dispatcher for the right
// pane of `/search`.
//
// Reads `searchControllerProvider` and renders one of five private
// sub-widgets via a `switch` over `SearchUiState`. The switch has no
// `default:` arm — sealed exhaustiveness makes the analyzer surface a
// regression the moment a new state variant is added (Req 10.4).
//
// Lazy paging: the last cell of `_ResultsGridView` enqueues
// `requestNextPage()` via a post-frame callback, avoiding setState during
// build (Req 7.2). `cacheExtent: 1500`, `addAutomaticKeepAlives`, and
// `addRepaintBoundaries` keep scroll-perf inside the Mali-friendly budget
// (Req 6.8, 9.5).
//
// Maps to Requirements 6.1, 6.2, 6.3, 6.4, 6.5, 6.6, 6.7, 6.8, 7.2, 9.5,
// 10.4, 11.1, 11.7.

import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide Chip;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:megav_iptv/core/ui/atoms/atoms.dart';

import '../../../core/playlist/models/channel.dart';
import '../../home/widgets/_grid_tokens.dart';
import '../state/search_controller.dart';
import 'search_state.dart';

/// Returns the column count for the search-results grid, clamped to
/// `[2, 4]` because the right pane sits next to the 360 px wide left
/// keyboard pane and must never grow as wide as the home grid.
///
/// Delegates to the existing [pickColumns] from the home grid tokens to
/// avoid duplicating breakpoint logic — single source of truth (Req 6.7).
int pickColumnsClamped(double w) {
  final base = pickColumns(w);
  return base.clamp(2, 4);
}

/// Right-pane host that translates the current [SearchUiState] into one
/// of five visual states (Idle / Loading / Empty / Error / Results).
///
/// Keep this widget purely declarative — every transition happens upstream
/// in `SearchController._transition`, and we just `switch` on the result.
class SearchResultsGrid extends ConsumerWidget {
  const SearchResultsGrid({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(searchControllerProvider);
    return switch (state) {
      Idle() => const _IdleHint(),
      Loading() => const _LoadingOverlay(),
      Empty(:final query) => _EmptyMessage(query: query),
      SearchError(:final message) => _ErrorRetry(message: message),
      Results(:final items, :final hasMore) => _ResultsGridView(items: items, hasMore: hasMore),
    };
  }
}

class _IdleHint extends StatelessWidget {
  const _IdleHint();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(child: Text('Начните вводить запрос', style: theme.textTheme.bodyLarge));
  }
}

class _LoadingOverlay extends StatelessWidget {
  const _LoadingOverlay();

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}

class _EmptyMessage extends StatelessWidget {
  const _EmptyMessage({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Text(
        'Ничего не найдено по запросу "$query"',
        textAlign: TextAlign.center,
        style: theme.textTheme.bodyLarge,
      ),
    );
  }
}

class _ErrorRetry extends ConsumerWidget {
  const _ErrorRetry({required this.message});

  final String message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center, style: theme.textTheme.bodyLarge),
          const SizedBox(height: 16),
          MvButton.ghost(label: 'Повторить', onPressed: () => ref.read(searchControllerProvider.notifier).retry()),
        ],
      ),
    );
  }
}

class _ResultsGridView extends ConsumerWidget {
  const _ResultsGridView({required this.items, required this.hasMore});

  final List<Channel> items;
  final bool hasMore;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cols = pickColumnsClamped(MediaQuery.of(context).size.width);
    return GridView.builder(
      cacheExtent: 1500,
      addAutomaticKeepAlives: true,
      addRepaintBoundaries: true,
      padding: const EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cols,
        childAspectRatio: 16 / 9,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: items.length,
      itemBuilder: (ctx, i) {
        if (i == items.length - 1 && hasMore) {
          // Defer to post-frame so we don't trigger a state mutation
          // during the build phase (Req 7.2).
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref.read(searchControllerProvider.notifier).requestNextPage();
          });
        }
        final ch = items[i];
        final logo = ch.logoUrl;
        final ImageProvider image = (logo != null && logo.isNotEmpty) ? NetworkImage(logo) : const _TransparentImage();
        return Poster(image: image, title: ch.name);
      },
    );
  }
}

/// Tiny in-memory 1×1 transparent placeholder used when a [Channel] has
/// no `logoUrl`. Avoids the `NetworkImage('')` failure path inside
/// [Poster.errorBuilder] and keeps the grid cell rendered as a flat
/// surface tile.
class _TransparentImage extends ImageProvider<_TransparentImage> {
  const _TransparentImage();

  static final Uint8List _bytes = Uint8List.fromList(const [
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // PNG signature
    0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
    0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
    0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
    0x89, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x44, 0x41,
    0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
    0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
    0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
    0x42, 0x60, 0x82,
  ]);

  @override
  Future<_TransparentImage> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<_TransparentImage>(this);
  }

  @override
  ImageStreamCompleter loadImage(_TransparentImage key, ImageDecoderCallback decode) {
    return MultiFrameImageStreamCompleter(codec: _loadAsync(key, decode), scale: 1.0);
  }

  Future<Codec> _loadAsync(_TransparentImage key, ImageDecoderCallback decode) async {
    final buffer = await ImmutableBuffer.fromUint8List(_bytes);
    return decode(buffer);
  }

  @override
  bool operator ==(Object other) => other is _TransparentImage;

  @override
  int get hashCode => 0;
}
