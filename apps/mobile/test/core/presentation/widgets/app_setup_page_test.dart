import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/core/presentation/widgets/app_action_button.dart';
import 'package:vinscent/core/presentation/widgets/app_setup_page.dart';

void main() {
  testWidgets('keeps the bottom action visible while setup content scrolls', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 480));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: AppSetupPage(
          header: const SizedBox(height: 56),
          bottomAction: AppActionButton(
            label: '계속',
            enabled: true,
            onPressed: () {},
          ),
          child: const SizedBox(height: 720),
        ),
      ),
    );

    expect(
      find.byKey(const Key('app-setup-page-scroll-view')),
      findsOneWidget,
    );
    expect(find.text('계속'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('bounds setup content width on a tablet viewport', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1024, 768));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        home: AppSetupPage(
          child: ColoredBox(
            key: Key('setup-content'),
            color: Colors.black,
            child: SizedBox(height: 100),
          ),
        ),
      ),
    );

    expect(tester.getSize(find.byKey(const Key('setup-content'))).width, 520);
  });

  testWidgets('shows the current setup step without text labels', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppSetupHeader(currentStep: 2, totalSteps: 3),
        ),
      ),
    );

    expect(find.byKey(const Key('app-setup-step-1')), findsOneWidget);
    expect(find.byKey(const Key('app-setup-step-2')), findsOneWidget);
    expect(find.byKey(const Key('app-setup-step-3')), findsOneWidget);
    expect(find.text('2 / 3'), findsNothing);
  });
}
