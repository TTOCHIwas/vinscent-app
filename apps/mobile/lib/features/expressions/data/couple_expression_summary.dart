import 'couple_expression.dart';

class CoupleExpressionSummary {
  const CoupleExpressionSummary({required this.type, required this.sentCount});

  factory CoupleExpressionSummary.fromJson(Map<String, dynamic> json) {
    return CoupleExpressionSummary(
      type: CoupleExpressionType.fromJson(json['expression_type'] as String),
      sentCount: (json['sent_count'] as num).toInt(),
    );
  }

  final CoupleExpressionType type;
  final int sentCount;
}
