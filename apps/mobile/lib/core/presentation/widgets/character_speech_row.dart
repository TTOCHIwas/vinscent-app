import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

class CharacterSpeechRow extends StatelessWidget {
  const CharacterSpeechRow({
    super.key,
    required this.character,
    required this.message,
    this.maximumContentWidth = 360,
    this.spacing = 12,
    this.expandMessage = false,
    this.messageLeadingExtent = 0,
  });

  final Widget character;
  final Widget message;
  final double maximumContentWidth;
  final double spacing;
  final bool expandMessage;
  final double messageLeadingExtent;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maximumContentWidth),
        child: Row(
          mainAxisSize: expandMessage ? MainAxisSize.max : MainAxisSize.min,
          crossAxisAlignment: messageLeadingExtent == 0
              ? CrossAxisAlignment.center
              : CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            _ContentCenterBaseline(child: character),
            SizedBox(width: spacing),
            Flexible(
              fit: expandMessage ? FlexFit.tight : FlexFit.loose,
              child: _ContentCenterBaseline(
                leadingExtent: messageLeadingExtent,
                child: Align(
                  key: const Key('character-speech-message-area'),
                  alignment: Alignment.center,
                  heightFactor: 1,
                  child: message,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContentCenterBaseline extends SingleChildRenderObjectWidget {
  const _ContentCenterBaseline({this.leadingExtent = 0, required super.child});

  final double leadingExtent;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderContentCenterBaseline(leadingExtent);

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderContentCenterBaseline renderObject,
  ) => renderObject.leadingExtent = leadingExtent;
}

class _RenderContentCenterBaseline extends RenderProxyBox {
  _RenderContentCenterBaseline(this._leadingExtent);

  double _leadingExtent;

  set leadingExtent(double value) {
    if (_leadingExtent == value) return;
    _leadingExtent = value;
    markNeedsLayout();
  }

  @override
  double computeDistanceToActualBaseline(TextBaseline baseline) =>
      // 상단 부가 영역을 제외한 본문 중심을 정렬선으로 사용한다.
      (size.height + _leadingExtent) / 2;

  @override
  double computeDryBaseline(
    BoxConstraints constraints,
    TextBaseline baseline,
  ) => (getDryLayout(constraints).height + _leadingExtent) / 2;
}
