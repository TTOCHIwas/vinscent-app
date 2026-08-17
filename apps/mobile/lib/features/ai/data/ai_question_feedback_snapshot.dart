import 'ai_learning_dashboard.dart';

sealed class AiQuestionFeedbackSnapshot {
  const AiQuestionFeedbackSnapshot();

  const factory AiQuestionFeedbackSnapshot.processing() =
      AiQuestionFeedbackSnapshotProcessing;

  const factory AiQuestionFeedbackSnapshot.published(
    AiQuestionFeedback feedback,
  ) = AiQuestionFeedbackSnapshotPublished;

  const factory AiQuestionFeedbackSnapshot.failed() =
      AiQuestionFeedbackSnapshotFailed;

  factory AiQuestionFeedbackSnapshot.fromJson(Map<String, dynamic> json) {
    return switch (json['status']) {
      'processing' => const AiQuestionFeedbackSnapshot.processing(),
      'published' => AiQuestionFeedbackSnapshot.published(
        AiQuestionFeedback.fromJson(_readFeedback(json['feedback'])),
      ),
      'failed' => const AiQuestionFeedbackSnapshot.failed(),
      _ => throw const FormatException('Invalid AI question feedback status'),
    };
  }
}

final class AiQuestionFeedbackSnapshotProcessing
    extends AiQuestionFeedbackSnapshot {
  const AiQuestionFeedbackSnapshotProcessing();
}

final class AiQuestionFeedbackSnapshotPublished
    extends AiQuestionFeedbackSnapshot {
  const AiQuestionFeedbackSnapshotPublished(this.feedback);

  final AiQuestionFeedback feedback;
}

final class AiQuestionFeedbackSnapshotFailed
    extends AiQuestionFeedbackSnapshot {
  const AiQuestionFeedbackSnapshotFailed();
}

Map<String, dynamic> _readFeedback(Object? value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }
  throw const FormatException('Invalid AI question feedback payload');
}
