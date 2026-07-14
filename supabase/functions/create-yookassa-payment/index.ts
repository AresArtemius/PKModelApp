import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.48.1';

type PaymentOrder = {
  order_id: string;
  profile_id: string;
  product_code: string;
  amount_minor: number;
  currency: string;
  description: string;
  idempotency_key: string;
};

const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY') ?? '';
const yookassaShopId = Deno.env.get('YOOKASSA_SHOP_ID') ?? '';
const yookassaSecretKey = Deno.env.get('YOOKASSA_SECRET_KEY') ?? '';
const publicAppUrl = trimTrailingSlash(Deno.env.get('PUBLIC_APP_URL') ?? '');
const yookassaReturnUrl =
  Deno.env.get('YOOKASSA_RETURN_URL') ??
  (publicAppUrl ? `${publicAppUrl}/#/billing?payment=return` : '');

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return corsResponse();
  if (req.method !== 'POST') {
    return json({ error: 'Method not allowed' }, 405);
  }

  try {
    if (!supabaseUrl || !supabaseAnonKey) {
      return json({ error: 'Supabase credentials are not configured' }, 500);
    }
    if (!yookassaShopId || !yookassaSecretKey || !yookassaReturnUrl) {
      return json({ error: 'YooKassa credentials are not configured' }, 500);
    }

    const authHeader = req.headers.get('Authorization') ?? '';
    if (!authHeader.toLowerCase().startsWith('bearer ')) {
      return json({ error: 'Auth required' }, 401);
    }

    const payload = await readJson(req);
    const profileId = asString(payload.profile_id);
    const productCode = asString(payload.product_code);
    if (!profileId || !productCode) {
      return json({ error: 'profile_id and product_code are required' }, 400);
    }

    const supabase = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authHeader } },
      auth: { persistSession: false, autoRefreshToken: false },
    });

    const { data: orderData, error: orderError } = await supabase.rpc(
      'create_yookassa_profile_payment_order',
      {
        p_profile_id: profileId,
        p_product_code: productCode,
      },
    );
    if (orderError) throw orderError;

    const order = firstRow<PaymentOrder>(orderData);
    if (!order) {
      return json({ error: 'Payment order was not created' }, 500);
    }

    const payment = await createYooKassaPayment(order);
    const confirmationUrl = payment.confirmation?.confirmation_url ?? '';
    if (!payment.id || !confirmationUrl) {
      return json({ error: 'YooKassa did not return confirmation_url' }, 502);
    }

    const { error: markError } = await supabase.rpc(
      'mark_yookassa_profile_payment_started',
      {
        p_order_id: order.order_id,
        p_provider_payment_id: payment.id,
        p_confirmation_url: confirmationUrl,
        p_provider_payload: payment,
      },
    );
    if (markError) throw markError;

    return json({
      ok: true,
      order_id: order.order_id,
      provider_payment_id: payment.id,
      confirmation_url: confirmationUrl,
      status: payment.status ?? 'pending',
    });
  } catch (error) {
    return json({ error: errorMessage(error) }, 500);
  }
});

async function createYooKassaPayment(order: PaymentOrder) {
  const response = await fetch('https://api.yookassa.ru/v3/payments', {
    method: 'POST',
    headers: {
      Authorization: `Basic ${btoa(`${yookassaShopId}:${yookassaSecretKey}`)}`,
      'Content-Type': 'application/json',
      'Idempotence-Key': order.idempotency_key,
    },
    body: JSON.stringify({
      amount: {
        value: formatRub(order.amount_minor),
        currency: order.currency || 'RUB',
      },
      capture: true,
      confirmation: {
        type: 'redirect',
        return_url: yookassaReturnUrl,
      },
      description: order.description.slice(0, 128),
      metadata: {
        order_id: order.order_id,
        profile_id: order.profile_id,
        product_code: order.product_code,
      },
    }),
  });

  const body = await response.json().catch(() => ({}));
  if (!response.ok) {
    throw new Error(
      `YooKassa payment create failed: ${response.status} ${JSON.stringify(body)}`,
    );
  }
  return body as Record<string, any>;
}

function firstRow<T>(value: unknown): T | null {
  if (Array.isArray(value)) return (value[0] as T | undefined) ?? null;
  if (value && typeof value === 'object') return value as T;
  return null;
}

function asString(value: unknown): string {
  return typeof value === 'string' ? value.trim() : '';
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

function formatRub(minor: number): string {
  return (Math.max(0, Number(minor) || 0) / 100).toFixed(2);
}

function trimTrailingSlash(value: string): string {
  return value.replace(/\/+$/, '');
}

function errorMessage(error: unknown): string {
  if (error instanceof Error) return error.message;
  return String(error);
}

function corsHeaders() {
  return {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
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
