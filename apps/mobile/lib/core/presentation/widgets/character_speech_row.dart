import 'package:flutter/material.dart';

class CharacterSpeechRow extends StatelessWidget {
  const CharacterSpeechRow({
    super.key,
    required this.character,
    required this.bubble,
    this.maximumContentWidth = 360,
  });

  final Widget character;
  final Widget bubble;
  final double maximumContentWidth;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maximumContentWidth),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            character,
            Flexible(fit: FlexFit.loose, child: bubble),
          ],
        ),
      ),
    );
  }
}
