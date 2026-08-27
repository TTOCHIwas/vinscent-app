import assert from 'node:assert/strict';
import test from 'node:test';

import {
  classifyPersonalizedAnswerEvidence,
  hasUnsupportedPastEventPresupposition,
} from '../src/domain/personalized-question-grounding.ts';

test('원 질문이 답변에 부여한 사실 상태를 구분한다', () => {
  assert.equal(
    classifyPersonalizedAnswerEvidence(
      '다음 주말에 둘이 같이 해보고 싶은 건 뭐야?',
    ),
    'intention_or_hypothetical',
  );
  assert.equal(
    classifyPersonalizedAnswerEvidence(
      '둘이 고기를 먹을 때 어떤 분위기의 식당이 좋아?',
    ),
    'preference',
  );
  assert.equal(
    classifyPersonalizedAnswerEvidence(
      '최근 둘이 라면 먹었을 때 가장 기억에 남은 건 뭐야?',
    ),
    'reported_experience',
  );
  assert.equal(
    classifyPersonalizedAnswerEvidence('요즘 새로 생긴 관심사가 있어?'),
    'open_response',
  );
});

test('희망 답변에서 근거 없는 과거 사건만 거부한다', () => {
  const sourceQuestion = '다음 주말에 둘이 같이 해보고 싶은 건 뭐야?';

  assert.equal(
    hasUnsupportedPastEventPresupposition(
      sourceQuestion,
      '요즘 둘이 같이 고기 먹으러 갔을 때 어떤 분위기였어?',
    ),
    true,
  );
  assert.equal(
    hasUnsupportedPastEventPresupposition(
      sourceQuestion,
      '둘이 고기를 먹었던 식당 중 어디가 좋았어?',
    ),
    true,
  );
  assert.equal(
    hasUnsupportedPastEventPresupposition(
      sourceQuestion,
      '둘이 고기 먹으러 간 곳은 어디야?',
    ),
    true,
  );
  assert.equal(
    hasUnsupportedPastEventPresupposition(
      sourceQuestion,
      '그때 고기 먹으면서 무슨 얘기 했어?',
    ),
    true,
  );
  assert.equal(
    hasUnsupportedPastEventPresupposition(
      sourceQuestion,
      '둘이 고기 먹으러 간다면 어떤 분위기의 식당이 좋아?',
    ),
    false,
  );
  assert.equal(
    hasUnsupportedPastEventPresupposition(
      '쉬는 날에는 보통 어떻게 쉬어?',
      '주말에 같이 하면 편한 활동이 뭐야?',
    ),
    false,
  );
  assert.equal(
    hasUnsupportedPastEventPresupposition(
      '최근 둘이 라면 먹었을 때 가장 기억에 남은 건 뭐야?',
      '둘이 라면 먹었던 날 어떤 이야기를 나눴어?',
    ),
    false,
  );
});
