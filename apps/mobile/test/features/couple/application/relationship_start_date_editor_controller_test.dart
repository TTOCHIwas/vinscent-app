import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/couple/application/couple_controller.dart';
import 'package:vinscent/features/couple/application/relationship_start_date_editor_controller.dart';
import 'package:vinscent/features/couple/data/couple.dart';
import 'package:vinscent/features/couple/data/couple_change_source.dart';
import 'package:vinscent/features/couple/data/couple_failure.dart';
import 'package:vinscent/features/couple/data/couple_repository.dart';

import '../../../support/couple_fixtures.dart';

void main() {
  test(
    'saves a changed relationship date through the couple boundary',
    () async {
      final repository = _RelationshipDateRepository();
      final container = _createContainer(repository);
      addTearDown(container.dispose);

      final initial = await container.read(
        relationshipStartDateEditorControllerProvider.future,
      );
      expect(initial.originalDate, DateTime(2026, 5, 30));
      expect(initial.latestAllowedDate, DateTime(2026, 7, 28));

      final controller = container.read(
        relationshipStartDateEditorControllerProvider.notifier,
      );
      controller.selectDate(DateTime(2026, 5, 1));
      expect(await controller.save(), isTrue);

      expect(repository.savedDate, DateTime(2026, 5, 1));
      final saved = container
          .read(relationshipStartDateEditorControllerProvider)
          .requireValue;
      expect(saved.originalDate, DateTime(2026, 5, 1));
      expect(saved.canSave, isFalse);
    },
  );

  test('keeps the selected date and explains a record conflict', () async {
    final repository = _RelationshipDateRepository(
      saveError: const CoupleRepositoryException(
        CoupleFailureReason.relationshipDateConflict,
      ),
    );
    final container = _createContainer(repository);
    addTearDown(container.dispose);

    await container.read(relationshipStartDateEditorControllerProvider.future);
    final controller = container.read(
      relationshipStartDateEditorControllerProvider.notifier,
    );
    controller.selectDate(DateTime(2026, 6, 1));

    expect(await controller.save(), isFalse);
    final failed = container
        .read(relationshipStartDateEditorControllerProvider)
        .requireValue;
    expect(failed.selectedDate, DateTime(2026, 6, 1));
    expect(failed.errorMessage, contains('이미 기록이 있는 날짜'));
    expect(failed.isSaving, isFalse);
  });
}

ProviderContainer _createContainer(_RelationshipDateRepository repository) {
  return ProviderContainer(
    overrides: [
      coupleRepositoryProvider.overrideWithValue(repository),
      coupleChangeSourceProvider.overrideWithValue(
        const _SilentCoupleChangeSource(),
      ),
      coupleControllerProvider.overrideWithBuild(
        (ref, notifier) async => repository.currentCouple,
      ),
    ],
  );
}

class _RelationshipDateRepository implements CoupleRepository {
  _RelationshipDateRepository({this.saveError});

  final Object? saveError;
  DateTime? savedDate;
  Couple currentCouple = activeCouple(
    relationshipStartDate: DateTime(2026, 5, 30),
    currentDate: DateTime(2026, 7, 28),
  );

  @override
  Future<Couple> updateRelationshipStartDate(DateTime date) async {
    final saveError = this.saveError;
    if (saveError != null) {
      throw saveError;
    }
    savedDate = date;
    return currentCouple = activeCouple(
      relationshipStartDate: date,
      currentDate: DateTime(2026, 7, 28),
    );
  }

  @override
  Future<Couple?> fetchCurrentCouple() async => currentCouple;

  @override
  Future<void> cancelInitialSetup() => throw UnimplementedError();

  @override
  Future<Couple?> cancelInvite() => throw UnimplementedError();

  @override
  Future<Couple> createInvite() => throw UnimplementedError();

  @override
  Future<void> deleteDisconnectedArchiveNow() => throw UnimplementedError();

  @override
  Future<Couple> disconnectCouple() => throw UnimplementedError();

  @override
  Future<Couple> joinByCode(String inviteCode) => throw UnimplementedError();

  @override
  Future<Couple> useDefaultCharacter() => throw UnimplementedError();
}

class _SilentCoupleChangeSource implements CoupleChangeSource {
  const _SilentCoupleChangeSource();

  @override
  Stream<void> watch({required String coupleId}) => const Stream.empty();
}
