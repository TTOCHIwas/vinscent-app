import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/presentation/widgets/app_action_button.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../profile/application/profile_controller.dart';
import '../../story_loops/application/story_loop_detail_navigation_provider.dart';
import '../../story_loops/application/story_loop_detail_provider.dart';
import '../../story_loops/data/story_loop_card_detail.dart';
import '../../story_loops/data/story_loop_detail_state.dart';
import '../../story_loops/presentation/widgets/story_card_pair_layout.dart';
import '../../story_loops/presentation/widgets/story_card_preview_surface.dart';
import '../application/question_answer_submit_controller.dart';
import '../data/daily_question.dart';
import '../data/daily_question_answer_state.dart';
import '../data/question_detail_state.dart';
import 'question_route_context.dart';
import 'story_loop_question_view_model.dart';
import 'widgets/question_answer_prompt_row.dart';
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

    final navigation = ref
        .watch(storyLoopDetailNavigationProvider(targetDate))
        .when(
          loading: () => null,
          error: (error, stackTrace) => null,
          data: (state) => state,
        );
    final detail = ref.watch(storyLoopDetailProvider(targetDate));
    final currentUserId = ref.watch(
      profileControllerProvider.select(
        (state) =>
            state.maybeWhen(data: (profile) => profile?.id, orElse: () => null),
      ),
    );
    final routeContext = QuestionRouteContext.fromQuestionScreen(
      backLocation: backLocation,
      targetDate: targetDate,
    );

    final page = detail.when(
      loading: () => _QuestionPageFrame(
        onBackPressed: () => _goBack(context, backLocation),
        child: const _CenteredLoader(),
      ),
      error: (error, stackTrace) => _QuestionPageFrame(
        onBackPressed: () => _goBack(context, backLocation),
        child: _QuestionLoadError(onRetry: () => _retry(ref)),
      ),
      data: (state) {
        final questionState = toQuestionDetailState(state);
        final cards = switch (state) {
          LoadedStoryLoopDetailState(detail: final detail) => detail.cards,
          _ => const <StoryLoopCardDetail>[],
        };
        return switch (questionState) {
          LoadedQuestionDetailState() => _QuestionPageFrame(
            question: questionState.question,
            onBackPressed: () => _goBack(context, backLocation),
            child: _QuestionDetailContent(
              question: questionState.question,
              cards: cards,
              currentUserId: currentUserId,
              child: QuestionAnswerOverview(
                answerState: questionState.answerState,
                myEmptyMessage: questionState.canEdit
                    ? '이곳을 눌러서 답변을 입력해주세요'
                    : '이 날에는 답변하지 않았어요',
                partnerHiddenMessage: questionState.canEdit
                    ? PartnerQuestionAnswerSection.todayHiddenMessage
                    : PartnerQuestionAnswerSection.historyHiddenMessage,
                onMyAnswerPressed: questionState.canEdit
                    ? () => context.push(routeContext.buildEditLocation())
                    : null,
              ),
            ),
          ),
          UnavailableQuestionDetailState() => _QuestionPageFrame(
            onBackPressed: () => _goBack(context, backLocation),
            child: _QuestionUnavailableMessage(reason: questionState.reason),
          ),
        };
      },
    );

    final previousDate = navigation?.previousDate;
    final nextDate = navigation?.nextDate;
    return _QuestionSwipeNavigationRegion(
      onPreviousDate: previousDate == null
          ? null
          : () => context.go(_questionDetailLocation(previousDate)),
      onNextDate: nextDate == null
          ? null
          : () => context.go(_questionDetailLocation(nextDate)),
      child: page,
    );
  }

  void _retry(WidgetRef ref) {
    final retryTargetDate = targetDate;
    ref.invalidate(storyLoopDetailProvider(retryTargetDate));
  }

  String _questionDetailLocation(DateTime date) {
    return QuestionRouteContext.fromQuestionScreen(
      backLocation: backLocation,
      targetDate: date,
    ).buildQuestionLocation();
  }
}

class _QuestionSwipeNavigationRegion extends StatelessWidget {
  const _QuestionSwipeNavigationRegion({
    required this.child,
    required this.onPreviousDate,
    required this.onNextDate,
  });

  static const _minimumSwipeVelocity = 350.0;

  final Widget child;
  final VoidCallback? onPreviousDate;
  final VoidCallback? onNextDate;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragEnd: _handleHorizontalDragEnd,
      child: child,
    );
  }

  void _handleHorizontalDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity.abs() < _minimumSwipeVelocity) {
      return;
    }

    if (velocity > 0) {
      onPreviousDate?.call();
      return;
    }

    onNextDate?.call();
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
      QuestionDetailUnavailableReason.invalidDate => '달력에서 다시 날짜를 선택해주세요.',
      QuestionDetailUnavailableReason.unavailable =>
        '커플 연결과 첫 만남 날짜를 먼저 완료해주세요.',
      QuestionDetailUnavailableReason.beforeRelationshipStartDate =>
        '연애 시작일 이후의 질문만 확인할 수 있어요.',
      QuestionDetailUnavailableReason.futureDate =>
        '오늘 이후의 질문은 해당 날짜가 되면 확인할 수 있어요.',
      QuestionDetailUnavailableReason.noQuestion => '질문이 생성된 날짜를 달력에서 선택해주세요.',
    };
  }
}

class _QuestionEditUnavailableMessage extends StatelessWidget {
  const _QuestionEditUnavailableMessage();

  @override
  Widget build(BuildContext context) {
    return const _StateMessage(
      title: '답변을 작성할 수 없어요',
      message: '오늘 질문 화면에서만 답변을 작성할 수 있어요.',
    );
  }
}

class TodayQuestionAnswerEditScreen extends ConsumerWidget {
  const TodayQuestionAnswerEditScreen({
    super.key,
    this.routeContext = const QuestionRouteContext(
      source: QuestionRouteSource.home,
    ),
  });

  final QuestionRouteContext routeContext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(storyLoopDetailProvider(routeContext.targetDate));
    final currentUserId = ref.watch(
      profileControllerProvider.select(
        (state) =>
            state.maybeWhen(data: (profile) => profile?.id, orElse: () => null),
      ),
    );

    return detail.when(
      loading: () => _QuestionPageFrame(
        onBackPressed: () => _goBackToQuestion(context, routeContext),
        child: const _CenteredLoader(),
      ),
      error: (error, stackTrace) => _QuestionPageFrame(
        onBackPressed: () => _goBackToQuestion(context, routeContext),
        child: _QuestionLoadError(
          onRetry: () =>
              ref.invalidate(storyLoopDetailProvider(routeContext.targetDate)),
        ),
      ),
      data: (state) {
        final questionState = toQuestionDetailState(state);
        final cards = switch (state) {
          LoadedStoryLoopDetailState(detail: final detail) => detail.cards,
          _ => const <StoryLoopCardDetail>[],
        };
        return switch (questionState) {
          LoadedQuestionDetailState() when questionState.canEdit => _AnswerForm(
            key: ValueKey(
              questionState.answerState?.myAnswerId ?? 'empty-answer',
            ),
            question: questionState.question,
            answerState: questionState.answerState,
            routeContext: routeContext,
            cards: cards,
            currentUserId: currentUserId,
          ),
          LoadedQuestionDetailState() => _QuestionPageFrame(
            question: questionState.question,
            onBackPressed: () => _goBackToQuestion(context, routeContext),
            child: const _QuestionEditUnavailableMessage(),
          ),
          UnavailableQuestionDetailState() => _QuestionPageFrame(
            onBackPressed: () => _goBackToQuestion(context, routeContext),
            child: _QuestionUnavailableMessage(reason: questionState.reason),
          ),
        };
      },
    );
  }
}

void _goBackToQuestion(
  BuildContext context,
  QuestionRouteContext routeContext,
) {
  if (context.canPop()) {
    context.pop();
    return;
  }

  context.go(routeContext.buildQuestionLocation());
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
    this.headerAction,
  });

  final DailyQuestion? question;
  final VoidCallback onBackPressed;
  final Widget child;
  final Widget? headerAction;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        QuestionDetailHeader(
          assignedDate: question?.assignedDate,
          onBackPressed: onBackPressed,
          action: headerAction,
        ),
        Expanded(child: child),
      ],
    );
  }
}

class _QuestionDetailContent extends StatelessWidget {
  const _QuestionDetailContent({
    required this.question,
    required this.cards,
    required this.currentUserId,
    required this.child,
  });

  final DailyQuestion question;
  final List<StoryLoopCardDetail> cards;
  final String? currentUserId;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bottomNavigationClearance = MediaQuery.paddingOf(context).bottom;
    final cardPair = _QuestionAnswerCardPair.fromCards(
      cards,
      currentUserId: currentUserId,
    );

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(12, 16, 12, 40 + bottomNavigationClearance),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (cardPair.hasCard) ...[
            _QuestionAnswerCards(cardPair: cardPair),
            const SizedBox(height: 16),
          ],
          QuestionAnswerPromptRow(questionText: question.questionText),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: child,
          ),
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
    required this.routeContext,
    required this.cards,
    required this.currentUserId,
  });

  final DailyQuestion question;
  final DailyQuestionAnswerState? answerState;
  final QuestionRouteContext routeContext;
  final List<StoryLoopCardDetail> cards;
  final String? currentUserId;

  @override
  ConsumerState<_AnswerForm> createState() => _AnswerFormState();
}

class _AnswerFormState extends ConsumerState<_AnswerForm> {
  static const _maxAnswerLength = 500;
  static const _compactLayoutHeight = 480.0;
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
    final cardPair = _QuestionAnswerCardPair.fromCards(
      widget.cards,
      currentUserId: widget.currentUserId,
    );
    final countColor = _characterCount > _maxAnswerLength
        ? Colors.redAccent
        : AppColors.textMuted;

    return _QuestionPageFrame(
      question: widget.question,
      onBackPressed: () => _goBackToQuestion(context, widget.routeContext),
      headerAction: _AnswerHeaderSaveAction(
        canSave: _canSubmit,
        isLoading: _isSubmitting,
        onSave: _submit,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compactLayout =
              constraints.hasBoundedHeight &&
              constraints.maxHeight < _compactLayoutHeight;

          return Padding(
            padding: EdgeInsets.fromLTRB(12, compactLayout ? 8 : 16, 12, 12),
            child: Column(
              children: [
                if (!compactLayout && cardPair.hasCard) ...[
                  _QuestionAnswerCards(cardPair: cardPair),
                  const SizedBox(height: 16),
                ],
                QuestionAnswerPromptRow(
                  questionText: widget.question.questionText,
                  compact: compactLayout,
                ),
                SizedBox(height: compactLayout ? 8 : 16),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: TextField(
                                  controller: _controller,
                                  expands: true,
                                  minLines: null,
                                  maxLines: null,
                                  keyboardType: TextInputType.multiline,
                                  textInputAction: TextInputAction.newline,
                                  textAlignVertical: TextAlignVertical.top,
                                  style: AppTextStyles.homeBody.copyWith(
                                    height: 1.5,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: '답변 입력',
                                    hintStyle: AppTextStyles.homeBody.copyWith(
                                      color: AppColors.textPlaceholder,
                                    ),
                                    filled: true,
                                    fillColor: AppColors.background,
                                    contentPadding: const EdgeInsets.fromLTRB(
                                      24,
                                      20,
                                      24,
                                      44,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(18),
                                      borderSide: const BorderSide(
                                        color: AppColors.textPlaceholder,
                                      ),
                                    ),
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
                              ),
                              Positioned(
                                right: 14,
                                bottom: 10,
                                child: IgnorePointer(
                                  child: Text(
                                    '$_characterCount / $_maxAnswerLength',
                                    key: const Key('answer-character-count'),
                                    style: AppTextStyles.homeCharacterLabel
                                        .copyWith(color: countColor),
                                  ),
                                ),
                              ),
                            ],
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
              ],
            ),
          );
        },
      ),
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
          .read(questionAnswerSubmitControllerProvider.notifier)
          .submit(
            targetDate: widget.routeContext.targetDate,
            answerText: _controller.text,
          );
      if (!mounted) {
        return;
      }

      _goBackToQuestion(context, widget.routeContext);
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

class _QuestionAnswerCards extends StatelessWidget {
  const _QuestionAnswerCards({required this.cardPair});

  final _QuestionAnswerCardPair cardPair;

  @override
  Widget build(BuildContext context) {
    return StoryCardPairLayout(
      leftCardBuilder: cardPair.myCard == null
          ? null
          : (context, cardWidth) => _QuestionAnswerStoryCard(
              card: cardPair.myCard!,
              width: cardWidth,
            ),
      rightCardBuilder: cardPair.partnerCard == null
          ? null
          : (context, cardWidth) => _QuestionAnswerStoryCard(
              card: cardPair.partnerCard!,
              width: cardWidth,
            ),
    );
  }
}

class _QuestionAnswerStoryCard extends StatelessWidget {
  const _QuestionAnswerStoryCard({required this.card, required this.width});

  final StoryLoopCardDetail card;
  final double width;

  @override
  Widget build(BuildContext context) {
    return StoryCardPreviewSurface(
      surfaceKey: ValueKey('question-answer-card-${card.id}'),
      previewUrl: card.previewUrl,
      width: width,
      semanticsLabel: '스토리 카드',
    );
  }
}

class _QuestionAnswerCardPair {
  const _QuestionAnswerCardPair({this.myCard, this.partnerCard});

  factory _QuestionAnswerCardPair.fromCards(
    List<StoryLoopCardDetail> cards, {
    required String? currentUserId,
  }) {
    final sortedCards = [...cards]
      ..sort((left, right) => left.submittedAt.compareTo(right.submittedAt));
    if (currentUserId == null) {
      return _QuestionAnswerCardPair(
        myCard: sortedCards.isEmpty ? null : sortedCards.first,
        partnerCard: sortedCards.length < 2 ? null : sortedCards[1],
      );
    }

    StoryLoopCardDetail? myCard;
    StoryLoopCardDetail? partnerCard;
    for (final card in sortedCards) {
      if (card.authorUserId == currentUserId) {
        myCard ??= card;
      } else {
        partnerCard ??= card;
      }
    }

    return _QuestionAnswerCardPair(myCard: myCard, partnerCard: partnerCard);
  }

  final StoryLoopCardDetail? myCard;
  final StoryLoopCardDetail? partnerCard;

  bool get hasCard => myCard != null || partnerCard != null;
}

class _AnswerHeaderSaveAction extends StatelessWidget {
  const _AnswerHeaderSaveAction({
    required this.canSave,
    required this.isLoading,
    required this.onSave,
  });

  final bool canSave;
  final bool isLoading;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: const Key('answer-save-action'),
      button: true,
      enabled: canSave,
      label: isLoading ? '저장 중' : '저장',
      excludeSemantics: true,
      child: SizedBox(
        width: 72,
        height: 44,
        child: TextButton(
          onPressed: canSave ? onSave : null,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.textPrimary,
            disabledForegroundColor: AppColors.textPlaceholder,
          ),
          child: isLoading
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(
                    color: AppColors.textPrimary,
                    strokeWidth: 2,
                  ),
                )
              : const Text('저장'),
        ),
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
