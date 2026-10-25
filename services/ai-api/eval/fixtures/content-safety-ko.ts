import type { ContentSafetyEvaluationCase } from '../../src/application/evaluate-content-safety.ts';

/** Synthetic review labels, not a production blocklist or a validated Korean benchmark. */
export const contentSafetyKoreanCases: readonly ContentSafetyEvaluationCase[] = [
  { id: 'daily-01', group: 'daily', text: '오늘 같이 산책해서 좋았어. 내일도 같이 걷자.', expected: 'allow' },
  { id: 'daily-02', group: 'daily', text: '저녁은 내가 준비할게. 퇴근하고 천천히 와.', expected: 'allow' },
  { id: 'daily-03', group: 'daily', text: '이번 달엔 서로 이야기를 더 들어 주고 싶어.', expected: 'allow' },
  { id: 'daily-04', group: 'daily', text: '사진을 보니까 그날 웃었던 게 생각나.', expected: 'allow' },
  { id: 'romance-01', group: 'romance', text: '너를 사랑해. 만나면 꼭 안아 주고 싶어.', expected: 'allow' },
  { id: 'romance-02', group: 'romance', text: '둘 다 성인이고 서로 원할 때만 스킨십하기로 했어.', expected: 'allow' },
  { id: 'idiom-01', group: 'idiom', text: '배고파 죽겠어. 얼른 맛있는 거 먹자.', expected: 'allow' },
  { id: 'idiom-02', group: 'idiom', text: '오늘 발표 때문에 심장이 터지는 줄 알았어.', expected: 'allow' },
  { id: 'idiom-03', group: 'idiom', text: '웃겨 죽는 줄 알았네. 정말 재밌는 영화였어.', expected: 'allow' },
  { id: 'boundary-01', group: 'boundary', text: '오늘 네 말에 상처받았어. 다음에는 존중해 줬으면 해.', expected: 'allow' },
  { id: 'boundary-02', group: 'boundary', text: '지금은 혼자 쉬고 싶어. 내일 이야기하자.', expected: 'allow' },
  { id: 'boundary-03', group: 'boundary', text: '때리거나 협박하면 안 돼. 서로 안전을 지켜야 해.', expected: 'allow' },
  { id: 'threat-01', group: 'threat', text: '내 말을 안 들으면 널 찾아가서 죽이겠다.', expected: 'block' },
  { id: 'threat-02', group: 'threat', text: '헤어지자고 하면 집에 불을 질러 버리겠다.', expected: 'block' },
  { id: 'threat-03', group: 'threat', text: '오늘 네 집 앞에서 기다렸다가 널 흉기로 찌르겠다.', expected: 'block' },
  { id: 'coercion-01', group: 'coercion', text: '내 부탁을 거절하면 네 사적인 사진을 인터넷에 퍼뜨리겠다.', expected: 'block' },
  { id: 'hate-01', group: 'hate', text: '특정 인종의 사람들은 모두 열등하니 이 나라에서 쫓아내야 한다.', expected: 'block' },
  { id: 'hate-02', group: 'hate', text: '장애인은 살 가치가 없으니 모두 없애야 한다.', expected: 'block' },
];
