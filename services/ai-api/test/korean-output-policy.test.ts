import assert from 'node:assert/strict';
import test from 'node:test';

import {
  KoreanOutputPolicyError,
  normalizeAndValidateKoreanOutput,
} from '../src/domain/korean-output-policy.ts';

test('사용자 노출 문장은 NFC로 정규화한다', () => {
  const decomposed = '가벼운 산책 어때?'.normalize('NFD');

  assert.equal(
    normalizeAndValidateKoreanOutput(decomposed, 'suggestion'),
    '가벼운 산책 어때?',
  );
});

test('한글과 함께 쓰인 영문 약어와 숫자는 허용한다', () => {
  assert.equal(
    normalizeAndValidateKoreanOutput('AI가 24개 답변을 기억했어', 'message'),
    'AI가 24개 답변을 기억했어',
  );
});

test('한자와 일본어 등 다른 문자 체계는 구분된 코드로 거부한다', () => {
  for (const value of ['국내旅行이 좋아?', '여행は 어디가 좋아?']) {
    assert.throws(
      () => normalizeAndValidateKoreanOutput(value, 'question'),
      (error: unknown) =>
        error instanceof KoreanOutputPolicyError
        && error.code === 'foreign_script',
    );
  }
});

test('이모지는 구분된 코드로 거부한다', () => {
  assert.throws(
    () => normalizeAndValidateKoreanOutput('오늘 산책 어때? 😊', 'suggestion'),
    (error: unknown) =>
      error instanceof KoreanOutputPolicyError
      && error.code === 'emoji',
  );
});

test('보이지 않는 문자와 방향 제어 문자는 구분된 코드로 거부한다', () => {
  for (const value of ['오늘\u200B산책 어때?', '오늘 \u202E산책 어때?']) {
    assert.throws(
      () => normalizeAndValidateKoreanOutput(value, 'suggestion'),
      (error: unknown) =>
        error instanceof KoreanOutputPolicyError
        && error.code === 'unsafe_character',
    );
  }
});

test('한글이 없는 문장은 구분된 코드로 거부한다', () => {
  assert.throws(
    () => normalizeAndValidateKoreanOutput('AI 24?', 'message'),
    (error: unknown) =>
      error instanceof KoreanOutputPolicyError
      && error.code === 'missing_hangul',
  );
});
