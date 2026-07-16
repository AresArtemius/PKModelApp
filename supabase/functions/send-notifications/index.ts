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

type FcmSendFailureReason = 'auth' | 'invalid_token' | 'quota' | 'unknown';

type FcmSendResult =
  | { ok: true }
  | {
      ok: false;
      error: string;
      disableToken: boolean;
      reason: FcmSendFailureReason;
    };

type NotificationPreferences = {
  push_enabled: boolean;
  email_enabled: boolean;
  chat_enabled: boolean;
  casting_enabled: boolean;
  profile_enabled: boolean;
  system_enabled: boolean;
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
  const preferences = await fetchPreferences(notification.user_id);
  const group = eventGroup(notification.type);

  if (!isGroupEnabled(preferences, group)) {
    if (['pending', 'failed'].includes(notification.push_status)) {
      await markPushSkipped(notification.id, 'Event disabled by user preferences');
      result.push = 'skipped';
    }
    if (['pending', 'failed'].includes(notification.email_status)) {
      await markEmailStatus(
        notification.id,
        'skipped',
        'Event disabled by user preferences',
      );
      result.email = 'skipped';
    }
    return result;
  }

  if (['pending', 'failed'].includes(notification.push_status)) {
    result.push = preferences.push_enabled
      ? await processPush(notification)
      : await skipPushByPreference(notification.id);
  }

  if (['pending', 'failed'].includes(notification.email_status)) {
    result.email = preferences.email_enabled
      ? await processEmail(notification)
      : await skipEmailByPreference(notification.id);
  }

  return result;
}

async function skipPushByPreference(id: string): Promise<string> {
  await markPushSkipped(id, 'Push disabled by user preferences');
  return 'skipped';
}

async function skipEmailByPreference(id: string): Promise<string> {
  await markEmailStatus(id, 'skipped', 'Email disabled by user preferences');
  return 'skipped';
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

  let accessToken = '';
  try {
    accessToken = await getFcmAccessToken();
  } catch (error) {
    await updateNotificationPushStatus(
      notification.id,
      'failed',
      `FCM credentials problem: ${errorMessage(error)}`.slice(0, 2000),
      null,
    );
    return 'failed';
  }

  let sent = 0;
  const errors: string[] = [];
  let disabledTokens = 0;
  let authFailures = 0;

  for (const device of tokens) {
    const result = await sendFcmMessage(notification, device, accessToken);
    if (result.ok) {
      sent += 1;
    } else {
      errors.push(result.error);
      if (result.reason === 'auth') authFailures += 1;
      if (result.disableToken) {
        await disableToken(device.token);
        disabledTokens += 1;
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

  if (disabledTokens > 0 && disabledTokens === tokens.length) {
    await markPushSkipped(
      notification.id,
      'No deliverable device tokens; invalid tokens were disabled',
    );
    return 'skipped';
  }

  const errorText = authFailures > 0
    ? `FCM credentials problem: ${errors.join('\n')}`
    : errors.join('\n');

  await updateNotificationPushStatus(
    notification.id,
    'failed',
    errorText.slice(0, 2000),
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

async function fetchPreferences(userId: string): Promise<NotificationPreferences> {
  const defaults: NotificationPreferences = {
    push_enabled: true,
    email_enabled: true,
    chat_enabled: true,
    casting_enabled: true,
    profile_enabled: true,
    system_enabled: true,
  };

  const { data, error } = await supabase
    .from('notification_preferences')
    .select(
      'push_enabled,email_enabled,chat_enabled,casting_enabled,' +
        'profile_enabled,system_enabled',
    )
    .eq('user_id', userId)
    .maybeSingle();

  if (error) {
    if (isMissingRelation(error)) return defaults;
    throw error;
  }

  return { ...defaults, ...(data ?? {}) } as NotificationPreferences;
}

function eventGroup(type: string): 'chat' | 'casting' | 'profile' | 'system' {
  if (type === 'chat_message') return 'chat';
  if (
    type === 'selection_invitation' ||
    type === 'video_intro_request' ||
    type.startsWith('casting_')
  ) {
    return 'casting';
  }
  if (type === 'profile_moderation' || type === 'casting_agent_moderation') {
    return 'profile';
  }
  return 'system';
}

function isGroupEnabled(
  preferences: NotificationPreferences,
  group: 'chat' | 'casting' | 'profile' | 'system',
) {
  if (group === 'chat') return preferences.chat_enabled;
  if (group === 'casting') return preferences.casting_enabled;
  if (group === 'profile') return preferences.profile_enabled;
  return preferences.system_enabled;
}

function isMissingRelation(error: { code?: string; message?: string }) {
  return error.code === '42P01' ||
    (error.message ?? '').includes('notification_preferences');
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
): Promise<FcmSendResult> {
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
  const reason = classifyFcmFailure(response.status, text);
  const disableToken = reason === 'invalid_token';
  const error = readableFcmError({
    platform: device.platform,
    status: response.status,
    reason,
    text,
  });

  return {
    ok: false,
    error,
    disableToken,
    reason,
  };
}

function classifyFcmFailure(
  status: number,
  text: string,
): FcmSendFailureReason {
  const normalized = text.toLowerCase();
  if (
    status === 401 ||
    status === 403 ||
    normalized.includes('third_party_auth_error') ||
    normalized.includes('unauthenticated') ||
    normalized.includes('permission_denied') ||
    normalized.includes('sender_id_mismatch')
  ) {
    return 'auth';
  }

  if (
    status === 404 ||
    normalized.includes('unregistered') ||
    normalized.includes('registration-token-not-registered') ||
    normalized.includes('invalid_registration') ||
    normalized.includes('invalid token') ||
    normalized.includes('invalid registration token') ||
    normalized.includes('registration token is not a valid')
  ) {
    return 'invalid_token';
  }

  if (status === 429 || normalized.includes('quota')) {
    return 'quota';
  }

  return 'unknown';
}

function readableFcmError({
  platform,
  status,
  reason,
  text,
}: {
  platform: string;
  status: number;
  reason: FcmSendFailureReason;
  text: string;
}) {
  const compact = text.replace(/\s+/g, ' ').trim().slice(0, 1200);
  if (reason === 'auth') {
    return `${platform}:${status}: FCM credentials problem (${compact})`;
  }
  if (reason === 'invalid_token') {
    return `${platform}:${status}: invalid push token disabled (${compact})`;
  }
  if (reason === 'quota') {
    return `${platform}:${status}: FCM quota/rate limit (${compact})`;
  }
  return `${platform}:${status}: FCM send failed (${compact})`;
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
  const appBaseUrl = publicAppUrl.replace(/\/$/, '');
  const logoUrl = appBaseUrl
    ? `${appBaseUrl}/assets/assets/images/pk-logo-red-512.png`
    : '';
  const isRussian = /[А-Яа-яЁё]/.test(`${notification.title} ${text}`);
  const ctaLabel = isRussian ? 'Открыть в приложении' : 'Open in app';
  const footerText = isRussian
    ? 'Это сервисное уведомление PK Management. Настройки уведомлений можно изменить в личном кабинете.'
    : 'This is a service notification from PK Management. You can change notification settings in your account.';
  const preheader = text.replace(/\s+/g, ' ').trim().slice(0, 140);
  const typeLabel = emailTypeLabel(notification.type, isRussian);
  const safeTitle = escapeHtml(notification.title);
  const safeText = escapeHtml(text).replaceAll('\n', '<br>');
  const safeUrl = escapeHtml(url);
  const safeLogoUrl = escapeHtml(logoUrl);
  const cta = url
    ? `
      <table role="presentation" cellspacing="0" cellpadding="0" border="0" style="margin:28px 0 0;width:auto">
        <tr>
          <td bgcolor="#1d1d1d" style="border-radius:999px;text-align:center">
            <a href="${safeUrl}" style="border:1px solid #1d1d1d;border-radius:999px;color:#ffffff;display:inline-block;font-family:Arial,Helvetica,sans-serif;font-size:13px;font-weight:700;letter-spacing:1.7px;line-height:18px;padding:14px 25px;text-decoration:none;text-transform:uppercase">${ctaLabel}</a>
          </td>
        </tr>
      </table>`
    : '';
  const brand = logoUrl
    ? `<img src="${safeLogoUrl}" width="54" height="54" alt="PK Management" style="border:0;display:block;height:54px;max-width:54px;object-fit:contain;width:54px">`
    : `<div style="color:#c60000;font-family:Arial,Helvetica,sans-serif;font-size:28px;font-weight:800;line-height:54px">PK</div>`;

  return `<!doctype html>
<html lang="${isRussian ? 'ru' : 'en'}">
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width,initial-scale=1">
    <meta name="x-apple-disable-message-reformatting">
    <title>${safeTitle}</title>
  </head>
  <body style="background:#eeeeee;margin:0;padding:0;width:100%">
    <div style="display:none;font-size:1px;color:#eeeeee;line-height:1px;max-height:0;max-width:0;opacity:0;overflow:hidden">${escapeHtml(preheader)}&#847;&zwnj;&nbsp;&#847;&zwnj;&nbsp;</div>
    <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" style="background:#eeeeee;border-collapse:collapse;width:100%">
      <tr>
        <td align="center" style="padding:24px 12px 36px">
          <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" style="border-collapse:separate;max-width:600px;width:100%">
            <tr>
              <td style="background:#242424;border-radius:22px 22px 0 0;padding:22px 26px">
                <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0">
                  <tr>
                    <td width="68" valign="middle">${brand}</td>
                    <td valign="middle">
                      <div style="color:#ffffff;font-family:Arial,Helvetica,sans-serif;font-size:15px;font-weight:800;letter-spacing:2.2px;line-height:20px">PK MANAGEMENT</div>
                      <div style="color:#bdbdbd;font-family:Arial,Helvetica,sans-serif;font-size:11px;letter-spacing:1.2px;line-height:18px;text-transform:uppercase">Model &amp; casting platform</div>
                    </td>
                  </tr>
                </table>
              </td>
            </tr>
            <tr>
              <td style="background:#ffffff;border-left:1px solid #dedede;border-right:1px solid #dedede;padding:34px 34px 36px">
                <div style="color:#c60000;font-family:Arial,Helvetica,sans-serif;font-size:11px;font-weight:800;letter-spacing:1.8px;line-height:16px;margin:0 0 14px;text-transform:uppercase">${escapeHtml(typeLabel)}</div>
                <h1 style="color:#202020;font-family:Arial,Helvetica,sans-serif;font-size:24px;font-weight:800;letter-spacing:1.2px;line-height:31px;margin:0 0 18px;text-transform:uppercase">${safeTitle}</h1>
                <div style="background:#f6f6f6;border-left:4px solid #c60000;border-radius:0 14px 14px 0;color:#404040;font-family:Arial,Helvetica,sans-serif;font-size:16px;line-height:25px;padding:20px 22px">${safeText}</div>
                ${cta}
              </td>
            </tr>
            <tr>
              <td style="background:#f8f8f8;border:1px solid #dedede;border-radius:0 0 22px 22px;border-top:0;padding:21px 34px 24px">
                <p style="color:#777777;font-family:Arial,Helvetica,sans-serif;font-size:12px;line-height:18px;margin:0">${footerText}</p>
                <p style="color:#aaaaaa;font-family:Arial,Helvetica,sans-serif;font-size:11px;line-height:17px;margin:10px 0 0">© ${new Date().getUTCFullYear()} PK Management · <a href="${escapeHtml(appBaseUrl)}" style="color:#777777;text-decoration:underline">app.pk.management</a></p>
              </td>
            </tr>
          </table>
        </td>
      </tr>
    </table>
  </body>
</html>`;
}

function emailTypeLabel(type: string, isRussian: boolean): string {
  const normalized = type.trim().toLowerCase();
  if (normalized.includes('support')) {
    return isRussian ? 'Поддержка' : 'Support';
  }
  if (normalized.includes('casting')) {
    return isRussian ? 'Кастинг' : 'Casting';
  }
  if (normalized.includes('chat') || normalized.includes('message')) {
    return isRussian ? 'Новое сообщение' : 'New message';
  }
  if (normalized.includes('profile') || normalized.includes('moderation')) {
    return isRussian ? 'Анкета' : 'Profile';
  }
  if (normalized.includes('security') || normalized.includes('email_change')) {
    return isRussian ? 'Безопасность' : 'Security';
  }
  if (normalized.includes('payment') || normalized.includes('billing')) {
    return isRussian ? 'Оплата' : 'Billing';
  }
  return isRussian ? 'Уведомление' : 'Notification';
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
