import 'package:flutter/material.dart';

class CharacterSpeechRow extends StatelessWidget {
  const CharacterSpeechRow({
    super.key,
    required this.character,
    required this.message,
    this.maximumContentWidth = 360,
    this.spacing = 12,
  });

  final Widget character;
  final Widget message;
  final double maximumContentWidth;
  final double spacing;

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
            SizedBox(width: spacing),
            Flexible(fit: FlexFit.loose, child: message),
          ],
        ),
      ),
    );
  }
}
