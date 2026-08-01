import type {
  DirectQuestionAnswer,
  DirectQuestionContext,
  PersonalizationRecentQuestionContext,
} from './learning-contract.ts';
import {
  hasExplicitScopePolarityConflict,
  questionsShareScope,
} from './question-scope-preservation.ts';

export type DirectQuestionResponseSemantics =
  | 'explicit_unknown'
  | 'explicit_none'
  | 'substantive';

export function classifyDirectQuestionResponse(
  value: string,
): DirectQuestionResponseSemantics {
  const normalized = value
    .trim()
    .replace(/[.!?…]+$/u, '')
    .replace(/\s+/gu, ' ');

  if (
    /^(?:아직(?:은)?\s*)?(?:잘\s*)?(?:몰라|모름|모르겠(?:어|다|음)?)$/u
      .test(normalized)
  ) {
    return 'explicit_unknown';
  }
  if (
    /^(?:아직(?:은)?\s*)?(?:딱히\s*)?(?:(?:그런\s*)?건\s*)?없(?:어|다|음)$/u
      .test(normalized)
    || /^없는\s*것\s*같(?:아|다)$/u.test(normalized)
  ) {
    return 'explicit_none';
  }
  return 'substantive';
}

export function reconcileDirectQuestionAnswer(
  context: DirectQuestionContext,
  candidate: DirectQuestionAnswer,
): DirectQuestionAnswer {
  if (!targetsPartner(context.questionText)) {
    return candidate;
  }

  if (candidate.status === 'insufficient') {
    return reconcileExplicitResponse(context, candidate);
  }
  if (hasConflictingPartnerEvidence(context)) {
    return {
      status: 'insufficient',
      text: '최근 답과 확인된 기억이 서로 달라서 지금은 확실히 말하기 어려워',
      followUpQuestion: null,
    };
  }
  return candidate;
}

function reconcileExplicitResponse(
  context: DirectQuestionContext,
  candidate: DirectQuestionAnswer,
): DirectQuestionAnswer {
  const relevantQuestions = context.recentCompletedQuestions.filter(
    (question) => questionsShareScope(
      context.questionText,
      question.questionText,
    ),
  );
  const partnerSemantics = relevantQuestions.flatMap((question) => (
    question.answers
      .filter((answer) => answer.subject === 'partner')
      .map((answer) => classifyDirectQuestionResponse(answer.text))
  ));

  if (partnerSemantics.includes('substantive')) {
    return candidate;
  }
  if (partnerSemantics.includes('explicit_unknown')) {
    return {
      status: 'answered',
      text: '상대방도 아직 잘 모르겠다고 했어',
      followUpQuestion: null,
    };
  }
  if (partnerSemantics.includes('explicit_none')) {
    return {
      status: 'answered',
      text: '상대방은 딱히 없다고 했어',
      followUpQuestion: null,
    };
  }
  return candidate;
}

function hasConflictingPartnerEvidence(
  context: DirectQuestionContext,
): boolean {
  const memories = context.confirmedMemories.filter((memory) => (
    memory.subject === 'partner'
    && questionsShareScope(context.questionText, memory.statement)
  ));
  if (memories.length === 0) {
    return false;
  }

  const recentAnswers = context.recentCompletedQuestions.flatMap(
    (question) => relatedSubstantivePartnerAnswers(context, question),
  );
  return memories.some((memory) => recentAnswers.some((answer) => (
    hasExplicitScopePolarityConflict(memory.statement, answer)
  )));
}

function relatedSubstantivePartnerAnswers(
  context: DirectQuestionContext,
  question: PersonalizationRecentQuestionContext,
): string[] {
  return question.answers
    .filter((answer) => (
      answer.subject === 'partner'
      && classifyDirectQuestionResponse(answer.text) === 'substantive'
      && (
        questionsShareScope(context.questionText, question.questionText)
        || questionsShareScope(context.questionText, answer.text)
      )
    ))
    .map((answer) => answer.text);
}

function targetsPartner(questionText: string): boolean {
  return /(?:상대방|상대|파트너|애인|연인|남자친구|여자친구|남친|여친)(?:은|는|이|가|을|를|의|에게|도|과|와)?(?=$|[\s,.!?…])/u
    .test(questionText);
}
