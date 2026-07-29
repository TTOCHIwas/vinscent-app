import { readFile, readdir } from 'node:fs/promises';
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
  return parseRemoteFunctionEntries(rawJson)
    .map(({ name }) => name)
    .filter((name, index, names) => names.indexOf(name) === index)
    .sort();
}

export function parseRemoteFunctionAuthorizationModes(rawJson) {
  const modes = new Map();

  for (const { entry, index, name } of parseRemoteFunctionEntries(rawJson)) {
    if (typeof entry.verify_jwt !== 'boolean') {
      throw new Error(
        `remote function inventory entry ${index} has no verify_jwt mode`,
      );
    }
    modes.set(name, entry.verify_jwt);
  }

  return new Map([...modes.entries()].sort(([left], [right]) =>
    left.localeCompare(right)
  ));
}

export async function loadLocalFunctionAuthorizationModes(repositoryRoot) {
  const [functionNames, configSource] = await Promise.all([
    listLocalFunctionNames(repositoryRoot),
    readFile(path.join(repositoryRoot, 'supabase', 'config.toml'), 'utf8'),
  ]);
  return parseLocalFunctionAuthorizationModes(configSource, functionNames);
}

export function parseLocalFunctionAuthorizationModes(
  configSource,
  functionNames,
) {
  const configuredModes = new Map();
  let currentFunctionName;

  for (const line of configSource.split(/\r?\n/)) {
    const trimmedLine = line.trim();
    const sectionMatch = trimmedLine.match(/^\[functions\.([^\]]+)\]$/);
    if (sectionMatch) {
      currentFunctionName = sectionMatch[1];
      continue;
    }
    if (trimmedLine.startsWith('[')) {
      currentFunctionName = undefined;
      continue;
    }

    const verifyJwtMatch = trimmedLine.match(
      /^verify_jwt\s*=\s*(true|false)(?:\s*#.*)?$/,
    );
    if (currentFunctionName && verifyJwtMatch) {
      configuredModes.set(
        currentFunctionName,
        verifyJwtMatch[1] === 'true',
      );
    }
  }

  return new Map(
    functionNames.map((functionName) => [
      functionName,
      configuredModes.get(functionName) ?? true,
    ]),
  );
}

function parseRemoteFunctionEntries(rawJson) {
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

  return entries.map((entry, index) => {
    const name =
      typeof entry?.slug === 'string'
        ? entry.slug
        : typeof entry?.name === 'string'
          ? entry.name
          : undefined;
    if (name === undefined || name.trim().length === 0) {
      throw new Error(`remote function inventory entry ${index} has no name`);
    }
    return { entry, index, name: name.trim() };
  });
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

export function compareFunctionAuthorizationModes({
  localModes,
  remoteModes,
  allowMissing,
}) {
  if (allowMissing) {
    return [];
  }

  const errors = [];
  for (const [functionName, expectedVerifyJwt] of localModes) {
    const remoteVerifyJwt = remoteModes.get(functionName);
    if (
      typeof remoteVerifyJwt === 'boolean'
      && remoteVerifyJwt !== expectedVerifyJwt
    ) {
      errors.push(
        `Edge Function JWT mode mismatch: ${functionName} expected `
          + `${expectedVerifyJwt}, remote ${remoteVerifyJwt}`,
      );
    }
  }
  return errors.sort();
}
