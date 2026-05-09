import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/playlist/models/now_playing.dart';
import '../../../core/theme/app_colors.dart';

/// Постер карточки + retry-логика загрузки превью.
///
/// Вынесено из `cinema_card.dart` отдельным StatefulWidget'ом, чтобы держать
/// сам `cinema_card.dart` ниже лимита 600 строк (`check-file-size` pre-commit
/// hook). Никаких изменений поведения — только организационный refactor.
///
/// Конвенция проекта: имя файла начинается с `_` для маркировки «внутренний
/// хелпер фичи `home/widgets`» (см. `_grid_tokens.dart`); сам же класс
/// `CardPoster` публичен на уровне библиотеки и используется только из
/// `cinema_card.dart`. Снаружи импортировать не следует.
///
/// Приоритет источников: KP poster (`program.icon`) → stream `thumbnailUrl`
/// → `logoUrl` канала. При ошибке загрузки дёргается экспоненциальный
/// backoff (3/5/10/15/30/60 сек, до 6 попыток).
class CardPoster extends StatefulWidget {
  final NowPlayingItem item;

  const CardPoster({super.key, required this.item});

  @override
  State<CardPoster> createState() => _CardPosterState();
}

class _CardPosterState extends State<CardPoster> {
  bool _thumbFailed = false;
  int _thumbRetryCount = 0;

  static const _cardBg = Color(0xFF12121E);

  @override
  Widget build(BuildContext context) => _buildPoster();

  Widget _buildPoster() {
    final iconUrl = widget.item.program?.icon;
    final thumbUrl = widget.item.thumbnailUrl;
    final logoUrl = widget.item.logoUrl;

    // Priority: KP poster (icon) → stream thumbnail → channel logo
    final primaryUrl = (iconUrl != null && iconUrl.isNotEmpty) ? iconUrl : null;
    final secondaryUrl = (thumbUrl != null && thumbUrl.isNotEmpty) ? thumbUrl : null;
    final tertiaryUrl = (logoUrl != null && logoUrl.isNotEmpty) ? logoUrl : null;
    final bestUrl = primaryUrl ?? secondaryUrl ?? tertiaryUrl;

    if (bestUrl == null) return _posterPlaceholder();

    final attemptUrl = bestUrl == secondaryUrl && _thumbRetryCount > 0 ? '$bestUrl?retry=$_thumbRetryCount' : bestUrl;

    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: _cardBg),
        if (!_thumbFailed)
          Image.network(
            attemptUrl,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            cacheWidth: 400,
            gaplessPlayback: true,
            alignment: Alignment.center,
            frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
              final ready = wasSynchronouslyLoaded || frame != null;
              return AnimatedOpacity(
                opacity: ready ? 1 : 0,
                duration: ready ? const Duration(milliseconds: 400) : Duration.zero,
                curve: Curves.easeOut,
                child: child,
              );
            },
            errorBuilder: (ctx, error, stackTrace) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && !_thumbFailed) {
                  setState(() => _thumbFailed = true);
                  _retryThumbnail();
                }
              });
              return const SizedBox.shrink();
            },
          ),
      ],
    );
  }

  void _retryThumbnail() {
    if (_thumbRetryCount >= 6) return;
    final delays = [3, 5, 10, 15, 30, 60];
    final delaySec = delays[_thumbRetryCount.clamp(0, delays.length - 1)];
    Future.delayed(Duration(seconds: delaySec), () {
      if (mounted) {
        setState(() {
          _thumbFailed = false;
          _thumbRetryCount++;
        });
      }
    });
  }

  Widget _posterPlaceholder() {
    return Container(
      color: _cardBg,
      child: Center(
        child: Icon(Icons.tv, size: 32.sp, color: AppColors.textHint.withValues(alpha: 0.2)),
      ),
    );
  }
}
