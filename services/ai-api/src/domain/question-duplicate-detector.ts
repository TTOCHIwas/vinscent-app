const questionWordPrefixPattern =
  /^(?:뭐|무엇|어떤|어디|언제|왜|어떻게)/u;
const preferencePrefixPattern = /^(?:좋|선호|취향|편하|편해|고르|선택)/u;
const particleSuffixPattern =
  /(?:에서는|에는|에서|에게|한테|으로|이랑|까지|부터|보다|처럼|하고|과|와|랑|은|는|이|가|을|를|에|의|도|만)$/u;
const predicateSuffixPattern =
  /(?:하면서|하거나|하려고|하는|했던|하게|해서|되는|되어|된|될|이면|이라면|이며|이고|인데|인지|였|던|고|어)$/u;
const comparisonStopWords = new Set([
  '가장',
  '거',
  '게',
  '걸',
  '건',
  '것',
  '더',
  '다음',
  '방식',
  '사람',
  '상대',
  '상대방',
  '스타일',
  '이번',
  '정도',
  '중',
  '쪽',
  '파트너',
  '편',
  '하',
]);
const topicStopWords = new Set([
  ...comparisonStopWords,
  '같이',
  '갈',
  '기분',
  '둘',
  '때',
  '받고',
  '보고',
  '보러',
  '볼',
  '새로',
  '서로',
  '선호',
  '시간',
  '싶',
  '어떤',
  '어때',
  '요즘',
  '이번',
  '주고',
  '주말',
  '평소',
  '하고',
  '함께',
  '해보',
]);

export function areQuestionsNearDuplicate(
  left: string,
  right: string,
): boolean {
  if (normalizeQuestionSurface(left) === normalizeQuestionSurface(right)) {
    return true;
  }

  const leftTerms = canonicalQuestionTerms(left);
  const rightTerms = canonicalQuestionTerms(right);
  if (leftTerms.size < 3 || leftTerms.size !== rightTerms.size) {
    return false;
  }
  return [...leftTerms].every((term) => rightTerms.has(term));
}

export function areQuestionsAboutSameTopic(
  left: string,
  right: string,
): boolean {
  if (areQuestionsNearDuplicate(left, right)) {
    return true;
  }

  const leftTerms = questionTopicTerms(left);
  const rightTerms = questionTopicTerms(right);
  if (leftTerms.size === 0 || rightTerms.size === 0) {
    return false;
  }
  return [...leftTerms].some((term) => rightTerms.has(term));
}

export function buildQuestionSemanticFocus(value: string): string {
  const terms = [...questionTopicTerms(value)];
  return terms.length === 0
    ? value.normalize('NFKC').trim()
    : terms.join(' ');
}

function normalizeQuestionSurface(value: string): string {
  return value
    .normalize('NFKC')
    .toLowerCase()
    .replace(/[^\p{Letter}\p{Number}]/gu, '');
}

function canonicalQuestionTerms(value: string): Set<string> {
  const normalized = value
    .normalize('NFKC')
    .toLowerCase()
    .replace(/아침형\s*인간(?:으로|은|이|을)?/gu, '아침 일찍')
    .replace(/저녁형\s*인간(?:으로|은|이|을)?/gu, '느긋하게')
    .replace(/늦게/gu, '느긋하게');
  const tokens = normalized.match(/[\p{Letter}\p{Number}]+/gu) ?? [];
  return new Set(tokens.map(canonicalQuestionTerm).filter(isQuestionTerm));
}

function canonicalQuestionTerm(value: string): string {
  if (questionWordPrefixPattern.test(value)) {
    return '';
  }
  if (preferencePrefixPattern.test(value)) {
    return '선호';
  }

  let normalized = value;
  let previous = '';
  while (previous !== normalized) {
    previous = normalized;
    normalized = normalized.replace(particleSuffixPattern, '');
  }
  normalized = normalized.replace(predicateSuffixPattern, '');

  if (preferencePrefixPattern.test(normalized)) {
    return '선호';
  }
  if (/^싶/u.test(normalized)) {
    return '싶';
  }
  return normalized;
}

function isQuestionTerm(value: string): boolean {
  return value.length > 0 && !comparisonStopWords.has(value);
}

function questionTopicTerms(value: string): Set<string> {
  return new Set(
    [...canonicalQuestionTerms(value)].filter((term) =>
      term.length >= 2 && !topicStopWords.has(term)
    ),
  );
}
