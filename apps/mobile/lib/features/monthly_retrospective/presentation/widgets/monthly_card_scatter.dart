import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../story_loops/presentation/widgets/story_card_preview_surface.dart';
import '../../data/monthly_retrospective.dart';
import '../../data/monthly_retrospective_repository.dart';
import 'monthly_card_scatter_layout.dart';

typedef MonthlyScatterCard = ({DateTime date, RetrospectiveCard card});
typedef _ScatterUrls = ({Map<String, String> values, bool pending});

List<MonthlyScatterCard> selectMonthlyScatterCards(
  List<RetrospectiveGalleryCard> gallery,
) {
  final sorted = [...gallery]
    ..sort((a, b) {
      final date = a.date.compareTo(b.date);
      if (date != 0) return date;
      final author = a.authorUserId.compareTo(b.authorUserId);
      return author != 0 ? author : a.id.compareTo(b.id);
    });
  final limit = switch (sorted.length) {
    <= 3 => sorted.length,
    <= 9 => 4,
    <= 19 => 6,
    _ => 8,
  };
  if (sorted.length <= limit) {
    return [for (final card in sorted) (date: card.date, card: card)];
  }
  final selected = <RetrospectiveGalleryCard>[];
  final authors = sorted.map((card) => card.authorUserId).toSet().toList();
  for (final author in authors) {
    final cards = sorted.where((card) => card.authorUserId == author).toList();
    final count = math.min(limit ~/ authors.length, cards.length);
    for (var index = 0; index < count; index++) {
      selected.add(
        cards[count == 1
            ? 0
            : (index * (cards.length - 1) / (count - 1)).round()],
      );
    }
  }
  for (final card in sorted) {
    if (selected.length == limit) break;
    if (!selected.contains(card)) selected.add(card);
  }
  selected.sort((a, b) => sorted.indexOf(a).compareTo(sorted.indexOf(b)));
  return [for (final card in selected) (date: card.date, card: card)];
}

class MonthlyCardScatter extends ConsumerStatefulWidget {
  const MonthlyCardScatter({
    super.key,
    required this.cards,
    required this.onOpenCard,
    this.compact = false,
    this.maxHeight,
  });

  final List<MonthlyScatterCard> cards;
  final ValueChanged<MonthlyScatterCard> onOpenCard;
  final bool compact;
  final double? maxHeight;

  @override
  ConsumerState<MonthlyCardScatter> createState() => _MonthlyCardScatterState();
}

class _MonthlyCardScatterState extends ConsumerState<MonthlyCardScatter> {
  MonthlyRetrospectiveRepository? _repository;
  Future<Map<String, String>>? _urls;

  @override
  void didUpdateWidget(MonthlyCardScatter oldWidget) {
    super.didUpdateWidget(oldWidget);
    _urls = null;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.cards.isEmpty) return const SizedBox.shrink();
    final repository = ref.watch(monthlyRetrospectiveRepositoryProvider);
    if (_urls == null || !identical(repository, _repository)) {
      _repository = repository;
      _urls = repository.previewUrls(widget.cards.map((entry) => entry.card));
    }
    return FutureBuilder<Map<String, String>>(
      future: _urls,
      builder: (context, snapshot) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            fit: FlexFit.loose,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final availableWidth = math.min(constraints.maxWidth, 440.0);
                if (widget.compact) {
                  return _compactScatter(
                    availableWidth,
                    math.min(
                      widget.maxHeight ?? double.infinity,
                      constraints.maxHeight,
                    ),
                    (
                      values: snapshot.data ?? const {},
                      pending:
                          snapshot.connectionState == ConnectionState.waiting,
                    ),
                  );
                }
                final count = widget.cards.length;
                final naturalHeight = availableWidth * 0.78;
                final height = math.min(
                  naturalHeight,
                  math.min(
                    widget.maxHeight ?? naturalHeight,
                    constraints.maxHeight,
                  ),
                );
                final width = availableWidth * height / naturalHeight;
                final cardHeight = width * 0.66;
                return Center(
                  heightFactor: 1,
                  child: SizedBox(
                    key: const Key('monthly-card-scatter'),
                    width: width,
                    height: height,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        for (var index = 0; index < count; index++)
                          _card(index, width, height, cardHeight, (
                            values: snapshot.data ?? const {},
                            pending:
                                snapshot.connectionState ==
                                ConnectionState.waiting,
                          )),
                      ],
                    ),
                  ),
                );
              },
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
      ),
    );
  }

  Widget _compactScatter(
    double availableWidth,
    double availableHeight,
    _ScatterUrls urls,
  ) {
    final layout = MonthlyCardScatterLayout.compact(
      width: availableWidth,
      aspectRatios: [for (final entry in widget.cards) entry.card.aspectRatio],
    );
    final scale = math.min(
      1.0,
      math.min(
        availableWidth / layout.size.width,
        availableHeight / layout.size.height,
      ),
    );
    return Center(
      heightFactor: 1,
      child: SizedBox(
        key: const Key('monthly-card-scatter'),
        width: layout.size.width * scale,
        height: layout.size.height * scale,
        child: FittedBox(
          child: SizedBox.fromSize(
            size: layout.size,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                for (var index = 0; index < layout.placements.length; index++)
                  Positioned.fromRect(
                    rect: layout.placements[index].rect,
                    child: Transform.rotate(
                      angle: layout.placements[index].angle,
                      child: _surface(
                        widget.cards[index],
                        layout.placements[index].rect.width,
                        urls,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _card(
    int index,
    double width,
    double height,
    double cardHeight,
    _ScatterUrls urls,
  ) {
    final entry = widget.cards[index];
    final count = widget.cards.length;
    final cardWidth = math.min(
      cardHeight * entry.card.aspectRatio,
      width * 0.62,
    );
    final actualHeight = cardWidth / entry.card.aspectRatio;
    const angles = [-0.16, 0.12, -0.06, 0.09, -0.12, 0.17, -0.08, 0.06];
    final columns = count;
    final column = index % columns;
    const offsets = [-0.02, 0.025, -0.015, 0.025, -0.025, 0.02, -0.015, 0.01];
    final pairSpacing =
        widget.cards.fold<double>(
          0,
          (sum, entry) =>
              sum + math.min(cardHeight * entry.card.aspectRatio, width * 0.62),
        ) *
        0.4;
    final x = count == 1
        ? 0.5
        : 0.5 + (column / (columns - 1) - 0.5) * pairSpacing / width;
    final y = 0.5 + offsets[(index + 3) % offsets.length];
    return Positioned(
      left: width * x - cardWidth / 2,
      top: height * y - actualHeight / 2 + (index.isEven ? -3 : 3),
      child: Transform.rotate(
        angle: angles[index % angles.length],
        child: _surface(entry, cardWidth, urls),
      ),
    );
  }

  Widget _surface(
    MonthlyScatterCard entry,
    double cardWidth,
    _ScatterUrls urls,
  ) => StoryCardPreviewSurface(
    surfaceKey: ValueKey('monthly-card-${entry.card.id}'),
    previewUrl: urls.values[entry.card.previewPath],
    isLoading: urls.pending && !urls.values.containsKey(entry.card.previewPath),
    width: cardWidth,
    cardType: entry.card.cardType,
    layoutVersion: entry.card.layoutVersion,
    aspectRatioOverride: entry.card.aspectRatio,
    semanticsLabel: '${entry.date.month}월 ${entry.date.day}일 카드 상세 보기',
    onTap: () => widget.onOpenCard(entry),
  );
}
