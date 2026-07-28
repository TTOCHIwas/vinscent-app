import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/calendar/data/calendar_cell_preview_mode.dart';
import 'package:vinscent/features/calendar/data/calendar_cell_preview_preference_store.dart';

void main() {
  test('stores preview modes independently for each user', () async {
    final preferences = _MemoryPreferences();
    final store = SharedPreferencesCalendarCellPreviewPreferenceStore(
      preferences: preferences,
    );

    await store.write(
      userId: 'user-a',
      mode: CalendarCellPreviewMode.cardsOnly,
    );
    await store.write(
      userId: 'user-b',
      mode: CalendarCellPreviewMode.eventsOnly,
    );

    expect(
      await store.read(userId: 'user-a'),
      CalendarCellPreviewMode.cardsOnly,
    );
    expect(
      await store.read(userId: 'user-b'),
      CalendarCellPreviewMode.eventsOnly,
    );
  });

  test('uses all when the saved value is missing or unsupported', () async {
    final preferences = _MemoryPreferences();
    final store = SharedPreferencesCalendarCellPreviewPreferenceStore(
      preferences: preferences,
    );

    expect(await store.read(userId: 'new-user'), CalendarCellPreviewMode.all);

    preferences.values['vinscent.calendar.cell_preview_mode.existing-user'] =
        'unsupported';
    expect(
      await store.read(userId: 'existing-user'),
      CalendarCellPreviewMode.all,
    );
  });

  test('clears only the targeted user preview mode', () async {
    final preferences = _MemoryPreferences();
    final store = SharedPreferencesCalendarCellPreviewPreferenceStore(
      preferences: preferences,
    );
    await store.write(
      userId: 'user-a',
      mode: CalendarCellPreviewMode.cardsOnly,
    );
    await store.write(
      userId: 'user-b',
      mode: CalendarCellPreviewMode.eventsOnly,
    );

    await store.clearForUser('user-a');

    expect(await store.read(userId: 'user-a'), CalendarCellPreviewMode.all);
    expect(
      await store.read(userId: 'user-b'),
      CalendarCellPreviewMode.eventsOnly,
    );
  });
}

class _MemoryPreferences implements CalendarCellPreviewPreferences {
  final Map<String, String> values = {};

  @override
  Future<String?> getString(String key) async => values[key];

  @override
  Future<void> remove(String key) async {
    values.remove(key);
  }

  @override
  Future<void> setString(String key, String value) async {
    values[key] = value;
  }
}
