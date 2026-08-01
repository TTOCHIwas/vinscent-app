import assert from 'node:assert/strict';
import test from 'node:test';

import { reconcileDirectQuestionAnswer } from '../src/domain/direct-question-evidence.ts';
import type {
  DirectQuestionAnswer,
  DirectQuestionContext,
} from '../src/domain/learning-contract.ts';

const insufficientAnswer: DirectQuestionAnswer = {
  status: 'insufficient',
  text: '아직 확인된 내용이 없어서 잘 모르겠어',
  followUpQuestion: null,
};

test('관련 질문에서 상대방이 모른다고 답했다면 그 사실을 답으로 사용한다', () => {
  const context = directContext({
    questionText: '상대방이 요즘 가장 소중하게 생각하는 건 뭐야?',
    recentQuestionText: '요즘 가장 소중하게 지키고 싶은 건 뭐야?',
    partnerAnswer: '몰라',
  });

  assert.deepEqual(
    reconcileDirectQuestionAnswer(context, insufficientAnswer),
    {
      status: 'answered',
      text: '상대방도 아직 잘 모르겠다고 했어',
      followUpQuestion: null,
    },
  );
});

test('관련 질문에서 상대방이 없다고 답했다면 그 사실을 답으로 사용한다', () => {
  const context = directContext({
    questionText: '상대방이 요즘 새로 생긴 관심사가 있어?',
    recentQuestionText: '요즘 새로 생긴 관심사가 있어?',
    partnerAnswer: '딱히 없어',
  });

  assert.deepEqual(
    reconcileDirectQuestionAnswer(context, insufficientAnswer),
    {
      status: 'answered',
      text: '상대방은 딱히 없다고 했어',
      followUpQuestion: null,
    },
  );
});

test('다른 주제에서 나온 모른다는 답은 현재 질문에 사용하지 않는다', () => {
  const context = directContext({
    questionText: '상대방이 가장 자신 있어 하는 요리가 뭐야?',
    recentQuestionText: '요즘 가장 소중하게 지키고 싶은 건 뭐야?',
    partnerAnswer: '몰라',
  });

  assert.equal(
    reconcileDirectQuestionAnswer(context, insufficientAnswer),
    insufficientAnswer,
  );
});

test('요즘처럼 약한 공통어만 같은 답변은 관련 근거로 사용하지 않는다', () => {
  const context = directContext({
    questionText: '상대방이 요즘 가장 자신 있는 요리가 뭐야?',
    recentQuestionText: '요즘 가장 소중하게 지키고 싶은 건 뭐야?',
    partnerAnswer: '몰라',
  });

  assert.equal(
    reconcileDirectQuestionAnswer(context, insufficientAnswer),
    insufficientAnswer,
  );
});

test('확인 기억과 최근 선호 답변이 명백히 충돌하면 단정하지 않는다', () => {
  const context: DirectQuestionContext = {
    questionText: '상대방은 여행할 때 계획을 꼼꼼히 세우는 편이야?',
    confirmedMemories: [{
      subject: 'partner',
      kind: 'travel_planning',
      domain: 'daily_life',
      statement: '여행 전에 일정을 꼼꼼히 정하는 걸 좋아해',
      confidence: 0.82,
    }],
    recentCompletedQuestions: [{
      questionText: '최근 여행은 어떻게 준비했어?',
      answers: [
        { subject: 'me', text: '미리 숙소를 정했어' },
        { subject: 'partner', text: '이번에는 아무 계획 없이 떠나는 게 좋았어' },
      ],
    }],
    recentSharedQuestionTexts: [],
  };
  const answered: DirectQuestionAnswer = {
    status: 'answered',
    text: '상대방은 여행 전에 계획을 꼼꼼히 세우는 편이야',
    followUpQuestion: null,
  };

  assert.deepEqual(reconcileDirectQuestionAnswer(context, answered), {
    status: 'insufficient',
    text: '최근 답과 확인된 기억이 서로 달라서 지금은 확실히 말하기 어려워',
    followUpQuestion: null,
  });
});

test('서로 충돌하지 않는 관련 기록은 모델 답변을 유지한다', () => {
  const context: DirectQuestionContext = {
    questionText: '상대방은 쉬는 날 걷는 걸 좋아해?',
    confirmedMemories: [{
      subject: 'partner',
      kind: 'rest_preference',
      domain: 'daily_life',
      statement: '쉬는 날에는 새로운 동네를 천천히 걷는 걸 좋아해',
      confidence: 0.92,
    }],
    recentCompletedQuestions: [{
      questionText: '지난 주말에는 어떻게 쉬었어?',
      answers: [
        { subject: 'me', text: '집에서 쉬었어' },
        { subject: 'partner', text: '동네를 오래 걸었어' },
      ],
    }],
    recentSharedQuestionTexts: [],
  };
  const answered: DirectQuestionAnswer = {
    status: 'answered',
    text: '상대방은 쉬는 날 천천히 걷는 걸 좋아해',
    followUpQuestion: null,
  };

  assert.equal(reconcileDirectQuestionAnswer(context, answered), answered);
});

function directContext(options: {
  questionText: string;
  recentQuestionText: string;
  partnerAnswer: string;
}): DirectQuestionContext {
  return {
    questionText: options.questionText,
    confirmedMemories: [],
    recentCompletedQuestions: [{
      questionText: options.recentQuestionText,
      answers: [
        { subject: 'me', text: '시간' },
        { subject: 'partner', text: options.partnerAnswer },
      ],
    }],
    recentSharedQuestionTexts: [],
  };
}
