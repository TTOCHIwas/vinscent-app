import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/auth/data/apple_auth_client.dart';

void main() {
  test('keeps the short-lived authorization code for server revocation', () {
    const tokens = AppleLoginTokens(
      idToken: 'identity-token',
      rawNonce: 'raw-nonce',
      authorizationCode: 'authorization-code',
    );

    expect(tokens.authorizationCode, 'authorization-code');
  });
}
