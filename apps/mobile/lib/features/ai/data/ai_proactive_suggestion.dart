enum AiProactiveSuggestionKind { dateIdea, cardIdea, sunsetCard }

class AiProactiveSuggestion {
  const AiProactiveSuggestion({
    required this.id,
    required this.text,
    required this.kind,
    required this.generatedAt,
    required this.validUntil,
    required this.contextDate,
    required this.hasCardToday,
  });

  factory AiProactiveSuggestion.fromJson(Map<String, dynamic> json) {
    return AiProactiveSuggestion(
      id: _requiredString(json, 'suggestion_id'),
      text: _requiredString(json, 'text'),
      kind: switch (json['kind']) {
        'date_idea' => AiProactiveSuggestionKind.dateIdea,
        'card_idea' => AiProactiveSuggestionKind.cardIdea,
        'sunset_card' => AiProactiveSuggestionKind.sunsetCard,
        _ => throw const FormatException('Invalid proactive suggestion kind'),
      },
      generatedAt: _dateTime(json, 'generated_at'),
      validUntil: _dateTime(json, 'valid_until'),
      contextDate: _dateString(json, 'context_date'),
      hasCardToday: _requiredBool(json, 'has_card_today'),
    );
  }

  final String id;
  final String text;
  final AiProactiveSuggestionKind kind;
  final DateTime generatedAt;
  final DateTime validUntil;
  final String contextDate;
  final bool hasCardToday;

  bool isValid({required DateTime now, required bool currentHasCardToday}) {
    return now.isBefore(validUntil) && hasCardToday == currentHasCardToday;
  }

  Map<String, Object?> toJson() {
    return {
      'suggestion_id': id,
      'text': text,
      'kind': switch (kind) {
        AiProactiveSuggestionKind.dateIdea => 'date_idea',
        AiProactiveSuggestionKind.cardIdea => 'card_idea',
        AiProactiveSuggestionKind.sunsetCard => 'sunset_card',
      },
      'generated_at': generatedAt.toIso8601String(),
      'valid_until': validUntil.toIso8601String(),
      'context_date': contextDate,
      'has_card_today': hasCardToday,
    };
  }
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('Invalid $key');
  }
  return value.trim();
}

bool _requiredBool(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! bool) {
    throw FormatException('Invalid $key');
  }
  return value;
}

DateTime _dateTime(Map<String, dynamic> json, String key) {
  final parsed = DateTime.tryParse(_requiredString(json, key));
  if (parsed == null) {
    throw FormatException('Invalid $key');
  }
  return parsed;
}

String _dateString(Map<String, dynamic> json, String key) {
  final value = _requiredString(json, key);
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
    throw FormatException('Invalid $key');
  }
  return value;
}
