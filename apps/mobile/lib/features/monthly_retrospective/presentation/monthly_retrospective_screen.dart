import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/presentation/widgets/app_answer_input.dart';
import '../../../core/presentation/widgets/app_loading_indicator.dart';
import '../../../core/presentation/widgets/app_back_button.dart';
import '../../../core/presentation/widgets/app_page_header.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../ai/presentation/widgets/ai_character_speech_row.dart';
import '../../questions/presentation/widgets/question_answer_sections.dart';
import '../../profile/application/profile_controller.dart';
import '../../story_loops/presentation/widgets/story_card_stack_overlay.dart';
import '../../safety/data/safety_report.dart';
import '../../safety/presentation/safety_report_sheet.dart';
import '../application/monthly_retrospective_controller.dart';
import '../data/monthly_retrospective.dart';
import 'widgets/monthly_card_scatter.dart';
import 'widgets/monthly_retrospective_pager.dart';

class MonthlyRetrospectiveScreen extends ConsumerStatefulWidget {
  const MonthlyRetrospectiveScreen({
    super.key,
    this.onBack,
    this.onDirtyChanged,
    this.recordLocation = '/ai/monthly-record',
  });

  final VoidCallback? onBack;
  final ValueChanged<bool>? onDirtyChanged;
  final String recordLocation;
  @override
  ConsumerState<MonthlyRetrospectiveScreen> createState() =>
      MonthlyRetrospectiveScreenState();
}

class MonthlyRetrospectiveScreenState
    extends ConsumerState<MonthlyRetrospectiveScreen> {
  final _answer = TextEditingController();
  String? _reflectionId;
  String _savedText = '';
  String? _generatedMonth;
  String? _failure;
  bool _editing = false;
  bool _saving = false;
  bool _generating = false;
  MonthlyRetrospective? _previousData;
  RetrospectiveReflection? _editingReflection;
  RetrospectiveReflection? _conflictReflection;
  bool get _dirty => _answer.text != _savedText;

  @override
  void initState() {
    super.initState();
    _answer.addListener(_changed);
  }

  void _changed() {
    widget.onDirtyChanged?.call(_dirty);
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _answer.removeListener(_changed);
    _answer.dispose();
    super.dispose();
  }

  Future<bool> confirmLeave() async {
    if (!_dirty) return true;
    final discard =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('작성 중인 답변이 있어요'),
            content: const Text('저장하지 않고 월간 회고를 닫을까요?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('계속 작성'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('닫기'),
              ),
            ],
          ),
        ) ??
        false;
    if (discard && mounted) {
      setState(() {
        _answer.text = _savedText;
        _editing = _savedText.isEmpty;
        _conflictReflection = null;
        final current = _previousData;
        if (current != null) _sync(current);
      });
    }
    return discard;
  }

  void _sync(MonthlyRetrospective data) {
    final reflection = data.reflection;
    if (_reflectionId == reflection?.id && (_dirty || _saving)) return;
    _reflectionId = reflection?.id;
    _savedText = reflection?.myAnswer ?? '';
    _answer.text = _savedText;
    _editing = reflection?.myAnswer == null;
    _editingReflection = reflection;
    _conflictReflection = null;
  }

  Future<void> _generate() async {
    if (_generating) return;
    setState(() {
      _generating = true;
      _failure = null;
    });
    try {
      await ref
          .read(monthlyRetrospectiveControllerProvider.notifier)
          .generate();
    } catch (_) {
      if (mounted) {
        setState(
          () => _failure = 'AI 회고를 만들지 못했어요. 다시 시도하거나 기본 질문으로 마음을 남겨 주세요.',
        );
      }
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(monthlyRetrospectiveControllerProvider);
    return Material(
      key: const Key('monthly-retrospective-surface'),
      color: AppColors.background,
      child: state.when(
        loading: () =>
            _withBackButton(const Center(child: AppLoadingIndicator())),
        error: (error, stack) => _withBackButton(
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    '월간 회고를 불러오지 못했어요. 연결 상태를 확인해 주세요.',
                    textAlign: TextAlign.center,
                  ),
                  TextButton(
                    onPressed: () =>
                        ref.invalidate(monthlyRetrospectiveControllerProvider),
                    child: const Text('다시 시도'),
                  ),
                ],
              ),
            ),
          ),
        ),
        data: (data) {
          if (_previousData != null &&
              _previousData!.month != data.month &&
              _dirty) {
            return _withBackButton(
              ListView(
                padding: EdgeInsets.fromLTRB(24, 24, 24, 24),
                children: [
                  const Text('새로운 월간 회고가 도착했어요. 이전 달의 작성 중인 답변은 아래에 남겨 두었어요.'),
                  const SizedBox(height: 16),
                  SelectableText(_answer.text),
                  TextButton(
                    onPressed: () async {
                      if (await confirmLeave() && mounted) {
                        setState(() {
                          _previousData = data;
                          _sync(data);
                        });
                      }
                    },
                    child: const Text('새 회고 열기'),
                  ),
                ],
              ),
            );
          }
          _previousData = data;
          if (_reflectionId != data.reflection?.id ||
              (!_dirty &&
                  !_saving &&
                  _savedText != (data.reflection?.myAnswer ?? ''))) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && identical(_previousData, data)) {
                setState(() => _sync(data));
              }
            });
          }
          if (data.needsGeneration &&
              _generatedMonth != data.month.toIso8601String()) {
            _generatedMonth = data.month.toIso8601String();
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) unawaited(_generate());
            });
          }
          final pages = [
            '지난달 이야기',
            if (data.hasRecords) '그날의 기억',
            if (data.conversation != null) '우리의 답',
            if (data.hasRecords) '마음 남기기',
          ];
          return Column(
            children: [
              _header('${data.month.year}년 ${data.month.month}월'),
              if (_failure != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    _failure!,
                    style: AppTextStyles.homeBody.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
              Expanded(
                child: MonthlyRetrospectivePager(
                  month: data.month,
                  pages: pages,
                  pageBuilder: (page) => LayoutBuilder(
                    builder: (context, constraints) {
                      final compact = constraints.maxHeight < 560;
                      return SingleChildScrollView(
                        key: PageStorageKey('${data.month}:$page'),
                        primary: false,
                        physics: const ClampingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: !data.hasRecords
                              ? [
                                  const Text(
                                    '지난달에는 남긴 기록이 없어요',
                                    style: AppTextStyles.homeBody,
                                  ),
                                ]
                              : switch (page) {
                                  '그날의 기억' => _moments(
                                    data,
                                    constraints.maxHeight,
                                  ),
                                  '우리의 답' => _conversation(data.conversation!),
                                  '마음 남기기' => _reflection(
                                    data,
                                    compact: compact,
                                  ),
                                  _ => _overview(data, constraints.maxHeight),
                                },
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _header(String title) => AppPageHeader(
    title: title,
    leading: widget.onBack == null
        ? null
        : AppBackButton(onPressed: widget.onBack, tooltip: '캘린더로 돌아가기'),
  );

  Widget _withBackButton(Widget child) => Column(
    children: [
      _header(''),
      Expanded(child: child),
    ],
  );

  List<Widget> _overview(MonthlyRetrospective data, double viewportHeight) => [
    if (data.gallery.isNotEmpty) ...[
      MonthlyCardScatter(
        cards: selectMonthlyScatterCards(data.gallery),
        compact: true,
        maxHeight: math.max(100, math.min(240, viewportHeight * 0.36)),
        onOpenCard: _openCard,
      ),
      const SizedBox(height: 16),
    ],
    Text(data.title, style: AppTextStyles.pageTitle),
    const SizedBox(height: 16),
    Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stat('${data.recordedDays}일', '기록한 날'),
        _stat(data.cardCountComplete ? '${data.cardCount}개' : '집계 불가', '남긴 카드'),
        _stat('${data.completedQuestions}개', '함께 답한 질문'),
      ],
    ),
    const SizedBox(height: 16),
    AiCharacterSpeechRow(
      characterSize: 64,
      speechText:
          data.summary ??
          '지난달 ${data.recordedDays}일에 기록을 남겼어. 함께 남긴 이야기를 돌아볼까?',
      showGeneratedIndicator: data.summary != null,
      onGeneratedIndicatorPressed: data.summary == null
          ? null
          : () => _reportAi(data.reflection!.id),
    ),
    if (data.needsGeneration) _generationAction(),
  ];

  Widget _stat(String value, String label) => Expanded(
    child: Column(
      children: [
        Text(value, style: AppTextStyles.homeBodyMedium),
        const SizedBox(height: 8),
        Text(
          label,
          textAlign: TextAlign.center,
          style: AppTextStyles.homeBody.copyWith(color: AppColors.textMuted),
        ),
      ],
    ),
  );

  List<Widget> _moments(MonthlyRetrospective data, double viewportHeight) =>
      data.moments.isEmpty
      ? [const Text('지난달에는 사진이 담긴 카드가 없어요', style: AppTextStyles.homeBody)]
      : [
          for (final moment in data.moments) ...[
            Row(
              key: ValueKey('monthly-moment-${moment.date}'),
              children: [
                SizedBox(
                  width: 110,
                  child: MonthlyCardScatter(
                    maxHeight: math.max(
                      88,
                      math.min(128, (viewportHeight - 48) / 3),
                    ),
                    cards: [
                      for (final card in moment.cards)
                        (date: moment.date, card: card),
                    ],
                    onOpenCard: _openCard,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${moment.date.month}월 ${moment.date.day}일',
                        style: AppTextStyles.homeBodyMedium,
                      ),
                      if (moment.question != null) ...[
                        const SizedBox(height: 8),
                        Text(moment.question!, style: AppTextStyles.homeBody),
                      ],
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            alignment: Alignment.centerLeft,
                          ),
                          onPressed: () => _openRecord(moment.date),
                          child: const Text('그날의 기록 보기'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ];

  void _openRecord(DateTime date) {
    final formatted =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    context.push('${widget.recordLocation}?date=$formatted');
  }

  Future<void> _openCard(MonthlyScatterCard entry) async {
    final userId = ref.read(profileControllerProvider).asData?.value?.id;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('사용자 정보를 불러온 뒤 다시 시도해 주세요.')),
      );
      return;
    }
    await showStoryCardByIdOverlay(
      context: context,
      date: entry.date,
      authorUserId: entry.card.authorUserId,
      cardId: entry.card.id,
      isMine: entry.card.authorUserId == userId,
    );
  }

  List<Widget> _conversation(RetrospectiveConversation conversation) => [
    Text(
      '${conversation.date.month}월 ${conversation.date.day}일 · 가장 길게 나눈 답변',
      style: AppTextStyles.homeBody.copyWith(color: AppColors.textMuted),
    ),
    const SizedBox(height: 16),
    Text(conversation.question, style: AppTextStyles.pageTitle),
    const SizedBox(height: 20),
    QuestionAnswerDisplaySection(
      title: '내 답변',
      body: conversation.myAnswer,
      isMuted: false,
      displayStyle: QuestionAnswerDisplayStyle.plain,
    ),
    const SizedBox(height: 20),
    QuestionAnswerDisplaySection(
      title: '상대방 답변',
      body: conversation.partnerAnswer,
      isMuted: false,
      displayStyle: QuestionAnswerDisplayStyle.plain,
      onReportPressed: () => showSafetyReportSheet(
        context: context,
        target: SafetyReportTarget(
          type: SafetyReportTargetType.questionAnswer,
          id: conversation.partnerAnswerId,
        ),
      ),
    ),
    const SizedBox(height: 20),
    const AiCharacterSpeechRow(
      characterSize: 64,
      speechText: '지난달 함께 길게 남긴 말이야. 천천히 다시 읽어볼까?',
    ),
  ];

  Widget _generationAction() => Padding(
    padding: const EdgeInsets.only(top: 16),
    child: _generating
        ? const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox.square(dimension: 20, child: AppLoadingIndicator()),
              SizedBox(width: 12),
              Text('지난달 이야기를 정리하는 중'),
            ],
          )
        : TextButton(onPressed: _generate, child: const Text('AI 회고 다시 시도')),
  );

  List<Widget> _reflection(MonthlyRetrospective data, {bool compact = false}) {
    final reflection = data.reflection;
    if (reflection == null) {
      return [];
    }
    if (reflection.question == null) {
      return [
        _generationAction(),
        TextButton(
          onPressed: () async {
            try {
              await ref
                  .read(monthlyRetrospectiveControllerProvider.notifier)
                  .useBasicQuestion(reflection.id);
            } catch (_) {
              if (mounted) {
                setState(() => _failure = '기본 질문을 불러오지 못했어요. 다시 시도해 주세요.');
              }
            }
          },
          child: const Text('기본 질문으로 마음 남기기'),
        ),
      ];
    }
    return [
      AiCharacterSpeechRow(
        characterSize: 64,
        speechText: reflection.question!,
        showGeneratedIndicator: reflection.source == 'ai',
        onGeneratedIndicatorPressed: reflection.source == 'ai'
            ? () => _reportAi(reflection.id)
            : null,
      ),
      const SizedBox(height: 16),
      if (_editing || reflection.myAnswer == null) ...[
        const Text('내 답변', style: AppTextStyles.homeBodyMedium),
        const SizedBox(height: 12),
        AppAnswerInput(
          controller: _answer,
          minLines: compact ? 2 : 3,
          maxLines: compact ? 3 : 5,
          maxLength: 500,
          enforceMaxLength: false,
          enabled: !_saving,
        ),
        AppAnswerCharacterCount(
          characterCount: _answer.text.runes.length,
          maxLength: 500,
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed:
              _saving ||
                  _conflictReflection != null ||
                  _answer.text.trim().isEmpty ||
                  _answer.text.runes.length > 500
              ? null
              : () => _save(_editingReflection ?? reflection),
          child: Text(_saving ? '저장 중' : '마음 남기기'),
        ),
        if (_conflictReflection != null) ...[
          const SizedBox(height: 16),
          QuestionAnswerDisplaySection(
            title: '다른 기기에 저장된 최신 답변',
            body: _conflictReflection!.myAnswer ?? '',
            isMuted: false,
            displayStyle: QuestionAnswerDisplayStyle.plain,
          ),
          TextButton(
            onPressed: () => setState(() {
              _savedText = _conflictReflection!.myAnswer ?? '';
              _answer.text = _savedText;
              _editingReflection = _conflictReflection;
              _conflictReflection = null;
              _editing = false;
              _failure = null;
            }),
            child: const Text('최신 답변으로 돌아가기'),
          ),
          TextButton(
            onPressed: _saving
                ? null
                : () {
                    final latest = _conflictReflection!;
                    setState(() {
                      _editingReflection = latest;
                      _conflictReflection = null;
                    });
                    unawaited(_save(latest));
                  },
            child: const Text('내 초안으로 다시 저장'),
          ),
        ],
      ] else ...[
        QuestionAnswerDisplaySection(
          title: '내 답변',
          body: reflection.myAnswer!,
          isMuted: false,
          displayStyle: QuestionAnswerDisplayStyle.plain,
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: () => setState(() {
              _savedText = reflection.myAnswer ?? '';
              _answer.text = _savedText;
              _editingReflection = reflection;
              _editing = true;
            }),
            child: const Text('수정하기'),
          ),
        ),
      ],
      const SizedBox(height: 16),
      QuestionAnswerDisplaySection(
        title: '상대방 답변',
        body: reflection.myAnswer == null
            ? '내 답변을 저장하면 상대방 답변을 확인할 수 있어요'
            : reflection.partnerAnswer ?? '상대방은 아직 답변하지 않았어요',
        isMuted: reflection.partnerAnswer == null,
        displayStyle: QuestionAnswerDisplayStyle.plain,
        onReportPressed: reflection.partnerAnswerId == null
            ? null
            : () => showSafetyReportSheet(
                context: context,
                target: SafetyReportTarget(
                  type: SafetyReportTargetType.monthlyReflectionAnswer,
                  id: reflection.partnerAnswerId!,
                ),
              ),
      ),
    ];
  }

  Future<void> _save(RetrospectiveReflection reflection) async {
    setState(() {
      _saving = true;
      _failure = null;
    });
    try {
      await ref
          .read(monthlyRetrospectiveControllerProvider.notifier)
          .save(reflection, _answer.text);
      if (mounted) {
        setState(() {
          _savedText = _answer.text;
          _editing = false;
        });
      }
    } catch (_) {
      if (mounted) {
        final latest = ref
            .read(monthlyRetrospectiveControllerProvider)
            .value
            ?.reflection;
        setState(() {
          if (latest?.id == reflection.id &&
              latest!.version != reflection.version) {
            _conflictReflection = latest;
            _failure = '다른 기기에서 답변이 변경됐어요. 최신 답변을 확인하고 저장할 내용을 선택해 주세요.';
          } else {
            _failure = '답변을 저장하지 못했어요. 입력은 유지했으니 다시 시도해 주세요.';
          }
        });
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _reportAi(String id) => showSafetyReportSheet(
    context: context,
    target: SafetyReportTarget(
      type: SafetyReportTargetType.aiMonthlyRetrospective,
      id: id,
    ),
  );
}
