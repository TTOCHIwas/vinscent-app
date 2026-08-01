const tokenPattern = /[\p{Letter}\p{Number}]+/gu;
const particleSuffixPattern =
  /(?:에서는|에게서는|한테서는|으로부터|에서부터|에게|한테|으로|까지|부터|보다|처럼|에서|하고|이랑|과|와|랑|은|는|이|가|을|를|에|의|도|만)$/u;
const predicateSuffixPattern =
  /(?:하면서|하거나|하려고|하는|했던|하게|해서|되는|되어|이면|이라면|이며|이고|인데|인지|였던|느라고|도록|다가|거나|려는|려면|라고|라는|던|고|어|아)$/u;
const ignoredTerms = new Set([
  '가장',
  '거',
  '게',
  '걸',
  '건',
  '것',
  '곳',
  '그',
  '날',
  '더',
  '둘',
  '뭐',
  '뭐야',
  '뭘',
  '사람',
  '상대',
  '상대방',
  '싶',
  '때',
  '어느',
  '어디',
  '어떤',
  '언제',
  '왜',
  '이번',
  '있',
  '중',
  '쪽',
  '파트너',
  '하',
]);
const weakRelationTerms = new Set([
  '내일',
  '어제',
  '오늘',
  '우리',
  '요즘',
  '최근',
  '평소',
  '함께',
]);

export function preservesQuestionScope(
  sourceQuestion: string,
  candidateQuestion: string,
): boolean {
  const sourceTerms = questionScopeTerms(sourceQuestion);
  if (sourceTerms.size < 2) {
    return true;
  }

  const candidateTerms = questionScopeTerms(candidateQuestion);
  const preservedCount = [...sourceTerms].filter(
    (term) => candidateTerms.has(term),
  ).length;
  const requiredCount = sourceTerms.size <= 4
    ? sourceTerms.size
    : Math.ceil(sourceTerms.size * 0.67);

  return preservedCount >= requiredCount;
}

export function questionsShareScope(
  left: string,
  right: string,
): boolean {
  return sharedQuestionScopeTerms(left, right).size > 0;
}

export function hasExplicitScopePolarityConflict(
  left: string,
  right: string,
): boolean {
  const sharedTerms = sharedQuestionScopeTerms(left, right);
  if (sharedTerms.size === 0) {
    return false;
  }

  const leftPolarities = scopeTermPolarities(left);
  const rightPolarities = scopeTermPolarities(right);

  return [...sharedTerms].some((term) => {
    const leftPolarity = leftPolarities.get(term);
    const rightPolarity = rightPolarities.get(term);
    return (
      (leftPolarity === 'positive' && rightPolarity === 'negative')
      || (leftPolarity === 'negative' && rightPolarity === 'positive')
    );
  });
}

function sharedQuestionScopeTerms(left: string, right: string): Set<string> {
  const leftTerms = questionScopeTerms(left);
  const rightTerms = questionScopeTerms(right);
  return new Set([...leftTerms].filter((term) => (
    rightTerms.has(term) && !weakRelationTerms.has(term)
  )));
}

function questionScopeTerms(value: string): Set<string> {
  const tokens = value
    .normalize('NFKC')
    .toLowerCase()
    .match(tokenPattern) ?? [];

  return new Set(tokens.map(canonicalScopeTerm).filter(Boolean));
}

function canonicalScopeTerm(value: string): string {
  if (/^(?:밖|바깥|나가|외출)/u.test(value)) {
    return '밖';
  }

  let normalized = value;
  let previous = '';
  while (previous !== normalized) {
    previous = normalized;
    normalized = normalized.replace(particleSuffixPattern, '');
  }
  normalized = normalized.replace(predicateSuffixPattern, '');

  if (
    normalized.length === 0
    || ignoredTerms.has(normalized)
    || /^(?:좋|선호|취향|고르|선택|궁금|생각|싶)/u.test(normalized)
  ) {
    return '';
  }
  if (/^(?:해외여행|해외)/u.test(normalized)) {
    return '해외';
  }
  if (/^(?:국내여행|국내)/u.test(normalized)) {
    return '국내';
  }
  if (/^(?:여행지|여행)/u.test(normalized)) {
    return '여행';
  }
  if (/^(?:계획|일정|준비)/u.test(normalized)) {
    return '계획';
  }
  if (/^(?:요리|메뉴|음식)/u.test(normalized)) {
    return '요리';
  }
  if (/^(?:잘|자신|능숙)/u.test(normalized)) {
    return '실력';
  }
  if (/^(?:느긋|늦|여유)/u.test(normalized)) {
    return '느긋';
  }
  if (/^(?:밖|바깥|나가|외출)/u.test(normalized)) {
    return '밖';
  }
  if (/^쉬/u.test(normalized)) {
    return '휴식';
  }
  if (/^움직/u.test(normalized)) {
    return '움직임';
  }
  if (/^실용/u.test(normalized)) {
    return '실용';
  }
  if (/^의미/u.test(normalized)) {
    return '의미';
  }
  if (/^선물/u.test(normalized)) {
    return '선물';
  }
  if (/^기념일/u.test(normalized)) {
    return '기념일';
  }
  if (/^아침/u.test(normalized)) {
    return '아침';
  }
  if (/^일찍/u.test(normalized)) {
    return '일찍';
  }
  if (/^집/u.test(normalized)) {
    return '집';
  }

  return normalized;
}

type ScopeTermPolarity = 'positive' | 'negative';

function scopeTermPolarities(value: string): Map<string, ScopeTermPolarity> {
  const normalized = value.normalize('NFKC').toLowerCase();
  const result = new Map<string, ScopeTermPolarity>();

  for (const match of normalized.matchAll(tokenPattern)) {
    const rawTerm = match[0];
    const term = canonicalScopeTerm(rawTerm);
    if (term.length === 0 || match.index === undefined) {
      continue;
    }

    const start = Math.max(0, match.index - 20);
    const end = Math.min(
      normalized.length,
      match.index + rawTerm.length + 20,
    );
    const window = normalized.slice(start, end);
    if (/(?:없|없이|아니|안\s|않|싫|별로|무계획|즉흥)/u.test(window)) {
      result.set(term, 'negative');
      continue;
    }
    if (/(?:좋아|선호|원하|중요|꼼꼼|미리|자주|편이)/u.test(window)) {
      result.set(term, 'positive');
    }
  }

  return result;
}
