import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/couple_expression.dart';
import '../data/couple_expression_repository.dart';

final coupleExpressionControllerProvider =
    AsyncNotifierProvider<CoupleExpressionController, CoupleExpression?>(
      CoupleExpressionController.new,
      retry: (_, _) => null,
    );

class CoupleExpressionController extends AsyncNotifier<CoupleExpression?> {
  @override
  Future<CoupleExpression?> build() async {
    return null;
  }

  Future<CoupleExpression> send(CoupleExpressionType type) async {
    final previousState = state;

    state = const AsyncValue.loading();
    try {
      final expression = await ref
          .read(coupleExpressionRepositoryProvider)
          .send(type);
      state = AsyncValue.data(expression);
      return expression;
    } catch (error, stackTrace) {
      state = previousState;
      Error.throwWithStackTrace(error, stackTrace);
    }
  }
}
