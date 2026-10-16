import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/core/date/today_controller.dart';
import 'package:vinscent/features/couple/application/couple_controller.dart';
import 'package:vinscent/features/monthly_retrospective/application/monthly_retrospective_availability_provider.dart';
import 'package:vinscent/features/monthly_retrospective/application/monthly_retrospective_controller.dart';
import 'package:vinscent/features/monthly_retrospective/data/monthly_retrospective.dart';
import 'package:vinscent/features/monthly_retrospective/data/monthly_retrospective_repository.dart';
import 'package:vinscent/features/story_loops/application/story_loop_realtime_controller.dart';
import '../../support/couple_fixtures.dart';

void main() {
  test(
    'calendar availability reads metadata without creating a retrospective and refreshes on new answers',
    () async {
      final repository = _Repository();
      final container = ProviderContainer(
        overrides: [
          monthlyRetrospectiveRepositoryProvider.overrideWithValue(repository),
          monthlyRetrospectiveClockProvider.overrideWithValue(
            () => DateTime.utc(2026, 10, 10),
          ),
          todayControllerProvider.overrideWithBuild(
            (ref, notifier) => DateTime(2026, 10, 10),
          ),
          coupleControllerProvider.overrideWithBuild(
            (ref, notifier) async =>
                activeCouple(currentDate: DateTime(2026, 10, 10)),
          ),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(
        monthlyRetrospectiveAvailabilityProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);
      expect(
        (await container.read(
          monthlyRetrospectiveAvailabilityProvider.future,
        ))!.hasRecords,
        isFalse,
      );
      repository.hasRecords = true;
      container.read(dailyQuestionReadRevisionProvider.notifier).advance();
      expect(
        (await container.read(
          monthlyRetrospectiveAvailabilityProvider.future,
        ))!.hasRecords,
        isTrue,
      );
      expect(repository.availabilityCalls, 2);
      expect(repository.fullReads, 0);
    },
  );
}

class _Repository implements MonthlyRetrospectiveRepository {
  bool hasRecords = false;
  int availabilityCalls = 0;
  int fullReads = 0;
  @override
  Future<MonthlyRetrospectiveAvailability> fetchAvailability() async {
    availabilityCalls++;
    return MonthlyRetrospectiveAvailability.fromJson({
      'couple_id': 'couple-id',
      'month': '2026-09-01',
      'available_until': '2026-11-01T00:00:00Z',
      'has_records': hasRecords,
    });
  }

  @override
  Future<MonthlyRetrospective> fetch() {
    fullReads++;
    throw StateError('Full retrospective must only load when opened');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
