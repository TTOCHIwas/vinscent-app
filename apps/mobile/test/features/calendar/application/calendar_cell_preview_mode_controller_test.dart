import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/calendar/application/calendar_cell_preview_mode_controller.dart';
import 'package:vinscent/features/calendar/data/calendar_cell_preview_mode.dart';
import 'package:vinscent/features/calendar/data/calendar_cell_preview_preference_store.dart';

void main() {
  test('loads and persists the current user preview mode', () async {
    final store = _MemoryStore({'user-a': CalendarCellPreviewMode.cardsOnly});
    final container = ProviderContainer(
      overrides: [
        calendarPreferenceUserIdProvider.overrideWithValue('user-a'),
        calendarCellPreviewPreferenceStoreProvider.overrideWithValue(store),
      ],
    );
    addTearDown(container.dispose);

    expect(
      await container.read(calendarCellPreviewModeControllerProvider.future),
      CalendarCellPreviewMode.cardsOnly,
    );

    await container
        .read(calendarCellPreviewModeControllerProvider.notifier)
        .selectMode(CalendarCellPreviewMode.eventsOnly);

    expect(
      container.read(calendarCellPreviewModeControllerProvider).requireValue,
      CalendarCellPreviewMode.eventsOnly,
    );
    expect(store.values['user-a'], CalendarCellPreviewMode.eventsOnly);
  });

  test('restores the previous mode when persistence fails', () async {
    final store = _MemoryStore({'user-a': CalendarCellPreviewMode.cardsOnly})
      ..failWrites = true;
    final container = ProviderContainer(
      overrides: [
        calendarPreferenceUserIdProvider.overrideWithValue('user-a'),
        calendarCellPreviewPreferenceStoreProvider.overrideWithValue(store),
      ],
    );
    addTearDown(container.dispose);
    await container.read(calendarCellPreviewModeControllerProvider.future);

    await expectLater(
      container
          .read(calendarCellPreviewModeControllerProvider.notifier)
          .selectMode(CalendarCellPreviewMode.eventsOnly),
      throwsStateError,
    );

    expect(
      container.read(calendarCellPreviewModeControllerProvider).requireValue,
      CalendarCellPreviewMode.cardsOnly,
    );
  });
}

class _MemoryStore implements CalendarCellPreviewPreferenceStore {
  _MemoryStore(Map<String, CalendarCellPreviewMode> values)
    : values = Map.of(values);

  final Map<String, CalendarCellPreviewMode> values;
  bool failWrites = false;

  @override
  Future<void> clearForUser(String userId) async {
    values.remove(userId);
  }

  @override
  Future<CalendarCellPreviewMode> read({required String userId}) async {
    return values[userId] ?? CalendarCellPreviewMode.all;
  }

  @override
  Future<void> write({
    required String userId,
    required CalendarCellPreviewMode mode,
  }) async {
    if (failWrites) {
      throw StateError('write failed');
    }
    values[userId] = mode;
  }
}
