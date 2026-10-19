import 'package:flutter/cupertino.dart' show CupertinoTextField;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/core/theme/app_colors.dart';
import 'package:vinscent/features/monthly_retrospective/application/monthly_retrospective_controller.dart';
import 'package:vinscent/features/monthly_retrospective/data/monthly_retrospective.dart';
import 'package:vinscent/features/monthly_retrospective/presentation/monthly_retrospective_screen.dart';

void main() {
  testWidgets(
    'a failed save shows its reason beside the save action and retains input',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await _pumpMutable(tester, controller: _FailingController.new);
      await tester.ensureVisible(find.byType(CupertinoTextField));
      await tester.enterText(find.byType(CupertinoTextField), '실패해도 남길 초안');
      await tester.pumpAndSettle();
      final save = find.widgetWithText(FilledButton, '마음 남기기');
      await tester.ensureVisible(save);
      expect(tester.widget<FilledButton>(save).onPressed, isNotNull);
      await tester.tap(save);
      await tester.pumpAndSettle();
      final error = find.byKey(const Key('monthly-reflection-error'));
      expect(error, findsOneWidget);
      expect(error.hitTestable(), findsOneWidget);
      expect(tester.getRect(error).bottom, lessThan(tester.getRect(save).top));
      expect(
        tester
            .widget<CupertinoTextField>(find.byType(CupertinoTextField))
            .controller!
            .text,
        '실패해도 남길 초안',
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('an empty month has no reflection input or generated content', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          monthlyRetrospectiveControllerProvider.overrideWithBuild(
            (ref, notifier) async => _fixture(hasRecords: false),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(body: MonthlyRetrospectiveScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('지난달에는 남긴 기록이 없어요'), findsOneWidget);
    expect(find.byType(CupertinoTextField), findsNothing);
    expect(find.byKey(const Key('monthly-overview-information')), findsNothing);
  });

  testWidgets('a new month starts the single scroll at the top', (
    tester,
  ) async {
    final container = await _pumpMutable(tester);
    await tester.ensureVisible(find.byType(CupertinoTextField));
    await tester.pumpAndSettle();
    expect(_scrollPosition(tester).pixels, greaterThan(0));
    (container.read(monthlyRetrospectiveControllerProvider.notifier)
            as _Controller)
        .replace(_fixture(month: '2026-10-01'));
    await tester.pumpAndSettle();
    expect(find.text('2026년 10월'), findsOneWidget);
    expect(_scrollPosition(tester).pixels, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a month change keeps the old draft until explicitly discarded', (
    tester,
  ) async {
    final container = await _pumpMutable(tester);
    await tester.ensureVisible(find.byType(CupertinoTextField));
    await tester.enterText(find.byType(CupertinoTextField), '이전 달의 초안');
    (container.read(monthlyRetrospectiveControllerProvider.notifier)
            as _Controller)
        .replace(_fixture(month: '2026-10-01'));
    await tester.pumpAndSettle();
    expect(find.text('이전 달의 초안'), findsOneWidget);
    expect(find.byType(CupertinoTextField), findsNothing);
    await tester.tap(find.text('새 회고 열기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('계속 작성'));
    await tester.pumpAndSettle();
    expect(find.text('이전 달의 초안'), findsOneWidget);
    await tester.tap(find.text('새 회고 열기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('닫기'));
    await tester.pumpAndSettle();
    expect(find.text('2026년 10월'), findsOneWidget);
    expect(
      tester
          .widget<CupertinoTextField>(find.byType(CupertinoTextField))
          .controller!
          .text,
      isEmpty,
    );
    expect(_scrollPosition(tester).pixels, 0);
    expect(tester.takeException(), isNull);
  });
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
      await tester.ensureVisible(find.byKey(const Key('monthly-reflection')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('수정하기'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(CupertinoTextField), '내가 작성 중인 초안');
      final controller =
          container.read(monthlyRetrospectiveControllerProvider.notifier)
              as _Controller;
      controller.replace(_fixture(answer: '다른 기기의 답변', version: 2));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<CupertinoTextField>(find.byType(CupertinoTextField))
            .controller!
            .text,
        '내가 작성 중인 초안',
      );
      await tester.ensureVisible(find.widgetWithText(FilledButton, '마음 남기기'));
      await tester.tap(find.widgetWithText(FilledButton, '마음 남기기'));
      await tester.pumpAndSettle();
      expect(controller.savedVersions, [1]);
      expect(find.text('다른 기기의 답변'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      await tester.ensureVisible(find.text('내 초안으로 다시 저장'));
      await tester.tap(find.text('내 초안으로 다시 저장'));
      await tester.pumpAndSettle();
      expect(controller.savedVersions, [1, 2]);
      expect(find.byType(CupertinoTextField), findsNothing);
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
    await tester.ensureVisible(find.byKey(const Key('monthly-reflection')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('수정하기'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(CupertinoTextField), '버릴 초안');
    final leave = key.currentState!.confirmLeave();
    await tester.pumpAndSettle();
    await tester.tap(find.text('닫기'));
    await tester.pumpAndSettle();
    expect(await leave, isTrue);
    await tester.tap(find.text('수정하기'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<CupertinoTextField>(find.byType(CupertinoTextField))
          .controller!
          .text,
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
    await tester.ensureVisible(find.byKey(const Key('monthly-reflection')));
    await tester.pumpAndSettle();
    (container.read(monthlyRetrospectiveControllerProvider.notifier)
            as _Controller)
        .replace(_fixture(answer: '새 답변', version: 2));
    await tester.pumpAndSettle();
    await tester.tap(find.text('수정하기'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<CupertinoTextField>(find.byType(CupertinoTextField))
          .controller!
          .text,
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
      expect(find.text('지난달 이야기'), findsNothing);
      expect(find.text('그날의 기억'), findsOneWidget);
      expect(find.text('지난달 사진이 담긴 날의 기록을 돌아봐요.'), findsOneWidget);
      expect(find.text('우리의 답'), findsNothing);
      expect(find.byKey(const Key('monthly-conversation')), findsNothing);
      expect(find.byKey(const Key('monthly-memories')), findsOneWidget);
      expect(find.byKey(const Key('monthly-reflection')), findsOneWidget);
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
      await tester.ensureVisible(find.byKey(const Key('monthly-reflection')));
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoTextField), findsOneWidget);
      await tester.enterText(find.byType(CupertinoTextField), '다음 달 같이 산책하기');
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, 600),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('monthly-reflection')));
      await tester.pumpAndSettle();
      expect(find.text('다음 달 같이 산책하기'), findsOneWidget);
    },
  );
}

ScrollPosition _scrollPosition(WidgetTester tester) => tester
    .state<ScrollableState>(
      find
          .descendant(
            of: find.byType(SingleChildScrollView),
            matching: find.byType(Scrollable),
          )
          .first,
    )
    .position;

Future<ProviderContainer> _pumpMutable(
  WidgetTester tester, {
  _Controller Function()? controller,
}) async {
  final container = ProviderContainer(
    overrides: [
      monthlyRetrospectiveControllerProvider.overrideWith(
        controller ?? _Controller.new,
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
  return container;
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

class _FailingController extends _Controller {
  @override
  Future<void> save(RetrospectiveReflection reflection, String text) async {
    throw StateError('save unavailable');
  }
}

MonthlyRetrospective _fixture({
  String? answer,
  int version = 0,
  bool hasRecords = true,
  String month = '2026-09-01',
}) => MonthlyRetrospective.fromJson({
  'couple_id': 'c1',
  'month': month,
  'available_until': '2026-11-01T00:00:00Z',
  'recorded_days': hasRecords ? 2 : 0,
  'card_count': null,
  'card_count_complete': false,
  'completed_questions': 0,
  'has_records': hasRecords,
  'ai_enabled': false,
  'title': '우리의 ${DateTime.parse(month).month}월',
  'summary': null,
  'content_status': 'basic',
  'moments': [],
  'conversation': null,
  'reflection': {
    'id': 'r$month',
    'question': '다음 달 함께하고 싶은 일은?',
    'source': 'basic',
    'my_answer': answer,
    'partner_answer': null,
    'partner_answer_exists': false,
    'version': version,
  },
});
