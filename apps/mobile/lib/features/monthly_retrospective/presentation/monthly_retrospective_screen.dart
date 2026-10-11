import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/presentation/widgets/app_answer_input.dart';
import '../../../core/presentation/widgets/app_loading_indicator.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../ai/presentation/widgets/ai_character_speech_row.dart';
import '../../questions/presentation/widgets/question_answer_sections.dart';
import '../../safety/data/safety_report.dart';
import '../../safety/presentation/safety_report_sheet.dart';
import '../application/monthly_retrospective_controller.dart';
import '../data/monthly_retrospective.dart';
import '../data/monthly_retrospective_repository.dart';

class MonthlyRetrospectiveScreen extends ConsumerStatefulWidget {
  const MonthlyRetrospectiveScreen({super.key});
  @override
  ConsumerState<MonthlyRetrospectiveScreen> createState() =>
      MonthlyRetrospectiveScreenState();
}

class MonthlyRetrospectiveScreenState
    extends ConsumerState<MonthlyRetrospectiveScreen> {
  final _answer = TextEditingController();
  String _page = '지난달 이야기';
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
        loading: () => const Center(child: AppLoadingIndicator()),
        error: (error, stack) => Center(
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
        data: (data) {
          if (_previousData != null &&
              _previousData!.month != data.month &&
              _dirty) {
            return ListView(
              padding: const EdgeInsets.all(24),
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
            '그날의 기억',
            if (data.conversation != null) '우리의 답',
            '마음 남기기',
          ];
          final selected = pages.contains(_page) ? _page : pages.first;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${data.month.year}년 ${data.month.month}월',
                        style: AppTextStyles.pageTitle,
                      ),
                    ),
                    const Text('월간 회고', style: AppTextStyles.homeBody),
                  ],
                ),
              ),
              if (data.hasRecords)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final page in pages)
                        TextButton(
                          onPressed: () => setState(() => _page = page),
                          child: Text(
                            page,
                            style: AppTextStyles.homeBody.copyWith(
                              color: selected == page
                                  ? AppColors.brandAccent
                                  : AppColors.textMuted,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
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
                child: RefreshIndicator(
                  onRefresh: () => ref
                      .read(monthlyRetrospectiveControllerProvider.notifier)
                      .refresh(),
                  child: ListView(
                    key: ValueKey('${data.month}:$selected'),
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
                    children: !data.hasRecords
                        ? [
                            const Text(
                              '지난달에는 남긴 기록이 없어요',
                              style: AppTextStyles.homeBody,
                            ),
                          ]
                        : switch (selected) {
                            '그날의 기억' => _moments(data),
                            '우리의 답' => _conversation(data.conversation!),
                            '마음 남기기' => _reflection(data),
                            _ => _overview(data),
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

  List<Widget> _overview(MonthlyRetrospective data) => [
    Text(data.title, style: AppTextStyles.pageTitle),
    const SizedBox(height: 24),
    if (data.moments.isNotEmpty) ...[
      _CardImages(
        cards: data.moments.expand((m) => m.cards).take(2).toList(),
        onPressed: (card) {
          final moment = data.moments.firstWhere((m) => m.cards.contains(card));
          _openRecord(moment.date);
        },
      ),
      const SizedBox(height: 24),
    ],
    Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stat('${data.recordedDays}일', '기록한 날'),
        _stat(data.cardCountComplete ? '${data.cardCount}개' : '집계 불가', '남긴 카드'),
        _stat('${data.completedQuestions}개', '함께 답한 질문'),
      ],
    ),
    const SizedBox(height: 28),
    AiCharacterSpeechRow(
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

  List<Widget> _moments(MonthlyRetrospective data) => data.moments.isEmpty
      ? [const Text('지난달에는 사진이 담긴 카드가 없어요', style: AppTextStyles.homeBody)]
      : [
          for (final moment in data.moments) ...[
            Text(
              '${moment.date.month}월 ${moment.date.day}일',
              style: AppTextStyles.homeBodyMedium,
            ),
            const SizedBox(height: 16),
            _CardImages(
              cards: moment.cards,
              onPressed: (_) => _openRecord(moment.date),
            ),
            if (moment.question != null) ...[
              const SizedBox(height: 16),
              Text(moment.question!, style: AppTextStyles.homeBody),
            ],
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => _openRecord(moment.date),
                child: const Text('그날의 기록 보기'),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ];

  void _openRecord(DateTime date) {
    final formatted =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    context.push('/ai/monthly-record?date=$formatted');
  }

  List<Widget> _conversation(RetrospectiveConversation conversation) => [
    Text(
      '${conversation.date.month}월 ${conversation.date.day}일 · 가장 길게 나눈 답변',
      style: AppTextStyles.homeBody.copyWith(color: AppColors.textMuted),
    ),
    const SizedBox(height: 24),
    Text(conversation.question, style: AppTextStyles.pageTitle),
    const SizedBox(height: 32),
    QuestionAnswerDisplaySection(
      title: '내 답변',
      body: conversation.myAnswer,
      isMuted: false,
      displayStyle: QuestionAnswerDisplayStyle.plain,
    ),
    const SizedBox(height: 28),
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
    const SizedBox(height: 32),
    const AiCharacterSpeechRow(speechText: '지난달 함께 길게 남긴 말이야. 천천히 다시 읽어볼까?'),
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

  List<Widget> _reflection(MonthlyRetrospective data) {
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
        speechText: reflection.question!,
        showGeneratedIndicator: reflection.source == 'ai',
        onGeneratedIndicatorPressed: reflection.source == 'ai'
            ? () => _reportAi(reflection.id)
            : null,
      ),
      const SizedBox(height: 28),
      if (_editing || reflection.myAnswer == null) ...[
        const Text('내 답변', style: AppTextStyles.homeBodyMedium),
        const SizedBox(height: 12),
        AppAnswerInput(
          controller: _answer,
          minLines: 4,
          maxLines: 8,
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
      const SizedBox(height: 28),
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

class _CardImages extends ConsumerWidget {
  const _CardImages({required this.cards, required this.onPressed});
  final List<RetrospectiveCard> cards;
  final void Function(RetrospectiveCard) onPressed;
  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      FutureBuilder<Map<String, String>>(
        future: ref
            .watch(monthlyRetrospectiveRepositoryProvider)
            .previewUrls(cards),
        builder: (context, snapshot) => Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final card in cards)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Semantics(
                    button: true,
                    label: '그날의 카드 보기',
                    child: InkWell(
                      onTap: () => onPressed(card),
                      child: AspectRatio(
                        aspectRatio: card.aspectRatio,
                        child: snapshot.data?[card.previewPath] == null
                            ? const ColoredBox(
                                color: AppColors.formSurface,
                                child: Center(child: Text('카드 미리보기')),
                              )
                            : Image.network(
                                snapshot.data![card.previewPath]!,
                                fit: BoxFit.contain,
                                errorBuilder: (_, error, stack) =>
                                    const Center(child: Text('사진을 불러오지 못했어요')),
                              ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
}
