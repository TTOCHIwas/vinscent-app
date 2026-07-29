export function parseRemoteSecretNames(rawJson) {
  const parsed = JSON.parse(rawJson);
  const entries = Array.isArray(parsed)
    ? parsed
    : Array.isArray(parsed?.secrets)
      ? parsed.secrets
      : Array.isArray(parsed?.data)
        ? parsed.data
        : undefined;

  if (entries === undefined) {
    throw new Error('remote secret inventory must be a JSON array');
  }

  const names = entries.map((entry, index) => {
    if (typeof entry?.name !== 'string' || entry.name.trim().length === 0) {
      throw new Error(`remote secret inventory entry ${index} has no name`);
    }
    return entry.name.trim();
  });

  return [...new Set(names)].sort();
}

export function validateRemoteSecretInventory(manifest, remoteNames) {
  if (
    typeof manifest !== 'object'
    || manifest === null
    || !Array.isArray(manifest.entries)
  ) {
    return ['runtime environment manifest entries must be an array'];
  }

  const errors = [];
  const configuredNames = new Set(remoteNames);
  const documentedNames = new Set(
    manifest.entries
      .filter(
        (entry) =>
          typeof entry === 'object'
          && entry !== null
          && typeof entry.name === 'string',
      )
      .map((entry) => entry.name),
  );

  for (const entry of manifest.entries) {
    if (
      typeof entry !== 'object'
      || entry === null
      || entry.provisioning !== 'supabase_secret'
      || typeof entry.name !== 'string'
    ) {
      continue;
    }

    if (
      entry.availability === 'required'
      && !configuredNames.has(entry.name)
    ) {
      errors.push(`missing required Edge secret: ${entry.name}`);
      continue;
    }

    if (
      entry.availability === 'fallback'
      && !configuredNames.has(entry.name)
      && (
        typeof entry.fallbackTo !== 'string'
        || !configuredNames.has(entry.fallbackTo)
      )
    ) {
      const fallbackLabel =
        typeof entry.fallbackTo === 'string' ? entry.fallbackTo : 'undefined';
      errors.push(
        `missing Edge secret fallback: ${entry.name} or ${fallbackLabel}`,
      );
    }
  }

  const undocumentedNames = remoteNames.filter(
    (name) => !documentedNames.has(name) && !name.startsWith('SUPABASE_'),
  );
  if (undocumentedNames.length > 0) {
    errors.push(
      `undocumented Edge secrets: ${undocumentedNames.sort().join(', ')}`,
    );
  }

  return errors;
}
