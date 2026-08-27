import assert from 'node:assert/strict';
import test from 'node:test';

import {
  isConsistentPersonalizedQuestionGroundingDecision,
  type PersonalizedQuestionGroundingDecision,
} from '../src/domain/personalized-question-grounding.ts';

test('의미 근거 판정은 허용 여부와 이유 코드가 일치해야 한다', () => {
  const consistent: PersonalizedQuestionGroundingDecision[] = [
    { supported: true, reasonCode: 'no_completed_event' },
    { supported: true, reasonCode: 'answers_confirm_same_event' },
    { supported: false, reasonCode: 'answers_do_not_confirm_event' },
    { supported: false, reasonCode: 'answers_contradict_event' },
    { supported: false, reasonCode: 'different_event' },
  ];

  for (const decision of consistent) {
    assert.equal(
      isConsistentPersonalizedQuestionGroundingDecision(decision),
      true,
    );
  }
});

test('의미 근거 판정은 모순된 허용 여부와 이유 코드를 거부한다', () => {
  const inconsistent: PersonalizedQuestionGroundingDecision[] = [
    { supported: false, reasonCode: 'no_completed_event' },
    { supported: false, reasonCode: 'answers_confirm_same_event' },
    { supported: true, reasonCode: 'answers_do_not_confirm_event' },
    { supported: true, reasonCode: 'answers_contradict_event' },
    { supported: true, reasonCode: 'different_event' },
  ];

  for (const decision of inconsistent) {
    assert.equal(
      isConsistentPersonalizedQuestionGroundingDecision(decision),
      false,
    );
  }
});
