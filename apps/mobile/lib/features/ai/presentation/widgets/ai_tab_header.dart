import 'package:flutter/material.dart';

import '../../../../core/presentation/widgets/app_attention_indicator.dart';
import '../../../../core/presentation/widgets/word_boundary_text.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

class AiTabHeader extends StatelessWidget {
  const AiTabHeader({
    super.key,
    required this.isQuestionReady,
    this.remainingQuestionCount,
    this.onHistoryPressed,
    this.onMemoryPressed,
    this.showMemoryAttention = false,
  }) : assert(
         !isQuestionReady ||
             (onHistoryPressed != null && onMemoryPressed != null),
       );

  static const minHeight = 56.0;

  final bool isQuestionReady;
  final int? remainingQuestionCount;
  final VoidCallback? onHistoryPressed;
  final VoidCallback? onMemoryPressed;
  final bool showMemoryAttention;

  @override
  Widget build(BuildContext context) {
    if (!isQuestionReady) {
      return ConstrainedBox(
        key: const Key('ai-tab-header'),
        constraints: const BoxConstraints(minHeight: AiTabHeader.minHeight),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: WordBoundaryText('서로 알아가기', style: AppTextStyles.pageTitle),
          ),
        ),
      );
    }

    return ConstrainedBox(
      key: const Key('ai-tab-header'),
      constraints: const BoxConstraints(minHeight: 68),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 7, 12, 7),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const WordBoundaryText(
                    '물어보기',
                    style: AppTextStyles.pageTitle,
                  ),
                  const SizedBox(height: 1),
                  WordBoundaryText(
                    _remainingCountLabel(remainingQuestionCount),
                    key: const Key('ai-tab-remaining-count'),
                    maxLines: 2,
                    style: AppTextStyles.homeCharacterLabel.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            _HeaderAction(
              actionKey: const Key('ai-tab-history-action'),
              tooltip: '지난 질문',
              icon: Icons.history_rounded,
              onPressed: onHistoryPressed!,
            ),
            _HeaderAction(
              actionKey: const Key('ai-tab-memory-action'),
              attentionKey: const Key('ai-tab-memory-attention'),
              tooltip: '기억한 내용',
              icon: Icons.bookmark_outline_rounded,
              onPressed: onMemoryPressed!,
              showAttention: showMemoryAttention,
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderAction extends StatelessWidget {
  const _HeaderAction({
    required this.actionKey,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.attentionKey,
    this.showAttention = false,
  });

  final Key actionKey;
  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;
  final Key? attentionKey;
  final bool showAttention;

  @override
  Widget build(BuildContext context) {
    return AppAttentionIndicator(
      key: attentionKey,
      isVisible: showAttention,
      semanticsLabel: showAttention ? '확인할 새 기억 있음' : null,
      offset: const Offset(-4, 4),
      child: IconButton(
        key: actionKey,
        tooltip: tooltip,
        onPressed: onPressed,
        constraints: const BoxConstraints.tightFor(width: 44, height: 44),
        padding: const EdgeInsets.all(10),
        icon: Icon(icon, size: 24, color: AppColors.textPrimary),
      ),
    );
  }
}

String _remainingCountLabel(int? remainingCount) {
  return switch (remainingCount) {
    null => '오늘의 질문을 확인하는 중',
    <= 0 => '오늘 질문을 모두 사용했어',
    final count => '오늘 $count번 더 물어볼 수 있어',
  };
}
