import '../../auth/application/auth_sign_out_service.dart';
import '../data/push_token_repository.dart';

class PushTokenAuthSignOutCleanup implements AuthSignOutCleanup {
  const PushTokenAuthSignOutCleanup(this._repository);

  final PushTokenRepository _repository;

  @override
  Future<void> run() => _repository.deactivateCurrentDeviceToken();
}
