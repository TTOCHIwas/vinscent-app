import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_text_styles.dart';
import '../../auth/application/auth_controller.dart';
import '../../couple/application/couple_controller.dart';
import '../../profile/application/profile_controller.dart';

class BootScreen extends ConsumerWidget {
  const BootScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileControllerProvider);
    final couple = ref.watch(coupleControllerProvider);
    final hasError = profile.hasError || couple.hasError;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: hasError
              ? Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        '정보를 불러오지 못했어요.',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.sectionTitle,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        '네트워크 연결을 확인한 뒤 다시 시도해주세요.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: () {
                          ref.invalidate(authControllerProvider);
                          ref.invalidate(profileControllerProvider);
                          ref.invalidate(coupleControllerProvider);
                        },
                        child: const Text('다시 시도'),
                      ),
                    ],
                  ),
                )
              : const CircularProgressIndicator(),
        ),
      ),
    );
  }
}
