export type KoreanQuestionNaturalnessIssueCode =
  | 'formal_translationese'
  | 'predicate_mismatch';

export interface KoreanQuestionNaturalnessIssue {
  code: KoreanQuestionNaturalnessIssueCode;
  reference:
    | 'im-not-ai:A-3'
    | 'im-not-ai:A-5'
    | 'im-not-ai:A-6'
    | 'im-not-ai:A-8'
    | 'im-not-ai:A-9'
    | 'danjjan:predicate-object';
  span: string;
  start: number;
  end: number;
}

interface KoreanQuestionNaturalnessRule {
  code: KoreanQuestionNaturalnessIssueCode;
  reference: KoreanQuestionNaturalnessIssue['reference'];
  pattern: RegExp;
}

const questionNaturalnessRules: readonly KoreanQuestionNaturalnessRule[] = [
  translationese('im-not-ai:A-3', /에\s*있어서/u),
  translationese('im-not-ai:A-5', /(?:와|과)\s*관련(?:하여|해서)/u),
  translationese(
    'im-not-ai:A-6',
    /(?:에\s*기반(?:하여|해서)|(?:을|를)\s*바탕으로)/u,
  ),
  translationese('im-not-ai:A-8', /되어진/u),
  translationese('im-not-ai:A-9', /에\s*의해/u),
  predicateMismatch(
    /해\s*보고\s*싶은\s*(?:영화|드라마|영상|노래|음악|책|공연|선물|메뉴|음식)/u,
  ),
  predicateMismatch(
    /(?<!해)(?<!해\s)보고\s*싶은\s*(?:활동|경험|도전|데이트|취미|놀이)/u,
  ),
  predicateMismatch(
    /가\s*보고\s*싶은\s*(?:영화|드라마|영상|노래|음악|책|공연|선물|메뉴|음식)/u,
  ),
];

export function findKoreanQuestionNaturalnessIssue(
  question: string,
): KoreanQuestionNaturalnessIssue | null {
  for (const rule of questionNaturalnessRules) {
    const match = rule.pattern.exec(question);
    if (match !== null) {
      return {
        code: rule.code,
        reference: rule.reference,
        span: match[0],
        start: match.index,
        end: match.index + match[0].length,
      };
    }
  }
  return null;
}

function translationese(
  reference: Extract<
    KoreanQuestionNaturalnessIssue['reference'],
    `im-not-ai:${string}`
  >,
  pattern: RegExp,
): KoreanQuestionNaturalnessRule {
  return { code: 'formal_translationese', reference, pattern };
}

function predicateMismatch(pattern: RegExp): KoreanQuestionNaturalnessRule {
  return {
    code: 'predicate_mismatch',
    reference: 'danjjan:predicate-object',
    pattern,
  };
}
