import { readFile } from 'node:fs/promises';
import path from 'node:path';

import {
  compareMigrationInventory,
  listLocalMigrationVersions,
  parseRemoteMigrationVersions,
} from './lib/supabase-migration-inventory.mjs';

function parseArguments(args) {
  const remoteIndex = args.indexOf('--remote');
  if (remoteIndex === -1 || remoteIndex === args.length - 1) {
    throw new Error('--remote <json-file> is required');
  }
  return {
    allowUnapplied: args.includes('--allow-unapplied'),
    remoteFile: args[remoteIndex + 1],
  };
}

const repositoryRoot = path.resolve(import.meta.dirname, '..');

try {
  const { allowUnapplied, remoteFile } = parseArguments(
    process.argv.slice(2),
  );
  const [localVersions, remoteJson] = await Promise.all([
    listLocalMigrationVersions(repositoryRoot),
    readFile(path.resolve(remoteFile), 'utf8'),
  ]);
  const remoteVersions = parseRemoteMigrationVersions(remoteJson);
  const errors = compareMigrationInventory({
    allowUnapplied,
    localVersions,
    remoteVersions,
  });

  if (errors.length > 0) {
    process.stderr.write(
      `Supabase migration inventory validation failed:\n${errors
        .map((error) => `- ${error}`)
        .join('\n')}\n`,
    );
    process.exitCode = 1;
  } else {
    process.stdout.write(
      allowUnapplied
        ? `Validated ${remoteVersions.length} known remote Supabase migrations.\n`
        : `Validated ${remoteVersions.length} applied Supabase migrations.\n`,
    );
  }
} catch (error) {
  process.stderr.write(
    `Supabase migration inventory validation failed: ${
      error instanceof Error ? error.message : String(error)
    }\n`,
  );
  process.exitCode = 1;
}
