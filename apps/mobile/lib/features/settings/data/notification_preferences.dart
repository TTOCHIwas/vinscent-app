import 'package:flutter/material.dart';

class NotificationPreferences {
  const NotificationPreferences({
    required this.userId,
    required this.expressionEnabled,
    required this.partnerAnswerEnabled,
    required this.dailyQuestionEnabled,
    required this.reminderEnabled,
    required this.coupleDisconnectEnabled,
    required this.recordingEnabled,
    required this.dailyQuestionDeliveryTime,
    required this.createdAt,
    required this.updatedAt,
  });

  factory NotificationPreferences.fromJson(Map<String, dynamic> json) {
    return NotificationPreferences(
      userId: json['user_id'] as String,
      expressionEnabled: json['expression_enabled'] as bool,
      partnerAnswerEnabled: json['partner_answer_enabled'] as bool,
      dailyQuestionEnabled: json['daily_question_enabled'] as bool,
      reminderEnabled: json['reminder_enabled'] as bool,
      coupleDisconnectEnabled: json['couple_disconnect_enabled'] as bool,
      recordingEnabled: json['recording_enabled'] as bool,
      dailyQuestionDeliveryTime: _parseTimeOfDay(
        json['daily_question_delivery_time'] as String,
      ),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  final String userId;
  final bool expressionEnabled;
  final bool partnerAnswerEnabled;
  final bool dailyQuestionEnabled;
  final bool reminderEnabled;
  final bool coupleDisconnectEnabled;
  final bool recordingEnabled;
  final TimeOfDay dailyQuestionDeliveryTime;
  final DateTime createdAt;
  final DateTime updatedAt;

  TimeOfDay get reminderDeliveryTime {
    final totalMinutes =
        dailyQuestionDeliveryTime.hour * 60 +
        dailyQuestionDeliveryTime.minute +
        60;
    final normalizedMinutes = totalMinutes % (24 * 60);

    return TimeOfDay(
      hour: normalizedMinutes ~/ 60,
      minute: normalizedMinutes % 60,
    );
  }

  NotificationPreferences copyWith({
    bool? expressionEnabled,
    bool? partnerAnswerEnabled,
    bool? dailyQuestionEnabled,
    bool? reminderEnabled,
    bool? coupleDisconnectEnabled,
    bool? recordingEnabled,
    TimeOfDay? dailyQuestionDeliveryTime,
  }) {
    return NotificationPreferences(
      userId: userId,
      expressionEnabled: expressionEnabled ?? this.expressionEnabled,
      partnerAnswerEnabled:
          partnerAnswerEnabled ?? this.partnerAnswerEnabled,
      dailyQuestionEnabled: dailyQuestionEnabled ?? this.dailyQuestionEnabled,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      coupleDisconnectEnabled:
          coupleDisconnectEnabled ?? this.coupleDisconnectEnabled,
      recordingEnabled: recordingEnabled ?? this.recordingEnabled,
      dailyQuestionDeliveryTime:
          dailyQuestionDeliveryTime ?? this.dailyQuestionDeliveryTime,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  static TimeOfDay _parseTimeOfDay(String value) {
    final parts = value.split(':');
    if (parts.length < 2) {
      throw FormatException('Invalid time value: $value');
    }

    return TimeOfDay(
      hour: int.parse(parts[0]),
      minute: int.parse(parts[1]),
    );
  }
}
