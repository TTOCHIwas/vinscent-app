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

test('서로 다른 휴식 방식에는 같이 답할 수 있는 중립 질문을 인정한다', () => {
  const cases = createCloudflareModelEvaluationCases();
  const restStyles = cases.find(
    (item) => item.name === 'personalized_question_different_rest_styles',
  );

  assert.ok(restStyles);
  assert.doesNotThrow(() => restStyles.validate({
    questionKey: 'personalized_generated_rest_activity',
    text: '주말에 같이 하면 편한 활동이 뭐야?',
    category: 'daily_life',
    mood: null,
    rationale: '둘 다 편하게 답할 수 있는 활동 선호를 확인해',
  }));
});

test('개인화 질문 평가는 현재 질문 반복과 직전 답변 맥락 단절을 거부한다', () => {
  const cases = createCloudflareModelEvaluationCases();
  const repeated = cases.find(
    (item) => item.name === 'personalized_question_rejects_temporal_rephrase',
  );
  const continuity = cases.find(
    (item) => item.name === 'personalized_question_continues_latest_answers',
  );

  assert.ok(repeated);
  assert.ok(continuity);
  assert.throws(() => repeated.validate({
    questionKey: 'personalized_generated_movie_repeat',
    text: '다음 주말에 둘이 같이 영화 보러 갈 때 어떤 영화 장르를 좋아해?',
    category: 'daily_life',
    mood: null,
    rationale: '영화 취향을 더 알아보기 위해',
  }), /duplicate_question/u);
  assert.throws(() => continuity.validate({
    questionKey: 'personalized_generated_unrelated_movie',
    text: '다음에는 둘이 어떤 영화를 같이 보고 싶어?',
    category: 'daily_life',
    mood: null,
    rationale: '함께 보고 싶은 영화를 알아보기 위해',
  }), /missing one of|forbidden pattern/u);
  assert.doesNotThrow(() => continuity.validate({
    questionKey: 'personalized_generated_after_test',
    text: '앱 테스트를 끝내고 둘이 먹고 싶은 메뉴는 뭐야?',
    category: 'daily_life',
    mood: null,
    rationale: '직전 계획 다음에 이어질 작은 보상을 알아보기 위해',
  }));
});

test('운영에서 재생성하는 작업은 평가에서도 복구 경로를 제공한다', () => {
  const cases = createCloudflareModelEvaluationCases();
  const recoverableTasks = new Set<ModelEvaluationTask>([
    'couple_feedback',
    'personalized_question',
    'direct_question_follow_up',
    'proactive_suggestion',
  ]);

  for (const item of cases) {
    if (recoverableTasks.has(item.task)) {
      assert.equal(typeof item.recoverValidation, 'function', item.name);
      assert.equal(typeof item.validateForRecovery, 'function', item.name);
    }
  }

  const feedback = cases.find((item) => item.task === 'couple_feedback');
  assert.ok(feedback);
  assert.equal(typeof feedback.resolveFallback, 'function');
});

test('직접 답변 평가는 명시적 모름을 보존하고 근거 밖 부연을 거부한다', () => {
  const cases = createCloudflareModelEvaluationCases();
  const unknown = cases.find(
    (item) => item.name === 'direct_answer_unknown_response_is_answered',
  );
  const restPreference = cases.find(
    (item) => item.name === 'direct_answer_grounded_rest_preference',
  );
  const foodSkill = cases.find(
    (item) => item.name === 'direct_answer_grounded_food_skill',
  );

  assert.ok(unknown);
  assert.ok(restPreference);
  assert.ok(foodSkill);
  assert.doesNotThrow(() => unknown.validate({
    status: 'answered',
    text: '상대방은 아직 무엇이 가장 소중한지 잘 몰라',
    followUpQuestion: null,
  }));
  assert.throws(() => unknown.validate({
    status: 'answered',
    text: '상대방은 아직 잘 몰라 하지만 나한테는 시간이 소중해',
    followUpQuestion: null,
  }), /forbidden pattern/i);
  assert.throws(() => unknown.validate({
    status: 'answered',
    text: '상대방은 소중하게 생각하는 게 없어 아직 잘 모르겠어',
    followUpQuestion: null,
  }), /forbidden pattern/i);
  assert.throws(() => restPreference.validate({
    status: 'answered',
    text: '새로운 동네를 천천히 걷는 걸 좋아하고 조용한 시간을 즐겨',
    followUpQuestion: null,
  }), /forbidden pattern/i);
  assert.doesNotThrow(() => restPreference.validate({
    status: 'answered',
    text: '상대방은 새로운 동네를 천천히 걸어다니는 걸 좋아해',
    followUpQuestion: null,
  }));
  assert.throws(() => foodSkill.validate({
    status: 'answered',
    text: '김치볶음밥을 자신 있게 만들고 요리 실력도 좋은 편이야',
    followUpQuestion: null,
  }), /forbidden pattern/i);
  assert.throws(() => foodSkill.validate({
    status: 'answered',
    text: '김치볶음밥을 자신 있게 만들고 가끔 자랑하는 모습도 보여',
    followUpQuestion: null,
  }), /forbidden pattern/i);
});

test('한마디 평가는 답변을 되읽거나 숨은 의도와 조언을 만들지 않는다', () => {
  const cases = createCloudflareModelEvaluationCases();
  const unknown = cases.find(
    (item) => item.name === 'feedback_unknown_and_time',
  );
  const heavyDay = cases.find(
    (item) => item.name === 'feedback_heavy_day_without_forced_positive',
  );
  const restPreferences = cases.find(
    (item) => item.name === 'feedback_distinct_rest_preferences',
  );
  const nothingSpecial = cases.find(
    (item) => item.name === 'feedback_nothing_special_without_judgment',
  );
  const rejectedOwner = cases.find(
    (item) => item.name === 'feedback_rejected_owner_reference',
  );

  assert.ok(unknown);
  assert.ok(heavyDay);
  assert.ok(restPreferences);
  assert.ok(nothingSpecial);
  assert.ok(rejectedOwner);
  assert.doesNotThrow(() => unknown.validate({
    text: '소중한 건 바로 이름 붙을 수도, 아직 빈칸일 수도 있나 봐...',
  }));
  assert.throws(() => unknown.validate({
    text: '소중한 걸 고르는 데도 시간이 조금 필요한가 봐...',
  }), /mixed certainty|forbidden pattern/i);
  assert.throws(() => unknown.validate({
    text: '뭘 지킬지 아직 모르지만, 시간은 잡아두고 싶네!',
  }), /mixed certainty|forbidden pattern/i);
  assert.throws(() => heavyDay.validate({
    text: '오늘은 서로 힘들었다는 걸 알아차렸으면 좋겠어...',
  }), /forbidden pattern/i);
  assert.throws(() => restPreferences.validate({
    text: '집에서 음악을 들을 때와 밖에서 걸을 때 모두 편안하네',
  }), /forbidden pattern/i);
  assert.throws(() => nothingSpecial.validate({
    text: '새로운 걸 찾으려 애쓰는 마음은 있지만 아직 떠오르지 않나 봐...',
  }), /forbidden pattern/i);
  assert.throws(() => rejectedOwner.validate({
    text: '시간이 소중한 건 알겠는데 아직은 잘 모르겠네...',
  }), /mixed certainty|forbidden pattern/i);
});

test('한마디 평가는 가볍고 긍정적인 장면을 말줄임표로 흐리지 않는다', () => {
  const cases = createCloudflareModelEvaluationCases();
  const scenarios = [
    {
      name: 'feedback_shared_laughter',
      lively: '둘이 웃기 시작하면 시계가 제일 먼저 퇴근하겠네!',
      trailing: '둘이 웃기 시작하면 시계가 제일 먼저 퇴근하겠네...',
    },
    {
      name: 'feedback_playful_food_difference',
      lively: '오늘 밤 메뉴판이 꽤 오래 고민하겠네!',
      trailing: '오늘 밤 메뉴판이 꽤 오래 고민하겠네...',
    },
    {
      name: 'feedback_shared_action_movie_stays_lively',
      lively: '영화 고를 때만큼은 둘의 고민이 오래 걸리지 않겠네!',
      trailing: '영화 고를 때만큼은 둘의 고민이 오래 걸리지 않겠네...',
    },
    {
      name: 'feedback_personalized_without_owner_exposure',
      lively: '이번 주 산책길에는 할 이야기가 한가득이겠네!',
      trailing: '이번 주 산책길에는 할 이야기가 한가득이겠네...',
    },
  ];

  for (const scenario of scenarios) {
    const evaluationCase = cases.find((item) => item.name === scenario.name);
    assert.ok(evaluationCase);
    assert.doesNotThrow(() => evaluationCase.validate({
      text: scenario.lively,
    }));
    assert.throws(() => evaluationCase.validate({
      text: scenario.trailing,
    }), /forbidden pattern/i);
  }
});

test('선제 추천 평가는 날씨 종류를 보존하고 자연스러운 장소 표현을 인정한다', () => {
  const cases = createCloudflareModelEvaluationCases();
  const hotWeather = cases.find(
    (item) => item.name === 'proactive_hot_weather_is_softened',
  );
  const rain = cases.find(
    (item) => item.name === 'proactive_rain_is_uncertain',
  );
  const snow = cases.find(
    (item) => item.name === 'proactive_snow_is_uncertain',
  );
  const coldWeather = cases.find(
    (item) => item.name === 'proactive_cold_weather_is_softened',
  );

  assert.ok(hotWeather);
  assert.ok(rain);
  assert.ok(snow);
  assert.ok(coldWeather);
  assert.doesNotThrow(() => hotWeather.validate({
    text: '오늘은 더울 것 같으니 근처 카페에서 잠깐 쉬는 건 어때',
    kind: 'date_idea',
  }));
  assert.throws(() => rain.validate({
    text: '눈이 올지도 모르니 가까운 실내에서 따뜻하게 쉬는 건 어때',
    kind: 'date_idea',
  }), /forbidden pattern/i);
  assert.throws(() => snow.validate({
    text: '비가 올지도 모르니 가까운 실내에서 따뜻하게 쉬는 건 어때',
    kind: 'date_idea',
  }), /forbidden pattern/i);
  assert.throws(() => coldWeather.validate({
    text: '가까운 공원으로 나가 천천히 산책하는 건 어때',
    kind: 'date_idea',
  }), /forbidden pattern/i);
  assert.doesNotThrow(() => coldWeather.validate({
    text: '천천히 걷는 걸 좋아하니까 오늘은 집에서 따뜻한 차 마시는 건 어때',
    kind: 'date_idea',
  }));
  const sunset = cases.find(
    (item) => item.name === 'proactive_sunset_card',
  );
  assert.ok(sunset);
  assert.throws(() => sunset.validate({
    text: '19:42 무렵 노을을 보며 사진 한 장 남겨 두면 어때?',
    kind: 'sunset_card',
  }), /raw context value|forbidden pattern/i);
});
