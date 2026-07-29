import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vinscent/core/presentation/widgets/app_back_button.dart';
import 'package:vinscent/core/presentation/widgets/app_page_header.dart';
import 'package:vinscent/features/settings/application/policy_document_links.dart';
import 'package:vinscent/features/settings/data/policy_document_launcher.dart';
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

  testWidgets('계정 설정 화면을 연다', (tester) async {
    await _pumpSettings(tester);

    await tester.scrollUntilVisible(
      find.byKey(const Key('settings-row-account')),
      100,
      scrollable: find.byType(Scrollable),
    );
    await tester.tap(find.byKey(const Key('settings-row-account')));
    await tester.pumpAndSettle();

    expect(find.text('account settings'), findsOneWidget);
  });

  testWidgets('차단한 사용자 관리 화면을 연다', (tester) async {
    await _pumpSettings(tester);

    await tester.scrollUntilVisible(
      find.byKey(const Key('settings-row-blocked-users')),
      100,
      scrollable: find.byType(Scrollable),
    );
    await tester.tap(find.byKey(const Key('settings-row-blocked-users')));
    await tester.pumpAndSettle();

    expect(find.text('blocked users'), findsOneWidget);
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
    expect(
      find.descendant(
        of: find.byType(SettingsPageHeader),
        matching: find.byType(AppPageHeader),
      ),
      findsOneWidget,
    );
  });

  testWidgets('설정 항목은 섹션별 그룹 목록으로 이어서 보여준다', (tester) async {
    _useTallViewport(tester);
    await _pumpSettings(tester);

    final notificationGroup = find.byKey(
      const Key('settings-group-notifications'),
    );
    final coupleGroup = find.byKey(const Key('settings-group-couple'));
    final accountGroup = find.byKey(const Key('settings-group-account'));
    final policyGroup = find.byKey(const Key('settings-group-policy'));

    expect(notificationGroup, findsOneWidget);
    expect(coupleGroup, findsOneWidget);
    expect(accountGroup, findsOneWidget);
    expect(policyGroup, findsOneWidget);
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
    expect(
      find.descendant(
        of: accountGroup,
        matching: find.byKey(const Key('settings-row-account')),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: policyGroup,
        matching: find.byKey(const Key('settings-row-privacy')),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: policyGroup,
        matching: find.byKey(const Key('settings-row-terms')),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: policyGroup,
        matching: find.byKey(const Key('settings-row-support')),
      ),
      findsOneWidget,
    );
  });

  testWidgets('개인정보처리방침을 검증된 외부 주소로 연다', (tester) async {
    _useTallViewport(tester);
    final launcher = _FakePolicyDocumentLauncher();
    await _pumpSettings(
      tester,
      policyDocumentLinks: const PolicyDocumentLinks(
        baseUrl: 'https://policy.danjjan.example',
      ),
      policyDocumentLauncher: launcher,
    );

    await tester.scrollUntilVisible(
      find.byKey(const Key('settings-row-privacy')),
      100,
      scrollable: find.byType(Scrollable),
    );
    await tester.tap(find.byKey(const Key('settings-row-privacy')));
    await tester.pumpAndSettle();

    expect(launcher.launchedUris, [
      Uri.parse('https://policy.danjjan.example/privacy'),
    ]);
  });

  testWidgets('정책 주소가 없으면 준비 중 안내를 보여준다', (tester) async {
    _useTallViewport(tester);
    final launcher = _FakePolicyDocumentLauncher();
    await _pumpSettings(
      tester,
      policyDocumentLinks: const PolicyDocumentLinks(baseUrl: ''),
      policyDocumentLauncher: launcher,
    );

    await tester.scrollUntilVisible(
      find.byKey(const Key('settings-row-terms')),
      100,
      scrollable: find.byType(Scrollable),
    );
    await tester.tap(find.byKey(const Key('settings-row-terms')));
    await tester.pumpAndSettle();

    expect(launcher.launchedUris, isEmpty);
    expect(find.text('페이지를 준비하고 있어요'), findsOneWidget);
  });

  testWidgets('고객지원 페이지를 검증된 외부 주소로 연다', (tester) async {
    _useTallViewport(tester);
    final launcher = _FakePolicyDocumentLauncher();
    await _pumpSettings(
      tester,
      policyDocumentLinks: const PolicyDocumentLinks(
        baseUrl: 'https://policy.danjjan.example',
      ),
      policyDocumentLauncher: launcher,
    );

    await tester.scrollUntilVisible(
      find.byKey(const Key('settings-row-support')),
      100,
      scrollable: find.byType(Scrollable),
    );
    await tester.tap(find.byKey(const Key('settings-row-support')));
    await tester.pumpAndSettle();

    expect(launcher.launchedUris, [
      Uri.parse('https://policy.danjjan.example/support'),
    ]);
  });
}

Future<void> _pumpSettings(
  WidgetTester tester, {
  double textScaleFactor = 1,
  PolicyDocumentLinks policyDocumentLinks = PolicyDocumentLinks.configured,
  PolicyDocumentLauncher policyDocumentLauncher =
      const UrlLauncherPolicyDocumentLauncher(),
}) async {
  final router = GoRouter(
    initialLocation: '/settings',
    routes: [
      GoRoute(
        path: '/settings',
        builder: (context, state) => SettingsScreen(
          policyDocumentLinks: policyDocumentLinks,
          policyDocumentLauncher: policyDocumentLauncher,
        ),
      ),
      GoRoute(
        path: '/settings/character',
        builder: (context, state) => const Text('character editor'),
      ),
      GoRoute(
        path: '/settings/account',
        builder: (context, state) => const Text('account settings'),
      ),
      GoRoute(
        path: '/settings/blocked-users',
        builder: (context, state) => const Text('blocked users'),
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
          child: Scaffold(body: child!),
        );
      },
    ),
  );
  await tester.pumpAndSettle();
}

void _useTallViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

class _FakePolicyDocumentLauncher implements PolicyDocumentLauncher {
  final launchedUris = <Uri>[];

  @override
  Future<bool> launch(Uri uri) async {
    launchedUris.add(uri);
    return true;
  }
}
