import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/profile/application/profile_controller.dart';
import 'package:vinscent/features/profile/application/profile_display_name_editor_controller.dart';
import 'package:vinscent/features/profile/data/profile_repository.dart';
import 'package:vinscent/features/profile/data/user_profile.dart';

void main() {
  test('normalizes and saves a valid changed nickname', () async {
    final repository = _ProfileRepository();
    final container = ProviderContainer(
      overrides: [
        profileRepositoryProvider.overrideWithValue(repository),
        profileControllerProvider.overrideWithBuild(
          (ref, notifier) async => repository.profile,
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(profileDisplayNameEditorControllerProvider.future);
    final controller = container.read(
      profileDisplayNameEditorControllerProvider.notifier,
    );
    controller.updateValue('  초코  ');
    expect(
      container
          .read(profileDisplayNameEditorControllerProvider)
          .requireValue
          .canSave,
      isTrue,
    );

    expect(await controller.save(), isTrue);
    expect(repository.savedDisplayName, '초코');
    expect(
      container
          .read(profileDisplayNameEditorControllerProvider)
          .requireValue
          .originalValue,
      '초코',
    );
  });

  test('does not save a nickname shorter than two characters', () async {
    final repository = _ProfileRepository();
    final container = ProviderContainer(
      overrides: [
        profileControllerProvider.overrideWithBuild(
          (ref, notifier) async => repository.profile,
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(profileDisplayNameEditorControllerProvider.future);
    final controller = container.read(
      profileDisplayNameEditorControllerProvider.notifier,
    );
    controller.updateValue('한');

    expect(await controller.save(), isFalse);
    expect(repository.savedDisplayName, isNull);
  });
}

class _ProfileRepository implements ProfileRepository {
  UserProfile profile = _profile('또치');
  String? savedDisplayName;

  @override
  Future<UserProfile> updateDisplayName(String displayName) async {
    savedDisplayName = displayName;
    return profile = _profile(displayName);
  }

  @override
  Future<UserProfile?> fetchCurrentProfile() async => profile;

  @override
  Future<UserProfile> completeOnboarding({
    required String displayName,
    required DateTime birthDate,
  }) => throw UnimplementedError();
}

UserProfile _profile(String displayName) {
  return UserProfile(
    id: 'user-id',
    displayName: displayName,
    birthDate: DateTime(2000),
    onboardingCompletedAt: DateTime(2026),
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
}
