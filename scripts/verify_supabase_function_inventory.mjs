import { readFile } from 'node:fs/promises';
import path from 'node:path';

import {
  compareFunctionInventory,
  listLocalFunctionNames,
  parseRemoteFunctionNames,
} from './lib/supabase-function-inventory.mjs';

function parseArguments(args) {
  const remoteIndex = args.indexOf('--remote');
  if (remoteIndex === -1 || remoteIndex === args.length - 1) {
    throw new Error('--remote <json-file> is required');
  }

  return {
    allowMissing: args.includes('--allow-missing'),
    remoteFile: args[remoteIndex + 1],
  };
}

const repositoryRoot = path.resolve(import.meta.dirname, '..');

try {
  const { allowMissing, remoteFile } = parseArguments(process.argv.slice(2));
  const [localNames, remoteJson] = await Promise.all([
    listLocalFunctionNames(repositoryRoot),
    readFile(path.resolve(remoteFile), 'utf8'),
  ]);
  const remoteNames = parseRemoteFunctionNames(remoteJson);
  const errors = compareFunctionInventory({
    localNames,
    remoteNames,
    allowMissing,
  });

  if (errors.length > 0) {
    process.stderr.write(
      `Supabase Edge Function inventory validation failed:\n${errors
        .map((error) => `- ${error}`)
        .join("\n")}\n`,
    );
    process.exitCode = 1;
  } else {
    process.stdout.write(
      `Validated ${localNames.length} tracked Edge Functions against the remote inventory.\n`,
    );
  }
} catch (error) {
  process.stderr.write(
    `Supabase Edge Function inventory validation failed: ${
      error instanceof Error ? error.message : String(error)
    }\n`,
  );
  process.exitCode = 1;
}
