import assert from 'node:assert/strict';
import test from 'node:test';

import {
  createAiLearningModel,
  defaultAiModelName,
} from '../../../supabase/functions/_shared/ai_learning_model.ts';

const mistralModel = '@cf/mistralai/mistral-small-3.1-24b-instruct';

test('AI Edge composition defaults to the selected Mistral model', () => {
  assert.equal(defaultAiModelName, mistralModel);

  const runtime = createAiLearningModel({
    readEnvironment: (name) => ({
      CLOUDFLARE_ACCOUNT_ID: '0123456789abcdef0123456789abcdef',
      CLOUDFLARE_WORKERS_AI_API_TOKEN: 'test-api-token',
    })[name],
  });

  assert.equal(runtime.provider, 'cloudflare');
  assert.equal(runtime.modelName, mistralModel);
});

test('AI Edge composition preserves an explicit model override', () => {
  const override = '@cf/qwen/qwen3-30b-a3b-fp8';
  const runtime = createAiLearningModel({
    readEnvironment: (name) => ({
      CLOUDFLARE_ACCOUNT_ID: '0123456789abcdef0123456789abcdef',
      CLOUDFLARE_WORKERS_AI_API_TOKEN: 'test-api-token',
      CLOUDFLARE_WORKERS_AI_MODEL: override,
    })[name],
  });

  assert.equal(runtime.modelName, override);
});
