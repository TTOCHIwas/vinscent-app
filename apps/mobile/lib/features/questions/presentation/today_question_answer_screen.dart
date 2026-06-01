import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/presentation/widgets/app_action_button.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../application/today_answer_controller.dart';
import '../application/today_question_controller.dart';
import '../data/daily_question.dart';
import '../data/daily_question_answer_state.dart';

class TodayQuestionAnswerScreen extends ConsumerWidget {
  const TodayQuestionAnswerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final question = ref.watch(todayQuestionControllerProvider);
    final answerState = ref.watch(todayAnswerControllerProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      child: question.when(
        loading: () => const _CenteredLoader(),
        error: (error, stackTrace) => const _StateMessage(
          title: '질문을 불러오지 못했어요',
          message: '잠시 후 다시 시도해 주세요.',
        ),
        data: (question) {
          if (question == null) {
            return const _StateMessage(
              title: '오늘 질문이 아직 없어요',
              message: '커플 연결과 첫 만남일 입력을 먼저 완료해 주세요.',
            );
          }

          return answerState.when(
            loading: () => _QuestionScaffold(
              question: question,
              child: const _CenteredLoader(),
            ),
            error: (error, stackTrace) => _QuestionScaffold(
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
            data: (state) => _QuestionScaffold(
              question: question,
              child: _AnswerForm(
                key: ValueKey(state?.myAnswerId ?? 'empty-answer'),
                answerState: state,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _QuestionScaffold extends StatelessWidget {
  const _QuestionScaffold({required this.question, required this.child});

  final DailyQuestion question;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('오늘의 질문', style: AppTextStyles.homeBodyMedium),
          const SizedBox(height: 12),
          Text(
            question.questionText,
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
  const _AnswerForm({super.key, required this.answerState});

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
    final answerState = widget.answerState;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _AnswerStatus(answerState: answerState),
        const SizedBox(height: 18),
        if (answerState?.canRevealPartnerAnswer == true) ...[
          _RevealedAnswerCards(answerState: answerState!),
          const SizedBox(height: 18),
        ],
        TextField(
          controller: _controller,
          minLines: 7,
          maxLines: 10,
          keyboardType: TextInputType.multiline,
          textInputAction: TextInputAction.newline,
          style: AppTextStyles.homeBody.copyWith(height: 1.5),
          decoration: InputDecoration(
            hintText: '답변을 적어주세요',
            hintStyle: AppTextStyles.homeBody.copyWith(
              color: AppColors.textPlaceholder,
            ),
            filled: true,
            fillColor: AppColors.background,
            contentPadding: const EdgeInsets.all(16),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.wireframeBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.textPrimary),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            '$_characterCount / $_maxAnswerLength',
            style: AppTextStyles.homeCharacterLabel.copyWith(
              color: _characterCount > _maxAnswerLength
                  ? Colors.redAccent
                  : AppColors.textMuted,
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
        const SizedBox(height: 24),
        AppActionButton(
          label: answerState?.hasMyAnswer == true ? '답변 수정' : '답변 저장',
          enabled: _canSubmit,
          isLoading: _isSubmitting,
          onPressed: _submit,
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

class _RevealedAnswerCards extends StatelessWidget {
  const _RevealedAnswerCards({required this.answerState});

  final DailyQuestionAnswerState answerState;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _AnswerCard(title: '내 답변', body: answerState.myAnswerText ?? ''),
        const SizedBox(height: 10),
        _AnswerCard(title: '상대방 답변', body: answerState.partnerAnswerText ?? ''),
      ],
    );
  }
}

class _AnswerCard extends StatelessWidget {
  const _AnswerCard({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.wireframeBorder),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTextStyles.homeCharacterLabel.copyWith(
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 8),
          Text(body, style: AppTextStyles.homeBody.copyWith(height: 1.45)),
        ],
      ),
    );
  }
}

class _AnswerStatus extends StatelessWidget {
  const _AnswerStatus({required this.answerState});

  final DailyQuestionAnswerState? answerState;

  @override
  Widget build(BuildContext context) {
    final label = _label;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.wireframeBorder),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: AppTextStyles.homeCharacterLabel.copyWith(
          color: AppColors.textMuted,
        ),
      ),
    );
  }

  String get _label {
    final state = answerState;
    if (state == null || !state.hasMyAnswer) {
      if (state?.partnerAnswerExists == true) {
        return '상대방이 먼저 답변했어요';
      }

      return '아직 답변하지 않았어요';
    }

    if (state.status == DailyQuestionStatus.completed) {
      return '둘 다 답변을 완료했어요';
    }

    if (state.partnerAnswerExists) {
      return '상대방도 답변했어요';
    }

    return '내 답변이 저장됐어요. 상대방을 기다리는 중이에요';
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
