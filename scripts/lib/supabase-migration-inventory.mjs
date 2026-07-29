import { readdir } from 'node:fs/promises';
import path from 'node:path';

const migrationVersionPattern = /^[0-9]{14}$/;
const migrationFilenamePattern = /^([0-9]{14})_[^/\\]+\.sql$/;

export async function listLocalMigrationVersions(repositoryRoot) {
  const migrationsRoot = path.join(repositoryRoot, 'supabase', 'migrations');
  const entries = await readdir(migrationsRoot, { withFileTypes: true });
  const filenames = entries
    .filter((entry) => entry.isFile() && entry.name.endsWith('.sql'))
    .map((entry) => entry.name);

  return parseLocalMigrationVersions(filenames);
}

export function parseLocalMigrationVersions(filenames) {
  const versions = [];
  const seen = new Set();

  for (const filename of filenames) {
    const match = migrationFilenamePattern.exec(filename);
    if (match === null) {
      throw new Error(`invalid local migration filename: ${filename}`);
    }

    const version = match[1];
    if (seen.has(version)) {
      throw new Error(`duplicate local migration version: ${version}`);
    }
    seen.add(version);
    versions.push(version);
  }

  return versions.sort();
}

export function parseRemoteMigrationVersions(rawJson) {
  const parsed = JSON.parse(rawJson.replace(/^\uFEFF/, ''));
  const entries = Array.isArray(parsed)
    ? parsed
    : Array.isArray(parsed?.migrations)
      ? parsed.migrations
      : undefined;

  if (entries === undefined) {
    throw new Error('remote migration inventory must contain a migrations array');
  }

  const versions = [];
  const seen = new Set();

  for (const [index, entry] of entries.entries()) {
    if (typeof entry?.remote !== 'string') {
      throw new Error(`remote migration inventory entry ${index} has no remote version`);
    }

    const version = entry.remote.trim();
    if (version.length === 0) {
      continue;
    }
    if (!migrationVersionPattern.test(version)) {
      throw new Error(
        `remote migration inventory entry ${index} has an invalid remote version`,
      );
    }
    if (seen.has(version)) {
      throw new Error(`duplicate remote migration version: ${version}`);
    }
    seen.add(version);
    versions.push(version);
  }

  return versions.sort();
}

export function compareMigrationInventory({
  allowUnapplied = false,
  localVersions,
  remoteVersions,
}) {
  const local = new Set(localVersions);
  const remote = new Set(remoteVersions);
  const remoteOnly = [...remote].filter((version) => !local.has(version)).sort();
  const unapplied = [...local].filter((version) => !remote.has(version)).sort();
  const errors = [];

  if (remoteOnly.length > 0) {
    errors.push(`remote-only migrations: ${remoteOnly.join(', ')}`);
  }
  if (!allowUnapplied && unapplied.length > 0) {
    errors.push(`unapplied migrations: ${unapplied.join(', ')}`);
  }

  return errors;
}
