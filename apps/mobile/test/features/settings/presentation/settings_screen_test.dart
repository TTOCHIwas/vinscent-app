import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vinscent/features/settings/presentation/settings_screen.dart';

void main() {
  testWidgets('커플 설정 영역에서 캐릭터 편집 화면을 연다', (tester) async {
    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: GoRouter(
          initialLocation: '/settings',
          routes: [
            GoRoute(
              path: '/settings',
              builder: (context, state) => const SettingsScreen(),
            ),
            GoRoute(
              path: '/settings/character',
              builder: (context, state) => const Text('character editor'),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('캐릭터 꾸미기'), findsOneWidget);

    await tester.tap(find.text('캐릭터 꾸미기'));
    await tester.pumpAndSettle();

    expect(find.text('character editor'), findsOneWidget);
  });
}
