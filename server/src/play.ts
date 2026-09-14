/**
 * Verifies a Play subscription purchase against Google's servers.
 *
 * A purchase token coming from the app proves nothing on its own — it is easy
 * to fake. This asks Google directly whether the subscription is active and
 * when it expires, and only then is the device marked entitled.
 *
 * Needs a service account with the "View financial data" permission in Play
 * Console, and the Google Play Android Developer API enabled on its project.
 */

interface PlayEnv {
  PLAY_SERVICE_ACCOUNT_EMAIL: string;
  /** The service account's private_key, PEM, newlines intact. */
  PLAY_PRIVATE_KEY: string;
  ANDROID_PACKAGE_NAME: string;
}

export interface Entitlement {
  active: boolean;
  expiresAt: number;
  productId: string;
}

const TOKEN_URL = 'https://oauth2.googleapis.com/token';
const SCOPE = 'https://www.googleapis.com/auth/androidpublisher';

/** Cached across requests on the same isolate; harmless if it's cold. */
let cachedToken: { value: string; expiresAt: number } | null = null;

function base64url(bytes: Uint8Array): string {
  let binary = '';
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

function encodeJson(value: unknown): string {
  return base64url(new TextEncoder().encode(JSON.stringify(value)));
}

/** PEM to the raw DER bytes WebCrypto wants. */
function pemToBytes(pem: string): Uint8Array {
  const body = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, '')
    .replace(/-----END PRIVATE KEY-----/, '')
    // Secrets pasted through a shell often arrive with literal \n.
    .replace(/\\n/g, '')
    .replace(/\s/g, '');

  const binary = atob(body);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return bytes;
}

async function accessToken(env: PlayEnv): Promise<string> {
  if (cachedToken && cachedToken.expiresAt > Date.now() + 60_000) {
    return cachedToken.value;
  }

  const now = Math.floor(Date.now() / 1000);
  const unsigned =
    encodeJson({ alg: 'RS256', typ: 'JWT' }) +
    '.' +
    encodeJson({
      iss: env.PLAY_SERVICE_ACCOUNT_EMAIL,
      scope: SCOPE,
      aud: TOKEN_URL,
      iat: now,
      exp: now + 3600,
    });

  const key = await crypto.subtle.importKey(
    'pkcs8',
    pemToBytes(env.PLAY_PRIVATE_KEY),
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  );

  const signature = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    key,
    new TextEncoder().encode(unsigned),
  );

  const assertion = `${unsigned}.${base64url(new Uint8Array(signature))}`;

  const response = await fetch(TOKEN_URL, {
    method: 'POST',
    headers: { 'content-type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion,
    }),
  });

  if (!response.ok) {
    throw new Error(
      `Play auth failed (${response.status}): ${(await response.text()).slice(0, 200)}`,
    );
  }

  const body = (await response.json()) as {
    access_token: string;
    expires_in: number;
  };

  cachedToken = {
    value: body.access_token,
    expiresAt: Date.now() + body.expires_in * 1000,
  };
  return cachedToken.value;
}

/**
 * Asks Google about a purchase token. Returns whether it is currently active
 * and when it runs out, so a cancelled subscription keeps working until the
 * end of the period the user paid for.
 */
export async function verifySubscription(
  purchaseToken: string,
  env: PlayEnv,
): Promise<Entitlement> {
  const token = await accessToken(env);

  const url =
    `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/` +
    `${encodeURIComponent(env.ANDROID_PACKAGE_NAME)}/purchases/subscriptionsv2/tokens/` +
    `${encodeURIComponent(purchaseToken)}`;

  const response = await fetch(url, {
    headers: { authorization: `Bearer ${token}` },
  });

  if (response.status === 404 || response.status === 400) {
    return { active: false, expiresAt: 0, productId: '' };
  }
  if (!response.ok) {
    throw new Error(
      `Play lookup failed (${response.status}): ${(await response.text()).slice(0, 200)}`,
    );
  }

  const body = (await response.json()) as {
    subscriptionState?: string;
    lineItems?: { productId?: string; expiryTime?: string }[];
  };

  const item = body.lineItems?.[0];
  const expiresAt = item?.expiryTime ? Date.parse(item.expiryTime) : 0;

  // Grace period and on-hold still count as paid access; cancelled does too,
  // until the expiry date passes.
  const activeStates = new Set([
    'SUBSCRIPTION_STATE_ACTIVE',
    'SUBSCRIPTION_STATE_IN_GRACE_PERIOD',
    'SUBSCRIPTION_STATE_CANCELED',
  ]);

  return {
    active:
      activeStates.has(body.subscriptionState ?? '') && expiresAt > Date.now(),
    expiresAt,
    productId: item?.productId ?? '',
  };
}
