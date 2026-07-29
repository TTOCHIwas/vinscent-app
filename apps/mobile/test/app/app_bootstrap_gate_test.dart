import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/app/app_bootstrap_gate.dart';

void main() {
  testWidgets('shows a stable loading surface until initialization completes', (
    tester,
  ) async {
    final initialization = Completer<void>();

    await tester.pumpWidget(
      AppBootstrapGate(
        initialize: () => initialization.future,
        child: const MaterialApp(home: Text('ready')),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('ready'), findsNothing);

    initialization.complete();
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('ready'), findsOneWidget);
  });

  testWidgets('offers a retry without exposing bootstrap errors', (
    tester,
  ) async {
    final retryInitialization = Completer<void>();
    var attempts = 0;

    await tester.pumpWidget(
      AppBootstrapGate(
        initialize: () {
          attempts += 1;
          if (attempts == 1) {
            return Future<void>.error(StateError('firebase secret detail'));
          }
          return retryInitialization.future;
        },
        child: const MaterialApp(home: Text('ready')),
      ),
    );
    await tester.pump();

    expect(find.text('앱을 시작하지 못했어요'), findsOneWidget);
    expect(find.text('firebase secret detail'), findsNothing);

    await tester.tap(find.text('다시 시도'));
    await tester.pump();

    expect(attempts, 2);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    retryInitialization.complete();
    await tester.pumpAndSettle();

    expect(find.text('ready'), findsOneWidget);
  });
}
