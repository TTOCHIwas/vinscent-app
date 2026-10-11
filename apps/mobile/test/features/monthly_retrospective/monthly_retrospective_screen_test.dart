import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/core/theme/app_colors.dart';
import 'package:vinscent/features/monthly_retrospective/application/monthly_retrospective_controller.dart';
import 'package:vinscent/features/monthly_retrospective/data/monthly_retrospective.dart';
import 'package:vinscent/features/monthly_retrospective/presentation/monthly_retrospective_screen.dart';

void main() {
  testWidgets('shows light overview and omits conversation without shared answers', (tester) async {
    await tester.pumpWidget(ProviderScope(overrides: [
      monthlyRetrospectiveControllerProvider.overrideWith(_Controller.new),
    ], child: const MaterialApp(home: Scaffold(body: MonthlyRetrospectiveScreen()))));
    await tester.pumpAndSettle();
    expect(find.text('지난달 이야기'), findsOneWidget);
    expect(find.text('그날의 기억'), findsOneWidget);
    expect(find.text('우리의 답'), findsNothing);
    expect(find.text('집계 불가'), findsOneWidget);
    expect(find.text('남긴 카드'), findsOneWidget);
    expect(tester.widget<Material>(find.byKey(const Key('monthly-retrospective-surface'))).color, AppColors.background);
    await tester.tap(find.text('마음 남기기'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
    await tester.enterText(find.byType(TextField), '다음 달 같이 산책하기');
    await tester.tap(find.text('지난달 이야기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('마음 남기기'));
    await tester.pumpAndSettle();
    expect(find.text('다음 달 같이 산책하기'), findsOneWidget);
  });
}

class _Controller extends MonthlyRetrospectiveController {
  @override
  Future<MonthlyRetrospective> build() async => MonthlyRetrospective.fromJson({
    'couple_id': 'c1', 'month': '2026-09-01', 'available_until': '2026-11-01T00:00:00Z',
    'recorded_days': 2, 'card_count': null, 'card_count_complete': false,
    'completed_questions': 0, 'has_records': true, 'ai_enabled': false,
    'title': '우리의 9월', 'summary': null, 'content_status': 'basic', 'moments': [],
    'conversation': null,
    'reflection': {'id': 'r1', 'question': '다음 달 함께하고 싶은 일은?', 'source': 'basic', 'my_answer': null, 'partner_answer': null, 'partner_answer_exists': false, 'version': 0},
  });
}
