import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ai/application/ai_attention_state.dart';
import '../../calendar/application/calendar_attention_state.dart';
import '../../recordings/application/recording_attention_state.dart';

class AppAttentionSummary {
  const AppAttentionSummary({
    required this.hasHomeAttention,
    required this.hasCalendarAttention,
    required this.hasAiAttention,
  });

  final bool hasHomeAttention;
  final bool hasCalendarAttention;
  final bool hasAiAttention;
}

final appAttentionSummaryProvider = Provider<AppAttentionSummary>((ref) {
  final recording = ref.watch(recordingAttentionStateProvider);
  final calendar = ref.watch(calendarAttentionStateProvider);
  final ai = ref.watch(aiAttentionStateProvider);

  return AppAttentionSummary(
    hasHomeAttention: recording.hasUnread,
    hasCalendarAttention: calendar.hasTodayEvent,
    hasAiAttention: ai.hasUnseenMemory,
  );
});
