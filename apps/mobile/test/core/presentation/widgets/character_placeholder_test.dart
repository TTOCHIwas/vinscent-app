import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/core/presentation/widgets/character_placeholder.dart';

void main() {
  testWidgets('shows the app icon as the default couple character', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(child: CharacterPlaceholder(label: '기본 캐릭터', size: 120)),
      ),
    );

    expect(find.byType(SvgPicture), findsOneWidget);
    expect(find.text('기본 캐릭터'), findsNothing);
    expect(
      tester.getSize(find.byType(CharacterPlaceholder)),
      const Size.square(120),
    );
  });
}
