final class StoreAssetVerificationOptions {
  const StoreAssetVerificationOptions({
    required this.appVersion,
    required this.buildNumber,
  });

  static const usage =
      'Usage: dart run tool/verify_store_assets.dart '
      '[--app-version X.Y.Z --build-number N]';

  final String? appVersion;
  final int? buildNumber;

  static StoreAssetVerificationOptions parse(List<String> arguments) {
    if (arguments.isEmpty) {
      return const StoreAssetVerificationOptions(
        appVersion: null,
        buildNumber: null,
      );
    }
    if (arguments.length != 4) {
      throw const FormatException(
        '--app-version and --build-number must be provided together.',
      );
    }

    String? appVersion;
    int? buildNumber;
    for (var index = 0; index < arguments.length; index += 2) {
      final option = arguments[index];
      final value = arguments[index + 1];
      switch (option) {
        case '--app-version':
          if (appVersion != null ||
              !RegExp(r'^\d+\.\d+\.\d+$').hasMatch(value)) {
            throw const FormatException('--app-version must use X.Y.Z format.');
          }
          appVersion = value;
          break;
        case '--build-number':
          final parsed = int.tryParse(value);
          if (buildNumber != null || parsed == null || parsed < 1) {
            throw const FormatException(
              '--build-number must be a positive integer.',
            );
          }
          buildNumber = parsed;
          break;
        default:
          throw FormatException('Unknown option: $option.');
      }
    }
    if (appVersion == null || buildNumber == null) {
      throw const FormatException(
        '--app-version and --build-number must be provided together.',
      );
    }
    return StoreAssetVerificationOptions(
      appVersion: appVersion,
      buildNumber: buildNumber,
    );
  }
}
