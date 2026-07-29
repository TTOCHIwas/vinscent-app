import 'package:url_launcher/url_launcher.dart';

abstract interface class PolicyDocumentLauncher {
  Future<bool> launch(Uri uri);
}

class UrlLauncherPolicyDocumentLauncher implements PolicyDocumentLauncher {
  const UrlLauncherPolicyDocumentLauncher();

  @override
  Future<bool> launch(Uri uri) {
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
