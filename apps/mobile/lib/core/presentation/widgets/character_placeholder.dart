import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

class CharacterPlaceholder extends StatelessWidget {
  const CharacterPlaceholder({super.key, this.label = '캐릭터', this.size = 140});

  final String label;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      color: AppColors.wireframePlaceholder,
      child: Text(label, style: AppTextStyles.homeCharacterLabel),
    );
  }
}
