import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../../auth/application/auth_status.dart';
import '../data/profile_repository.dart';
import '../data/user_profile.dart';

final profileControllerProvider =
    AsyncNotifierProvider<ProfileController, UserProfile?>(
      ProfileController.new,
    );

class ProfileController extends AsyncNotifier<UserProfile?> {
  @override
  Future<UserProfile?> build() async {
    final authStatus = ref.watch(authControllerProvider);
    if (authStatus != AuthStatus.authenticated) {
      return null;
    }

    return ref.watch(profileRepositoryProvider).fetchCurrentProfile();
  }

  Future<UserProfile> completeOnboarding({
    required String displayName,
    required DateTime birthDate,
  }) async {
    final profile = await ref
        .read(profileRepositoryProvider)
        .completeOnboarding(displayName: displayName, birthDate: birthDate);

    state = AsyncValue.data(profile);
    return profile;
  }
}
