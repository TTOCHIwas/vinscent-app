import assert from 'node:assert/strict';
import test from 'node:test';

import { preservesQuestionScope } from '../src/domain/question-scope-preservation.ts';

const preservedCases = [
  [
    '상대방은 해외여행을 선호할까, 국내여행을 선호할까?',
    '여행을 간다면 해외와 국내 중 어디가 더 좋아?',
  ],
  [
    '상대방은 여행지에서 아침에 일찍 움직이는 걸 좋아할까, 늦게 쉬는 걸 좋아할까?',
    '여행지에서는 아침 일찍 움직이는 게 좋아, 느긋하게 쉬는 게 좋아?',
  ],
  [
    '상대방이 가장 잘하는 요리가 뭐야?',
    '직접 만든 요리 중 자신 있게 추천하고 싶은 메뉴는 뭐야?',
  ],
  [
    '상대방은 기념일에 실용적인 선물과 의미 있는 선물 중 뭘 더 좋아할까?',
    '기념일 선물은 실용적인 것과 의미 있는 것 중 어느 쪽이 더 좋아?',
  ],
  [
    '상대방은 쉬는 날 집에 있는 것과 밖에 나가는 것 중 뭘 좋아할까?',
    '쉬는 날에는 집과 바깥 중 어디에서 쉬는 게 더 좋아?',
  ],
] as const;

test('공용 후속 질문은 원래 질문의 장소와 선택지를 보존한다', () => {
  for (const [source, candidate] of preservedCases) {
    assert.equal(
      preservesQuestionScope(source, candidate),
      true,
      `${source} -> ${candidate}`,
    );
  }
});

test('공용 후속 질문이 구체적인 비교 기준을 일반화하면 거부한다', () => {
  assert.equal(
    preservesQuestionScope(
      '상대방은 해외여행을 선호할까, 국내여행을 선호할까?',
      '둘이 함께 가보고 싶은 여행지는 어디야?',
    ),
    false,
  );
  assert.equal(
    preservesQuestionScope(
      '상대방은 여행지에서 아침에 일찍 움직이는 걸 좋아할까, 늦게 쉬는 걸 좋아할까?',
      '여행지에서 보내고 싶은 하루는 어떤 모습이야?',
    ),
    false,
  );
});

test('핵심어가 하나뿐인 짧은 질문에는 범위 보존 휴리스틱을 적용하지 않는다', () => {
  assert.equal(
    preservesQuestionScope('상대방은 커피를 좋아해?', '둘이 마시고 싶은 건 뭐야?'),
    true,
  );
});
