import assert from 'node:assert/strict';
import test from 'node:test';

import type {
  ModelEvaluationTask,
} from '../eval/cloudflare-model-eval-case.ts';
import {
  createCloudflareModelEvaluationCases,
} from '../eval/cloudflare-model-eval-cases.ts';

const expectedTasks: ModelEvaluationTask[] = [
  'foundation_ranking',
  'memory_extraction',
  'couple_feedback',
  'general_question',
  'personalized_question',
  'direct_answer',
  'direct_question_follow_up',
  'proactive_suggestion',
];

test('Cloudflare 모델 평가는 서로 다른 한국어 사례를 30개 이상 사용한다', () => {
  const cases = createCloudflareModelEvaluationCases();
  const names = new Set(cases.map((item) => item.name));

  assert.ok(cases.length >= 30);
  assert.equal(names.size, cases.length);
  for (const item of cases) {
    assert.match(item.scenario, /[가-힣]/u);
    assert.match(item.expectation, /[가-힣]/u);
  }
});

test('Cloudflare 모델 평가는 운영 AI 작업 유형을 모두 포함한다', () => {
  const cases = createCloudflareModelEvaluationCases();
  const tasks = new Set(cases.map((item) => item.task));

  assert.deepEqual([...tasks].sort(), [...expectedTasks].sort());
  for (const task of expectedTasks) {
    assert.ok(cases.some((item) => item.task === task));
  }
});

test('Cloudflare 모델 평가는 실제 앱 회귀 유형을 별도로 표시한다', () => {
  const cases = createCloudflareModelEvaluationCases();
  const regressions = cases.filter(
    (item) => item.source === 'production_regression',
  );
  const names = new Set(regressions.map((item) => item.name));

  assert.ok(regressions.length >= 10);
  assert.ok(names.has('feedback_unknown_and_time'));
  assert.ok(names.has('direct_answer_insufficient_travel_range'));
  assert.ok(names.has('follow_up_preserves_travel_rhythm'));
  assert.ok(names.has('follow_up_preserves_cooking_skill'));
  assert.ok(names.has('proactive_sunset_card'));
  assert.ok(names.has('memory_prompt_injection_ignored'));
});

test('한국어 활용형과 실내 맥락을 평가 표현으로 인정한다', () => {
  const cases = createCloudflareModelEvaluationCases();
  const feedback = cases.find(
    (item) => item.name === 'feedback_personalized_without_owner_exposure',
  );
  const coldWeather = cases.find(
    (item) => item.name === 'proactive_cold_weather_is_softened',
  );

  assert.ok(feedback);
  assert.ok(coldWeather);
  assert.doesNotThrow(() => feedback.validate({
    text: '이번 주에는 함께 걸으면서 오래된 이야기도 나누고 싶은가 봐',
  }));
  assert.throws(
    () => feedback.validate({
      text: '이번 주에는 함께 새로운 걸 이야기하고 싶은가 봐',
    }),
    /missing one of/i,
  );
  assert.doesNotThrow(() => coldWeather.validate({
    text: '오늘은 집에서 함께 차 마시면서 영화 한 편 보는 건 어때',
    kind: 'date_idea',
  }));
});
