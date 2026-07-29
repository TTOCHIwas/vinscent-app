import { readdir } from 'node:fs/promises';
import path from 'node:path';

export async function listLocalFunctionNames(repositoryRoot) {
  const functionsRoot = path.join(repositoryRoot, 'supabase', 'functions');
  const directories = await readdir(functionsRoot, { withFileTypes: true });
  const functionNames = [];

  for (const directory of directories) {
    if (!directory.isDirectory() || directory.name.startsWith('_')) {
      continue;
    }

    const files = await readdir(path.join(functionsRoot, directory.name));
    if (files.includes('index.ts')) {
      functionNames.push(directory.name);
    }
  }

  return functionNames.sort();
}

export function parseRemoteFunctionNames(rawJson) {
  const parsed = JSON.parse(rawJson);
  const entries = Array.isArray(parsed)
    ? parsed
    : Array.isArray(parsed?.functions)
      ? parsed.functions
      : Array.isArray(parsed?.data)
        ? parsed.data
        : undefined;

  if (entries === undefined) {
    throw new Error('remote function inventory must be a JSON array');
  }

  const names = entries.map((entry, index) => {
    const name =
      typeof entry?.slug === 'string'
        ? entry.slug
        : typeof entry?.name === 'string'
          ? entry.name
          : undefined;
    if (name === undefined || name.trim().length === 0) {
      throw new Error(`remote function inventory entry ${index} has no name`);
    }
    return name.trim();
  });

  return [...new Set(names)].sort();
}

export function compareFunctionInventory({
  localNames,
  remoteNames,
  allowMissing,
}) {
  const errors = [];
  const local = new Set(localNames);
  const remote = new Set(remoteNames);
  const staleRemote = [...remote].filter((name) => !local.has(name)).sort();
  const missingRemote = [...local].filter((name) => !remote.has(name)).sort();

  if (staleRemote.length > 0) {
    errors.push(`remote-only Edge Functions: ${staleRemote.join(", ")}`);
  }
  if (!allowMissing && missingRemote.length > 0) {
    errors.push(`undeployed Edge Functions: ${missingRemote.join(", ")}`);
  }

  return errors;
}
