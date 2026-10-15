import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../home/presentation/widgets/home_hanging_story_cards.dart';
import '../../../story_loops/presentation/widgets/story_card_preview_surface.dart';
import '../../data/monthly_retrospective.dart';
import '../../data/monthly_retrospective_repository.dart';

typedef MonthlyClotheslineCard = ({DateTime date, RetrospectiveCard card});

class MonthlyCardClotheslines extends ConsumerStatefulWidget {
  const MonthlyCardClotheslines({
    super.key,
    required this.cards,
    required this.onOpenRecord,
    this.compact = false,
    this.showDates = false,
  });

  final List<MonthlyClotheslineCard> cards;
  final ValueChanged<DateTime> onOpenRecord;
  final bool compact;
  final bool showDates;

  @override
  ConsumerState<MonthlyCardClotheslines> createState() =>
      _MonthlyCardClotheslinesState();
}

class _MonthlyCardClotheslinesState
    extends ConsumerState<MonthlyCardClotheslines> {
  MonthlyRetrospectiveRepository? _repository;
  Future<Map<String, String>>? _urls;

  @override
  void didUpdateWidget(MonthlyCardClotheslines oldWidget) {
    super.didUpdateWidget(oldWidget);
    _urls = null;
  }

  @override
  Widget build(BuildContext context) {
    final repository = ref.watch(monthlyRetrospectiveRepositoryProvider);
    if (_urls == null || !identical(repository, _repository)) {
      _repository = repository;
      _urls = repository.previewUrls(widget.cards.map((entry) => entry.card));
    }
    return FutureBuilder<Map<String, String>>(
      future: _urls,
      builder: (context, snapshot) => LayoutBuilder(
        builder: (context, constraints) {
          final columns = widget.compact
              ? (constraints.maxWidth < 340 ? 3 : 4)
              : math.min(2, widget.cards.length);
          if (columns == 0) return const SizedBox.shrink();
          return Column(
            children: [
              for (var start = 0; start < widget.cards.length; start += columns)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _row(
                    widget.cards.sublist(
                      start,
                      math.min(start + columns, widget.cards.length),
                    ),
                    columns,
                    snapshot.data ?? const {},
                  ),
                ),
              if (snapshot.hasError)
                TextButton(
                  onPressed: () => setState(() {
                    _urls = repository.previewUrls(
                      widget.cards.map((entry) => entry.card),
                    );
                  }),
                  child: const Text('카드 미리보기 다시 불러오기'),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _row(
    List<MonthlyClotheslineCard> cards,
    int columns,
    Map<String, String> urls,
  ) => Column(
    children: [
      HomeHangingStoryCards.gallery(
        size: widget.compact
            ? HomeHangingStoryCardSize.compact
            : HomeHangingStoryCardSize.standard,
        slotsPerRow: columns,
        cardBuilders: [
          for (final entry in cards)
            (context, width) => Center(
              child: StoryCardPreviewSurface(
                surfaceKey: ValueKey('monthly-card-${entry.card.id}'),
                previewUrl: urls[entry.card.previewPath],
                width: width * entry.card.aspectRatio / 0.8,
                cardType: entry.card.cardType,
                layoutVersion: entry.card.layoutVersion,
                aspectRatioOverride: entry.card.aspectRatio,
                semanticsLabel:
                    '${entry.date.month}월 ${entry.date.day}일 카드, 그날의 기록 보기',
                onTap: () => widget.onOpenRecord(entry.date),
              ),
            ),
        ],
      ),
      if (widget.showDates)
        ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: HomeHangingStoryCards.maximumContentWidth,
          ),
          child: Row(
            children: [
              for (var index = 0; index < columns; index++)
                Expanded(
                  child: Text(
                    index < cards.length
                        ? '${cards[index].date.month}.${cards[index].date.day}'
                        : '',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.homeBody.copyWith(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
            ],
          ),
        ),
    ],
  );
}
