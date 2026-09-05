import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/calendar/data/couple_calendar_event.dart';
import 'package:vinscent/features/calendar/data/device_calendar_sync.dart';

void main() {
  test('같은 일정의 최신 저장 작업만 유지한다', () {
    final first = _event(revision: 1, title: '처음 일정');
    final latest = _event(revision: 2, title: '바뀐 일정');

    final queue = DeviceCalendarSyncQueue.empty()
        .enqueueUpsert(first)
        .enqueueUpsert(latest);

    expect(queue.operations, hasLength(1));
    expect(
      queue.operations.single.type,
      DeviceCalendarSyncOperationType.upsert,
    );
    expect(queue.operations.single.event?.revision, 2);
    expect(queue.operations.single.event?.title, '바뀐 일정');
  });

  test('삭제 작업은 대기 중인 저장 작업을 대체한다', () {
    final event = _event(revision: 3, title: '삭제할 일정');

    final queue = DeviceCalendarSyncQueue.empty()
        .enqueueUpsert(event)
        .enqueueDelete(event);

    expect(queue.operations, hasLength(1));
    expect(
      queue.operations.single.type,
      DeviceCalendarSyncOperationType.delete,
    );
    expect(queue.operations.single.event?.id, event.id);
  });
}

CoupleCalendarEvent _event({required int revision, required String title}) {
  return CoupleCalendarEvent(
    id: 'event-id',
    coupleId: 'couple-id',
    title: title,
    eventDate: DateTime(2026, 9, 10),
    occurrenceDate: DateTime(2026, 9, 10),
    repeatRule: CoupleCalendarEventRepeatRule.none,
    memo: '메모',
    revision: revision,
    createdByUserId: 'user-a',
    updatedByUserId: 'user-a',
    createdAt: DateTime(2026, 9, 1),
    updatedAt: DateTime(2026, 9, 2),
    reminder: const CoupleCalendarEventReminder.disabled(),
  );
}
