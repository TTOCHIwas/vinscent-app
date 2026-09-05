export const appEventTypes = [
  'couple_setup_started',
  'couple_setup_completed',
  'couple_character_updated',
  'couple_reconnected',
  'ai_feedback_ready',
  'ai_memory_review_ready',
  'ai_personalization_activated',
  'ai_direct_answer_ready',
  'ai_direct_answer_failed',
  'ai_focused_partner_waiting',
] as const;

export type AppEventType = (typeof appEventTypes)[number];

export const appEventTypeSet = new Set<AppEventType>(appEventTypes);

export function notificationTypeFor(eventType: AppEventType) {
  return eventType.startsWith('ai_')
    ? 'ai_update' as const
    : 'couple_activity' as const;
}

export function preferenceColumnFor(eventType: AppEventType) {
  return eventType.startsWith('ai_')
    ? 'ai_updates_enabled' as const
    : 'couple_activity_enabled' as const;
}

export function notificationBodyFor(eventType: AppEventType) {
  switch (eventType) {
    case 'couple_setup_started':
      return '상대방이 우리 둘의 공간을 준비하고 있어.';
    case 'couple_setup_completed':
      return '우리 둘의 공간이 준비됐어.';
    case 'couple_character_updated':
      return '우리 캐릭터가 새롭게 바뀌었어.';
    case 'couple_reconnected':
      return '우리 둘의 연결이 다시 이어졌어.';
    case 'ai_feedback_ready':
      return '오늘 답변을 보고 한마디를 남겼어.';
    case 'ai_memory_review_ready':
      return '지금까지 알게 된 내용을 확인해 줘.';
    case 'ai_personalization_activated':
      return '이제 너희 둘을 조금 더 잘 알게 됐어.';
    case 'ai_direct_answer_ready':
      return '물어본 질문에 답을 준비했어';
    case 'ai_direct_answer_failed':
      return '이번에는 답을 준비하지 못했어... 다시 물어봐 줘';
    case 'ai_focused_partner_waiting':
      return '상대방이 질문을 모두 마쳤어, 편할 때 이어서 답해 줘';
  }
}

export function routeFor(eventType: AppEventType, assignedDate: unknown) {
  if (eventType === 'ai_feedback_ready') {
    return typeof assignedDate === 'string'
      ? `/home/question?date=${encodeURIComponent(assignedDate)}`
      : '/home/question';
  }

  if (eventType === 'ai_memory_review_ready') {
    return '/ai/memories';
  }

  if (eventType.startsWith('ai_')) {
    return '/ai';
  }

  return '/home';
}
