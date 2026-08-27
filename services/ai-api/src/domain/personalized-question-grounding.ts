export const personalizedQuestionGroundingReasonCodes = [
  'no_completed_event',
  'answers_confirm_same_event',
  'answers_do_not_confirm_event',
  'answers_contradict_event',
  'different_event',
] as const;

export type PersonalizedQuestionGroundingReasonCode =
  typeof personalizedQuestionGroundingReasonCodes[number];

export interface PersonalizedQuestionGroundingDecision {
  supported: boolean;
  reasonCode: PersonalizedQuestionGroundingReasonCode;
}

const supportedReasonCodes = new Set<
  PersonalizedQuestionGroundingReasonCode
>([
  'no_completed_event',
  'answers_confirm_same_event',
]);

export function isConsistentPersonalizedQuestionGroundingDecision(
  decision: PersonalizedQuestionGroundingDecision,
): boolean {
  return decision.supported === supportedReasonCodes.has(decision.reasonCode);
}
