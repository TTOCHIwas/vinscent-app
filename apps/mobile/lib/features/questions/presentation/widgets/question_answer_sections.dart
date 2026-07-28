import 'package:flutter/material.dart';

import '../../../../core/presentation/widgets/word_boundary_text.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../safety/data/safety_report.dart';
import '../../../safety/presentation/safety_report_sheet.dart';
import '../../data/daily_question_answer_state.dart';

enum QuestionAnswerDisplayStyle { boxed, plain }

const _partnerAnswerReportTooltip =
    '\uc0c1\ub300\ubc29 \ub2f5\ubcc0 \uc2e0\uace0';

class QuestionAnswerOverview extends StatelessWidget {
  const QuestionAnswerOverview({
    super.key,
    required this.answerState,
    this.displayStyle = QuestionAnswerDisplayStyle.boxed,
    this.myEmptyMessage = '아직 답변하지 않았어요',
    this.partnerHiddenMessage = PartnerQuestionAnswerSection.todayHiddenMessage,
    this.onMyAnswerPressed,
  });

  final DailyQuestionAnswerState? answerState;
  final QuestionAnswerDisplayStyle displayStyle;
  final String myEmptyMessage;
  final String partnerHiddenMessage;
  final VoidCallback? onMyAnswerPressed;

  @override
  Widget build(BuildContext context) {
    final partnerAnswerId = answerState?.canRevealPartnerAnswer == true
        ? answerState?.partnerAnswerId
        : null;
    final myAnswer = MyQuestionAnswerSection(
      answerState: answerState,
      displayStyle: displayStyle,
      emptyMessage: myEmptyMessage,
      onPressed: onMyAnswerPressed,
    );
    final partnerAnswer = PartnerQuestionAnswerSection(
      answerState: answerState,
      hiddenMessage: partnerHiddenMessage,
      displayStyle: displayStyle,
      onReportPressed: partnerAnswerId == null
          ? null
          : () => showSafetyReportSheet(
              context: context,
              target: SafetyReportTarget(
                type: SafetyReportTargetType.questionAnswer,
                id: partnerAnswerId,
              ),
            ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [myAnswer, const SizedBox(height: 28), partnerAnswer],
    );
  }
}

class MyQuestionAnswerSection extends StatelessWidget {
  const MyQuestionAnswerSection({
    super.key,
    required this.answerState,
    this.title = '내 답변',
    this.emptyMessage = '아직 답변하지 않았어요',
    this.displayStyle = QuestionAnswerDisplayStyle.boxed,
    this.onPressed,
  });

  final DailyQuestionAnswerState? answerState;
  final String title;
  final String emptyMessage;
  final QuestionAnswerDisplayStyle displayStyle;
  final VoidCallback? onPressed;

  bool get _hasAnswer {
    final state = answerState;
    return state?.hasMyAnswer == true &&
        (state?.myAnswerText?.trim().isNotEmpty ?? false);
  }

  String get _body {
    if (!_hasAnswer) {
      return emptyMessage;
    }

    return answerState!.myAnswerText!.trim();
  }

  @override
  Widget build(BuildContext context) {
    final section = QuestionAnswerDisplaySection(
      title: title,
      body: _body,
      isMuted: !_hasAnswer,
      displayStyle: displayStyle,
    );

    final onPressed = this.onPressed;
    if (onPressed == null) {
      return section;
    }

    return Semantics(
      button: true,
      label: title,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(10),
          child: section,
        ),
      ),
    );
  }
}

class PartnerQuestionAnswerSection extends StatelessWidget {
  const PartnerQuestionAnswerSection({
    super.key,
    required this.answerState,
    this.title = '상대방 답변',
    this.hiddenMessage = todayHiddenMessage,
    this.waitingMessage = '상대방은 아직 답변하지 않았어요',
    this.displayStyle = QuestionAnswerDisplayStyle.boxed,
    this.onReportPressed,
  });

  static const todayHiddenMessage = '내 답변을 저장하면 상대방 답변을 확인할 수 있어요';
  static const historyHiddenMessage = '내 답변이 없어 상대방 답변을 확인할 수 없어요';

  final DailyQuestionAnswerState? answerState;
  final String title;
  final String hiddenMessage;
  final String waitingMessage;
  final QuestionAnswerDisplayStyle displayStyle;
  final VoidCallback? onReportPressed;

  bool get _showsPartnerAnswer {
    final state = answerState;
    return state?.canRevealPartnerAnswer == true &&
        (state?.partnerAnswerText?.trim().isNotEmpty ?? false);
  }

  String get _body {
    final state = answerState;
    if (state == null || !state.hasMyAnswer) {
      return hiddenMessage;
    }

    if (_showsPartnerAnswer) {
      return state.partnerAnswerText!.trim();
    }

    return waitingMessage;
  }

  @override
  Widget build(BuildContext context) {
    return QuestionAnswerDisplaySection(
      title: title,
      body: _body,
      isMuted: !_showsPartnerAnswer,
      displayStyle: displayStyle,
      onReportPressed: _showsPartnerAnswer ? onReportPressed : null,
    );
  }
}

class QuestionAnswerDisplaySection extends StatelessWidget {
  const QuestionAnswerDisplaySection({
    super.key,
    required this.title,
    required this.body,
    required this.isMuted,
    this.displayStyle = QuestionAnswerDisplayStyle.boxed,
    this.onReportPressed,
  });

  final String title;
  final String body;
  final bool isMuted;
  final QuestionAnswerDisplayStyle displayStyle;
  final VoidCallback? onReportPressed;

  @override
  Widget build(BuildContext context) {
    return switch (displayStyle) {
      QuestionAnswerDisplayStyle.boxed => _BoxedAnswerDisplaySection(
        title: title,
        body: body,
        isMuted: isMuted,
        onReportPressed: onReportPressed,
      ),
      QuestionAnswerDisplayStyle.plain => _PlainAnswerDisplaySection(
        title: title,
        body: body,
        isMuted: isMuted,
        onReportPressed: onReportPressed,
      ),
    };
  }
}

class _BoxedAnswerDisplaySection extends StatelessWidget {
  const _BoxedAnswerDisplaySection({
    required this.title,
    required this.body,
    required this.isMuted,
    required this.onReportPressed,
  });

  final String title;
  final String body;
  final bool isMuted;
  final VoidCallback? onReportPressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _AnswerSectionTitle(
          title: title,
          style: AppTextStyles.homeBodyMedium,
          onReportPressed: onReportPressed,
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.wireframeBorder),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(body, style: _boxedBodyStyle(isMuted)),
        ),
      ],
    );
  }
}

class _PlainAnswerDisplaySection extends StatelessWidget {
  const _PlainAnswerDisplaySection({
    required this.title,
    required this.body,
    required this.isMuted,
    required this.onReportPressed,
  });

  final String title;
  final String body;
  final bool isMuted;
  final VoidCallback? onReportPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _AnswerSectionTitle(
            title: title,
            style: AppTextStyles.homeCharacterLabel.copyWith(
              color: AppColors.textMuted,
              fontWeight: FontWeight.w500,
            ),
            onReportPressed: onReportPressed,
          ),
          const SizedBox(height: 8),
          WordBoundaryText(
            body,
            style: AppTextStyles.homeBody.copyWith(
              color: isMuted ? AppColors.textMuted : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _AnswerSectionTitle extends StatelessWidget {
  const _AnswerSectionTitle({
    required this.title,
    required this.style,
    required this.onReportPressed,
  });

  final String title;
  final TextStyle style;
  final VoidCallback? onReportPressed;

  @override
  Widget build(BuildContext context) {
    final onReportPressed = this.onReportPressed;
    return Row(
      children: [
        Expanded(child: Text(title, style: style)),
        if (onReportPressed != null)
          IconButton(
            key: const Key('partner-answer-report'),
            onPressed: onReportPressed,
            tooltip: _partnerAnswerReportTooltip,
            style: IconButton.styleFrom(
              fixedSize: const Size.square(40),
              foregroundColor: AppColors.textMuted,
            ),
            icon: const Icon(Icons.flag_outlined, size: 20),
          ),
      ],
    );
  }
}

TextStyle _boxedBodyStyle(bool isMuted) {
  return isMuted
      ? AppTextStyles.homeCharacterLabel.copyWith(color: AppColors.textMuted)
      : AppTextStyles.homeBody;
}
