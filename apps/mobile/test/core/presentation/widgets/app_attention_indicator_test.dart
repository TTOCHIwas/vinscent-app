import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/core/presentation/widgets/app_attention_indicator.dart';
import 'package:vinscent/core/theme/app_colors.dart';

void main() {
  testWidgets('renders a semantic brand-colored dot only when visible', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: AppAttentionIndicator(
            isVisible: true,
            semanticsLabel: '새 녹음 있음',
            child: Icon(Icons.mic_none_rounded),
          ),
        ),
      ),
    );

    final badge = tester.widget<Badge>(find.byType(Badge));
    expect(badge.backgroundColor, AppColors.attention);
    expect(badge.isLabelVisible, isTrue);
    expect(find.bySemanticsLabel('새 녹음 있음'), findsOneWidget);
  });
}
