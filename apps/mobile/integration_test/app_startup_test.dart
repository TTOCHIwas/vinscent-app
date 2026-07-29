import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home_widget/home_widget.dart';
import 'package:integration_test/integration_test.dart';
import 'package:vinscent/core/config/app_config.dart';
import 'package:vinscent/features/auth/presentation/login_screen.dart';
import 'package:vinscent/features/auth/presentation/widgets/apple_login_button.dart';
import 'package:vinscent/features/auth/presentation/widgets/kakao_login_button.dart';
import 'package:vinscent/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'production main cold starts safely without release configuration',
    (tester) async {
      app.main();
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 30),
      );

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(KakaoLoginButton), findsOneWidget);
      expect(find.byType(AppleLoginButton), findsOneWidget);
      expect(AppConfig.isSupabaseConfigured, isFalse);
      expect(Firebase.apps, isNotEmpty);
      await FirebaseMessaging.instance.getInitialMessage();
      await HomeWidget.initiallyLaunchedFromHomeWidget();
      expect(tester.takeException(), isNull);

      await tester.tap(find.byType(KakaoLoginButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(SnackBar), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
