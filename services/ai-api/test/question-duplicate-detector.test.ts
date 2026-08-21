import assert from 'node:assert/strict';
import test from 'node:test';

import {
  areQuestionsNearDuplicate,
} from '../src/domain/question-duplicate-detector.ts';

const recentTravelQuestion =
  '여행지에서는 아침 일찍 움직이는 게 좋아, 느긋하게 쉬는 게 좋아?';

test('한국어 조사와 선호 표현이 달라도 같은 질문으로 판단한다', () => {
  assert.equal(
    areQuestionsNearDuplicate(
      recentTravelQuestion,
      '여행지에서 아침 일찍 움직이는 게 좋거나 느긋하게 쉬는 게 좋을까?',
    ),
    true,
  );
  assert.equal(
    areQuestionsNearDuplicate(
      recentTravelQuestion,
      '여행지에서 아침형 인간으로 움직이는 거랑 느긋하게 쉬는 거 중 뭐가 더 취향이야?',
    ),
    true,
  );
  assert.equal(
    areQuestionsNearDuplicate(
      '상대방은 여행지에서 아침 일찍 움직이는 걸 좋아할까, 느긋하게 쉬는 걸 좋아할까?',
      recentTravelQuestion,
    ),
    true,
  );
  assert.equal(
    areQuestionsNearDuplicate(
      recentTravelQuestion,
      '여행지에서 아침형 인간으로 움직이는 거랑 느긋하게 쉬는 거 중 어떤 스타일이 더 편해?',
    ),
    true,
  );
  assert.equal(
    areQuestionsNearDuplicate(
      '기념일에는 실용적인 선물이 더 좋아, 의미 있는 선물이 더 좋아?',
      '기념일 선물은 실용적인 거랑 의미 있는 거 중 뭐가 더 취향이야?',
    ),
    true,
  );
  assert.equal(
    areQuestionsNearDuplicate(
      '주말에 둘이 같이 영화 보러 갈 때 어떤 영화 장르를 좋아해?',
      '다음 주말에 둘이 같이 영화 보러 갈 때 어떤 영화 장르를 좋아해?',
    ),
    true,
  );
});

test('같은 주제라도 질문 초점이나 극성이 다르면 허용한다', () => {
  assert.equal(
    areQuestionsNearDuplicate(
      recentTravelQuestion,
      '여행지에서 가장 기대하는 순간은 언제야?',
    ),
    false,
  );
  assert.equal(
    areQuestionsNearDuplicate(
      '주말에 함께 가장 하고 싶은 건 뭐야?',
      '이번 주말에 함께 먹고 싶은 건 뭐야?',
    ),
    false,
  );
  assert.equal(
    areQuestionsNearDuplicate(
      '가장 잘하는 요리는 뭐야?',
      '가장 좋아하는 요리는 뭐야?',
    ),
    false,
  );
  assert.equal(
    areQuestionsNearDuplicate(
      '여행지에서 아침 일찍 움직이는 게 좋아?',
      '여행지에서 아침 일찍 움직이는 게 싫어?',
    ),
    false,
  );
});
