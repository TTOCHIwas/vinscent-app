import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/core/presentation/widgets/app_loading_indicator.dart';
import 'package:vinscent/core/theme/app_colors.dart';

void main() {
  testWidgets('uses a neutral color for general loading', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: SizedBox.square(
            dimension: 24,
            child: AppLoadingIndicator(strokeWidth: 2),
          ),
        ),
      ),
    );

    final indicator = tester.widget<CircularProgressIndicator>(
      find.byType(CircularProgressIndicator),
    );
    expect(indicator.color, AppColors.textMuted);
    expect(indicator.strokeWidth, 2);
    expect(
      tester.getSize(find.byType(AppLoadingIndicator)),
      const Size.square(24),
    );
  });
}
