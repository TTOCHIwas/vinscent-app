import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/auth/application/social_login_controller.dart';
import 'package:vinscent/features/auth/application/social_login_state.dart';
import 'package:vinscent/features/auth/data/apple_auth_client.dart';
import 'package:vinscent/features/auth/data/kakao_auth_client.dart';
import 'package:vinscent/features/auth/data/social_auth_failure.dart';
import 'package:vinscent/features/auth/data/social_session_repository.dart';

void main() {
  test(
    'signInWithKakao creates a Supabase session through repository',
    () async {
      final repository = _FakeSocialSessionRepository();
      final kakaoClient = _FakeKakaoAuthClient(
        tokens: const KakaoLoginTokens(idToken: 'id', accessToken: 'access'),
      );
      final container = ProviderContainer(
        overrides: [
          kakaoAuthClientProvider.overrideWithValue(kakaoClient),
          socialSessionRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);
      final states = <SocialLoginState>[];

      container.listen(
        socialLoginControllerProvider,
        (_, next) => states.add(next),
        fireImmediately: true,
      );

      await container
          .read(socialLoginControllerProvider.notifier)
          .signInWithKakao();

      expect(repository.kakaoSignInCount, 1);
      expect(kakaoClient.signInCount, 1);
      expect(states[1].isSigningInWith(SocialAuthProvider.kakao), isTrue);
      expect(container.read(socialLoginControllerProvider).failure, isNull);
    },
  );

  test(
    'signInWithKakao fails before provider login when Supabase is missing',
    () async {
      final kakaoClient = _FakeKakaoAuthClient(
        tokens: const KakaoLoginTokens(idToken: 'id', accessToken: 'access'),
      );
      final container = ProviderContainer(
        overrides: [
          kakaoAuthClientProvider.overrideWithValue(kakaoClient),
          socialSessionRepositoryProvider.overrideWithValue(
            _FakeSocialSessionRepository(canCreateSession: false),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(socialLoginControllerProvider.notifier)
          .signInWithKakao();

      expect(kakaoClient.signInCount, 0);
      expect(
        container.read(socialLoginControllerProvider).failure?.reason,
        SocialAuthFailureReason.notConfigured,
      );
    },
  );

  test('signInWithApple stores unsupported platform failure', () async {
    final failure = const SocialAuthFailure(
      SocialAuthFailureReason.unsupportedPlatform,
    );
    final container = ProviderContainer(
      overrides: [
        appleAuthClientProvider.overrideWithValue(
          _FakeAppleAuthClient(failure: failure),
        ),
        socialSessionRepositoryProvider.overrideWithValue(
          _FakeSocialSessionRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container
        .read(socialLoginControllerProvider.notifier)
        .signInWithApple();

    expect(
      container.read(socialLoginControllerProvider).failure?.reason,
      SocialAuthFailureReason.unsupportedPlatform,
    );
  });
}

class _FakeKakaoAuthClient implements KakaoAuthClient {
  _FakeKakaoAuthClient({required this.tokens});

  final KakaoLoginTokens tokens;
  var signInCount = 0;

  @override
  Future<KakaoLoginTokens> signIn() async {
    signInCount++;
    return tokens;
  }
}

class _FakeAppleAuthClient implements AppleAuthClient {
  const _FakeAppleAuthClient({required this.failure});

  final SocialAuthFailure failure;

  @override
  Future<AppleLoginTokens> signIn() async {
    throw failure;
  }
}

class _FakeSocialSessionRepository implements SocialSessionRepository {
  _FakeSocialSessionRepository({this.canCreateSession = true});

  @override
  final bool canCreateSession;

  var kakaoSignInCount = 0;

  @override
  Future<void> signInWithKakao(KakaoLoginTokens tokens) async {
    kakaoSignInCount++;
  }

  @override
  Future<void> signInWithApple(AppleLoginTokens tokens) async {}
}
