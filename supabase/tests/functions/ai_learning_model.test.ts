import assert from 'node:assert/strict';
import test from 'node:test';

import {
  createAiLearningModel,
  defaultAiModelName,
} from '../../functions/_shared/ai_learning_model.ts';
import {
  StructuredLearningModel,
} from '../../../services/ai-api/src/application/structured-learning-model.ts';

const accountId = '0123456789abcdef0123456789abcdef';

test('AI Edge Functions share the Mistral production model by default', () => {
  const runtime = createAiLearningModel({
    readEnvironment: environmentReader({
      CLOUDFLARE_ACCOUNT_ID: accountId,
      CLOUDFLARE_WORKERS_AI_API_TOKEN: 'test-token',
    }),
  });

  assert.equal(
    defaultAiModelName,
    '@cf/mistralai/mistral-small-3.1-24b-instruct',
  );
  assert.equal(runtime.provider, 'cloudflare');
  assert.equal(runtime.modelName, defaultAiModelName);
  assert.equal(runtime.model instanceof StructuredLearningModel, true);
});

test('AI model composition accepts an explicit Cloudflare model and timeout', () => {
  const runtime = createAiLearningModel({
    readEnvironment: environmentReader({
      CLOUDFLARE_ACCOUNT_ID: accountId,
      CLOUDFLARE_WORKERS_AI_API_TOKEN: 'test-token',
      CLOUDFLARE_WORKERS_AI_MODEL: '@cf/test/model',
    }),
    timeoutMs: 15_000,
  });

  assert.equal(runtime.modelName, '@cf/test/model');
});

test('AI model composition requires Cloudflare credentials', () => {
  assert.throws(
    () => createAiLearningModel({
      readEnvironment: environmentReader({
        CLOUDFLARE_ACCOUNT_ID: accountId,
      }),
    }),
    /missing_env:CLOUDFLARE_WORKERS_AI_API_TOKEN/,
  );
});

function environmentReader(
  values: Record<string, string>,
): (name: string) => string | undefined {
  return (name) => values[name];
}
