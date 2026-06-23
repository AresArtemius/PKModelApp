type HookPayload = Record<string, unknown>;

const smsAeroEmail = Deno.env.get('SMSAERO_EMAIL') ?? '';
const smsAeroApiKey = Deno.env.get('SMSAERO_API_KEY') ?? '';
const smsAeroSign = Deno.env.get('SMSAERO_SIGN') ?? 'SMS Aero';
const hookSecret = Deno.env.get('AUTH_HOOK_SECRET') ?? '';

const smsAeroEndpoint =
  Deno.env.get('SMSAERO_ENDPOINT') ??
  'https://gate.smsaero.ru/v2/sms/send';

Deno.serve(async (req) => {
  if (req.method !== 'POST') {
    return json({ error: 'Method not allowed' }, 405);
  }

  const rawBody = await req.text();

  try {
    await verifyHookRequest(req, rawBody);

    if (!smsAeroEmail || !smsAeroApiKey) {
      return json({ error: 'SMS Aero credentials are not configured' }, 500);
    }

    const payload = parseJson(rawBody);
    const phone = extractPhone(payload);
    const text = buildMessage(payload);

    if (!phone) {
      return json({ error: 'Phone number is missing in hook payload' }, 400);
    }

    if (!text) {
      return json({ error: 'OTP message is missing in hook payload' }, 400);
    }

    runInBackground(sendSmsAero({
      phone,
      text,
      sign: smsAeroSign,
    }));

    return json({});
  } catch (error) {
    console.error('send-sms-aero-otp failed', {
      message: errorMessage(error),
      status: error instanceof UnauthorizedHookRequestError ? 401 : 500,
    });
    if (error instanceof UnauthorizedHookRequestError) {
      return json({ error: error.message }, 401);
    }
    return json({ error: errorMessage(error) }, 500);
  }
});

class UnauthorizedHookRequestError extends Error {
  constructor() {
    super('Unauthorized hook request');
  }
}

function runInBackground(task: Promise<unknown>) {
  const loggedTask = task.catch((error) => {
    console.error('SMS Aero background send failed', {
      message: errorMessage(error),
    });
  });

  const edgeRuntime = globalThis as typeof globalThis & {
    EdgeRuntime?: { waitUntil?: (promise: Promise<unknown>) => void };
  };

  if (edgeRuntime.EdgeRuntime?.waitUntil != null) {
    edgeRuntime.EdgeRuntime.waitUntil(loggedTask);
    return;
  }
}

async function sendSmsAero({
  phone,
  text,
  sign,
}: {
  phone: string;
  text: string;
  sign: string;
}) {
  const auth = btoa(`${smsAeroEmail}:${smsAeroApiKey}`);
  const body = new URLSearchParams({
    number: normalizePhoneForSmsAero(phone),
    text,
    sign,
  });

  const response = await fetch(smsAeroEndpoint, {
    method: 'POST',
    headers: {
      Authorization: `Basic ${auth}`,
      'Content-Type': 'application/x-www-form-urlencoded',
      Accept: 'application/json',
    },
    body,
  });

  const responseText = await response.text();
  const data = parseJson(responseText);
  const success = asRecord(data)?.success === true;

  if (!response.ok || !success) {
    const details = responseText.trim();
    throw new Error(
      `SMS Aero send failed: HTTP ${response.status}${
        details.length === 0 ? '' : ` ${details}`
      }`,
    );
  }
}

function buildMessage(payload: HookPayload | null): string {
  const sms = asRecord(payload?.sms);
  const otp =
    asString(sms?.otp) ??
    asString(payload?.otp) ??
    asString(payload?.token) ??
    asString(payload?.code);
  if (otp) return `Ваш код PK Management: ${otp}`;

  return asString(sms?.message) ?? asString(payload?.message) ?? '';
}

function extractPhone(payload: HookPayload | null): string {
  const user = asRecord(payload?.user);
  const sms = asRecord(payload?.sms);

  return (
    asString(sms?.phone) ??
    asString(payload?.phone) ??
    asString(user?.phone) ??
    asString(user?.phone_number) ??
    ''
  );
}

function normalizePhoneForSmsAero(phone: string): string {
  return phone.replace(/[^0-9]/g, '');
}

async function verifyHookRequest(req: Request, rawBody: string) {
  if (!hookSecret) return;

  const authorization = req.headers.get('authorization') ?? '';
  if (authorization === `Bearer ${hookSecret}`) return;

  const directSecret =
    req.headers.get('x-hook-secret') ??
    req.headers.get('x-supabase-hook-secret') ??
    '';
  if (directSecret === hookSecret) return;

  if (await verifyStandardWebhook(req, rawBody, hookSecret)) return;

  throw new UnauthorizedHookRequestError();
}

async function verifyStandardWebhook(
  req: Request,
  rawBody: string,
  secret: string,
): Promise<boolean> {
  const id = req.headers.get('webhook-id') ?? '';
  const timestamp = req.headers.get('webhook-timestamp') ?? '';
  const signatureHeader = req.headers.get('webhook-signature') ?? '';

  if (!id || !timestamp || !signatureHeader) return false;

  const signedContent = `${id}.${timestamp}.${rawBody}`;
  const signatures = signatureHeader
    .split(' ')
    .map((part) => part.trim())
    .filter(Boolean)
    .map((part) => part.replace(/^v1,/, ''));
  if (signatures.length === 0) return false;

  const expected = await hmacSha256Base64(
    decodeWebhookSecret(secret),
    signedContent,
  );

  return signatures.some((signature) => timingSafeEqual(signature, expected));
}

async function hmacSha256Base64(secret: Uint8Array, data: string) {
  const key = await crypto.subtle.importKey(
    'raw',
    secret,
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const signature = await crypto.subtle.sign(
    'HMAC',
    key,
    new TextEncoder().encode(data),
  );
  return bytesToBase64(new Uint8Array(signature));
}

function decodeWebhookSecret(secret: string): Uint8Array {
  const normalizedSecret = secret.startsWith('v1,')
    ? secret.slice('v1,'.length)
    : secret;
  const value = normalizedSecret.startsWith('whsec_')
    ? normalizedSecret.slice('whsec_'.length)
    : '';
  if (!value) return new TextEncoder().encode(secret);

  try {
    return base64ToBytes(value);
  } catch (_) {
    return new TextEncoder().encode(secret);
  }
}

function timingSafeEqual(a: string, b: string): boolean {
  const aBytes = new TextEncoder().encode(a);
  const bBytes = new TextEncoder().encode(b);
  if (aBytes.length !== bBytes.length) return false;

  let result = 0;
  for (let i = 0; i < aBytes.length; i += 1) {
    result |= aBytes[i] ^ bBytes[i];
  }
  return result === 0;
}

function parseJson(text: string): HookPayload | null {
  try {
    return JSON.parse(text) as HookPayload;
  } catch (_) {
    return null;
  }
}

function asRecord(value: unknown): Record<string, unknown> | null {
  if (typeof value !== 'object' || value === null || Array.isArray(value)) {
    return null;
  }
  return value as Record<string, unknown>;
}

function asString(value: unknown): string | null {
  return typeof value === 'string' && value.trim().length > 0
    ? value.trim()
    : null;
}

function json(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json; charset=utf-8' },
  });
}

function errorMessage(error: unknown) {
  return error instanceof Error ? error.message : String(error);
}

function bytesToBase64(bytes: Uint8Array): string {
  let binary = '';
  for (const byte of bytes) {
    binary += String.fromCharCode(byte);
  }
  return btoa(binary);
}

function base64ToBytes(value: string): Uint8Array {
  const binary = atob(value);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i += 1) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes;
}
