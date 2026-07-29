import '../../../core/config/app_config.dart';

class PolicyDocumentLinks {
  const PolicyDocumentLinks({required this.baseUrl});

  static const configured = PolicyDocumentLinks(
    baseUrl: AppConfig.policyBaseUrl,
  );

  final String baseUrl;

  Uri? get privacy => _resolve('privacy');
  Uri? get terms => _resolve('terms');
  Uri? get support => _resolve('support');

  Uri? _resolve(String documentPath) {
    final baseUri = Uri.tryParse(baseUrl.trim());
    if (baseUri == null ||
        baseUri.scheme != 'https' ||
        baseUri.host.isEmpty ||
        baseUri.userInfo.isNotEmpty ||
        baseUri.query.isNotEmpty ||
        baseUri.fragment.isNotEmpty) {
      return null;
    }

    final basePath = baseUri.path.endsWith('/')
        ? baseUri.path
        : '${baseUri.path}/';
    return baseUri.replace(path: '$basePath$documentPath');
  }
}
