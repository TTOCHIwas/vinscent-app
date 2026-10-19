import 'package:flutter/cupertino.dart';
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
            child: AppLoadingIndicator(radius: 8),
          ),
        ),
      ),
    );

    final indicator = tester.widget<CupertinoActivityIndicator>(
      find.byType(CupertinoActivityIndicator),
    );
    expect(indicator.color, AppColors.textMuted);
    expect(indicator.radius, 8);
    expect(
      tester.getSize(find.byType(AppLoadingIndicator)),
      const Size.square(24),
    );
  });
}
