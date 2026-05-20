import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

class AppleLoginButton extends StatelessWidget {
  const AppleLoginButton({super.key, required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Apple로 로그인',
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: Material(
          color: AppColors.appleContainer,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(12),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: Center(
                      child: SizedBox(
                        width: 18,
                        height: 22,
                        child: CustomPaint(
                          painter: _AppleSymbolPainter(
                            color: AppColors.appleContent,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Apple로 로그인',
                    style: AppTextStyles.socialButton.copyWith(
                      color: AppColors.appleContent,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AppleSymbolPainter extends CustomPainter {
  const _AppleSymbolPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width * .50779, size.height * .28732)
      ..cubicTo(
        size.width * .4593,
        size.height * .28732,
        size.width * .38424,
        size.height * .24241,
        size.width * .30519,
        size.height * .24404,
      )
      ..cubicTo(
        size.width * .2009,
        size.height * .24512,
        size.width * .10525,
        size.height * .29328,
        size.width * .05145,
        size.height * .36957,
      )
      ..cubicTo(
        size.width * -.05683,
        size.height * .5227,
        size.width * .02355,
        size.height * .74888,
        size.width * .12916,
        size.height * .87333,
      )
      ..cubicTo(
        size.width * .18097,
        size.height * .93394,
        size.width * .24209,
        size.height * 1.00211,
        size.width * .32313,
        size.height * .99995,
      )
      ..cubicTo(
        size.width * .40084,
        size.height * .99724,
        size.width * .43007,
        size.height * .95883,
        size.width * .52439,
        size.height * .95883,
      )
      ..cubicTo(
        size.width * .61805,
        size.height * .95883,
        size.width * .64462,
        size.height * .99995,
        size.width * .72699,
        size.height * .99833,
      )
      ..cubicTo(
        size.width * .81069,
        size.height * .99724,
        size.width * .86383,
        size.height * .93664,
        size.width * .91498,
        size.height * .8755,
      )
      ..cubicTo(
        size.width * .97409,
        size.height * .80515,
        size.width * .99867,
        size.height * .73698,
        size.width,
        size.height * .73319,
      )
      ..cubicTo(
        size.width * .99801,
        size.height * .73265,
        size.width * .83726,
        size.height * .68233,
        size.width * .83526,
        size.height * .53082,
      )
      ..cubicTo(
        size.width * .83394,
        size.height * .4042,
        size.width * .96214,
        size.height * .3436,
        size.width * .96812,
        size.height * .34089,
      )
      ..cubicTo(
        size.width * .89505,
        size.height * .25378,
        size.width * .78279,
        size.height * .24404,
        size.width * .7436,
        size.height * .24187,
      )
      ..cubicTo(
        size.width * .6413,
        size.height * .23538,
        size.width * .55561,
        size.height * .28732,
        size.width * .50779,
        size.height * .28732,
      )
      ..close()
      ..moveTo(size.width * .68049, size.height * .15962)
      ..cubicTo(
        size.width * .72367,
        size.height * .11742,
        size.width * .75223,
        size.height * .05844,
        size.width * .74426,
        0,
      )
      ..cubicTo(
        size.width * .68249,
        size.height * .00216,
        size.width * .60809,
        size.height * .03355,
        size.width * .56359,
        size.height * .07575,
      )
      ..cubicTo(
        size.width * .52373,
        size.height * .11309,
        size.width * .48919,
        size.height * .17315,
        size.width * .49849,
        size.height * .23051,
      )
      ..cubicTo(
        size.width * .56691,
        size.height * .23484,
        size.width * .63732,
        size.height * .20183,
        size.width * .68049,
        size.height * .15962,
      )
      ..close();

    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _AppleSymbolPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
