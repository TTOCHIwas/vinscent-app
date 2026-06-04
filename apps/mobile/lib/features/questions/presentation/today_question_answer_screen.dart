import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/presentation/widgets/app_action_button.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../application/daily_question_history_provider.dart';
import '../application/question_detail_provider.dart';
import '../application/today_answer_controller.dart';
import '../application/today_question_controller.dart';
import '../data/daily_question.dart';
import '../data/daily_question_answer_state.dart';
import '../data/question_detail_state.dart';
import 'widgets/question_detail_header.dart';
import 'widgets/question_answer_sections.dart';

class TodayQuestionAnswerScreen extends ConsumerWidget {
  const TodayQuestionAnswerScreen({
    super.key,
    this.targetDate,
    this.hasInvalidTargetDate = false,
    this.backLocation = '/home',
  });

  final DateTime? targetDate;
  final bool hasInvalidTargetDate;
  final String backLocation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (hasInvalidTargetDate) {
      return _QuestionPageFrame(
        onBackPressed: () => _goBack(context, backLocation),
        child: const _QuestionUnavailableMessage(
          reason: QuestionDetailUnavailableReason.invalidDate,
        ),
      );
    }

    final detail = ref.watch(questionDetailProvider(targetDate));

    return detail.when(
      loading: () => _QuestionPageFrame(
        onBackPressed: () => _goBack(context, backLocation),
        child: const _CenteredLoader(),
      ),
      error: (error, stackTrace) => _QuestionPageFrame(
        onBackPressed: () => _goBack(context, backLocation),
        child: _QuestionLoadError(
          onRetry: () => _retry(ref),
        ),
      ),
      data: (state) {
        return switch (state) {
          LoadedQuestionDetailState() => _QuestionPageFrame(
            question: state.question,
            onBackPressed: () => _goBack(context, backLocation),
            child: _QuestionContent(
              question: state.question,
              child: QuestionAnswerOverview(
                answerState: state.answerState,
                myEmptyMessage: state.canEdit
                    ? '이곳을 눌러서 답변을 입력해주세요'
                    : '이 날에는 답변하지 않았어요',
                partnerHiddenMessage: state.canEdit
                    ? PartnerQuestionAnswerSection.todayHiddenMessage
                    : PartnerQuestionAnswerSection.historyHiddenMessage,
                onMyAnswerPressed: state.canEdit
                    ? () => context.push('/home/question/edit')
                    : null,
              ),
            ),
          ),
          UnavailableQuestionDetailState() => _QuestionPageFrame(
            onBackPressed: () => _goBack(context, backLocation),
            child: _QuestionUnavailableMessage(reason: state.reason),
          ),
        };
      },
    );
  }

  void _retry(WidgetRef ref) {
    final retryTargetDate = targetDate;
    ref.invalidate(questionDetailProvider(retryTargetDate));
    ref.invalidate(todayQuestionControllerProvider);
    ref.invalidate(todayAnswerControllerProvider);

    if (retryTargetDate != null) {
      ref.invalidate(dailyQuestionHistoryProvider(retryTargetDate));
    }
  }
}

void _goBack(BuildContext context, String fallbackLocation) {
  if (context.canPop()) {
    context.pop();
    return;
  }

  context.go(fallbackLocation);
}

class _QuestionUnavailableMessage extends StatelessWidget {
  const _QuestionUnavailableMessage({required this.reason});

  final QuestionDetailUnavailableReason reason;

  @override
  Widget build(BuildContext context) {
    return _StateMessage(title: _title, message: _message);
  }

  String get _title {
    return switch (reason) {
      QuestionDetailUnavailableReason.invalidDate => '날짜를 확인할 수 없어요',
      QuestionDetailUnavailableReason.unavailable => '질문을 확인할 수 없어요',
      QuestionDetailUnavailableReason.beforeRelationshipStartDate =>
        '아직 기록이 없어요',
      QuestionDetailUnavailableReason.futureDate => '아직 열리지 않은 질문이에요',
      QuestionDetailUnavailableReason.noQuestion => '이 날의 질문이 없어요',
    };
  }

  String get _message {
    return switch (reason) {
      QuestionDetailUnavailableReason.invalidDate =>
        '달력에서 다시 날짜를 선택해주세요.',
      QuestionDetailUnavailableReason.unavailable =>
        '커플 연결과 첫 만남 날짜를 먼저 완료해주세요.',
      QuestionDetailUnavailableReason.beforeRelationshipStartDate =>
        '연애 시작일 이후의 질문만 확인할 수 있어요.',
      QuestionDetailUnavailableReason.futureDate =>
        '오늘 이후의 질문은 해당 날짜가 되면 확인할 수 있어요.',
      QuestionDetailUnavailableReason.noQuestion =>
        '질문이 생성된 날짜를 달력에서 선택해주세요.',
    };
  }
}

class TodayQuestionAnswerEditScreen extends ConsumerWidget {
  const TodayQuestionAnswerEditScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final question = ref.watch(todayQuestionControllerProvider);
    final answerState = ref.watch(todayAnswerControllerProvider);

    return question.when(
      loading: () => _QuestionPageFrame(
        onBackPressed: () => _goBackToQuestion(context),
        child: const _CenteredLoader(),
      ),
      error: (error, stackTrace) => _QuestionPageFrame(
        onBackPressed: () => _goBackToQuestion(context),
        child: _QuestionLoadError(
          onRetry: () => ref.invalidate(todayQuestionControllerProvider),
        ),
      ),
      data: (question) {
        if (question == null) {
          return _QuestionPageFrame(
            onBackPressed: () => _goBackToQuestion(context),
            child: const _StateMessage(
              title: '오늘 질문이 아직 없어요',
              message: '커플 연결과 첫 만남일 입력을 먼저 완료해 주세요.',
            ),
          );
        }

        return _QuestionPageFrame(
          question: question,
          onBackPressed: () => _goBackToQuestion(context),
          child: answerState.when(
            loading: () => _QuestionContent(
              question: question,
              child: const _CenteredLoader(),
            ),
            error: (error, stackTrace) => _QuestionContent(
              question: question,
              child: Column(
                children: [
                  const _StateMessage(
                    title: '답변 정보를 불러오지 못했어요',
                    message: '네트워크 상태를 확인한 뒤 다시 시도해 주세요.',
                  ),
                  const SizedBox(height: 16),
                  AppActionButton(
                    label: '다시 시도',
                    enabled: true,
                    onPressed: () => ref
                        .read(todayAnswerControllerProvider.notifier)
                        .refresh(),
                  ),
                ],
              ),
            ),
            data: (state) => _AnswerForm(
              key: ValueKey(state?.myAnswerId ?? 'empty-answer'),
              question: question,
              answerState: state,
            ),
          ),
        );
      },
    );
  }
}

void _goBackToQuestion(BuildContext context) {
  if (context.canPop()) {
    context.pop();
    return;
  }

  context.go('/home/question');
}

class _QuestionLoadError extends StatelessWidget {
  const _QuestionLoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _StateMessage(
          title: '질문을 불러오지 못했어요',
          message: '잠시 후 다시 시도해 주세요.',
        ),
        const SizedBox(height: 16),
        AppActionButton(label: '다시 시도', enabled: true, onPressed: onRetry),
      ],
    );
  }
}

class _QuestionPageFrame extends StatelessWidget {
  const _QuestionPageFrame({
    required this.onBackPressed,
    required this.child,
    this.question,
  });

  final DailyQuestion? question;
  final VoidCallback onBackPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        QuestionDetailHeader(
          assignedDate: question?.assignedDate,
          onBackPressed: onBackPressed,
        ),
        Expanded(child: child),
      ],
    );
  }
}

class _QuestionContent extends StatelessWidget {
  const _QuestionContent({
    required this.question,
    required this.child,
  });

  final DailyQuestion question;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(32, 32, 32, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text('질문', style: AppTextStyles.homeBodyMedium),
          const SizedBox(height: 12),
          Text(
            question.questionText,
            textAlign: TextAlign.center,
            style: AppTextStyles.onboardingTitle.copyWith(height: 1.35),
          ),
          const SizedBox(height: 28),
          child,
        ],
      ),
    );
  }
}

class _AnswerForm extends ConsumerStatefulWidget {
  const _AnswerForm({
    super.key,
    required this.question,
    required this.answerState,
  });

  final DailyQuestion question;
  final DailyQuestionAnswerState? answerState;

  @override
  ConsumerState<_AnswerForm> createState() => _AnswerFormState();
}

class _AnswerFormState extends ConsumerState<_AnswerForm> {
  static const _maxAnswerLength = 500;
  static const _submitFailureMessage = '답변을 저장하지 못했어요. 잠시 후 다시 시도해 주세요.';

  late final TextEditingController _controller;
  var _isSubmitting = false;
  String? _submitErrorMessage;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _initialText)
      ..addListener(_onTextChanged);
  }

  @override
  void didUpdateWidget(covariant _AnswerForm oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.answerState?.myAnswerText != _initialText &&
        _controller.text != _initialText) {
      _controller.text = _initialText;
      _controller.selection = TextSelection.collapsed(
        offset: _controller.text.length,
      );
    }
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onTextChanged)
      ..dispose();
    super.dispose();
  }

  String get _initialText => widget.answerState?.myAnswerText ?? '';

  int get _characterCount => _controller.text.characters.length;

  bool get _canSubmit {
    final normalizedText = _controller.text.trim();
    return normalizedText.isNotEmpty &&
        _characterCount <= _maxAnswerLength &&
        !_isSubmitting;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: _QuestionContent(
            question: widget.question,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _controller,
                  minLines: 10,
                  maxLines: 14,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.newline,
                  style: AppTextStyles.homeBody.copyWith(height: 1.5),
                  decoration: InputDecoration(
                    hintText: '답변 입력',
                    hintStyle: AppTextStyles.homeBody.copyWith(
                      color: AppColors.textPlaceholder,
                    ),
                    filled: true,
                    fillColor: AppColors.background,
                    contentPadding: const EdgeInsets.all(24),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: const BorderSide(
                        color: AppColors.textPlaceholder,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: const BorderSide(
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
                if (_submitErrorMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _submitErrorMessage!,
                    style: AppTextStyles.homeCharacterLabel.copyWith(
                      color: Colors.redAccent,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        _AnswerSaveBar(
          characterCount: _characterCount,
          maxAnswerLength: _maxAnswerLength,
          canSave: _canSubmit,
          isLoading: _isSubmitting,
          onSave: _submit,
        ),
      ],
    );
  }

  void _onTextChanged() {
    setState(() {
      _submitErrorMessage = null;
    });
  }

  Future<void> _submit() async {
    if (!_canSubmit) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _submitErrorMessage = null;
    });

    String? submitErrorMessage;
    try {
      await ref
          .read(todayAnswerControllerProvider.notifier)
          .submit(_controller.text);
      if (!mounted) {
        return;
      }

      context.go('/home/question');
      return;
    } catch (_) {
      submitErrorMessage = _submitFailureMessage;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _isSubmitting = false;
      _submitErrorMessage = submitErrorMessage;
    });
  }
}

class _AnswerSaveBar extends StatelessWidget {
  const _AnswerSaveBar({
    required this.characterCount,
    required this.maxAnswerLength,
    required this.canSave,
    required this.isLoading,
    required this.onSave,
  });

  final int characterCount;
  final int maxAnswerLength;
  final bool canSave;
  final bool isLoading;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final countColor = characterCount > maxAnswerLength
        ? Colors.redAccent
        : AppColors.textMuted;
    final saveColor = canSave ? AppColors.textPrimary : AppColors.textMuted;

    return Container(
      height: 82,
      width: double.infinity,
      color: AppColors.actionDisabled,
      padding: const EdgeInsets.fromLTRB(32, 10, 32, 34),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Semantics(
            button: true,
            label: '저장',
            child: InkWell(
              onTap: canSave ? onSave : null,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  isLoading ? '저장 중' : '저장',
                  style: AppTextStyles.homeCharacterLabel.copyWith(
                    color: saveColor,
                  ),
                ),
              ),
            ),
          ),
          Text(
            '$characterCount / $maxAnswerLength',
            style: AppTextStyles.homeCharacterLabel.copyWith(
              color: countColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _CenteredLoader extends StatelessWidget {
  const _CenteredLoader();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SizedBox.square(
        dimension: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }
}

class _StateMessage extends StatelessWidget {
  const _StateMessage({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTextStyles.homeBodyMedium,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTextStyles.homeCharacterLabel.copyWith(
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
