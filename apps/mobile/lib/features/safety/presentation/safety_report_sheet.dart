import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/presentation/widgets/app_action_button.dart';
import '../../../core/presentation/widgets/app_action_tone.dart';
import '../../../core/presentation/widgets/word_boundary_text.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../data/safety_report.dart';
import '../data/safety_report_failure.dart';
import '../data/safety_report_repository.dart';

Future<bool> showSafetyReportSheet({
  required BuildContext context,
  required SafetyReportTarget target,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: AppColors.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    clipBehavior: Clip.antiAlias,
    builder: (context) => SafetyReportSheet(target: target),
  );

  return result == true;
}

class SafetyReportSheet extends ConsumerStatefulWidget {
  const SafetyReportSheet({super.key, required this.target});

  final SafetyReportTarget target;

  @override
  ConsumerState<SafetyReportSheet> createState() => _SafetyReportSheetState();
}

class _SafetyReportSheetState extends ConsumerState<SafetyReportSheet> {
  final _detailsController = TextEditingController();

  SafetyReportReason? _selectedReason;
  String? _errorMessage;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final reason = _selectedReason;
    if (reason == null || _isSubmitting) {
      return;
    }

    setState(() {
      _errorMessage = null;
      _isSubmitting = true;
    });

    try {
      await ref
          .read(safetyReportRepositoryProvider)
          .submit(
            SafetyReportRequest(
              target: widget.target,
              reason: reason,
              details: _detailsController.text,
            ),
          );
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = _messageForError(error);
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final reasons = _reportReasons(widget.target.type);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            key: const Key('safety-report-sheet'),
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(child: _SheetHandle()),
              const SizedBox(height: 20),
              const WordBoundaryText('신고하기', style: AppTextStyles.sectionTitle),
              const SizedBox(height: 8),
              WordBoundaryText(
                '문제가 있는 이유를 골라줘',
                style: AppTextStyles.homeBody.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 16),
              for (var index = 0; index < reasons.length; index++) ...[
                _ReasonRow(
                  item: reasons[index],
                  selected: _selectedReason == reasons[index].reason,
                  onTap: _isSubmitting
                      ? null
                      : () {
                          setState(() {
                            _selectedReason = reasons[index].reason;
                            _errorMessage = null;
                          });
                        },
                ),
                if (index != reasons.length - 1) const SizedBox(height: 4),
              ],
              const SizedBox(height: 16),
              TextField(
                key: const Key('safety-report-details'),
                controller: _detailsController,
                enabled: !_isSubmitting,
                minLines: 2,
                maxLines: 3,
                maxLength: 1000,
                textInputAction: TextInputAction.newline,
                style: AppTextStyles.homeBody,
                decoration: InputDecoration(
                  hintText: '자세히 알려줘 (선택)',
                  hintStyle: AppTextStyles.homeBody.copyWith(
                    color: AppColors.textPlaceholder,
                  ),
                  counterText: '',
                  filled: true,
                  fillColor: AppColors.formSurface,
                  contentPadding: const EdgeInsets.all(14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              if (_errorMessage case final message?) ...[
                const SizedBox(height: 8),
                WordBoundaryText(message, style: AppTextStyles.compactError),
              ],
              const SizedBox(height: 20),
              AppActionButton(
                key: const Key('safety-report-submit'),
                label: '신고 보내기',
                enabled: _selectedReason != null,
                isLoading: _isSubmitting,
                tone: AppActionTone.brand,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReportReasonItem {
  const _ReportReasonItem({
    required this.reason,
    required this.icon,
    required this.label,
  });

  final SafetyReportReason reason;
  final IconData icon;
  final String label;
}

class _ReasonRow extends StatelessWidget {
  const _ReasonRow({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _ReportReasonItem item;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final foregroundColor = selected
        ? AppColors.selection
        : AppColors.textPrimary;

    return Material(
      color: selected ? AppColors.selectionSurface : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        key: ValueKey('safety-report-reason-${item.reason.name}'),
        onTap: onTap,
        splashColor: AppColors.settingsPressed,
        highlightColor: AppColors.settingsPressed,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          height: 52,
          child: Row(
            children: [
              const SizedBox(width: 12),
              Icon(item.icon, size: 22, color: foregroundColor),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  item.label,
                  style: AppTextStyles.homeBody.copyWith(
                    color: foregroundColor,
                  ),
                ),
              ),
              if (selected)
                const Icon(
                  Icons.check_circle_rounded,
                  size: 20,
                  color: AppColors.selection,
                ),
              const SizedBox(width: 12),
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.settingsDivider,
        borderRadius: BorderRadius.circular(2),
      ),
      child: const SizedBox(width: 36, height: 4),
    );
  }
}

List<_ReportReasonItem> _reportReasons(SafetyReportTargetType targetType) {
  return [
    const _ReportReasonItem(
      reason: SafetyReportReason.inappropriate,
      icon: Icons.report_outlined,
      label: '불쾌하거나 부적절해요',
    ),
    if (_isAiTarget(targetType))
      const _ReportReasonItem(
        reason: SafetyReportReason.unsafeAi,
        icon: Icons.warning_amber_rounded,
        label: '위험하거나 잘못된 AI 답변이에요',
      )
    else
      const _ReportReasonItem(
        reason: SafetyReportReason.harassment,
        icon: Icons.shield_outlined,
        label: '괴롭힘이나 위협이 있어요',
      ),
    const _ReportReasonItem(
      reason: SafetyReportReason.privacy,
      icon: Icons.lock_outline_rounded,
      label: '개인정보가 드러나요',
    ),
    const _ReportReasonItem(
      reason: SafetyReportReason.spam,
      icon: Icons.mark_chat_unread_outlined,
      label: '스팸 또는 반복된 내용이에요',
    ),
    const _ReportReasonItem(
      reason: SafetyReportReason.other,
      icon: Icons.more_horiz_rounded,
      label: '다른 문제가 있어요',
    ),
  ];
}

bool _isAiTarget(SafetyReportTargetType targetType) {
  return switch (targetType) {
    SafetyReportTargetType.aiQuestion ||
    SafetyReportTargetType.aiFeedback ||
    SafetyReportTargetType.aiDirectAnswer ||
    SafetyReportTargetType.aiProactiveSuggestion ||
    SafetyReportTargetType.aiMemory => true,
    _ => false,
  };
}

String _messageForError(Object error) {
  final reason = error is SafetyReportException
      ? error.reason
      : SafetyReportFailureReason.unknown;

  return switch (reason) {
    SafetyReportFailureReason.configMissing => '서비스 연결을 확인해 주세요',
    SafetyReportFailureReason.authRequired => '로그인이 만료됐어요. 다시 로그인해 주세요',
    SafetyReportFailureReason.activeCoupleRequired => '커플 연결 상태를 확인해 주세요',
    SafetyReportFailureReason.invalidTarget ||
    SafetyReportFailureReason.targetNotAvailable => '신고할 내용을 다시 확인해 주세요',
    SafetyReportFailureReason.invalidReason => '신고 사유를 다시 골라 주세요',
    SafetyReportFailureReason.detailsTooLong => '상세 내용은 1000자 이내로 작성해 주세요',
    SafetyReportFailureReason.snapshotRequired ||
    SafetyReportFailureReason.snapshotTooLong => '신고할 내용을 불러오지 못했어요',
    SafetyReportFailureReason.requestTimeout => '요청이 늦어지고 있어요. 다시 시도해 주세요',
    SafetyReportFailureReason.unknown => '신고를 보내지 못했어요. 잠시 후 다시 시도해 주세요',
  };
}
