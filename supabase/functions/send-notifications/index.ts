import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.48.1';

type AppNotification = {
  id: string;
  user_id: string;
  title: string;
  body: string;
  route: string;
  type: string;
  data: Record<string, unknown>;
  push_status: string;
  email_status: string;
  email_to: string;
  email_subject: string;
  email_body: string;
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
const resendApiKey = Deno.env.get('RESEND_API_KEY') ?? '';
const emailFrom = Deno.env.get('EMAIL_FROM') ?? '';
const publicAppUrl = Deno.env.get('PUBLIC_APP_URL') ?? '';

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

async function processNotification(notification: AppNotification) {
  const result = {
    id: notification.id,
    push: 'not_requested',
    email: 'not_requested',
  };

  if (['pending', 'failed'].includes(notification.push_status)) {
    result.push = await processPush(notification);
  }

  if (['pending', 'failed'].includes(notification.email_status)) {
    result.email = await processEmail(notification);
  }

  return result;
}

async function processPush(notification: AppNotification): Promise<string> {
  if (!fcmProjectId || !fcmClientEmail || !fcmPrivateKey) {
    await markPushSkipped(notification.id, 'FCM service account secrets are not configured');
    return 'skipped';
  }

  await markPushProcessing(notification.id);

  const tokens = await fetchTokens(notification.user_id);
  if (tokens.length === 0) {
    await markPushSkipped(notification.id, 'No enabled device tokens');
    return 'skipped';
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
    await updateNotificationPushStatus(
      notification.id,
      'sent',
      null,
      new Date().toISOString(),
    );
    return 'sent';
  }

  await updateNotificationPushStatus(
    notification.id,
    'failed',
    errors.join('\n').slice(0, 2000),
    null,
  );
  return 'failed';
}

async function processEmail(notification: AppNotification): Promise<string> {
  if (!resendApiKey || !emailFrom) {
    await markEmailStatus(
      notification.id,
      'skipped',
      'RESEND_API_KEY or EMAIL_FROM is not configured',
    );
    return 'skipped';
  }

  const to = notification.email_to.trim();
  if (!to) {
    await markEmailStatus(notification.id, 'skipped', 'No recipient email');
    return 'skipped';
  }

  await markEmailStatus(notification.id, 'processing');

  const subject = notification.email_subject.trim() || notification.title;
  const text = notification.email_body.trim() || notification.body;
  const html = renderEmailHtml(notification, text);

  const response = await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${resendApiKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      from: emailFrom,
      to: [to],
      subject,
      text,
      html,
      tags: [
        { name: 'notification_id', value: notification.id },
        { name: 'notification_type', value: notification.type },
      ],
    }),
  });

  if (response.ok) {
    await markEmailStatus(notification.id, 'sent');
    return 'sent';
  }

  const errorText = `${response.status}: ${await response.text()}`.slice(
    0,
    2000,
  );
  await markEmailStatus(notification.id, 'failed', errorText);
  return 'failed';
}

async function fetchNotification(id: string): Promise<AppNotification[]> {
  const { data, error } = await supabase
    .from('app_notifications')
    .select(notificationColumns)
    .eq('id', id)
    .or('push_status.in.(pending,failed),email_status.in.(pending,failed)')
    .limit(1);

  if (error) throw error;
  return (data ?? []) as AppNotification[];
}

async function fetchPendingNotifications(): Promise<AppNotification[]> {
  const { data, error } = await supabase
    .from('app_notifications')
    .select(notificationColumns)
    .or('push_status.eq.pending,email_status.eq.pending')
    .order('created_at', { ascending: true })
    .limit(50);

  if (error) throw error;
  return (data ?? []) as AppNotification[];
}

const notificationColumns =
  'id,user_id,title,body,route,type,data,push_status,email_status,' +
  'email_to,email_subject,email_body';

async function fetchTokens(userId: string): Promise<PushDeviceToken[]> {
  const { data, error } = await supabase
    .from('push_device_tokens')
    .select('token,platform')
    .eq('user_id', userId)
    .eq('enabled', true);

  if (error) throw error;
  return (data ?? []) as PushDeviceToken[];
}

async function markPushProcessing(id: string) {
  const { error } = await supabase.rpc('mark_app_notification_push_attempt', {
    p_notification_id: id,
  });

  if (error) throw error;
}

async function markPushSkipped(id: string, reason: string) {
  await updateNotificationPushStatus(id, 'skipped', reason, null);
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

async function markEmailStatus(
  id: string,
  status: string,
  errorText: string | null = null,
) {
  const { error } = await supabase.rpc('mark_app_notification_email_status', {
    p_notification_id: id,
    p_status: status,
    p_error: errorText,
  });

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

function renderEmailHtml(notification: AppNotification, text: string): string {
  const route = notification.route.trim();
  const url = route && publicAppUrl
    ? `${publicAppUrl.replace(/\/$/, '')}/#${route.startsWith('/') ? route : `/${route}`}`
    : '';
  const cta = url
    ? `<p style="margin:28px 0 0"><a href="${escapeHtml(url)}" style="background:#1f1f1f;border-radius:999px;color:#fff;display:inline-block;font-family:Arial,sans-serif;font-size:14px;font-weight:700;letter-spacing:2px;padding:14px 24px;text-decoration:none;text-transform:uppercase">Открыть</a></p>`
    : '';

  return `
    <div style="background:#f4f4f4;padding:32px">
      <div style="background:#fff;border-radius:18px;color:#1f1f1f;font-family:Arial,sans-serif;margin:0 auto;max-width:560px;padding:32px">
        <h1 style="font-size:22px;letter-spacing:2px;margin:0 0 18px;text-transform:uppercase">${escapeHtml(notification.title)}</h1>
        <p style="font-size:16px;line-height:1.6;margin:0;white-space:pre-line">${escapeHtml(text)}</p>
        ${cta}
      </div>
    </div>
  `;
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
    throw new Error(
      `FCM auth returned no access_token: ${JSON.stringify(jsonBody)}`,
    );
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

function extractNotificationId(payload: Record<string, unknown> | null) {
  const record = asRecord(payload?.record);
  return (
    asString(record?.id) ??
    asString(payload?.notification_id) ??
    asString(payload?.id)
  );
}

async function readJson(req: Request): Promise<Record<string, unknown> | null> {
  try {
    return await req.json();
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

function base64Url(value: string): string {
  return base64UrlBytes(new TextEncoder().encode(value));
}

function base64UrlBytes(bytes: Uint8Array): string {
  let binary = '';
  for (const byte of bytes) {
    binary += String.fromCharCode(byte);
  }
  return btoa(binary)
    .replaceAll('+', '-')
    .replaceAll('/', '_')
    .replaceAll('=', '');
}

function escapeHtml(value: string): string {
  return value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#039;');
}

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

function errorMessage(error: unknown) {
  return error instanceof Error ? error.message : String(error);
}
