import {
  DiscordWebhookClient,
  DiscordWebhookRequestError,
} from '../_shared/discord_webhook.ts';
import {
  type ClaimedSafetyModerationAlert,
  type SafetyModerationAlertDelivery,
  SafetyModerationDeliveryError,
} from './safety_moderation_alert_contract.ts';

type DiscordSafetyModerationAlertDeliveryOptions = {
  endpoint: string;
  timeoutMs?: number;
  fetchImpl?: typeof fetch;
};

const targetLabels: Record<string, string> = {
  partner: '상대방',
  story_card: '카드',
  question_answer: '질문 답변',
  recording: '녹음',
  calendar_event: '일정',
  character: '캐릭터',
  ai_question: 'AI 질문',
  ai_feedback: 'AI 한마디',
  ai_direct_answer: 'AI 답변',
  ai_proactive_suggestion: 'AI 추천',
  ai_memory: 'AI 기억',
};

const reasonLabels: Record<string, string> = {
  inappropriate: '부적절한 콘텐츠',
  harassment: '괴롭힘',
  privacy: '개인정보 침해',
  spam: '스팸',
  unsafe_ai: '안전하지 않은 AI 응답',
  other: '기타',
};

export class DiscordSafetyModerationAlertDelivery
  implements SafetyModerationAlertDelivery {
  readonly #client: DiscordWebhookClient;

  constructor(options: DiscordSafetyModerationAlertDeliveryOptions) {
    this.#client = new DiscordWebhookClient(options);
  }

  async deliver(alert: ClaimedSafetyModerationAlert): Promise<void> {
    try {
      await this.#client.send(buildDiscordPayload(alert));
    } catch (error) {
      throw new SafetyModerationDeliveryError(
        moderationErrorCode(error),
      );
    }
  }
}

function buildDiscordPayload(alert: ClaimedSafetyModerationAlert) {
  return {
    username: '단짠 안전 신고',
    allowed_mentions: { parse: [] },
    embeds: [{
      title: '새로운 신고가 접수됐어요',
      description: '관리자 화면에서 신고 내용을 확인해 주세요',
      color: 0xDC_69_57,
      fields: [
        {
          name: '대상',
          value: targetLabels[alert.targetType] ?? alert.targetType,
          inline: true,
        },
        {
          name: '사유',
          value: reasonLabels[alert.reason] ?? alert.reason,
          inline: true,
        },
        {
          name: '상세 내용',
          value: alert.hasDetails ? '있음' : '없음',
          inline: true,
        },
        {
          name: '콘텐츠 보관본',
          value: alert.hasContentSnapshot ? '있음' : '없음',
          inline: true,
        },
      ],
      footer: {
        text: `신고 ID ${alert.reportId}`,
      },
      timestamp: alert.reportCreatedAt,
    }],
  };
}

function moderationErrorCode(error: unknown) {
  if (error instanceof DiscordWebhookRequestError) {
    return switchDiscordErrorCode(error.kind);
  }
  return 'moderation_webhook_unavailable';
}

function switchDiscordErrorCode(
  kind: DiscordWebhookRequestError['kind'],
) {
  switch (kind) {
    case 'rate_limited':
      return 'moderation_webhook_rate_limited';
    case 'rejected':
      return 'moderation_webhook_rejected';
    case 'unavailable':
      return 'moderation_webhook_unavailable';
  }
}
