import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/presentation/widgets/app_confirmation_dialog.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../safety/data/safety_report.dart';
import '../../../safety/presentation/safety_report_sheet.dart';
import '../../application/story_card_download_service.dart';
import '../../application/story_loop_realtime_controller.dart';
import '../../application/today_story_card_stacks_provider.dart';
import '../../data/story_card_download_failure.dart';
import '../../data/story_card_read_receipt_repository.dart';
import '../../data/story_card_stack_item.dart';
import '../../data/story_card_stack_preview.dart';
import '../../data/story_loop_write_repository.dart';
import 'story_card_action_sheet.dart';
import 'story_card_preview_surface.dart';
import 'story_card_swipe_dismiss_surface.dart';

Future<void> showStoryCardStackOverlay({
  required BuildContext context,
  required DateTime date,
  required StoryCardStackPreview stack,
}) {
  final barrierLabel = MaterialLocalizations.of(
    context,
  ).modalBarrierDismissLabel;
  return showGeneralDialog<void>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: true,
    barrierLabel: barrierLabel,
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (context, animation, secondaryAnimation) =>
        _StoryCardStackOverlay(date: date, stack: stack),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: child,
      );
    },
  );
}

class _StoryCardStackOverlay extends ConsumerStatefulWidget {
  const _StoryCardStackOverlay({required this.date, required this.stack});

  final DateTime date;
  final StoryCardStackPreview stack;

  @override
  ConsumerState<_StoryCardStackOverlay> createState() =>
      _StoryCardStackOverlayState();
}

class _StoryCardStackOverlayState
    extends ConsumerState<_StoryCardStackOverlay> {
  PageController? _pageController;
  var _currentIndex = 0;
  var _isMutating = false;
  final _acknowledgedCardIds = <String>{};

  StoryCardStackRequest get _request => StoryCardStackRequest(
    date: widget.date,
    authorUserId: widget.stack.authorUserId,
  );

  @override
  void dispose() {
    _pageController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(storyCardStackProvider(_request));
    final loadedItems = itemsAsync.asData?.value;
    final items = loadedItems == null
        ? null
        : _sortChronologically(loadedItems);
    if (items != null && items.isNotEmpty) {
      _initializePageController(items);
    }
    if (items != null && items.isNotEmpty && _currentIndex >= items.length) {
      _currentIndex = items.length - 1;
    }
    final currentItem = items == null || items.isEmpty
        ? null
        : items[_currentIndex];

    return KeyedSubtree(
      key: const Key('story-card-stack-overlay'),
      child: StoryCardSwipeDismissSurface(
        onDismissed: () => Navigator.of(context).pop(),
        child: SafeArea(
          minimum: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Material(
            color: Colors.transparent,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _buildCardArea(itemsAsync, items),
                Positioned(
                  top: 0,
                  left: 0,
                  child: IconButton(
                    key: const Key('story-card-stack-close'),
                    tooltip: '카드 상세 닫기',
                    onPressed: () => Navigator.of(context).pop(),
                    color: AppColors.textInverse,
                    icon: const Icon(Icons.close_rounded, size: 28),
                  ),
                ),
                if (items != null && items.length > 1)
                  Positioned(
                    top: 13,
                    left: 64,
                    right: 64,
                    child: Center(
                      child: Text(
                        '${_currentIndex + 1} / ${items.length}',
                        style: const TextStyle(
                          color: AppColors.textInverse,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                if (currentItem != null)
                  Positioned(
                    left: 0,
                    bottom: 0,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 160),
                      opacity: currentItem.canFeature ? 1 : 0,
                      child: IgnorePointer(
                        ignoring: !currentItem.canFeature || _isMutating,
                        child: IconButton(
                          key: const Key('story-card-stack-feature'),
                          tooltip: currentItem.isFeatured
                              ? '오늘의 사진으로 선택됨'
                              : '오늘의 사진으로 선택',
                          onPressed: () => _feature(currentItem),
                          color: AppColors.textInverse,
                          icon: Icon(
                            currentItem.isFeatured
                                ? Icons.star_rounded
                                : Icons.star_border_rounded,
                            size: 30,
                          ),
                        ),
                      ),
                    ),
                  ),
                if (currentItem != null)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: IconButton(
                      key: const Key('story-card-stack-menu'),
                      tooltip: '카드 메뉴',
                      onPressed: _isMutating
                          ? null
                          : () => unawaited(
                              _openActions(currentItem, items!.length),
                            ),
                      color: AppColors.textInverse,
                      disabledColor: AppColors.textInverse.withValues(
                        alpha: 0.4,
                      ),
                      icon: const Icon(Icons.more_vert_rounded, size: 28),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCardArea(
    AsyncValue<List<StoryCardStackItem>> itemsAsync,
    List<StoryCardStackItem>? items,
  ) {
    if (items != null && items.isNotEmpty) {
      return LayoutBuilder(
        builder: (context, constraints) {
          return PageView.builder(
            key: const Key('story-card-stack-pages'),
            controller: _pageController,
            itemCount: items.length,
            onPageChanged: (index) {
              setState(() => _currentIndex = index);
              _acknowledgeIfNeeded(items[index]);
            },
            itemBuilder: (context, index) {
              final item = items[index];
              final cardWidth = math.min(
                constraints.maxWidth,
                (constraints.maxHeight - 48) *
                    item.card.cardType.canvasAspectRatio,
              );
              return Center(
                child: Stack(
                  children: [
                    StoryCardPreviewSurface(
                      surfaceKey: Key('story-card-stack-${item.card.id}'),
                      previewUrl: item.card.previewUrl,
                      width: cardWidth,
                      cardType: item.card.cardType,
                      semanticsLabel: '스토리 카드 ${index + 1}',
                    ),
                    Positioned.fill(
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              behavior: HitTestBehavior.translucent,
                              onTap: index > 0 ? _previous : null,
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              behavior: HitTestBehavior.translucent,
                              onTap: index + 1 < items.length ? _next : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      );
    }

    if (itemsAsync.hasError) {
      return Center(
        child: IconButton(
          key: const Key('story-card-stack-retry'),
          tooltip: '다시 시도',
          color: AppColors.textInverse,
          onPressed: () => ref.invalidate(storyCardStackProvider(_request)),
          icon: const Icon(Icons.refresh_rounded, size: 28),
        ),
      );
    }

    if (items != null) {
      return const Center(
        child: Text(
          '남아 있는 카드가 없어요.',
          style: TextStyle(color: AppColors.textInverse),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = math.min(
          constraints.maxWidth,
          (constraints.maxHeight - 48) *
              widget.stack.latestCard.cardType.canvasAspectRatio,
        );
        return Center(
          child: Stack(
            alignment: Alignment.center,
            children: [
              StoryCardPreviewSurface(
                surfaceKey: Key(
                  'story-card-stack-${widget.stack.latestCard.id}',
                ),
                previewUrl: widget.stack.latestCard.previewUrl,
                width: cardWidth,
                cardType: widget.stack.latestCard.cardType,
                semanticsLabel: '스토리 카드',
              ),
              const SizedBox.square(
                dimension: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.textInverse,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _previous() {
    _pageController?.previousPage(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  void _next() {
    _pageController?.nextPage(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  List<StoryCardStackItem> _sortChronologically(
    List<StoryCardStackItem> items,
  ) {
    return [...items]..sort((left, right) {
      final submittedAtOrder = left.card.submittedAt.compareTo(
        right.card.submittedAt,
      );
      if (submittedAtOrder != 0) {
        return submittedAtOrder;
      }
      return left.card.id.compareTo(right.card.id);
    });
  }

  void _initializePageController(List<StoryCardStackItem> items) {
    if (_pageController != null) {
      return;
    }

    final firstUnreadIndex = items.indexWhere((item) => !item.isRead);
    _currentIndex = firstUnreadIndex >= 0 ? firstUnreadIndex : items.length - 1;
    _pageController = PageController(initialPage: _currentIndex);
    final initialItem = items[_currentIndex];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _acknowledgeIfNeeded(initialItem);
      }
    });
  }

  void _acknowledgeIfNeeded(StoryCardStackItem item) {
    if (item.isRead || !_acknowledgedCardIds.add(item.card.id)) {
      return;
    }
    unawaited(_acknowledge(item.card.id));
  }

  Future<void> _acknowledge(String cardId) async {
    try {
      final acknowledged = await ref
          .read(storyCardReadReceiptRepositoryProvider)
          .acknowledgeCard(cardId: cardId);
      if (!acknowledged) {
        _acknowledgedCardIds.remove(cardId);
      }
    } catch (_) {
      _acknowledgedCardIds.remove(cardId);
    }
  }

  Future<void> _feature(StoryCardStackItem item) async {
    if (_isMutating || !item.canFeature || item.isFeatured) {
      return;
    }
    setState(() => _isMutating = true);
    try {
      await ref
          .read(storyLoopWriteRepositoryProvider)
          .setFeaturedCard(item.card.id);
      _refreshCards();
    } catch (_) {
      if (mounted) {
        _showMessage('오늘의 사진을 선택하지 못했어요.');
      }
    } finally {
      if (mounted) {
        setState(() => _isMutating = false);
      }
    }
  }

  Future<void> _openActions(StoryCardStackItem item, int itemCount) async {
    final action = await showStoryCardActionSheet(
      context: context,
      cardId: item.card.id,
      showDelete: item.canDelete,
      showReport: !widget.stack.isMine,
    );
    if (!mounted || action == null) {
      return;
    }

    switch (action) {
      case StoryCardAction.download:
        await _download(item);
      case StoryCardAction.delete:
        await _delete(item, itemCount);
      case StoryCardAction.report:
        await _report(item);
    }
  }

  Future<void> _delete(StoryCardStackItem item, int itemCount) async {
    if (_isMutating || !item.canDelete) {
      return;
    }
    final confirmed = await showAppConfirmationDialog(
      context: context,
      title: '이 카드를 삭제할까?',
      message: '삭제한 카드는 다시 복구할 수 없어',
      confirmLabel: '삭제',
    );
    if (!confirmed || !mounted) {
      return;
    }

    setState(() => _isMutating = true);
    try {
      await ref.read(storyLoopWriteRepositoryProvider).deleteCard(item.card.id);
      if (!mounted) {
        return;
      }
      if (itemCount == 1) {
        _refreshCards();
        Navigator.of(context).pop();
        return;
      }
      if (_currentIndex == itemCount - 1) {
        _currentIndex -= 1;
      }
      _refreshCards();
    } catch (_) {
      if (mounted) {
        _showMessage('카드를 삭제하지 못했어요.');
      }
    } finally {
      if (mounted) {
        setState(() => _isMutating = false);
      }
    }
  }

  Future<void> _download(StoryCardStackItem item) async {
    if (_isMutating) {
      return;
    }
    setState(() => _isMutating = true);
    try {
      await ref.read(storyCardDownloaderProvider).download(item.card.id);
      if (mounted) {
        _showMessage('카드를 갤러리에 저장했어요.');
      }
    } on StoryCardDownloadException {
      if (mounted) {
        _showMessage('카드를 저장하지 못했어요.');
      }
    } catch (_) {
      if (mounted) {
        _showMessage('카드를 저장하지 못했어요.');
      }
    } finally {
      if (mounted) {
        setState(() => _isMutating = false);
      }
    }
  }

  Future<void> _report(StoryCardStackItem item) {
    return showSafetyReportSheet(
      context: context,
      target: SafetyReportTarget(
        type: SafetyReportTargetType.storyCard,
        id: item.card.id,
      ),
    );
  }

  void _refreshCards() {
    ref.invalidate(storyCardStackProvider(_request));
    ref.invalidate(todayStoryCardStacksProvider);
    ref.read(storyLoopRealtimeControllerProvider.notifier).refreshReadModels();
  }

  void _showMessage(String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }
}
