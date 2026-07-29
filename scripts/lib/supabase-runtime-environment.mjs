import { readFile, readdir } from 'node:fs/promises';
import path from 'node:path';

const allowedAvailability = new Set([
  'required',
  'optional',
  'fallback',
]);
const allowedProvisioning = new Set([
  'supabase_platform',
  'supabase_secret',
]);
const allowedSensitivity = new Set([
  'configuration',
  'secret',
]);
const allowedEntryKeys = new Set([
  'availability',
  'description',
  'fallbackTo',
  'functions',
  'name',
  'provisioning',
  'sensitivity',
]);
const environmentReferencePatterns = [
  /\brequiredEnv\s*\(\s*['"]([A-Z][A-Z0-9_]*)['"]/g,
  /\boptionalEnv\s*\(\s*['"]([A-Z][A-Z0-9_]*)['"]/g,
  /\boptionalPositiveIntegerEnv\s*\(\s*['"]([A-Z][A-Z0-9_]*)['"]/g,
  /\bDeno\.env\.get\s*\(\s*['"]([A-Z][A-Z0-9_]*)['"]/g,
  /\benvName\s*:\s*['"]([A-Z][A-Z0-9_]*)['"]/g,
  /\bfallbackEnvName\s*:\s*['"]([A-Z][A-Z0-9_]*)['"]/g,
];
const importPattern = /\bfrom\s+['"]([^'"]+)['"]/g;
const dynamicEnvironmentReferencePatterns = [
  /\brequiredEnv\s*\(\s*[^\s'"]/,
  /\boptionalEnv\s*\(\s*[^\s'"]/,
  /\boptionalPositiveIntegerEnv\s*\(\s*[^\s'"]/,
  /\bDeno\.env\.get\s*\(\s*[^\s'"]/,
];

export async function loadRuntimeEnvironmentManifest(repositoryRoot) {
  const manifestPath = path.join(
    repositoryRoot,
    'supabase',
    'runtime-environment.manifest.json',
  );
  return JSON.parse(await readFile(manifestPath, 'utf8'));
}

export async function inspectRuntimeEnvironment(repositoryRoot) {
  const functionsRoot = path.join(repositoryRoot, 'supabase', 'functions');
  const sourceFiles = await findFiles(functionsRoot, (fileName) =>
    fileName.endsWith('.ts')
  );
  const sourceByPath = new Map(
    await Promise.all(
      sourceFiles.map(async (filePath) => [
        filePath,
        await readFile(filePath, 'utf8'),
      ]),
    ),
  );
  const importsByPath = new Map(
    [...sourceByPath.entries()].map(([filePath, source]) => [
      filePath,
      resolveLocalImports(filePath, source, sourceByPath),
    ]),
  );
  const entrypoints = await findEntrypoints(functionsRoot);
  const entriesByName = new Map();
  const dynamicReferences = [];

  for (const [filePath, source] of sourceByPath) {
    if (filePath === path.join(functionsRoot, '_shared', 'environment.ts')) {
      continue;
    }
    if (
      dynamicEnvironmentReferencePatterns.some((pattern) =>
        pattern.test(source)
      )
    ) {
      dynamicReferences.push(path.relative(repositoryRoot, filePath));
    }
  }

  for (const [functionName, entrypointPath] of entrypoints) {
    for (const dependencyPath of collectDependencies(
      entrypointPath,
      importsByPath,
    )) {
      const source = sourceByPath.get(dependencyPath);
      if (source === undefined) {
        continue;
      }
      for (const name of extractEnvironmentNames(source)) {
        const functions = entriesByName.get(name) ?? new Set();
        functions.add(functionName);
        entriesByName.set(name, functions);
      }
    }
  }

  return {
    dynamicReferences: dynamicReferences.sort(),
    entrypoints: [...entrypoints.keys()].sort(),
    entries: [...entriesByName.entries()]
      .map(([name, functions]) => ({
        name,
        functions: [...functions].sort(),
      }))
      .sort((left, right) => left.name.localeCompare(right.name)),
  };
}

export function validateRuntimeEnvironmentManifest(manifest, inventory) {
  const errors = [];
  if (inventory.dynamicReferences.length > 0) {
    errors.push(
      `dynamic environment references outside the shared reader: ${
        inventory.dynamicReferences.join(', ')
      }`,
    );
  }
  if (!isRecord(manifest)) {
    return ['manifest must be a JSON object'];
  }
  if (manifest.schemaVersion !== 1) {
    errors.push('schemaVersion must be 1');
  }
  if (!Array.isArray(manifest.entries)) {
    return [...errors, 'entries must be an array'];
  }

  const names = [];
  const entriesByName = new Map();
  for (const [index, entry] of manifest.entries.entries()) {
    const prefix = `entries[${index}]`;
    if (!isRecord(entry)) {
      errors.push(`${prefix} must be an object`);
      continue;
    }

    const extraKeys = Object.keys(entry).filter(
      (key) => !allowedEntryKeys.has(key),
    );
    if (extraKeys.length > 0) {
      errors.push(`${prefix} has unsupported keys: ${extraKeys.join(', ')}`);
    }
    if (
      typeof entry.name !== 'string'
      || !/^[A-Z][A-Z0-9_]*$/.test(entry.name)
    ) {
      errors.push(`${prefix}.name must be an uppercase environment name`);
      continue;
    }

    names.push(entry.name);
    if (entriesByName.has(entry.name)) {
      errors.push(`duplicate environment entry: ${entry.name}`);
    }
    entriesByName.set(entry.name, entry);

    if (!allowedAvailability.has(entry.availability)) {
      errors.push(`${entry.name}.availability is invalid`);
    }
    if (!allowedProvisioning.has(entry.provisioning)) {
      errors.push(`${entry.name}.provisioning is invalid`);
    }
    if (!allowedSensitivity.has(entry.sensitivity)) {
      errors.push(`${entry.name}.sensitivity is invalid`);
    }
    if (
      typeof entry.description !== 'string'
      || entry.description.trim().length === 0
    ) {
      errors.push(`${entry.name}.description must not be empty`);
    }
    if (
      !Array.isArray(entry.functions)
      || entry.functions.length === 0
      || entry.functions.some((value) => typeof value !== 'string')
    ) {
      errors.push(`${entry.name}.functions must be a non-empty string array`);
    } else {
      assertSortedUnique(
        entry.functions,
        `${entry.name}.functions`,
        errors,
      );
      const unknownFunctions = entry.functions.filter(
        (functionName) => !inventory.entrypoints.includes(functionName),
      );
      if (unknownFunctions.length > 0) {
        errors.push(
          `${entry.name}.functions contains unknown entries: ${
            unknownFunctions.join(', ')
          }`,
        );
      }
    }
    if (entry.availability === 'fallback') {
      if (
        typeof entry.fallbackTo !== 'string'
        || entry.fallbackTo.length === 0
      ) {
        errors.push(`${entry.name}.fallbackTo is required`);
      }
    } else if (entry.fallbackTo !== undefined) {
      errors.push(
        `${entry.name}.fallbackTo is only valid for fallback entries`,
      );
    }
  }

  assertSortedUnique(names, 'entries', errors);

  const discoveredNames = inventory.entries.map((entry) => entry.name);
  const missingNames = discoveredNames.filter(
    (name) => !entriesByName.has(name),
  );
  const staleNames = names.filter(
    (name) => !discoveredNames.includes(name),
  );
  if (missingNames.length > 0) {
    errors.push(`undocumented environment names: ${missingNames.join(', ')}`);
  }
  if (staleNames.length > 0) {
    errors.push(`stale environment names: ${staleNames.join(', ')}`);
  }

  for (const discovered of inventory.entries) {
    const documented = entriesByName.get(discovered.name);
    if (!documented || !Array.isArray(documented.functions)) {
      continue;
    }
    if (!arraysEqual(documented.functions, discovered.functions)) {
      errors.push(
        `${discovered.name}.functions must be [${
          discovered.functions.join(', ')
        }]`,
      );
    }
  }

  for (const entry of manifest.entries) {
    if (
      isRecord(entry)
      && typeof entry.fallbackTo === 'string'
      && !entriesByName.has(entry.fallbackTo)
    ) {
      errors.push(
        `${entry.name}.fallbackTo references unknown ${entry.fallbackTo}`,
      );
    }
  }

  return errors;
}

async function findEntrypoints(functionsRoot) {
  const directories = await readdir(functionsRoot, { withFileTypes: true });
  const entrypoints = new Map();

  for (const directory of directories) {
    if (!directory.isDirectory() || directory.name.startsWith('_')) {
      continue;
    }
    const entrypointPath = path.join(
      functionsRoot,
      directory.name,
      'index.ts',
    );
    try {
      await readFile(entrypointPath, 'utf8');
      entrypoints.set(directory.name, entrypointPath);
    } catch (error) {
      if (error?.code !== 'ENOENT') {
        throw error;
      }
    }
  }

  return new Map(
    [...entrypoints.entries()].sort(([left], [right]) =>
      left.localeCompare(right)
    ),
  );
}

async function findFiles(directory, predicate) {
  const entries = await readdir(directory, { withFileTypes: true });
  const files = [];

  for (const entry of entries) {
    const entryPath = path.join(directory, entry.name);
    if (entry.isDirectory()) {
      files.push(...await findFiles(entryPath, predicate));
    } else if (entry.isFile() && predicate(entry.name)) {
      files.push(entryPath);
    }
  }

  return files.sort();
}

function resolveLocalImports(filePath, source, sourceByPath) {
  const imports = [];
  for (const match of source.matchAll(importPattern)) {
    const specifier = match[1];
    if (!specifier.startsWith('.')) {
      continue;
    }
    const resolvedPath = path.resolve(path.dirname(filePath), specifier);
    if (sourceByPath.has(resolvedPath)) {
      imports.push(resolvedPath);
    }
  }
  return imports;
}

function collectDependencies(entrypointPath, importsByPath) {
  const pending = [entrypointPath];
  const visited = new Set();

  while (pending.length > 0) {
    const currentPath = pending.pop();
    if (currentPath === undefined || visited.has(currentPath)) {
      continue;
    }
    visited.add(currentPath);
    pending.push(...(importsByPath.get(currentPath) ?? []));
  }

  return visited;
}

function extractEnvironmentNames(source) {
  const names = new Set();
  for (const pattern of environmentReferencePatterns) {
    for (const match of source.matchAll(pattern)) {
      names.add(match[1]);
    }
  }
  return names;
}

function assertSortedUnique(values, label, errors) {
  const sortedValues = [...new Set(values)].sort((left, right) =>
    left.localeCompare(right)
  );
  if (!arraysEqual(values, sortedValues)) {
    errors.push(`${label} must be sorted and unique`);
  }
}

function arraysEqual(left, right) {
  return left.length === right.length
    && left.every((value, index) => value === right[index]);
}

function isRecord(value) {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}
