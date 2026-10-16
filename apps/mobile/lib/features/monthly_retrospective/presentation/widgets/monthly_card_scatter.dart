import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../story_loops/presentation/widgets/story_card_preview_surface.dart';
import '../../data/monthly_retrospective.dart';
import '../../data/monthly_retrospective_repository.dart';

typedef MonthlyScatterCard = ({DateTime date, RetrospectiveCard card});

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
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final availableWidth = math.min(constraints.maxWidth, 440.0);
              final count = widget.cards.length;
              final rows = widget.compact ? (count / 3).ceil() : 1;
              final naturalHeight = widget.compact
                  ? availableWidth *
                        (rows == 1
                            ? 0.64
                            : rows == 2
                            ? 0.82
                            : 0.96)
                  : availableWidth * 0.78;
              final height = math.min(
                naturalHeight,
                widget.maxHeight ?? naturalHeight,
              );
              final width = availableWidth * height / naturalHeight;
              final cardHeight = width * (widget.compact ? 0.5 : 0.66);
              return Center(
                child: SizedBox(
                  key: const Key('monthly-card-scatter'),
                  width: width,
                  height: height,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      for (var index = 0; index < count; index++)
                        _card(
                          index,
                          width,
                          height,
                          cardHeight,
                          snapshot.data ?? const {},
                        ),
                    ],
                  ),
                ),
              );
            },
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

  Widget _card(
    int index,
    double width,
    double height,
    double cardHeight,
    Map<String, String> urls,
  ) {
    final entry = widget.cards[index];
    final count = widget.cards.length;
    final cardWidth = math.min(
      cardHeight * entry.card.aspectRatio,
      width * 0.62,
    );
    final actualHeight = cardWidth / entry.card.aspectRatio;
    const angles = [-0.16, 0.12, -0.06, 0.09, -0.12, 0.17, -0.08, 0.06];
    final columns = widget.compact ? math.min(3, count) : count;
    final rows = (count / columns).ceil();
    final row = index ~/ columns;
    final column = index % columns;
    final rowCards = math.min(columns, count - row * columns);
    const offsets = [-0.02, 0.025, -0.015, 0.025, -0.025, 0.02, -0.015, 0.01];
    final pileX =
        (rowCards == 1 ? 0.5 : 0.26 + column * 0.48 / (rowCards - 1)) +
        offsets[index % offsets.length];
    final pairSpacing =
        widget.cards.fold<double>(
          0,
          (sum, entry) =>
              sum + math.min(cardHeight * entry.card.aspectRatio, width * 0.62),
        ) *
        0.4;
    final x = widget.compact
        ? pileX
        : count == 1
        ? 0.5
        : 0.5 + (column / (columns - 1) - 0.5) * pairSpacing / width;
    final y =
        (rows == 1 ? 0.5 : 0.29 + row * 0.42 / (rows - 1)) +
        offsets[(index + 3) % offsets.length];
    return Positioned(
      left: width * x - cardWidth / 2,
      top: height * y - actualHeight / 2 + (index.isEven ? -3 : 3),
      child: Transform.rotate(
        angle: angles[index % angles.length],
        child: StoryCardPreviewSurface(
          surfaceKey: ValueKey('monthly-card-${entry.card.id}'),
          previewUrl: urls[entry.card.previewPath],
          width: cardWidth,
          cardType: entry.card.cardType,
          layoutVersion: entry.card.layoutVersion,
          aspectRatioOverride: entry.card.aspectRatio,
          semanticsLabel: '${entry.date.month}월 ${entry.date.day}일 카드 상세 보기',
          onTap: () => widget.onOpenCard(entry),
        ),
      ),
    );
  }
}
