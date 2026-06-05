enum CoupleExpressionType {
  missYou('miss_you', '보고싶어'),
  thanks('thanks', '고마워'),
  feelingDown('feeling_down', '우울해'),
  cheerUp('cheer_up', '힘내');

  const CoupleExpressionType(this.value, this.label);

  final String value;
  final String label;

  static CoupleExpressionType fromJson(String value) {
    return switch (value) {
      'miss_you' => CoupleExpressionType.missYou,
      'thanks' => CoupleExpressionType.thanks,
      'feeling_down' => CoupleExpressionType.feelingDown,
      'cheer_up' => CoupleExpressionType.cheerUp,
      _ => throw FormatException('Unknown couple expression type: $value'),
    };
  }
}

class CoupleExpression {
  const CoupleExpression({
    required this.id,
    required this.coupleId,
    required this.senderUserId,
    required this.receiverUserId,
    required this.type,
    required this.sentAt,
  });

  factory CoupleExpression.fromJson(Map<String, dynamic> json) {
    return CoupleExpression(
      id: json['id'] as String,
      coupleId: json['couple_id'] as String,
      senderUserId: json['sender_user_id'] as String,
      receiverUserId: json['receiver_user_id'] as String,
      type: CoupleExpressionType.fromJson(json['expression_type'] as String),
      sentAt: DateTime.parse(json['sent_at'] as String),
    );
  }

  final String id;
  final String coupleId;
  final String senderUserId;
  final String receiverUserId;
  final CoupleExpressionType type;
  final DateTime sentAt;
}
