import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/ai/application/ai_attention_state.dart';
import 'package:vinscent/features/calendar/application/calendar_attention_state.dart';
import 'package:vinscent/features/recordings/application/recording_attention_state.dart';
import 'package:vinscent/features/shell/application/app_attention_summary.dart';

void main() {
  test('maps each domain attention state to its parent shell tab', () {
    final container = ProviderContainer(
      overrides: [
        recordingAttentionStateProvider.overrideWithValue(
          const RecordingAttentionState(
            hasUnseenCurrentRecording: false,
            unseenSlotIds: {'slot-1'},
          ),
        ),
        calendarAttentionStateProvider.overrideWithValue(
          const CalendarAttentionState(hasTodayEvent: true),
        ),
        aiAttentionStateProvider.overrideWithValue(
          const AiAttentionState(unseenMemoryCount: 0),
        ),
      ],
    );
    addTearDown(container.dispose);

    final summary = container.read(appAttentionSummaryProvider);

    expect(summary.hasHomeAttention, isTrue);
    expect(summary.hasCalendarAttention, isTrue);
    expect(summary.hasAiAttention, isFalse);
  });
}
