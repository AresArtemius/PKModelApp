import {
  createClient,
  type SupabaseClient,
} from 'npm:@supabase/supabase-js@2.48.1';

const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
const webhookSecret = Deno.env.get('YOOKASSA_WEBHOOK_SECRET') ?? '';
const yookassaShopId = Deno.env.get('YOOKASSA_SHOP_ID') ?? '';
const yookassaSecretKey = Deno.env.get('YOOKASSA_SECRET_KEY') ?? '';

type BillingOrder = {
  id: string;
  profile_id: string;
  product_id: string;
  amount_minor: number;
  currency: string;
  provider_payment_id: string;
};

type BillingProduct = {
  code: string;
};

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

    if (
      !webhookSecret ||
      !yookassaShopId ||
      !yookassaSecretKey
    ) {
      return json({ error: 'YooKassa verification is not configured' }, 503);
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

    if (event === 'payment.succeeded') {
      const verified = await verifyPaymentWithYooKassa(
        supabase,
        providerPaymentId,
        'succeeded',
      );
      const verifiedPayload = {
        notification: payload,
        verified_payment: verified,
      };
      await storeWebhookEvent(
        supabase,
        event,
        providerPaymentId,
        verifiedPayload,
      );
      const { data, error } = await supabase.rpc(
        'apply_yookassa_profile_payment_succeeded',
        {
          p_provider_payment_id: providerPaymentId,
          p_provider_payload: verified,
        },
      );
      if (error) throw error;
      await markWebhookProcessed(supabase, providerPaymentId);
      return json({ ok: true, status: 'processed', payment_id: data });
    }

    if (event === 'payment.canceled') {
      const verified = await verifyPaymentWithYooKassa(
        supabase,
        providerPaymentId,
        'canceled',
      );
      const verifiedPayload = {
        notification: payload,
        verified_payment: verified,
      };
      await storeWebhookEvent(
        supabase,
        event,
        providerPaymentId,
        verifiedPayload,
      );
      const { error } = await supabase.rpc(
        'mark_yookassa_profile_payment_canceled',
        {
          p_provider_payment_id: providerPaymentId,
          p_provider_payload: verified,
        },
      );
      if (error) throw error;
      await markWebhookProcessed(supabase, providerPaymentId);
      return json({ ok: true, status: 'canceled' });
    }

    await storeWebhookEvent(supabase, event, providerPaymentId, payload);
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

async function verifyPaymentWithYooKassa(
  supabase: SupabaseClient,
  providerPaymentId: string,
  expectedStatus: 'succeeded' | 'canceled',
): Promise<Record<string, unknown>> {
  const { data: orderData, error: orderError } = await supabase
    .from('billing_payment_orders')
    .select(
      'id,profile_id,product_id,amount_minor,currency,provider_payment_id',
    )
    .eq('provider', 'yookassa')
    .eq('provider_payment_id', providerPaymentId)
    .maybeSingle();
  if (orderError) throw orderError;
  if (!orderData) throw new Error('Billing order was not found');

  const order = orderData as BillingOrder;
  const { data: productData, error: productError } = await supabase
    .from('billing_products')
    .select('code')
    .eq('id', order.product_id)
    .maybeSingle();
  if (productError) throw productError;
  if (!productData) throw new Error('Billing product was not found');
  const product = productData as BillingProduct;

  const response = await fetch(
    `https://api.yookassa.ru/v3/payments/${
      encodeURIComponent(providerPaymentId)
    }`,
    {
      method: 'GET',
      headers: {
        Authorization:
          `Basic ${btoa(`${yookassaShopId}:${yookassaSecretKey}`)}`,
        Accept: 'application/json',
      },
    },
  );
  const body = await response.json().catch(() => ({}));
  if (!response.ok) {
    throw new Error(`YooKassa verification failed: HTTP ${response.status}`);
  }

  const payment = asRecord(body);
  if (!payment) throw new Error('Invalid YooKassa payment response');
  const amount = asRecord(payment.amount);
  const metadata = asRecord(payment.metadata);
  const actualAmountMinor = rublesToMinor(asString(amount?.value));
  const actualCurrency = asString(amount?.currency).toUpperCase();
  const actualStatus = asString(payment.status);

  if (asString(payment.id) !== providerPaymentId) {
    throw new Error('YooKassa payment id mismatch');
  }
  if (actualStatus !== expectedStatus) {
    throw new Error(`Unexpected YooKassa payment status: ${actualStatus}`);
  }
  if (expectedStatus === 'succeeded' && payment.paid !== true) {
    throw new Error('YooKassa payment is not marked as paid');
  }
  if (actualAmountMinor !== Number(order.amount_minor)) {
    throw new Error('YooKassa payment amount mismatch');
  }
  if (actualCurrency !== asString(order.currency).toUpperCase()) {
    throw new Error('YooKassa payment currency mismatch');
  }
  if (asString(metadata?.order_id) !== order.id) {
    throw new Error('YooKassa order metadata mismatch');
  }
  if (asString(metadata?.profile_id) !== order.profile_id) {
    throw new Error('YooKassa profile metadata mismatch');
  }
  if (asString(metadata?.product_code) !== product.code) {
    throw new Error('YooKassa product metadata mismatch');
  }

  return payment;
}

function rublesToMinor(value: string): number {
  if (!/^\d+(?:\.\d{1,2})?$/.test(value)) {
    throw new Error('Invalid YooKassa payment amount');
  }
  const [rubles, kopecks = ''] = value.split('.');
  return Number(rubles) * 100 + Number(kopecks.padEnd(2, '0'));
}

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
