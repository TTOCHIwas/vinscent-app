import path from 'node:path';

const allowedEnvironmentTemplates = [
  '.example',
  '.sample',
  '.template',
];

const allowedGoogleClientConfigPaths = new Set([
  'apps/mobile/android/app/google-services.json',
  'apps/mobile/ios/runner/googleservice-info.plist',
]);

const forbiddenExtensions = new Set([
  '.jks',
  '.keystore',
  '.mobileprovision',
  '.p12',
  '.p8',
]);

const textExtensions = new Set([
  '',
  '.cfg',
  '.cmd',
  '.conf',
  '.css',
  '.csv',
  '.dart',
  '.entitlements',
  '.gradle',
  '.graphql',
  '.html',
  '.java',
  '.js',
  '.json',
  '.jsx',
  '.kt',
  '.kts',
  '.md',
  '.mjs',
  '.plist',
  '.properties',
  '.ps1',
  '.scss',
  '.sh',
  '.sql',
  '.swift',
  '.toml',
  '.ts',
  '.tsx',
  '.txt',
  '.xcconfig',
  '.xml',
  '.yaml',
  '.yml',
]);

const contentDetectors = [
  {
    code: 'google_api_key',
    pattern: /\bAIza[0-9A-Za-z_-]{35}\b/g,
  },
  {
    code: 'github_token',
    pattern:
      /\b(?:gh[pousr]_[0-9A-Za-z]{36,255}|github_pat_[0-9A-Za-z_]{20,255})\b/g,
  },
  {
    code: 'supabase_secret_key',
    pattern: /\bsb_secret_[0-9A-Za-z_-]{20,}\b/g,
  },
  {
    code: 'aws_access_key',
    pattern: /\bAKIA[0-9A-Z]{16}\b/g,
  },
];

const jwtPattern =
  /\b[0-9A-Za-z_-]{20,}\.([0-9A-Za-z_-]{20,})\.[0-9A-Za-z_-]{20,}\b/g;

const privateKeyBlockPattern =
  /-----BEGIN (?:RSA |EC |OPENSSH |ENCRYPTED )?PRIVATE KEY-----([\s\S]*?)-----END (?:RSA |EC |OPENSSH |ENCRYPTED )?PRIVATE KEY-----/g;

export function trackedPathIssue(filePath) {
  const normalizedPath = filePath.replaceAll('\\', '/');
  const lowercasePath = normalizedPath.toLowerCase();
  const segments = lowercasePath.split('/');
  const basename = segments.at(-1) ?? '';
  const extension = path.posix.extname(basename);

  if (
    segments.some((segment, index) =>
      segment === 'supabase' && segments[index + 1] === '.temp'
    )
  ) {
    return 'supabase_temp_cache';
  }

  if (basename === '.env' || basename.startsWith('.env.')) {
    const isTemplate = allowedEnvironmentTemplates.some((suffix) =>
      basename.endsWith(suffix)
    );
    if (!isTemplate) {
      return 'environment_file';
    }
  }

  if (forbiddenExtensions.has(extension)) {
    return 'credential_file';
  }

  if (
    basename === 'key.properties'
    || /^service-account.*\.json$/.test(basename)
    || /^firebase-adminsdk.*\.json$/.test(basename)
  ) {
    return 'credential_file';
  }

  return null;
}

export function shouldInspectTrackedText(filePath) {
  const normalizedPath = filePath.replaceAll('\\', '/').toLowerCase();
  return textExtensions.has(path.posix.extname(normalizedPath));
}

export function inspectTrackedText(filePath, source) {
  const issues = [];

  const privateKeyLine = privateKeyMaterialLine(source);
  if (privateKeyLine != null) {
    issues.push(issue(filePath, 'private_key', privateKeyLine));
  }

  for (const detector of contentDetectors) {
    if (
      detector.code === 'google_api_key'
      && allowedGoogleClientConfigPaths.has(
        filePath.replaceAll('\\', '/').toLowerCase(),
      )
    ) {
      continue;
    }
    detector.pattern.lastIndex = 0;
    const match = detector.pattern.exec(source);
    if (match != null) {
      issues.push(issue(filePath, detector.code, lineAt(source, match.index)));
    }
  }

  jwtPattern.lastIndex = 0;
  for (const match of source.matchAll(jwtPattern)) {
    if (jwtRole(match[1]) === 'service_role') {
      issues.push(
        issue(filePath, 'supabase_service_role_jwt', lineAt(source, match.index)),
      );
      break;
    }
  }

  return issues;
}

function privateKeyMaterialLine(source) {
  privateKeyBlockPattern.lastIndex = 0;
  for (const match of source.matchAll(privateKeyBlockPattern)) {
    const encodedBody = match[1]
      .replaceAll('\\n', '\n')
      .replace(/\s/g, '');
    if (
      encodedBody.length >= 100
      && /^[0-9A-Za-z+/=]+$/.test(encodedBody)
    ) {
      return lineAt(source, match.index);
    }
  }
  return null;
}

function issue(filePath, code, line) {
  return { filePath, code, line };
}

function lineAt(source, index) {
  return source.slice(0, index).split('\n').length;
}

function jwtRole(encodedPayload) {
  try {
    const payload = JSON.parse(
      Buffer.from(encodedPayload, 'base64url').toString('utf8'),
    );
    return typeof payload.role === 'string' ? payload.role : null;
  } catch {
    return null;
  }
}
