import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/onboarding/presentation/onboarding_screen.dart';

void main() {
  testWidgets('presents nickname as the first focused setup step', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: OnboardingScreen())),
    );

    expect(find.text('어떻게 불러주면 될까?'), findsOneWidget);
    expect(find.text('다음'), findsOneWidget);
    expect(find.byKey(const Key('app-setup-step-1')), findsOneWidget);

    final textField = tester.widget<TextField>(find.byType(TextField));
    expect(textField.decoration?.filled, isTrue);
    expect(textField.decoration?.border, isA<OutlineInputBorder>());
  });

  testWidgets('explains the birthday calendar purpose on the second step', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: OnboardingScreen())),
    );

    await tester.enterText(find.byType(TextField), '또치');
    await tester.pump();
    await tester.tap(find.text('다음'));
    await tester.pumpAndSettle();

    expect(find.text('생일은 언제야?'), findsOneWidget);
    expect(find.text('생일은 둘의 캘린더에 기본 일정으로 표시돼'), findsOneWidget);
    expect(find.text('완료'), findsOneWidget);
    expect(
      find.byKey(const Key('onboarding-birth-date-field')),
      findsOneWidget,
    );
  });

  testWidgets('does not overflow with large text on a compact screen', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 568),
              textScaler: TextScaler.linear(1.6),
            ),
            child: const OnboardingScreen(),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('다음'), findsOneWidget);
  });
}
