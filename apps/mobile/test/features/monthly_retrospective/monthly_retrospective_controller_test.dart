import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/monthly_retrospective/application/monthly_retrospective_controller.dart';
import 'package:vinscent/features/monthly_retrospective/data/monthly_retrospective.dart';
import 'package:vinscent/features/monthly_retrospective/data/monthly_retrospective_repository.dart';

void main() {
  test('late refresh cannot replace a successfully saved answer', () async {
    final repository = _Repository();
    final container = ProviderContainer(
      overrides: [
        monthlyRetrospectiveRepositoryProvider.overrideWithValue(repository),
        monthlyRetrospectiveControllerProvider.overrideWith(_Controller.new),
      ],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(
      monthlyRetrospectiveControllerProvider,
      (_, _) {},
    );
    addTearDown(subscription.close);
    await container.read(monthlyRetrospectiveControllerProvider.future);
    final controller = container.read(
      monthlyRetrospectiveControllerProvider.notifier,
    );
    final refresh = controller.refresh();
    await controller.save(_data().reflection!, '같이 걷기');
    repository.pending.complete(_data());
    await refresh;
    expect(
      container
          .read(monthlyRetrospectiveControllerProvider)
          .value!
          .reflection!
          .myAnswer,
      '같이 걷기',
    );
    expect(
      container
          .read(monthlyRetrospectiveControllerProvider)
          .value!
          .reflection!
          .version,
      1,
    );
  });
}

MonthlyRetrospective _data([String? answer]) => MonthlyRetrospective.fromJson({
  'couple_id': 'c',
  'month': '2026-09-01',
  'available_until': '2026-11-01T00:00:00Z',
  'recorded_days': 1,
  'card_count': 1,
  'card_count_complete': true,
  'completed_questions': 0,
  'has_records': true,
  'ai_enabled': false,
  'title': '우리의 9월',
  'summary': null,
  'content_status': 'basic',
  'moments': [],
  'conversation': null,
  'reflection': {
    'id': 'r',
    'question': '다음 달 무엇을 할까?',
    'source': 'basic',
    'my_answer': answer,
    'partner_answer': null,
    'partner_answer_exists': false,
    'version': answer == null ? 0 : 1,
  },
});

class _Controller extends MonthlyRetrospectiveController {
  @override
  Future<MonthlyRetrospective> build() async => _data();
}

class _Repository implements MonthlyRetrospectiveRepository {
  final pending = Completer<MonthlyRetrospective>();
  @override
  Future<MonthlyRetrospective> fetch() => pending.future;
  @override
  Future<MonthlyRetrospective> save(
    RetrospectiveReflection reflection,
    String text,
  ) async => _data(text);
  @override
  Future<void> generate() async {}
  @override
  Future<Map<String, String>> previewUrls(
    Iterable<RetrospectiveCard> cards,
  ) async => {};
  @override
  Future<MonthlyRetrospective> useBasicQuestion(String id) async => _data();
}
