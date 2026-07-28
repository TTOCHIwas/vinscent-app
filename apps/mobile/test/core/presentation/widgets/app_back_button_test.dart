import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/core/presentation/widgets/app_back_button.dart';

void main() {
  testWidgets('uses the shared rounded back chevron', (tester) async {
    var pressed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppBackButton(
            onPressed: () => pressed = true,
            color: Colors.red,
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.chevron_left_rounded), findsOneWidget);
    final icon = tester.widget<Icon>(find.byIcon(Icons.chevron_left_rounded));
    expect(icon.size, isNull);
    expect(icon.color, isNull);

    final button = tester.widget<IconButton>(find.byType(IconButton));
    expect(button.iconSize, 24);
    expect(button.color, Colors.red);

    await tester.tap(find.byType(IconButton));
    expect(pressed, isTrue);
  });
}
