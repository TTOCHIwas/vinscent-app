import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/onboarding/presentation/widgets/birth_date_step.dart';

void main() {
  testWidgets('explains an ineligible birthday without stating a target age', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BirthDateStep(
            birthDate: DateTime(2012, 7, 31),
            showEligibilityError: true,
            onTap: () {},
          ),
        ),
      ),
    );

    expect(find.text('현재 이용 기준에 해당하지 않아 가입할 수 없어'), findsOneWidget);
    expect(find.textContaining('14'), findsNothing);
  });
}
