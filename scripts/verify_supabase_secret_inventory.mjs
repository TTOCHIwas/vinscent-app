import { readFile } from 'node:fs/promises';
import path from 'node:path';

import {
  parseRemoteSecretNames,
  validateRemoteSecretInventory,
} from './lib/supabase-secret-inventory.mjs';
import {
  loadRuntimeEnvironmentManifest,
} from './lib/supabase-runtime-environment.mjs';

function parseArguments(args) {
  const remoteIndex = args.indexOf('--remote');
  if (remoteIndex === -1 || remoteIndex === args.length - 1) {
    throw new Error('--remote <json-file> is required');
  }
  return { remoteFile: args[remoteIndex + 1] };
}

const repositoryRoot = path.resolve(import.meta.dirname, '..');

try {
  const { remoteFile } = parseArguments(process.argv.slice(2));
  const [manifest, remoteJson] = await Promise.all([
    loadRuntimeEnvironmentManifest(repositoryRoot),
    readFile(path.resolve(remoteFile), 'utf8'),
  ]);
  const remoteNames = parseRemoteSecretNames(remoteJson);
  const errors = validateRemoteSecretInventory(manifest, remoteNames);

  if (errors.length > 0) {
    process.stderr.write(
      `Supabase Edge secret inventory validation failed:\n${errors
        .map((error) => `- ${error}`)
        .join('\n')}\n`,
    );
    process.exitCode = 1;
  } else {
    process.stdout.write(
      `Validated ${remoteNames.length} configured Edge secret names.\n`,
    );
  }
} catch (error) {
  process.stderr.write(
    `Supabase Edge secret inventory validation failed: ${
      error instanceof Error ? error.message : String(error)
    }\n`,
  );
  process.exitCode = 1;
}
