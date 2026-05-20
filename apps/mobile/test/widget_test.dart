import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/app/app.dart';

void main() {
  testWidgets('redirects unauthenticated users to login screen', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: VinscentApp()));
    await tester.pumpAndSettle();

    expect(find.text('카카오 로그인'), findsOneWidget);
    expect(find.text('Apple로 로그인'), findsOneWidget);
  });
}
