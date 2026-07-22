import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vinscent/core/presentation/widgets/app_back_button.dart';
import 'package:vinscent/features/settings/presentation/settings_screen.dart';
import 'package:vinscent/features/settings/presentation/widgets/settings_page_header.dart';
import 'package:vinscent/features/shell/presentation/app_shell.dart';

void main() {
  testWidgets('커플 설정 영역에서 캐릭터 편집 화면을 연다', (tester) async {
    await _pumpSettings(tester);

    expect(find.text('캐릭터 꾸미기'), findsOneWidget);

    await tester.tap(find.text('캐릭터 꾸미기'));
    await tester.pumpAndSettle();

    expect(find.text('character editor'), findsOneWidget);
  });

  testWidgets('작은 화면과 확대 글자에서도 설정 항목을 스크롤해 확인한다', (tester) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpSettings(tester, textScaleFactor: 1.5);

    expect(tester.takeException(), isNull);
    expect(find.byType(Scrollable), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('커플 설정'),
      100,
      scrollable: find.byType(Scrollable),
    );
    expect(find.text('커플 설정'), findsOneWidget);
  });

  testWidgets('설정 헤더는 shell 상단 여백 바로 아래에 배치된다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(padding: EdgeInsets.only(top: 32)),
          child: const AppShell(location: '/settings', child: SettingsScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.getTopLeft(find.byType(SettingsPageHeader)).dy,
      AppShell.topMinHeight,
    );
  });

  testWidgets('설정 헤더의 뒤로가기 버튼은 화면 끝에서 20px 떨어진다', (tester) async {
    await _pumpSettings(tester);

    final headerLeft = tester.getTopLeft(find.byType(SettingsPageHeader)).dx;
    final backButtonLeft = tester.getTopLeft(find.byType(AppBackButton)).dx;

    expect(backButtonLeft - headerLeft, 20);
  });

  testWidgets('설정 항목은 섹션별 그룹 목록으로 이어서 보여준다', (tester) async {
    await _pumpSettings(tester);

    final notificationGroup = find.byKey(
      const Key('settings-group-notifications'),
    );
    final coupleGroup = find.byKey(const Key('settings-group-couple'));

    expect(notificationGroup, findsOneWidget);
    expect(coupleGroup, findsOneWidget);
    expect(
      find.descendant(
        of: notificationGroup,
        matching: find.byKey(const Key('settings-row-notifications')),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: coupleGroup,
        matching: find.byKey(const Key('settings-row-character')),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: coupleGroup,
        matching: find.byKey(const Key('settings-row-couple')),
      ),
      findsOneWidget,
    );
  });
}

Future<void> _pumpSettings(
  WidgetTester tester, {
  double textScaleFactor = 1,
}) async {
  final router = GoRouter(
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
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    MaterialApp.router(
      routerConfig: router,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScaleFactor)),
          child: child!,
        );
      },
    ),
  );
  await tester.pumpAndSettle();
}
