import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class CalendarImportantDateUnderline extends StatelessWidget {
  const CalendarImportantDateUnderline({super.key});

  static const size = Size(22, 5);

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
      child: ExcludeSemantics(
        child: CustomPaint(size: size, painter: _HandDrawnUnderlinePainter()),
      ),
    );
  }
}

class _HandDrawnUnderlinePainter extends CustomPainter {
  const _HandDrawnUnderlinePainter();

  static final _outline = Path()
    ..moveTo(0.02, 0.23)
    ..cubicTo(0.04, 0.14, 0.07, 0.21, 0.09, 0.34)
    ..lineTo(0.14, 0.61)
    ..cubicTo(0.15, 0.65, 0.16, 0.64, 0.18, 0.56)
    ..lineTo(0.25, 0.25)
    ..cubicTo(0.28, 0.13, 0.31, 0.19, 0.34, 0.29)
    ..lineTo(0.47, 0.62)
    ..cubicTo(0.48, 0.65, 0.49, 0.64, 0.50, 0.59)
    ..lineTo(0.64, 0.13)
    ..cubicTo(0.67, 0.03, 0.71, 0.08, 0.74, 0.19)
    ..lineTo(0.82, 0.47)
    ..cubicTo(0.83, 0.51, 0.84, 0.51, 0.86, 0.46)
    ..lineTo(0.94, 0.25)
    ..cubicTo(0.97, 0.18, 1.00, 0.22, 0.99, 0.34)
    ..cubicTo(0.98, 0.41, 0.97, 0.47, 0.95, 0.51)
    ..lineTo(0.85, 0.82)
    ..cubicTo(0.83, 0.89, 0.81, 0.88, 0.79, 0.82)
    ..lineTo(0.69, 0.48)
    ..cubicTo(0.68, 0.44, 0.67, 0.45, 0.65, 0.51)
    ..lineTo(0.50, 0.96)
    ..cubicTo(0.49, 1.00, 0.47, 0.99, 0.45, 0.94)
    ..lineTo(0.28, 0.56)
    ..cubicTo(0.27, 0.53, 0.26, 0.55, 0.25, 0.59)
    ..lineTo(0.17, 0.94)
    ..cubicTo(0.15, 1.00, 0.13, 0.98, 0.11, 0.89)
    ..lineTo(0.01, 0.43)
    ..cubicTo(0.00, 0.36, 0.00, 0.29, 0.02, 0.23)
    ..close();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width, size.height);
    canvas.drawPath(_outline, Paint()..color = AppColors.brandAccent);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _HandDrawnUnderlinePainter oldDelegate) => false;
}
