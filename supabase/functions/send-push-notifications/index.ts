import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.48.1';

type AppNotification = {
  id: string;
  user_id: string;
  title: string;
  body: string;
  route: string;
  type: string;
  data: Record<string, unknown>;
};

type PushDeviceToken = {
  token: string;
  platform: string;
};

const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
const fcmProjectId = Deno.env.get('FCM_PROJECT_ID') ?? '';
const fcmClientEmail = Deno.env.get('FCM_CLIENT_EMAIL') ?? '';
const fcmPrivateKey = (Deno.env.get('FCM_PRIVATE_KEY') ?? '').replaceAll(
  '\\n',
  '\n',
);

const supabase = createClient(supabaseUrl, serviceRoleKey, {
  auth: { persistSession: false, autoRefreshToken: false },
});

let cachedAccessToken: { token: string; expiresAt: number } | null = null;

Deno.serve(async (req) => {
  try {
    if (!supabaseUrl || !serviceRoleKey) {
      return json(
        { error: 'Supabase service credentials are not configured' },
        500,
      );
    }

    if (!fcmProjectId || !fcmClientEmail || !fcmPrivateKey) {
      return json(
        { error: 'FCM service account secrets are not configured' },
        500,
      );
    }

    const payload = await readJson(req);
    const notificationId = extractNotificationId(payload);

    const notifications = notificationId
      ? await fetchNotification(notificationId)
      : await fetchPendingNotifications();

    const results = [];
    for (const notification of notifications) {
      results.push(await processNotification(notification));
    }

    return json({ ok: true, processed: results.length, results });
  } catch (error) {
    return json({ error: errorMessage(error) }, 500);
  }
});

function extractNotificationId(payload: Record<string, unknown> | null) {
  const record = asRecord(payload?.record);
  return (
    asString(record?.id) ??
    asString(payload?.notification_id) ??
    asString(payload?.id)
  );
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

async function readJson(req: Request): Promise<Record<string, unknown> | null> {
  try {
    return await req.json();
  } catch (_) {
    return null;
  }
}

async function fetchNotification(id: string): Promise<AppNotification[]> {
  const { data, error } = await supabase
    .from('app_notifications')
    .select('id,user_id,title,body,route,type,data')
    .eq('id', id)
    .in('push_status', ['pending', 'failed'])
    .limit(1);

  if (error) throw error;
  return (data ?? []) as AppNotification[];
}

async function fetchPendingNotifications(): Promise<AppNotification[]> {
  const { data, error } = await supabase
    .from('app_notifications')
    .select('id,user_id,title,body,route,type,data')
    .eq('push_status', 'pending')
    .order('created_at', { ascending: true })
    .limit(50);

  if (error) throw error;
  return (data ?? []) as AppNotification[];
}

async function processNotification(notification: AppNotification) {
  await markProcessing(notification.id);

  const tokens = await fetchTokens(notification.user_id);
  if (tokens.length === 0) {
    await markSkipped(notification.id, 'No enabled device tokens');
    return { id: notification.id, status: 'skipped', sent: 0 };
  }

  const accessToken = await getFcmAccessToken();
  let sent = 0;
  const errors: string[] = [];

  for (const device of tokens) {
    const result = await sendFcmMessage(notification, device, accessToken);
    if (result.ok) {
      sent += 1;
    } else {
      errors.push(result.error);
      if (result.disableToken) {
        await disableToken(device.token);
      }
    }
  }

  if (sent > 0) {
    await markSent(notification.id);
    return { id: notification.id, status: 'sent', sent, failed: errors.length };
  }

  const errorText = errors.join('\n').slice(0, 2000);
  await markFailed(notification.id, errorText);
  return { id: notification.id, status: 'failed', sent, error: errorText };
}

async function fetchTokens(userId: string): Promise<PushDeviceToken[]> {
  const { data, error } = await supabase
    .from('push_device_tokens')
    .select('token,platform')
    .eq('user_id', userId)
    .eq('enabled', true);

  if (error) throw error;
  return (data ?? []) as PushDeviceToken[];
}

async function markProcessing(id: string) {
  const { error } = await supabase.rpc('mark_app_notification_push_attempt', {
    p_notification_id: id,
  });

  if (error) throw error;
}

async function markSent(id: string) {
  await updateNotificationPushStatus(id, 'sent', null, new Date().toISOString());
}

async function markSkipped(id: string, reason: string) {
  await updateNotificationPushStatus(id, 'skipped', reason, null);
}

async function markFailed(id: string, errorText: string) {
  await updateNotificationPushStatus(id, 'failed', errorText, null);
}

async function updateNotificationPushStatus(
  id: string,
  status: string,
  errorText: string | null,
  sentAt: string | null,
) {
  const { error } = await supabase
    .from('app_notifications')
    .update({
      push_status: status,
      push_error: errorText,
      push_sent_at: sentAt,
    })
    .eq('id', id);

  if (error) throw error;
}

async function disableToken(token: string) {
  await supabase
    .from('push_device_tokens')
    .update({ enabled: false, updated_at: new Date().toISOString() })
    .eq('token', token);
}

async function sendFcmMessage(
  notification: AppNotification,
  device: PushDeviceToken,
  accessToken: string,
): Promise<{ ok: true } | { ok: false; error: string; disableToken: boolean }> {
  const response = await fetch(
    `https://fcm.googleapis.com/v1/projects/${fcmProjectId}/messages:send`,
    {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${accessToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        message: {
          token: device.token,
          notification: {
            title: notification.title,
            body: notification.body,
          },
          data: buildFcmData(notification),
          android: {
            priority: 'HIGH',
            notification: { sound: 'default' },
          },
          apns: {
            payload: {
              aps: { sound: 'default' },
            },
          },
        },
      }),
    },
  );

  if (response.ok) return { ok: true };

  const text = await response.text();
  const disableToken =
    response.status === 404 ||
    text.includes('UNREGISTERED') ||
    text.includes('registration-token-not-registered');

  return {
    ok: false,
    error: `${device.platform}:${response.status}:${text}`,
    disableToken,
  };
}

function buildFcmData(notification: AppNotification): Record<string, string> {
  const data: Record<string, string> = {
    notification_id: notification.id,
    type: notification.type,
    route: notification.route,
  };

  for (const [key, value] of Object.entries(notification.data ?? {})) {
    if (value == null) continue;
    data[key] = typeof value === 'string' ? value : JSON.stringify(value);
  }

  return data;
}

async function getFcmAccessToken(): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  if (cachedAccessToken && cachedAccessToken.expiresAt - 60 > now) {
    return cachedAccessToken.token;
  }

  const assertion = await createServiceAccountJwt(now);
  const body = new URLSearchParams({
    grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
    assertion,
  });

  const response = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body,
  });

  if (!response.ok) {
    throw new Error(
      `FCM auth failed: ${response.status} ${await response.text()}`,
    );
  }

  const jsonBody = await response.json();
  const token = typeof jsonBody.access_token === 'string'
    ? jsonBody.access_token.trim()
    : '';
  if (!token) {
    throw new Error(`FCM auth returned no access_token: ${JSON.stringify(jsonBody)}`);
  }

  cachedAccessToken = {
    token,
    expiresAt: now + Number(jsonBody.expires_in ?? 3600),
  };

  return token;
}

async function createServiceAccountJwt(now: number): Promise<string> {
  const header = base64Url(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));
  const claims = base64Url(
    JSON.stringify({
      iss: fcmClientEmail,
      scope: 'https://www.googleapis.com/auth/firebase.messaging',
      aud: 'https://oauth2.googleapis.com/token',
      iat: now,
      exp: now + 3600,
    }),
  );

  const input = `${header}.${claims}`;
  const key = await importPrivateKey(fcmPrivateKey);
  const signature = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    key,
    new TextEncoder().encode(input),
  );

  return `${input}.${base64UrlBytes(new Uint8Array(signature))}`;
}

async function importPrivateKey(pem: string): Promise<CryptoKey> {
  const base64 = pem
    .replace('-----BEGIN PRIVATE KEY-----', '')
    .replace('-----END PRIVATE KEY-----', '')
    .replace(/\s/g, '');
  const binary = Uint8Array.from(atob(base64), (char) => char.charCodeAt(0));

  return await crypto.subtle.importKey(
    'pkcs8',
    binary,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  );
}

function base64Url(value: string): string {
  return base64UrlBytes(new TextEncoder().encode(value));
}

function base64UrlBytes(bytes: Uint8Array): string {
  let binary = '';
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary)
    .replaceAll('+', '-')
    .replaceAll('/', '_')
    .replaceAll('=', '');
}

function json(body: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

function errorMessage(error: unknown): string {
  return error instanceof Error ? error.message : String(error);
}
