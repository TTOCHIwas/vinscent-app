import assert from 'node:assert/strict';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

import {
  inspectRuntimeEnvironment,
  loadRuntimeEnvironmentManifest,
  validateRuntimeEnvironmentManifest,
} from '../../../scripts/lib/supabase-runtime-environment.mjs';

const repositoryRoot = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  '../../..',
);

test('runtime environment manifest matches every Edge Function usage', async () => {
  const manifest = await loadRuntimeEnvironmentManifest(repositoryRoot);
  const inventory = await inspectRuntimeEnvironment(repositoryRoot);

  assert.deepEqual(
    validateRuntimeEnvironmentManifest(manifest, inventory),
    [],
  );
});

test('runtime environment validator rejects undocumented usage', async () => {
  const manifest = await loadRuntimeEnvironmentManifest(repositoryRoot);
  const inventory = await inspectRuntimeEnvironment(repositoryRoot);
  const undocumentedInventory = {
    ...inventory,
    entries: [
      ...inventory.entries,
      {
        name: 'UNDOCUMENTED_RUNTIME_VALUE',
        functions: [inventory.entrypoints[0]],
      },
    ].sort((left, right) => left.name.localeCompare(right.name)),
  };

  assert.ok(
    validateRuntimeEnvironmentManifest(
      manifest,
      undocumentedInventory,
    ).some((error) =>
      error.includes(
        'undocumented environment names: UNDOCUMENTED_RUNTIME_VALUE',
      )
    ),
  );
});

test('runtime environment validator rejects untraceable dynamic access', async () => {
  const manifest = await loadRuntimeEnvironmentManifest(repositoryRoot);
  const inventory = await inspectRuntimeEnvironment(repositoryRoot);

  assert.ok(
    validateRuntimeEnvironmentManifest(manifest, {
      ...inventory,
      dynamicReferences: ['supabase/functions/example/index.ts'],
    }).some((error) =>
      error.includes(
        'dynamic environment references outside the shared reader',
      )
    ),
  );
});
