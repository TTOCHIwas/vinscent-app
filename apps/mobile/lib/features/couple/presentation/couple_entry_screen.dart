import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/presentation/widgets/app_action_button.dart';
import '../../../core/presentation/widgets/app_action_tone.dart';
import '../../../core/presentation/widgets/app_confirmation_dialog.dart';
import '../../../core/presentation/widgets/app_setup_page.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../safety/application/user_block_providers.dart';
import '../../safety/application/user_block_service.dart';
import '../../safety/data/user_block.dart';
import '../../safety/data/user_block_failure.dart';
import '../application/couple_flow_controller.dart';
import '../application/couple_flow_state.dart';
import 'widgets/couple_connection_mode_selector.dart';
import 'widgets/reconnectable_couple_archive_section.dart';

class CoupleEntryScreen extends ConsumerStatefulWidget {
  const CoupleEntryScreen({super.key});

  @override
  ConsumerState<CoupleEntryScreen> createState() => _CoupleEntryScreenState();
}

class _CoupleEntryScreenState extends ConsumerState<CoupleEntryScreen> {
  CoupleConnectionMode _mode = CoupleConnectionMode.createInvite;
  late final TextEditingController _inviteCodeController;
  String? _reconnectingCoupleId;
  String? _safetyErrorMessage;

  @override
  void initState() {
    super.initState();
    _inviteCodeController = TextEditingController(
      text: ref.read(coupleFlowControllerProvider).inviteCode,
    );
  }

  @override
  void dispose() {
    _inviteCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(coupleFlowControllerProvider);
    final controller = ref.read(coupleFlowControllerProvider.notifier);
    final isCreateMode = _mode == CoupleConnectionMode.createInvite;
    final reconnectableArchives = ref
        .watch(reconnectableCoupleArchivesProvider)
        .maybeWhen(
          data: (archives) => archives,
          orElse: () => const <ReconnectableCoupleArchive>[],
        );
    final isReconnecting = _reconnectingCoupleId != null;
    final isProcessing = state.isSubmitting || isReconnecting;

    return AppSetupPage(
      header: const AppSetupHeader(),
      bottomAction: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if ((state.errorMessage ?? _safetyErrorMessage)
              case final errorMessage?) ...[
            Text(errorMessage, style: AppTextStyles.compactError),
            const SizedBox(height: 10),
          ],
          AppActionButton(
            label: isCreateMode ? '초대 코드 만들기' : '연결하기',
            enabled: isCreateMode
                ? !isProcessing
                : state.canJoin && !isReconnecting,
            isLoading: isCreateMode
                ? state.operation == CoupleFlowOperation.creating
                : state.operation == CoupleFlowOperation.joining,
            tone: AppActionTone.brand,
            onPressed: isCreateMode
                ? controller.createInvite
                : controller.joinByCode,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('둘만의 공간을 연결해볼까?', style: AppTextStyles.onboardingTitle),
          const SizedBox(height: 8),
          Text(
            '한 사람이 초대 코드를 만들고 상대방이 입력하면 연결돼',
            style: AppTextStyles.homeBody.copyWith(color: AppColors.textMuted),
          ),
          if (reconnectableArchives.isNotEmpty) ...[
            const SizedBox(height: 28),
            ReconnectableCoupleArchiveSection(
              archives: reconnectableArchives,
              enabled: !isProcessing,
              processingCoupleId: _reconnectingCoupleId,
              onSelected: _confirmReconnect,
            ),
          ],
          const SizedBox(height: 32),
          CoupleConnectionModeSelector(
            selectedMode: _mode,
            onSelected: _selectMode,
          ),
          const SizedBox(height: 28),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: isCreateMode
                ? const _CreateInviteContent(
                    key: ValueKey(CoupleConnectionMode.createInvite),
                  )
                : _EnterCodeContent(
                    key: const ValueKey(CoupleConnectionMode.enterCode),
                    controller: _inviteCodeController,
                    canJoin: state.canJoin,
                    onChanged: controller.updateInviteCode,
                    onSubmitted: controller.joinByCode,
                  ),
          ),
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.center,
            child: TextButton.icon(
              key: const Key('couple-entry-blocked-users-action'),
              onPressed: isProcessing
                  ? null
                  : () => context.push('/settings/blocked-users'),
              icon: const Icon(Icons.block_outlined, size: 19),
              label: const Text('차단한 사용자 관리'),
            ),
          ),
        ],
      ),
    );
  }

  void _selectMode(CoupleConnectionMode mode) {
    if (_mode == mode) {
      return;
    }
    ref.read(coupleFlowControllerProvider.notifier).clearError();
    setState(() {
      _mode = mode;
      _safetyErrorMessage = null;
    });
  }

  Future<void> _confirmReconnect(ReconnectableCoupleArchive archive) async {
    final confirmed = await showAppConfirmationDialog(
      context: context,
      title: '${archive.partnerDisplayName}님과 다시 연결할까?',
      message:
          '차단 해제만으로는 다시 연결되지 않아\n'
          '상대방이 새 초대 코드를 입력하면 기존 기록을 이어서 사용할 수 있어',
      confirmLabel: '재연결 초대 만들기',
      isDestructive: false,
    );
    if (!mounted || !confirmed) {
      return;
    }

    setState(() {
      _reconnectingCoupleId = archive.coupleId;
      _safetyErrorMessage = null;
    });

    try {
      await ref
          .read(userBlockServiceProvider)
          .createReconnectInvite(archive.coupleId);
    } catch (error) {
      if (mounted) {
        setState(() {
          _safetyErrorMessage = _reconnectFailureMessage(error);
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _reconnectingCoupleId = null;
        });
      }
    }
  }

  String _reconnectFailureMessage(Object error) {
    if (error is! UserBlockException) {
      return '재연결 초대를 만들지 못했어요. 다시 시도해 주세요';
    }

    return switch (error.reason) {
      UserBlockFailureReason.userBlocked => '서로의 차단을 먼저 해제해 주세요',
      UserBlockFailureReason.archiveNotAvailable =>
        '보관 기간이 끝났거나 기록을 더 이상 이어갈 수 없어요',
      UserBlockFailureReason.coupleAlreadyExists => '이미 진행 중인 커플 연결이 있어요',
      UserBlockFailureReason.authRequired => '로그인 세션을 다시 확인해 주세요',
      _ => '재연결 초대를 만들지 못했어요. 다시 시도해 주세요',
    };
  }
}

class _CreateInviteContent extends StatelessWidget {
  const _CreateInviteContent({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.ios_share_outlined, size: 28),
        const SizedBox(height: 14),
        Text(
          '새 코드를 만들어 상대방에게 보내줘\n상대방이 입력하면 자동으로 다음 단계로 넘어가',
          style: AppTextStyles.homeBody.copyWith(color: AppColors.textMuted),
        ),
      ],
    );
  }
}

class _EnterCodeContent extends StatelessWidget {
  const _EnterCodeContent({
    super.key,
    required this.controller,
    required this.canJoin,
    required this.onChanged,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final bool canJoin;
  final ValueChanged<String> onChanged;
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          autofocus: true,
          autofillHints: const [AutofillHints.oneTimeCode],
          autocorrect: false,
          enableSuggestions: false,
          keyboardType: TextInputType.visiblePassword,
          textCapitalization: TextCapitalization.characters,
          textInputAction: TextInputAction.done,
          textAlign: TextAlign.center,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9]')),
            LengthLimitingTextInputFormatter(6),
            _UpperCaseTextFormatter(),
          ],
          style: AppTextStyles.onboardingInput.copyWith(letterSpacing: 6),
          decoration: InputDecoration(
            hintText: 'ABC234',
            hintStyle: AppTextStyles.onboardingInput.copyWith(
              color: AppColors.textPlaceholder,
              letterSpacing: 6,
            ),
            filled: true,
            fillColor: AppColors.formSurface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: AppColors.textPrimary),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
          onChanged: onChanged,
          onSubmitted: (_) {
            if (canJoin) {
              onSubmitted();
            }
          },
        ),
        const SizedBox(height: 12),
        Text(
          '영문과 숫자 6자리',
          style: AppTextStyles.onboardingHint.copyWith(
            color: AppColors.textMuted,
          ),
        ),
      ],
    );
  }
}

class _UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}
