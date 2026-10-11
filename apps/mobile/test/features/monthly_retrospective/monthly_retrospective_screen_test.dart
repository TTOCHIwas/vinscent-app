import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/core/theme/app_colors.dart';
import 'package:vinscent/features/monthly_retrospective/application/monthly_retrospective_controller.dart';
import 'package:vinscent/features/monthly_retrospective/data/monthly_retrospective.dart';
import 'package:vinscent/features/monthly_retrospective/presentation/monthly_retrospective_screen.dart';

void main() {
  testWidgets(
    'editing preserves its version until a conflict is explicitly resolved',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final container = ProviderContainer(
        overrides: [
          monthlyRetrospectiveControllerProvider.overrideWith(
            _SavedController.new,
          ),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(body: MonthlyRetrospectiveScreen()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('마음 남기기'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('수정하기'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '내가 작성 중인 초안');
      final controller =
          container.read(monthlyRetrospectiveControllerProvider.notifier)
              as _Controller;
      controller.replace(_fixture(answer: '다른 기기의 답변', version: 2));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '내가 작성 중인 초안',
      );
      await tester.tap(find.widgetWithText(FilledButton, '마음 남기기'));
      await tester.pumpAndSettle();
      expect(controller.savedVersions, [1]);
      expect(find.text('다른 기기의 답변'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      await tester.tap(find.text('내 초안으로 다시 저장'));
      await tester.pumpAndSettle();
      expect(controller.savedVersions, [1, 2]);
      expect(find.byType(TextField), findsNothing);
      expect(find.text('내가 작성 중인 초안'), findsOneWidget);
    },
  );
  testWidgets('discard restores the saved answer when the page is kept alive', (
    tester,
  ) async {
    final key = GlobalKey<MonthlyRetrospectiveScreenState>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          monthlyRetrospectiveControllerProvider.overrideWith(
            _SavedController.new,
          ),
        ],
        child: MaterialApp(
          home: Scaffold(body: MonthlyRetrospectiveScreen(key: key)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('마음 남기기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('수정하기'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '버릴 초안');
    final leave = key.currentState!.confirmLeave();
    await tester.pumpAndSettle();
    await tester.tap(find.text('닫기'));
    await tester.pumpAndSettle();
    expect(await leave, isTrue);
    await tester.tap(find.text('수정하기'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '이전 답변',
    );
  });
  testWidgets('editing uses the latest answer from another device', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        monthlyRetrospectiveControllerProvider.overrideWith(
          _SavedController.new,
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(body: MonthlyRetrospectiveScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('마음 남기기'));
    await tester.pumpAndSettle();
    (container.read(monthlyRetrospectiveControllerProvider.notifier)
            as _Controller)
        .replace(_fixture(answer: '새 답변', version: 2));
    await tester.pumpAndSettle();
    await tester.tap(find.text('수정하기'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '새 답변',
    );
  });
  testWidgets(
    'shows light overview and omits conversation without shared answers',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            monthlyRetrospectiveControllerProvider.overrideWith(
              _Controller.new,
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(body: MonthlyRetrospectiveScreen()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('지난달 이야기'), findsOneWidget);
      expect(find.text('그날의 기억'), findsOneWidget);
      expect(find.text('우리의 답'), findsNothing);
      expect(find.text('집계 불가'), findsOneWidget);
      expect(find.text('남긴 카드'), findsOneWidget);
      expect(
        tester
            .widget<Material>(
              find.byKey(const Key('monthly-retrospective-surface')),
            )
            .color,
        AppColors.background,
      );
      await tester.tap(find.text('마음 남기기'));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsOneWidget);
      await tester.enterText(find.byType(TextField), '다음 달 같이 산책하기');
      await tester.tap(find.text('지난달 이야기'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('마음 남기기'));
      await tester.pumpAndSettle();
      expect(find.text('다음 달 같이 산책하기'), findsOneWidget);
    },
  );
}

class _Controller extends MonthlyRetrospectiveController {
  final savedVersions = <int>[];
  void replace(MonthlyRetrospective data) => state = AsyncData(data);
  @override
  Future<void> save(RetrospectiveReflection reflection, String text) async {
    savedVersions.add(reflection.version);
    if (reflection.version != state.requireValue.reflection!.version) {
      throw StateError('version conflict');
    }
    replace(_fixture(answer: text, version: reflection.version + 1));
  }

  @override
  Future<MonthlyRetrospective> build() async => _fixture();
}

class _SavedController extends _Controller {
  @override
  Future<MonthlyRetrospective> build() async =>
      _fixture(answer: '이전 답변', version: 1);
}

MonthlyRetrospective _fixture({String? answer, int version = 0}) =>
    MonthlyRetrospective.fromJson({
      'couple_id': 'c1',
      'month': '2026-09-01',
      'available_until': '2026-11-01T00:00:00Z',
      'recorded_days': 2,
      'card_count': null,
      'card_count_complete': false,
      'completed_questions': 0,
      'has_records': true,
      'ai_enabled': false,
      'title': '우리의 9월',
      'summary': null,
      'content_status': 'basic',
      'moments': [],
      'conversation': null,
      'reflection': {
        'id': 'r1',
        'question': '다음 달 함께하고 싶은 일은?',
        'source': 'basic',
        'my_answer': answer,
        'partner_answer': null,
        'partner_answer_exists': false,
        'version': version,
      },
    });
