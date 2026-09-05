import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/couple_calendar_event.dart';
import '../data/couple_calendar_event_repository.dart';
import 'device_calendar_sync_coordinator.dart';

final coupleCalendarEventDeletionServiceProvider =
    Provider<CoupleCalendarEventDeletionService>((ref) {
      return CoupleCalendarEventDeletionService(
        repository: ref.watch(coupleCalendarEventRepositoryProvider),
        deviceCalendarSyncCoordinator: ref.watch(
          deviceCalendarSyncCoordinatorProvider,
        ),
      );
    });

class CoupleCalendarEventDeletionService {
  const CoupleCalendarEventDeletionService({
    required CoupleCalendarEventRepository repository,
    required DeviceCalendarSyncCoordinator deviceCalendarSyncCoordinator,
  }) : _repository = repository,
       _deviceCalendarSyncCoordinator = deviceCalendarSyncCoordinator;

  final CoupleCalendarEventRepository _repository;
  final DeviceCalendarSyncCoordinator _deviceCalendarSyncCoordinator;

  Future<void> delete(CoupleCalendarEvent event) async {
    await _repository.deleteEvent(
      eventId: event.id,
      expectedRevision: event.revision,
    );
    await _deviceCalendarSyncCoordinator.scheduleDelete(event);
  }
}
