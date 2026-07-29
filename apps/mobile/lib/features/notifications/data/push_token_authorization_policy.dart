import 'package:firebase_messaging/firebase_messaging.dart';

class PushTokenAuthorizationPolicy {
  const PushTokenAuthorizationPolicy();

  bool canRegister(AuthorizationStatus status) {
    return switch (status) {
      AuthorizationStatus.authorized || AuthorizationStatus.provisional => true,
      AuthorizationStatus.denied || AuthorizationStatus.notDetermined => false,
    };
  }
}
