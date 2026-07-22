import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../application/story_card_download_service.dart';
import '../../data/story_card_download_failure.dart';
import '../../data/story_card_scene.dart';
import 'story_card_preview_surface.dart';

const _closeTooltip = '\uce74\ub4dc \uc0c1\uc138 \ub2eb\uae30';
const _downloadTooltip = '\uce74\ub4dc \ub2e4\uc6b4\ub85c\ub4dc';
const _cardSemanticsLabel = '\uc2a4\ud1a0\ub9ac \uce74\ub4dc \uc0c1\uc138';
const _downloadSuccessMessage =
    '\uce74\ub4dc\ub97c \uac24\ub7ec\ub9ac\uc5d0 \uc800\uc7a5\ud588\uc2b5\ub2c8\ub2e4.';

Future<void> showStoryCardDetailOverlay({
  required BuildContext context,
  required String cardId,
  required String? previewUrl,
}) {
  final barrierLabel = MaterialLocalizations.of(
    context,
  ).modalBarrierDismissLabel;

  return showGeneralDialog<void>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: true,
    barrierLabel: barrierLabel,
    barrierColor: const Color(0xB3000000),
    transitionDuration: const Duration(milliseconds: 240),
    pageBuilder: (context, animation, secondaryAnimation) {
      return _StoryCardDetailOverlay(cardId: cardId, previewUrl: previewUrl);
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curvedAnimation = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curvedAnimation,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.92, end: 1).animate(curvedAnimation),
          child: child,
        ),
      );
    },
  );
}

class _StoryCardDetailOverlay extends ConsumerStatefulWidget {
  const _StoryCardDetailOverlay({
    required this.cardId,
    required this.previewUrl,
  });

  static const _horizontalMargin = 16.0;
  static const _verticalMargin = 24.0;
  static const _closeButtonExtent = 44.0;

  final String cardId;
  final String? previewUrl;

  @override
  ConsumerState<_StoryCardDetailOverlay> createState() =>
      _StoryCardDetailOverlayState();
}

class _StoryCardDetailOverlayState
    extends ConsumerState<_StoryCardDetailOverlay> {
  bool _isDownloading = false;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: const Key('story-card-detail-overlay'),
      child: SafeArea(
        minimum: const EdgeInsets.symmetric(
          horizontal: _StoryCardDetailOverlay._horizontalMargin,
          vertical: _StoryCardDetailOverlay._verticalMargin,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final widthBound = math.max(0.0, constraints.maxWidth);
            final heightBound = math.max(
              0.0,
              constraints.maxHeight -
                  _StoryCardDetailOverlay._closeButtonExtent,
            );
            final cardWidth = math.min(
              widthBound,
              heightBound * storyCardCanvasAspectRatio,
            );

            return Stack(
              fit: StackFit.expand,
              children: [
                Center(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {},
                    child: StoryCardPreviewSurface(
                      surfaceKey: Key('story-card-detail-${widget.cardId}'),
                      previewUrl: widget.previewUrl,
                      width: cardWidth,
                      semanticsLabel: _cardSemanticsLabel,
                    ),
                  ),
                ),
                Positioned(
                  top: 0,
                  right: _StoryCardDetailOverlay._closeButtonExtent + 8,
                  child: IconButton(
                    key: const Key('story-card-detail-download'),
                    onPressed: _isDownloading ? null : _download,
                    tooltip: _downloadTooltip,
                    style: IconButton.styleFrom(
                      fixedSize: const Size.square(
                        _StoryCardDetailOverlay._closeButtonExtent,
                      ),
                      backgroundColor: const Color(0x99000000),
                      foregroundColor: AppColors.textInverse,
                      disabledBackgroundColor: const Color(0x99000000),
                      disabledForegroundColor: AppColors.textInverse,
                      shape: const CircleBorder(),
                    ),
                    icon: _isDownloading
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.textInverse,
                            ),
                          )
                        : const Icon(Icons.download_rounded, size: 25),
                  ),
                ),
                Positioned(
                  top: 0,
                  right: 0,
                  child: IconButton(
                    key: const Key('story-card-detail-close'),
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: _closeTooltip,
                    style: IconButton.styleFrom(
                      fixedSize: const Size.square(
                        _StoryCardDetailOverlay._closeButtonExtent,
                      ),
                      backgroundColor: const Color(0x99000000),
                      foregroundColor: AppColors.textInverse,
                      shape: const CircleBorder(),
                    ),
                    icon: const Icon(Icons.close_rounded, size: 26),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _download() async {
    if (_isDownloading) {
      return;
    }

    setState(() => _isDownloading = true);
    try {
      await ref.read(storyCardDownloaderProvider).download(widget.cardId);
      if (!mounted) {
        return;
      }
      _showSnackBar(_downloadSuccessMessage);
    } on StoryCardDownloadException catch (error) {
      if (!mounted) {
        return;
      }
      _showSnackBar(_downloadFailureMessage(error.reason));
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showSnackBar(
        _downloadFailureMessage(StoryCardDownloadFailureReason.unknown),
      );
    } finally {
      if (mounted) {
        setState(() => _isDownloading = false);
      }
    }
  }

  void _showSnackBar(String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  String _downloadFailureMessage(StoryCardDownloadFailureReason reason) {
    return switch (reason) {
      StoryCardDownloadFailureReason.accessDenied =>
        '\uc0ac\uc9c4 \ubcf4\uad00\ud568 \uad8c\ud55c\uc744 \ud655\uc778\ud574 \uc8fc\uc138\uc694.',
      StoryCardDownloadFailureReason.notEnoughSpace =>
        '\uc800\uc7a5 \uacf5\uac04\uc774 \ubd80\uc871\ud574 \uce74\ub4dc\ub97c \uc800\uc7a5\ud558\uc9c0 \ubabb\ud588\uc5b4\uc694.',
      StoryCardDownloadFailureReason.notSupported =>
        '\uc774 \uae30\uae30\uc5d0\ub294 \uce74\ub4dc\ub97c \uc800\uc7a5\ud560 \uc218 \uc5c6\uc5b4\uc694.',
      StoryCardDownloadFailureReason.requestTimeout =>
        '\uc5f0\uacb0\uc774 \uc9c0\uc5f0\ub418\uace0 \uc788\uc5b4\uc694. \ub2e4\uc2dc \uc2dc\ub3c4\ud574 \uc8fc\uc138\uc694.',
      StoryCardDownloadFailureReason.cardNotFound ||
      StoryCardDownloadFailureReason.sourceUnavailable ||
      StoryCardDownloadFailureReason.invalidSource =>
        '\uce74\ub4dc \uc6d0\ubcf8\uc744 \ubd88\ub7ec\uc624\uc9c0 \ubabb\ud588\uc5b4\uc694.',
      StoryCardDownloadFailureReason.configMissing ||
      StoryCardDownloadFailureReason.renderFailed ||
      StoryCardDownloadFailureReason.unknown =>
        '\uce74\ub4dc\ub97c \uc800\uc7a5\ud558\uc9c0 \ubabb\ud588\uc5b4\uc694. \ub2e4\uc2dc \uc2dc\ub3c4\ud574 \uc8fc\uc138\uc694.',
    };
  }
}
