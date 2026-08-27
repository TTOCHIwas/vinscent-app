export type PersonalizedAnswerEvidenceKind =
  | 'intention_or_hypothetical'
  | 'preference'
  | 'reported_experience'
  | 'open_response';

export interface PersonalizedAnswerEvidence {
  kind: PersonalizedAnswerEvidenceKind;
  supports: string;
  doesNotSupport: string;
}

const intentionOrHypotheticalPattern =
  /(?:싶|원하|바라|계획|예정|만약|한다면|간다면|먹는다면|본다면|된다면|고른다면|선택한다면)/u;
const preferencePattern =
  /(?:좋아|선호|취향|편해|편한|고르|선택|어느\s*(?:쪽|게|것))/u;
const pastEventClausePattern =
  /(?:갔|왔|했|먹었|봤|보냈|만났|다녀왔|걸었|마셨|놀았|쉬었|찍었|만들었|받았|줬|샀|방문했|여행했)(?:을|던)\s*때/u;
const pastEventAttributivePattern =
  /(?:^|\s)(?:간|온|한|먹은|본|보낸|만난|다녀온|걸은|마신|논|쉰|찍은|만든|받은|준|산|방문한|여행한)\s+(?:곳|날|때|식당|카페|영화|활동|여행|데이트|선물|음식|메뉴|분위기|경험|기억)/u;
const pastEventPredicatePattern =
  /(?:갔|왔|했|먹었|봤|보냈|만났|다녀왔|걸었|마셨|놀았|쉬었|찍었|만들었|받았|줬|샀|방문했|여행했)(?:어|어요|지|는데|고)(?:\?|\s|$)/u;
const retrospectiveQuestionPattern =
  /(?:어땠어|뭐\s*했어|어디(?:에|서)?\s*갔어|무엇을\s*봤어|뭘\s*먹었어|기억(?:에\s*남|나)|좋았어|재밌었어|즐거웠어|였어)\?$/u;
const reportedExperiencePattern =
  /(?:기억(?:에\s*남|나)|지난(?:번|날|주|달)|최근(?:에)?[^?]{0,32}(?:갔|왔|했|먹었|봤|보냈|만났|다녀왔)|어땠어)/u;

export function classifyPersonalizedAnswerEvidence(
  sourceQuestion: string,
): PersonalizedAnswerEvidenceKind {
  if (intentionOrHypotheticalPattern.test(sourceQuestion)) {
    return 'intention_or_hypothetical';
  }
  if (
    pastEventClausePattern.test(sourceQuestion)
    || retrospectiveQuestionPattern.test(sourceQuestion)
    || reportedExperiencePattern.test(sourceQuestion)
  ) {
    return 'reported_experience';
  }
  if (preferencePattern.test(sourceQuestion)) {
    return 'preference';
  }
  return 'open_response';
}

export function describePersonalizedAnswerEvidence(
  sourceQuestion: string,
): PersonalizedAnswerEvidence {
  const kind = classifyPersonalizedAnswerEvidence(sourceQuestion);
  if (kind === 'intention_or_hypothetical') {
    return {
      kind,
      supports: 'desire, plan, or hypothetical preference only',
      doesNotSupport: 'that the activity already happened',
    };
  }
  if (kind === 'preference') {
    return {
      kind,
      supports: 'the directly stated preference only',
      doesNotSupport: 'that a specific event already happened',
    };
  }
  if (kind === 'reported_experience') {
    return {
      kind,
      supports: 'the reported experience and directly stated details',
      doesNotSupport: 'unstated event details, causes, or frequency',
    };
  }
  return {
    kind,
    supports: 'only content explicitly stated in each answer',
    doesNotSupport: 'an event, preference, or intention not directly stated',
  };
}

export function hasUnsupportedPastEventPresupposition(
  sourceQuestion: string,
  candidateQuestion: string,
): boolean {
  if (
    classifyPersonalizedAnswerEvidence(sourceQuestion)
      === 'reported_experience'
  ) {
    return false;
  }
  return pastEventClausePattern.test(candidateQuestion)
    || pastEventAttributivePattern.test(candidateQuestion)
    || pastEventPredicatePattern.test(candidateQuestion)
    || retrospectiveQuestionPattern.test(candidateQuestion);
}
