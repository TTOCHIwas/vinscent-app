import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/couple/application/couple_flow_state.dart';

void main() {
  test('validates normalized invite code format', () {
    expect(const CoupleFlowState(inviteCode: 'abc234').isInviteCodeValid, true);
    expect(const CoupleFlowState(inviteCode: 'ABC23').isInviteCodeValid, false);
    expect(
      const CoupleFlowState(inviteCode: 'ABC230').isInviteCodeValid,
      false,
    );
    expect(
      const CoupleFlowState(inviteCode: 'ABCI23').isInviteCodeValid,
      false,
    );
  });

  test('enables join only with valid code and idle operation', () {
    expect(const CoupleFlowState(inviteCode: 'ABC234').canJoin, true);
    expect(
      const CoupleFlowState(
        inviteCode: 'ABC234',
        operation: CoupleFlowOperation.joining,
      ).canJoin,
      false,
    );
  });

  test('enables date saving only after selecting date', () {
    expect(const CoupleFlowState().canSaveDate, false);
    expect(
      CoupleFlowState(relationshipStartDate: DateTime(2026)).canSaveDate,
      true,
    );
  });
}
