interface SharedMemoryEvidence {
  questionText: string;
  statement: string;
  answerTexts: string[];
}

const weakEvidencePhrases = [
  '가장',
  '각자',
  '같아',
  '그냥',
  '느낌',
  '둘 다',
  '둘이',
  '마음',
  '먼저',
  '방식',
  '서로',
  '소중하게',
  '소중해',
  '순간',
  '시간',
  '요즘',
  '우리',
  '원해',
  '정말',
  '조금',
  '좋아',
  '중요하게',
  '중요해',
  '편안해',
  '편해',
  '필요해',
  '하고 싶어',
  '하루',
  '함께',
];

const weakEvidenceAnchors = extractLexicalAnchors(
  weakEvidencePhrases.join(' '),
);

export function hasSharedMemoryEvidence(
  evidence: SharedMemoryEvidence,
): boolean {
  if (evidence.answerTexts.length < 2) {
    return false;
  }

  const questionAnchors = extractLexicalAnchors(evidence.questionText);
  const statementAnchors = extractLexicalAnchors(evidence.statement);
  const answerAnchors = evidence.answerTexts.map(extractLexicalAnchors);

  for (const anchor of statementAnchors) {
    if (
      weakEvidenceAnchors.has(anchor)
      || questionAnchors.has(anchor)
    ) {
      continue;
    }
    if (answerAnchors.every((anchors) => anchors.has(anchor))) {
      return true;
    }
  }

  return false;
}

function extractLexicalAnchors(value: string): Set<string> {
  const anchors = new Set<string>();
  const tokens = value
    .normalize('NFKC')
    .toLocaleLowerCase('ko-KR')
    .match(/[\p{L}\p{N}]+/gu) ?? [];

  for (const token of tokens) {
    const characters = Array.from(token);
    if (characters.length < 2) {
      continue;
    }
    if (!/^\p{Script=Hangul}+$/u.test(token)) {
      anchors.add(token);
      continue;
    }

    const maximumLength = Math.min(4, characters.length);
    for (let length = 2; length <= maximumLength; length += 1) {
      for (
        let start = 0;
        start + length <= characters.length;
        start += 1
      ) {
        anchors.add(characters.slice(start, start + length).join(''));
      }
    }
  }

  return anchors;
}
