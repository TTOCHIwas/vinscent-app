import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../assets/app_icons.dart';

class CharacterPlaceholder extends StatelessWidget {
  const CharacterPlaceholder({super.key, this.label = '캐릭터', this.size = 140});

  final String label;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: SvgPicture.asset(
        AppIcons.appIcon,
        width: size,
        height: size,
        fit: BoxFit.contain,
        semanticsLabel: label,
      ),
    );
  }
}
