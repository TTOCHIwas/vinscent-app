import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

class KakaoLoginButton extends StatelessWidget {
  const KakaoLoginButton({super.key, required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '카카오 로그인',
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: Material(
          color: AppColors.kakaoContainer,
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
                    child: CustomPaint(painter: _KakaoSymbolPainter()),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '카카오 로그인',
                    style: AppTextStyles.socialButton.copyWith(
                      color: AppColors.kakaoContent,
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

class _KakaoSymbolPainter extends CustomPainter {
  const _KakaoSymbolPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(12, 2.49375)
      ..cubicTo(17.9663, 2.49375, 22.8, 6.3075, 22.8, 11.01)
      ..cubicTo(22.8, 15.7125, 17.9663, 19.5263, 12, 19.5263)
      ..cubicTo(11.3437, 19.5263, 10.7025, 19.4812, 10.08, 19.3912)
      ..cubicTo(9.4575, 19.83, 5.8575, 22.3575, 5.51625, 22.4062)
      ..cubicTo(5.51625, 22.4062, 5.3775, 22.4587, 5.2575, 22.3912)
      ..cubicTo(5.1375, 22.3237, 5.16, 22.14, 5.16, 22.14)
      ..cubicTo(5.1975, 21.8925, 6.0975, 18.795, 6.2625, 18.2212)
      ..cubicTo(3.22125, 16.7175, 1.2, 14.0475, 1.2, 11.0063)
      ..cubicTo(1.2, 6.30375, 6.03375, 2.49375, 12, 2.49375)
      ..close();

    canvas
      ..save()
      ..scale(size.width / 24, size.height / 24)
      ..drawPath(path, Paint()..color = Colors.black)
      ..restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
