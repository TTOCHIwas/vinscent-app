import {
  DiscordWebhookClient,
  DiscordWebhookRequestError,
} from '../_shared/discord_webhook.ts';
import {
  type ClaimedStorageCleanupAlert,
  type StorageCleanupAlertDelivery,
  StorageCleanupAlertDeliveryError,
  type StorageCleanupIssueCode,
} from './storage_cleanup_alert_contract.ts';

type DiscordStorageCleanupAlertDeliveryOptions = {
  endpoint: string;
  timeoutMs?: number;
  fetchImpl?: typeof fetch;
};

const issueLabels: Record<StorageCleanupIssueCode, string> = {
  failed_requests: '최종 실패 요청 존재',
  stale_processing: '10분 이상 processing 상태',
  overdue_pending: '60분 이상 처리되지 않은 pending 상태',
  cleanup_cron_missing: '정리 Cron 없음',
  cleanup_cron_duplicate: '정리 Cron 중복',
  cleanup_cron_inactive: '정리 Cron 비활성',
  cleanup_cron_schedule_mismatch: '정리 Cron 주기 불일치',
  cleanup_cron_never_succeeded: '정리 Cron 성공 기록 없음',
  cleanup_cron_stale: '정리 Cron 최근 성공 지연',
};

export class DiscordStorageCleanupAlertDelivery
  implements StorageCleanupAlertDelivery {
  readonly #client: DiscordWebhookClient;

  constructor(options: DiscordStorageCleanupAlertDeliveryOptions) {
    this.#client = new DiscordWebhookClient(options);
  }

  async deliver(alert: ClaimedStorageCleanupAlert): Promise<void> {
    try {
      await this.#client.send(buildDiscordPayload(alert));
    } catch (error) {
      throw storageCleanupDeliveryError(error);
    }
  }
}

function buildDiscordPayload(alert: ClaimedStorageCleanupAlert) {
  const recovered = alert.alertKind === 'recovered';
  return {
    username: '단짠 운영 알림',
    allowed_mentions: { parse: [] },
    embeds: [{
      title: recovered
        ? 'Storage 정리 상태 복구'
        : 'Storage 정리 상태 이상',
      description: recovered
        ? 'Storage 정리 작업이 정상 상태로 돌아왔습니다'
        : 'Storage 정리 작업에 운영자 확인이 필요합니다',
      color: recovered ? 0x3B_82_F6 : 0xDC_26_26,
      fields: [
        {
          name: recovered ? '해결된 항목' : '감지 항목',
          value: alert.issueCodes.map((code) => issueLabels[code]).join('\n'),
          inline: false,
        },
        {
          name: '최종 실패',
          value: String(alert.failedRequestCount),
          inline: true,
        },
        {
          name: '지연 processing',
          value: String(alert.staleProcessingCount),
          inline: true,
        },
        {
          name: '지연 pending',
          value: String(alert.overduePendingCount),
          inline: true,
        },
        {
          name: '정리 Cron',
          value: alert.cleanupCronStatus,
          inline: true,
        },
        {
          name: 'Cron 마지막 성공',
          value: alert.cleanupCronLastSucceededAt ?? '기록 없음',
          inline: true,
        },
        {
          name: '장애 시작',
          value: alert.incidentStartedAt,
          inline: true,
        },
      ],
      footer: {
        text: `incident ${alert.incidentId}`,
      },
      timestamp: alert.detectedAt,
    }],
  };
}

function storageCleanupDeliveryError(error: unknown) {
  if (!(error instanceof DiscordWebhookRequestError)) {
    return new StorageCleanupAlertDeliveryError(
      'discord_webhook_unavailable',
      { retryable: true },
    );
  }

  return new StorageCleanupAlertDeliveryError(
    `discord_webhook_${error.kind}`,
    {
      retryable: error.kind !== 'rejected',
      retryAfterSeconds: error.retryAfterSeconds,
    },
  );
}
