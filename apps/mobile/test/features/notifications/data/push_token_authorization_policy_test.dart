import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/notifications/data/push_token_authorization_policy.dart';

void main() {
  const policy = PushTokenAuthorizationPolicy();

  test('allows token registration for authorized notification access', () {
    expect(policy.canRegister(AuthorizationStatus.authorized), isTrue);
    expect(policy.canRegister(AuthorizationStatus.provisional), isTrue);
  });

  test('blocks token registration without notification access', () {
    expect(policy.canRegister(AuthorizationStatus.denied), isFalse);
    expect(policy.canRegister(AuthorizationStatus.notDetermined), isFalse);
  });
}
