import { containsBlockedAiTopic } from './learning-contract.ts';

const internalContextExtractionPattern = new RegExp(
  [
    '(?:이전|앞선|기존)\\s*(?:지시|명령).{0,20}(?:무시|잊어)',
    '(?:system\\s*prompt|시스템\\s*프롬프트)',
    'confirmed_profile',
    'memory_key',
    '내부\\s*(?:키|프로필|프롬프트|지시|명령)',
    '(?:프롬프트|프로필).{0,20}(?:원문|전부|그대로).{0,20}(?:보여|출력|공개)',
  ].join('|'),
  'iu',
);

export function resolveDirectQuestionRefusal(
  questionText: string,
): string | null {
  if (internalContextExtractionPattern.test(questionText)) {
    return '그 요청에는 답할 수 없어';
  }
  if (containsBlockedAiTopic(questionText)) {
    return '그건 답변만으로 판단할 수 없어';
  }
  return null;
}
