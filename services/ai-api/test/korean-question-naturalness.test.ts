import assert from 'node:assert/strict';
import test from 'node:test';

import {
  findKoreanQuestionNaturalnessIssue,
} from '../src/domain/korean-question-naturalness.ts';

test('짧은 질문에서 격식 번역투의 실제 구간과 출처 규칙을 찾는다', () => {
  const cases = [
    {
      text: '둘의 관계에 있어서 가장 중요한 건 뭐야?',
      span: '에 있어서',
      reference: 'im-not-ai:A-3',
    },
    {
      text: '둘의 추억과 관련하여 가장 먼저 떠오르는 건 뭐야?',
      span: '과 관련하여',
      reference: 'im-not-ai:A-5',
    },
    {
      text: '둘의 취향에 기반하여 고르고 싶은 데이트는 뭐야?',
      span: '에 기반하여',
      reference: 'im-not-ai:A-6',
    },
    {
      text: '둘의 대화에 의해 달라진 점은 뭐야?',
      span: '에 의해',
      reference: 'im-not-ai:A-9',
    },
    {
      text: '둘이 선택되어진 장소는 어디야?',
      span: '되어진',
      reference: 'im-not-ai:A-8',
    },
  ];

  for (const item of cases) {
    const issue = findKoreanQuestionNaturalnessIssue(item.text);

    assert.equal(issue?.code, 'formal_translationese');
    assert.equal(issue?.span, item.span);
    assert.equal(issue?.reference, item.reference);
    assert.equal(item.text.slice(issue?.start, issue?.end), item.span);
  }
});

test('목적어와 맞지 않는 포괄 동사를 국소적으로 찾는다', () => {
  for (const text of [
    '둘이 같이 해보고 싶은 영화는 뭐야?',
    '둘이 같이 보고 싶은 활동은 뭐야?',
    '둘이 같이 가보고 싶은 노래는 뭐야?',
  ]) {
    const issue = findKoreanQuestionNaturalnessIssue(text);

    assert.equal(issue?.code, 'predicate_mismatch');
    assert.equal(issue?.reference, 'danjjan:predicate-object');
    assert.ok(issue?.span.length);
  }
});

test('자연스러운 구어 질문과 단발성 표현은 그대로 허용한다', () => {
  for (const text of [
    '서로에 대해 새롭게 알게 된 건 뭐야?',
    '어떤 생각을 가지고 있어?',
    '실내 데이트와 야외 데이트 중 뭐가 좋아?',
    '둘이 같이 보고 싶은 영화는 뭐야?',
    '둘이 같이 해보고 싶은 활동은 뭐야?',
    '둘이 같이 듣고 싶은 노래는 뭐야?',
  ]) {
    assert.equal(findKoreanQuestionNaturalnessIssue(text), null);
  }
});
