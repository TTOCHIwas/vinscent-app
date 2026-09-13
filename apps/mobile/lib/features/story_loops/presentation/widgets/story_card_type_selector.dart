import 'package:flutter/material.dart';

import '../../data/story_card_type.dart';

class StoryCardTypeSelector extends StatelessWidget {
  const StoryCardTypeSelector({
    required this.onBack,
    required this.onSelected,
    super.key,
  });

  final VoidCallback onBack;
  final ValueChanged<StoryCardType> onSelected;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F5),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          tooltip: '뒤로',
        ),
        title: const Text('카드 선택'),
        centerTitle: true,
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: StoryCardType.values
                .map((type) {
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        right: type == StoryCardType.fourCutStrip ? 0 : 10,
                      ),
                      child: _StoryCardTypeOption(
                        key: ValueKey(
                          'story-card-type-${type.storageValue.replaceAll('_', '-')}',
                        ),
                        type: type,
                        onTap: () => onSelected(type),
                      ),
                    ),
                  );
                })
                .toList(growable: false),
          ),
        ),
      ),
    );
  }
}

class _StoryCardTypeOption extends StatelessWidget {
  const _StoryCardTypeOption({
    required this.type,
    required this.onTap,
    super.key,
  });

  final StoryCardType type;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final previewRatio = type.canvasAspectRatio;
    return Semantics(
      button: true,
      label: type.displayName,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(2),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            children: [
              AspectRatio(
                aspectRatio: 4 / 5,
                child: Center(
                  child: AspectRatio(
                    aspectRatio: previewRatio,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: const Color(0xFFD8D8D5)),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x16000000),
                            blurRadius: 8,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      child: CustomPaint(
                        painter: _StoryCardTypePreviewPainter(type),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                type.displayName,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: const Color(0xFF191918),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StoryCardTypePreviewPainter extends CustomPainter {
  const _StoryCardTypePreviewPainter(this.type);

  final StoryCardType type;

  @override
  void paint(Canvas canvas, Size size) {
    final layout = StoryCardLayout.fromSize(type: type, size: size);
    final photoPaint = Paint()..color = const Color(0xFFE5E5E1);
    for (final rect in layout.photoRects) {
      canvas.drawRect(rect, photoPaint);
    }
    final captionRect = layout.captionRect;
    if (captionRect != null) {
      final linePaint = Paint()
        ..color = const Color(0xFFC7C7C2)
        ..strokeWidth = 1;
      canvas.drawLine(
        Offset(captionRect.left, captionRect.center.dy),
        Offset(captionRect.right * 0.72, captionRect.center.dy),
        linePaint,
      );
    }
  }

  @override
  bool shouldRepaint(_StoryCardTypePreviewPainter oldDelegate) {
    return oldDelegate.type != type;
  }
}
