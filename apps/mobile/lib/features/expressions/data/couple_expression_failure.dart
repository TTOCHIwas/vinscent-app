enum CoupleExpressionFailureReason {
  configMissing,
  authRequired,
  activeCoupleRequired,
  relationshipDateRequired,
  invalidExpressionType,
  requestTimeout,
  unknown,
}

class CoupleExpressionRepositoryException implements Exception {
  const CoupleExpressionRepositoryException(this.reason, [this.message]);

  final CoupleExpressionFailureReason reason;
  final String? message;

  @override
  String toString() {
    final message = this.message;
    if (message == null || message.isEmpty) {
      return 'CoupleExpressionRepositoryException($reason)';
    }

    return 'CoupleExpressionRepositoryException($reason, $message)';
  }
}
