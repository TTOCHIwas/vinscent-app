import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/core/presentation/widgets/app_initial_reveal.dart';

void main() {
  testWidgets('reveals its child once after the first frame', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AppInitialReveal(
          duration: Duration(milliseconds: 220),
          child: Text('calendar content'),
        ),
      ),
    );

    final reveal = find.byType(AppInitialReveal);
    FadeTransition fade() => tester.widget<FadeTransition>(
      find.descendant(of: reveal, matching: find.byType(FadeTransition)),
    );

    expect(fade().opacity.value, 0);

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 110));

    expect(fade().opacity.value, greaterThan(0));
    expect(fade().opacity.value, lessThan(1));

    await tester.pumpAndSettle();

    expect(fade().opacity.value, 1);
    expect(find.text('calendar content'), findsOneWidget);
  });

  testWidgets('shows content immediately when animations are disabled', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: const AppInitialReveal(child: Text('calendar content')),
      ),
    );

    final fade = tester.widget<FadeTransition>(find.byType(FadeTransition));
    expect(fade.opacity.value, 1);
  });
}
