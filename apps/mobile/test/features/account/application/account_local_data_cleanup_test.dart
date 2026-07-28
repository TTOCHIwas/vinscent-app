import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/account/application/account_local_data_cleanup.dart';

void main() {
  test('clears every user and device scoped account artifact', () async {
    final events = <String>[];
    final cleanup = AccountLocalDataCleanup(
      clearProactiveSuggestion: (userId) async {
        events.add('proactive:$userId');
      },
      clearCalendarPreviewPreference: (userId) async {
        events.add('calendar:$userId');
      },
      clearHomeFeedbackImpression: (userId) async {
        events.add('feedback:$userId');
      },
      clearPendingRecordingDrafts: () async {
        events.add('recording');
      },
      clearHomeWidgets: () async {
        events.add('widgets');
      },
    );

    final result = await cleanup.execute('user-a');

    expect(result.isComplete, isTrue);
    expect(result.failures, isEmpty);
    expect(events, [
      'proactive:user-a',
      'calendar:user-a',
      'feedback:user-a',
      'recording',
      'widgets',
    ]);
  });

  test('attempts every cleanup and reports individual failures', () async {
    final events = <String>[];
    final cleanup = AccountLocalDataCleanup(
      clearProactiveSuggestion: (_) async {
        events.add('proactive');
        throw StateError('proactive failed');
      },
      clearCalendarPreviewPreference: (_) async {
        events.add('calendar');
      },
      clearHomeFeedbackImpression: (_) async {
        events.add('feedback');
        throw StateError('feedback failed');
      },
      clearPendingRecordingDrafts: () async {
        events.add('recording');
      },
      clearHomeWidgets: () async {
        events.add('widgets');
      },
    );

    final result = await cleanup.execute('user-a');

    expect(result.isComplete, isFalse);
    expect(events, [
      'proactive',
      'calendar',
      'feedback',
      'recording',
      'widgets',
    ]);
    expect(result.failures.map((failure) => failure.operation), [
      AccountLocalDataCleanupOperation.proactiveSuggestion,
      AccountLocalDataCleanupOperation.homeFeedbackImpression,
    ]);
  });
}
