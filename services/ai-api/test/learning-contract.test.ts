import assert from 'node:assert/strict';
import test from 'node:test';

import {
  anonymizeCompletedQuestionContext,
  deriveLearningStage,
  resolveMemoryCandidates,
  validateMemoryCandidates,
  validateQuestionRecommendation,
  type CompletedQuestionContext,
} from '../src/domain/learning-contract.ts';

const context: CompletedQuestionContext = {
  coupleId: 'couple-1',
  question: {
    dailyQuestionId: 'daily-question-1',
    questionId: 'question-1',
    text: '힘든 날에는 상대가 어떻게 곁에 있어주면 가장 힘이 돼?',
    domain: 'emotional_support',
  },
  answers: [
    {
      answerId: 'answer-a',
      userId: 'user-a',
      text: '조언보다 먼저 조용히 들어주면 좋겠어.',
    },
    {
      answerId: 'answer-b',
      userId: 'user-b',
      text: '잠깐 혼자 정리할 시간을 준 뒤 말을 걸어주면 좋아.',
    },
  ],
  confirmedMemories: [],
  remainingFoundationQuestions: [
    {
      questionKey: 'foundation_v1_communication_01',
      text: '생각이 다를 때 어떤 대화를 하면 이해받았다고 느껴?',
      domain: 'communication_repair',
    },
    {
      questionKey: 'foundation_v1_daily_life_01',
      text: '아무 일정도 없는 날을 함께 보낸다면 어떻게 보내고 싶어?',
      domain: 'daily_life',
    },
  ],
};

test('학습 단계 경계를 24개 커리큘럼 기준으로 계산한다', () => {
  assert.equal(deriveLearningStage(0, 24), 'collecting');
  assert.equal(deriveLearningStage(7, 24), 'collecting');
  assert.equal(deriveLearningStage(8, 24), 'exploring');
  assert.equal(deriveLearningStage(15, 24), 'exploring');
  assert.equal(deriveLearningStage(16, 24), 'refining');
  assert.equal(deriveLearningStage(23, 24), 'refining');
  assert.equal(deriveLearningStage(24, 24), 'ready');
  assert.equal(deriveLearningStage(30, 24), 'ready');
});

test('모델 문맥에서 실제 커플과 사용자 식별자를 제거한다', () => {
  const anonymized = anonymizeCompletedQuestionContext(context);
  const serialized = JSON.stringify(anonymized);

  assert.deepEqual(
    anonymized.answers.map((answer) => answer.participantKey),
    ['partner_a', 'partner_b'],
  );
  assert.equal(serialized.includes('couple-1'), false);
  assert.equal(serialized.includes('user-a'), false);
  assert.equal(serialized.includes('user-b'), false);
});

test('기억 후보는 입력 답변을 근거로 사용해야 한다', () => {
  assert.doesNotThrow(() => {
    validateMemoryCandidates(context, [
      {
        memoryKey: 'support_listening_first_user_a',
        scope: 'personal',
        subjectUserId: 'user-a',
        kind: 'support_preference',
        statement: '힘든 날에는 조언보다 먼저 이야기를 들어주는 것을 선호한다.',
        confidence: 0.78,
        evidenceAnswerIds: ['answer-a'],
      },
    ]);
  });

  assert.throws(
    () => {
      validateMemoryCandidates(context, [
        {
          memoryKey: 'unsupported_memory',
          scope: 'couple',
          subjectUserId: null,
          kind: 'relationship_strength',
          statement: '두 사람은 갈등을 항상 빠르게 해결한다.',
          confidence: 0.9,
          evidenceAnswerIds: ['unknown-answer'],
        },
      ]);
    },
    /unknown evidence answer/i,
  );
});

test('개인 기억 대상은 답변 참여자 중 한 명이어야 한다', () => {
  assert.throws(
    () => {
      validateMemoryCandidates(context, [
        {
          memoryKey: 'foreign_subject',
          scope: 'personal',
          subjectUserId: 'other-user',
          kind: 'value',
          statement: '확인되지 않은 사용자에 대한 기억이다.',
          confidence: 0.5,
          evidenceAnswerIds: ['answer-a'],
        },
      ]);
    },
    /unknown personal subject/i,
  );
});

test('모델의 익명 참여자 키는 서버 경계에서만 사용자 ID로 복원한다', () => {
  const [resolved] = resolveMemoryCandidates(context, [
    {
      memoryKey: 'anonymous_subject',
      scope: 'personal',
      subjectParticipantKey: 'partner_a',
      kind: 'support_preference',
      statement: '힘든 날에는 먼저 조용히 들어주는 것을 선호한다.',
      confidence: 0.75,
      evidenceAnswerIds: ['answer-a'],
    },
  ]);

  assert.equal(resolved?.subjectUserId, 'user-a');
});

test('고정 질문 추천은 남은 커리큘럼 후보 안에서만 선택한다', () => {
  assert.doesNotThrow(() => {
    validateQuestionRecommendation(
      context.remainingFoundationQuestions,
      'foundation_v1_communication_01',
    );
  });

  assert.throws(
    () => {
      validateQuestionRecommendation(
        context.remainingFoundationQuestions,
        'foundation_v1_unknown_99',
      );
    },
    /question recommendation is not an allowed candidate/i,
  );
});
