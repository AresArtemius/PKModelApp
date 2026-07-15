import {
  createClient,
  type SupabaseClient,
} from 'https://esm.sh/@supabase/supabase-js@2.48.1';

const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
const webhookSecret = Deno.env.get('YOOKASSA_WEBHOOK_SECRET') ?? '';

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return corsResponse();
  if (req.method !== 'POST') {
    return json({ error: 'Method not allowed' }, 405);
  }

  try {
    if (!supabaseUrl || !serviceRoleKey) {
      return json(
        { error: 'Supabase service credentials are not configured' },
        500,
      );
    }

    if (!webhookSecret) {
      return json({ error: 'Webhook secret is not configured' }, 503);
    }

    if (!isSecretValid(req)) {
      return json({ error: 'Webhook secret mismatch' }, 401);
    }

    const supabase = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const payload = await readJson(req);
    const event = asString(payload.event);
    const object = asRecord(payload.object);
    const providerPaymentId = asString(object?.id);

    if (!event || !providerPaymentId) {
      return json({ error: 'Invalid YooKassa webhook payload' }, 400);
    }

    await storeWebhookEvent(supabase, event, providerPaymentId, payload);

    if (event === 'payment.succeeded') {
      const { data, error } = await supabase.rpc(
        'apply_yookassa_profile_payment_succeeded',
        {
          p_provider_payment_id: providerPaymentId,
          p_provider_payload: payload,
        },
      );
      if (error) throw error;
      await markWebhookProcessed(supabase, providerPaymentId);
      return json({ ok: true, status: 'processed', payment_id: data });
    }

    if (event === 'payment.canceled') {
      const { error } = await supabase.rpc(
        'mark_yookassa_profile_payment_canceled',
        {
          p_provider_payment_id: providerPaymentId,
          p_provider_payload: payload,
        },
      );
      if (error) throw error;
      await markWebhookProcessed(supabase, providerPaymentId);
      return json({ ok: true, status: 'canceled' });
    }

    await markWebhookIgnored(
      supabase,
      providerPaymentId,
      `Ignored event: ${event}`,
    );
    return json({ ok: true, status: 'ignored', event });
  } catch (error) {
    return json({ error: errorMessage(error) }, 500);
  }
});

function isSecretValid(req: Request): boolean {
  const headerSecret =
    req.headers.get('x-yookassa-webhook-secret') ??
    req.headers.get('x-webhook-secret') ??
    '';
  const urlSecret = new URL(req.url).searchParams.get('secret') ?? '';
  return headerSecret === webhookSecret || urlSecret === webhookSecret;
}

async function storeWebhookEvent(
  supabase: SupabaseClient,
  event: string,
  providerPaymentId: string,
  payload: Record<string, unknown>,
) {
  const { error } = await supabase
    .from('billing_webhook_events')
    .upsert(
      {
        provider: 'yookassa',
        provider_event_id: providerPaymentId,
        event_type: event,
        related_payment_id: providerPaymentId,
        payload,
        processing_status: 'received',
      },
      { onConflict: 'provider,provider_event_id' },
    );
  if (error) throw error;
}

async function markWebhookProcessed(
  supabase: SupabaseClient,
  providerPaymentId: string,
) {
  await updateWebhookStatus(supabase, providerPaymentId, 'processed', '');
}

async function markWebhookIgnored(
  supabase: SupabaseClient,
  providerPaymentId: string,
  reason: string,
) {
  await updateWebhookStatus(supabase, providerPaymentId, 'ignored', reason);
}

async function updateWebhookStatus(
  supabase: SupabaseClient,
  providerPaymentId: string,
  status: string,
  errorText: string,
) {
  const { error } = await supabase
    .from('billing_webhook_events')
    .update({
      processing_status: status,
      processing_error: errorText,
      processed_at: new Date().toISOString(),
    })
    .eq('provider', 'yookassa')
    .eq('provider_event_id', providerPaymentId);
  if (error) throw error;
}

async function readJson(req: Request): Promise<Record<string, unknown>> {
  try {
    const value = await req.json();
    return value && typeof value === 'object' && !Array.isArray(value)
      ? value as Record<string, unknown>
      : {};
  } catch (_) {
    return {};
  }
}

function asRecord(value: unknown): Record<string, unknown> | null {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return null;
  return value as Record<string, unknown>;
}

function asString(value: unknown): string {
  return typeof value === 'string' ? value.trim() : '';
}

function errorMessage(error: unknown): string {
  if (error instanceof Error) return error.message;
  return String(error);
}

function corsHeaders() {
  return {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-webhook-secret, x-yookassa-webhook-secret',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
  };
}

function corsResponse() {
  return new Response('ok', { headers: corsHeaders() });
}

function json(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders(),
      'Content-Type': 'application/json',
    },
  });
}
