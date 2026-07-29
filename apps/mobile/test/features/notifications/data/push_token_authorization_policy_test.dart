import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/notifications/data/push_token_authorization_policy.dart';

void main() {
  const policy = PushTokenAuthorizationPolicy();

  test('allows token registration for authorized notification access', () {
    expect(
      policy.actionFor(AuthorizationStatus.authorized),
      PushTokenAuthorizationAction.register,
    );
    expect(
      policy.actionFor(AuthorizationStatus.provisional),
      PushTokenAuthorizationAction.register,
    );
  });

  test('deactivates tokens after notification access is denied', () {
    expect(
      policy.actionFor(AuthorizationStatus.denied),
      PushTokenAuthorizationAction.deactivate,
    );
  });

  test('waits before the first notification permission decision', () {
    expect(
      policy.actionFor(AuthorizationStatus.notDetermined),
      PushTokenAuthorizationAction.none,
    );
  });
}
