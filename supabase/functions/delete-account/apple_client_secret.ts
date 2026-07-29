type AppleClientSecretSignerOptions = {
  teamId: string;
  keyId: string;
  clientId: string;
  privateKey: string;
  now?: () => Date;
};

const appleAudience = 'https://appleid.apple.com';
const clientSecretLifetimeSeconds = 300;

export class AppleClientSecretSigner {
  readonly #teamId: string;
  readonly #keyId: string;
  readonly #clientId: string;
  readonly #privateKey: string;
  readonly #now: () => Date;

  constructor(options: AppleClientSecretSignerOptions) {
    this.#teamId = options.teamId.trim();
    this.#keyId = options.keyId.trim();
    this.#clientId = options.clientId.trim();
    this.#privateKey = options.privateKey.replace(/\\n/g, '\n').trim();
    this.#now = options.now ?? (() => new Date());
  }

  async createClientSecret(): Promise<string> {
    this.#validateConfiguration();

    const issuedAt = Math.floor(this.#now().getTime() / 1000);
    if (!Number.isFinite(issuedAt)) {
      throw new Error('apple_client_secret_clock_invalid');
    }

    const header = base64UrlEncode(JSON.stringify({
      alg: 'ES256',
      kid: this.#keyId,
      typ: 'JWT',
    }));
    const payload = base64UrlEncode(JSON.stringify({
      iss: this.#teamId,
      iat: issuedAt,
      exp: issuedAt + clientSecretLifetimeSeconds,
      aud: appleAudience,
      sub: this.#clientId,
    }));
    const unsignedToken = `${header}.${payload}`;
    const privateKey = await importPrivateKey(this.#privateKey);
    const signature = await crypto.subtle.sign(
      { name: 'ECDSA', hash: 'SHA-256' },
      privateKey,
      new TextEncoder().encode(unsignedToken),
    );

    return `${unsignedToken}.${base64UrlEncode(signature)}`;
  }

  #validateConfiguration() {
    if (!this.#teamId) {
      throw new Error('apple_team_id_required');
    }
    if (!this.#keyId) {
      throw new Error('apple_key_id_required');
    }
    if (!this.#clientId) {
      throw new Error('apple_client_id_required');
    }
    if (!this.#privateKey) {
      throw new Error('apple_private_key_required');
    }
  }
}

async function importPrivateKey(privateKey: string) {
  const keyData = privateKey
    .replace('-----BEGIN PRIVATE KEY-----', '')
    .replace('-----END PRIVATE KEY-----', '')
    .replace(/\s/g, '');
  if (!keyData) {
    throw new Error('apple_private_key_invalid');
  }

  let binaryKey: ArrayBuffer;
  try {
    const decodedKey = atob(keyData);
    binaryKey = new ArrayBuffer(decodedKey.length);
    const keyBytes = new Uint8Array(binaryKey);
    for (let index = 0; index < decodedKey.length; index += 1) {
      keyBytes[index] = decodedKey.charCodeAt(index);
    }
  } catch {
    throw new Error('apple_private_key_invalid');
  }

  try {
    return await crypto.subtle.importKey(
      'pkcs8',
      binaryKey,
      { name: 'ECDSA', namedCurve: 'P-256' },
      false,
      ['sign'],
    );
  } catch (error) {
    throw new Error('apple_private_key_invalid', { cause: error });
  }
}

function base64UrlEncode(value: string | ArrayBuffer) {
  const bytes = typeof value === 'string'
    ? new TextEncoder().encode(value)
    : new Uint8Array(value);
  let binary = '';
  for (const byte of bytes) {
    binary += String.fromCharCode(byte);
  }

  return btoa(binary)
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/g, '');
}
