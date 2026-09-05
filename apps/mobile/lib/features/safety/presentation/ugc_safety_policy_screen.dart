import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/presentation/widgets/app_action_button.dart';
import '../../../core/presentation/widgets/app_action_tone.dart';
import '../../../core/presentation/widgets/app_loading_indicator.dart';
import '../../../core/presentation/widgets/app_setup_page.dart';
import '../../../core/presentation/widgets/word_boundary_text.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../auth/application/auth_controller.dart';
import '../application/ugc_safety_policy_controller.dart';
import '../data/ugc_safety_policy_failure.dart';

class UgcSafetyPolicyScreen extends ConsumerStatefulWidget {
  const UgcSafetyPolicyScreen({super.key});

  @override
  ConsumerState<UgcSafetyPolicyScreen> createState() =>
      _UgcSafetyPolicyScreenState();
}

class _UgcSafetyPolicyScreenState extends ConsumerState<UgcSafetyPolicyScreen> {
  var _hasAcknowledged = false;
  var _isSubmitting = false;
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    final policyStatus = ref.watch(ugcSafetyPolicyControllerProvider);

    return AppSetupPage(
      header: AppSetupHeader(
        action: IconButton(
          key: const Key('ugc-policy-sign-out-button'),
          tooltip: '로그아웃',
          onPressed: _isSubmitting ? null : _signOut,
          icon: const Icon(LucideIcons.logOut, size: 22),
        ),
      ),
      bottomAction: policyStatus.when(
        loading: () => const SizedBox(
          height: 56,
          child: Center(child: AppLoadingIndicator()),
        ),
        error: (_, _) => AppActionButton(
          key: const Key('ugc-policy-retry-button'),
          label: '다시 불러오기',
          enabled: true,
          onPressed: () {
            ref.invalidate(ugcSafetyPolicyControllerProvider);
          },
        ),
        data: (status) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_errorMessage case final errorMessage?) ...[
              WordBoundaryText(errorMessage, style: AppTextStyles.compactError),
              const SizedBox(height: 10),
            ],
            AppActionButton(
              key: const Key('ugc-policy-accept-button'),
              label: '동의하고 계속',
              enabled: status != null && !status.isAccepted && _hasAcknowledged,
              isLoading: _isSubmitting,
              tone: AppActionTone.brand,
              onPressed: _acceptPolicy,
            ),
          ],
        ),
      ),
      child: policyStatus.when(
        loading: () => const SizedBox.shrink(),
        error: (_, _) => const _PolicyLoadFailure(),
        data: (status) => status == null
            ? const _PolicyLoadFailure()
            : _PolicyContent(
                hasAcknowledged: _hasAcknowledged,
                onAcknowledgedChanged: _isSubmitting
                    ? null
                    : (value) {
                        setState(() {
                          _hasAcknowledged = value;
                          _errorMessage = null;
                        });
                      },
                onOpenAccountSettings: _isSubmitting
                    ? null
                    : () => context.push('/settings/account'),
              ),
      ),
    );
  }

  Future<void> _acceptPolicy() async {
    if (!_hasAcknowledged || _isSubmitting) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    try {
      await ref
          .read(ugcSafetyPolicyControllerProvider.notifier)
          .acceptCurrentPolicy();
    } on UgcSafetyPolicyException catch (error) {
      if (mounted) {
        setState(() {
          _errorMessage = _failureMessage(error.reason);
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _errorMessage = _failureMessage(UgcSafetyPolicyFailureReason.unknown);
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _signOut() async {
    try {
      await ref.read(authControllerProvider.notifier).signOut();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('로그아웃하지 못했어요. 다시 시도해 주세요')),
        );
      }
    }
  }

  String _failureMessage(UgcSafetyPolicyFailureReason reason) {
    return switch (reason) {
      UgcSafetyPolicyFailureReason.versionOutdated =>
        '안전 이용 약속이 업데이트됐어요. 내용을 다시 확인해 주세요',
      UgcSafetyPolicyFailureReason.authRequired => '로그인 정보가 만료됐어요. 다시 로그인해 주세요',
      UgcSafetyPolicyFailureReason.configMissing => '서비스 설정을 확인해 주세요',
      UgcSafetyPolicyFailureReason.requestTimeout => '요청 시간이 초과됐어요. 다시 시도해 주세요',
      UgcSafetyPolicyFailureReason.invalidResponse ||
      UgcSafetyPolicyFailureReason.unknown => '동의를 저장하지 못했어요. 잠시 후 다시 시도해 주세요',
    };
  }
}

class _PolicyContent extends StatelessWidget {
  const _PolicyContent({
    required this.hasAcknowledged,
    required this.onAcknowledgedChanged,
    required this.onOpenAccountSettings,
  });

  final bool hasAcknowledged;
  final ValueChanged<bool>? onAcknowledgedChanged;
  final VoidCallback? onOpenAccountSettings;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          LucideIcons.shieldCheck,
          size: 36,
          color: AppColors.textPrimary,
        ),
        const SizedBox(height: 20),
        const WordBoundaryText(
          '안전하게 함께 쓰기',
          style: AppTextStyles.onboardingTitle,
        ),
        const SizedBox(height: 10),
        WordBoundaryText(
          '단짠은 연결한 두 사람이 카드, 답변, 그림과 녹음을 나누는 공간이에요',
          style: AppTextStyles.homeBody.copyWith(color: AppColors.textMuted),
        ),
        const SizedBox(height: 28),
        const _PolicyRule(
          icon: LucideIcons.heartHandshake,
          title: '서로를 존중해요',
          description: '모욕, 괴롭힘, 혐오와 위협이 담긴 콘텐츠는 올리지 않아요',
        ),
        const SizedBox(height: 18),
        const _PolicyRule(
          icon: LucideIcons.circleAlert,
          title: '위험한 콘텐츠를 나누지 않아요',
          description: '성적 착취, 불법 행위, 자해나 위험 행동을 조장하는 콘텐츠는 금지돼요',
        ),
        const SizedBox(height: 18),
        const _PolicyRule(
          icon: LucideIcons.shieldCheck,
          title: '개인정보를 지켜요',
          description: '상대방이나 다른 사람의 개인정보를 허락 없이 공유하지 않아요',
        ),
        const SizedBox(height: 18),
        const _PolicyRule(
          icon: LucideIcons.flag,
          title: '불편한 콘텐츠는 바로 신고할 수 있어요',
          description: '신고된 콘텐츠는 검토 후 삭제될 수 있고 계정 이용이 제한될 수 있어요',
        ),
        const SizedBox(height: 28),
        Material(
          color: AppColors.formSurface,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            key: const Key('ugc-policy-acknowledgement'),
            onTap: onAcknowledgedChanged == null
                ? null
                : () => onAcknowledgedChanged!(!hasAcknowledged),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox.square(
                    dimension: 24,
                    child: Checkbox(
                      key: const Key('ugc-policy-checkbox'),
                      value: hasAcknowledged,
                      activeColor: AppColors.selection,
                      checkColor: AppColors.onSelection,
                      onChanged: onAcknowledgedChanged == null
                          ? null
                          : (value) {
                              onAcknowledgedChanged!(value ?? false);
                            },
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: WordBoundaryText(
                      '위 내용을 확인했고 안전 이용 약속에 동의해요',
                      style: AppTextStyles.homeBodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Center(
          child: TextButton.icon(
            key: const Key('ugc-policy-account-settings-button'),
            onPressed: onOpenAccountSettings,
            icon: const Icon(Icons.manage_accounts_outlined, size: 20),
            label: const Text('계정 관리'),
            style: TextButton.styleFrom(foregroundColor: AppColors.textMuted),
          ),
        ),
      ],
    );
  }
}

class _PolicyRule extends StatelessWidget {
  const _PolicyRule({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 21, color: AppColors.textPrimary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              WordBoundaryText(title, style: AppTextStyles.homeBodyMedium),
              const SizedBox(height: 3),
              WordBoundaryText(
                description,
                style: AppTextStyles.homeBody.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PolicyLoadFailure extends StatelessWidget {
  const _PolicyLoadFailure();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: WordBoundaryText(
        '안전 이용 약속을 불러오지 못했어요',
        textAlign: TextAlign.center,
        style: AppTextStyles.sectionTitle,
      ),
    );
  }
}
