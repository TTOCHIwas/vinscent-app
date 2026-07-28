import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/account/application/account_deletion_authorizer.dart';
import 'package:vinscent/features/account/data/account_deletion_repository.dart';

void main() {
  test('does not request Apple authorization for another provider', () async {
    var requestCount = 0;
    final authorizer = AccountDeletionAuthorizer(
      requiresAppleAuthorization: () => false,
      requestAppleAuthorizationCode: () async {
        requestCount += 1;
        return 'authorization-code';
      },
    );

    final code = await authorizer.authorize();

    expect(code, isNull);
    expect(requestCount, 0);
  });

  test('returns a normalized code for an Apple account', () async {
    final authorizer = AccountDeletionAuthorizer(
      requiresAppleAuthorization: () => true,
      requestAppleAuthorizationCode: () async => ' authorization-code ',
    );

    final code = await authorizer.authorize();

    expect(code, 'authorization-code');
  });

  test('maps an invalid Apple response to reauthentication failure', () async {
    final authorizer = AccountDeletionAuthorizer(
      requiresAppleAuthorization: () => true,
      requestAppleAuthorizationCode: () async => ' ',
    );

    await expectLater(
      authorizer.authorize(),
      throwsA(
        isA<AccountDeletionException>().having(
          (error) => error.reason,
          'reason',
          AccountDeletionFailureReason.reauthenticationFailed,
        ),
      ),
    );
  });

  test('preserves a typed Apple cancellation', () async {
    final authorizer = AccountDeletionAuthorizer(
      requiresAppleAuthorization: () => true,
      requestAppleAuthorizationCode: () async {
        throw const AccountDeletionException(
          AccountDeletionFailureReason.reauthenticationCancelled,
        );
      },
    );

    await expectLater(
      authorizer.authorize(),
      throwsA(
        isA<AccountDeletionException>().having(
          (error) => error.reason,
          'reason',
          AccountDeletionFailureReason.reauthenticationCancelled,
        ),
      ),
    );
  });
}
