import {
  optionalEnv,
  readDenoEnvironment,
  requiredEnv,
  type EnvironmentReader,
} from '../_shared/environment.ts';
import {
  DiscordSafetyModerationAlertDelivery,
} from './discord_safety_moderation_alert_delivery.ts';
import type {
  SafetyModerationAlertDelivery,
} from './safety_moderation_alert_contract.ts';
import {
  SafetyModerationWebhookDelivery,
} from './safety_moderation_webhook_delivery.ts';

type CreateSafetyModerationAlertDeliveryOptions = {
  readEnvironment?: EnvironmentReader;
  fetchImpl?: typeof fetch;
};

export function createSafetyModerationAlertDelivery(
  options: CreateSafetyModerationAlertDeliveryOptions = {},
): SafetyModerationAlertDelivery {
  const readEnvironment = options.readEnvironment ?? readDenoEnvironment;
  const discordEndpoint = optionalEnv(
    'SAFETY_MODERATION_DISCORD_WEBHOOK_URL',
    readEnvironment,
  );

  if (discordEndpoint !== undefined) {
    return new DiscordSafetyModerationAlertDelivery({
      endpoint: discordEndpoint,
      fetchImpl: options.fetchImpl,
    });
  }

  return new SafetyModerationWebhookDelivery({
    endpoint: requiredEnv(
      'SAFETY_MODERATION_WEBHOOK_URL',
      readEnvironment,
    ),
    bearerToken: optionalEnv(
      'SAFETY_MODERATION_WEBHOOK_BEARER_TOKEN',
      readEnvironment,
    ),
    fetchImpl: options.fetchImpl,
  });
}
