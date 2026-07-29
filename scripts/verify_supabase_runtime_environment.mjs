import path from 'node:path';

import {
  inspectRuntimeEnvironment,
  loadRuntimeEnvironmentManifest,
  validateRuntimeEnvironmentManifest,
} from './lib/supabase-runtime-environment.mjs';

const repositoryRoot = path.resolve(import.meta.dirname, '..');
const manifest = await loadRuntimeEnvironmentManifest(repositoryRoot);
const inventory = await inspectRuntimeEnvironment(repositoryRoot);
const errors = validateRuntimeEnvironmentManifest(manifest, inventory);

if (errors.length > 0) {
  console.error('Supabase runtime environment validation failed:');
  for (const error of errors) {
    console.error(`- ${error}`);
  }
  process.exitCode = 1;
} else {
  console.log(
    `Validated ${inventory.entries.length} runtime environment entries `
      + `across ${inventory.entrypoints.length} Edge Functions.`,
  );
}
