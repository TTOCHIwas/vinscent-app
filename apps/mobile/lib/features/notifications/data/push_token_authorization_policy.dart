import 'package:firebase_messaging/firebase_messaging.dart';

enum PushTokenAuthorizationAction { register, deactivate, none }

class PushTokenAuthorizationPolicy {
  const PushTokenAuthorizationPolicy();

  PushTokenAuthorizationAction actionFor(AuthorizationStatus status) {
    return switch (status) {
      AuthorizationStatus.authorized ||
      AuthorizationStatus.provisional => PushTokenAuthorizationAction.register,
      AuthorizationStatus.denied => PushTokenAuthorizationAction.deactivate,
      AuthorizationStatus.notDetermined => PushTokenAuthorizationAction.none,
    };
  }
}
