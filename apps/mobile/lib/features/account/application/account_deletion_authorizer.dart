import '../data/account_deletion_repository.dart';

typedef AppleAuthorizationRequirement = bool Function();
typedef AppleAuthorizationCodeRequester = Future<String> Function();

abstract interface class AccountDeletionAuthorizationProvider {
  Future<String?> authorize();
}

class AccountDeletionAuthorizer
    implements AccountDeletionAuthorizationProvider {
  const AccountDeletionAuthorizer({
    required AppleAuthorizationRequirement requiresAppleAuthorization,
    required AppleAuthorizationCodeRequester requestAppleAuthorizationCode,
  }) : _requiresAppleAuthorization = requiresAppleAuthorization,
       _requestAppleAuthorizationCode = requestAppleAuthorizationCode;

  final AppleAuthorizationRequirement _requiresAppleAuthorization;
  final AppleAuthorizationCodeRequester _requestAppleAuthorizationCode;

  @override
  Future<String?> authorize() async {
    try {
      if (!_requiresAppleAuthorization()) {
        return null;
      }

      final authorizationCode = (await _requestAppleAuthorizationCode()).trim();
      if (authorizationCode.isEmpty) {
        throw const AccountDeletionException(
          AccountDeletionFailureReason.reauthenticationFailed,
        );
      }
      return authorizationCode;
    } on AccountDeletionException {
      rethrow;
    } catch (_) {
      throw const AccountDeletionException(
        AccountDeletionFailureReason.reauthenticationFailed,
      );
    }
  }
}
