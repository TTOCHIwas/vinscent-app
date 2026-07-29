import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/settings/application/policy_document_links.dart';

void main() {
  group('PolicyDocumentLinks', () {
    test('HTTPS 기본 주소에서 정책 문서 주소를 만든다', () {
      const links = PolicyDocumentLinks(
        baseUrl: 'https://policy.danjjan.example/support',
      );

      expect(
        links.privacy,
        Uri.parse('https://policy.danjjan.example/support/privacy'),
      );
      expect(
        links.terms,
        Uri.parse('https://policy.danjjan.example/support/terms'),
      );
    });

    test('후행 슬래시를 중복하지 않는다', () {
      const links = PolicyDocumentLinks(
        baseUrl: 'https://policy.danjjan.example/',
      );

      expect(
        links.privacy,
        Uri.parse('https://policy.danjjan.example/privacy'),
      );
    });

    test('비어 있거나 안전하지 않은 기본 주소를 거부한다', () {
      for (final baseUrl in [
        '',
        'http://policy.danjjan.example',
        'javascript:alert(1)',
        'https://user:password@policy.danjjan.example',
        'https://policy.danjjan.example?redirect=other',
        'https://policy.danjjan.example#privacy',
      ]) {
        final links = PolicyDocumentLinks(baseUrl: baseUrl);

        expect(links.privacy, isNull, reason: baseUrl);
        expect(links.terms, isNull, reason: baseUrl);
      }
    });
  });
}
