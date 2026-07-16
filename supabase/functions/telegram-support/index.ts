import { createClient } from "https://esm.sh/@supabase/supabase-js@2.48.1";

const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const botToken = Deno.env.get("TELEGRAM_BOT_TOKEN") ?? "";
const telegramSecret = Deno.env.get("TELEGRAM_WEBHOOK_SECRET") ?? "";
const dbWebhookSecret = Deno.env.get("SUPPORT_DB_WEBHOOK_SECRET") ?? "";
const supabase = createClient(supabaseUrl, serviceRoleKey, {
  auth: { persistSession: false },
});

type TelegramMessage = {
  chat?: { id?: number };
  from?: { id?: number; username?: string };
  text?: string;
};

type TelegramCallback = {
  id?: string;
  from?: { id?: number; username?: string };
  message?: TelegramMessage;
  data?: string;
};

const quickKeyboard = {
  inline_keyboard: [
    [{ text: "Анкета в каталоге", callback_data: "faq:profile_hidden" },
     { text: "Модерация", callback_data: "faq:moderation_time" }],
    [{ text: "Оплата размещения", callback_data: "faq:placement_payment" },
     { text: "Отклик на кастинг", callback_data: "faq:casting_response" }],
    [{ text: "Написать администратору", callback_data: "support:admin" }],
  ],
};

async function sendMessage(chatId: number, text: string, withKeyboard = false) {
  const response = await fetch(`https://api.telegram.org/bot${botToken}/sendMessage`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ chat_id: chatId, text, disable_web_page_preview: true,
      ...(withKeyboard ? { reply_markup: quickKeyboard } : {}) }),
  });
  if (!response.ok) throw new Error(`Telegram send failed: ${response.status}`);
}

async function answerCallback(callbackId: string) {
  await fetch(`https://api.telegram.org/bot${botToken}/answerCallbackQuery`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ callback_query_id: callbackId }),
  });
}

async function faqAnswerBySlug(slug: string): Promise<string | null> {
  const { data } = await supabase.from("support_faq").select("answer")
    .eq("slug", slug).eq("is_active", true).maybeSingle();
  return data?.answer ?? null;
}

function normalize(value: string) {
  return value.toLowerCase().replace(/ё/g, "е").replace(/[^a-zа-я0-9 ]/gi, " ");
}

async function faqAnswer(text: string): Promise<string | null> {
  const { data } = await supabase
    .from("support_faq")
    .select("answer,keywords")
    .eq("is_active", true)
    .order("sort_order");
  const normalized = normalize(text);
  let best: { score: number; answer: string } | null = null;
  for (const row of data ?? []) {
    const score = ((row.keywords as string[]) ?? []).filter((keyword) =>
      normalized.includes(normalize(keyword).trim())
    ).length;
    if (score > 0 && (!best || score > best.score)) best = { score, answer: row.answer };
  }
  return best?.answer ?? null;
}

async function linkedUser(chatId: number): Promise<string | null> {
  const { data } = await supabase
    .from("telegram_support_links")
    .select("user_id")
    .eq("telegram_chat_id", chatId)
    .is("revoked_at", null)
    .maybeSingle();
  return data?.user_id ?? null;
}

async function escalate(userId: string, chatId: number, body: string) {
  const { data: existing } = await supabase
    .from("support_tickets")
    .select("id")
    .eq("user_id", userId)
    .eq("channel", "telegram")
    .not("status", "in", '(resolved,closed)')
    .order("updated_at", { ascending: false })
    .limit(1)
    .maybeSingle();

  let ticketId = existing?.id as string | undefined;
  if (!ticketId) {
    const subject = body.length < 3
      ? "Вопрос из Telegram"
      : body.length > 80 ? `${body.slice(0, 77)}…` : body;
    const { data, error } = await supabase
      .from("support_tickets")
      .insert({ user_id: userId, channel: "telegram", category: "other", subject,
        status: "queued_for_admin" })
      .select("id")
      .single();
    if (error) throw error;
    ticketId = data.id;
  }
  const { error } = await supabase.from("support_messages").insert({
    ticket_id: ticketId,
    author_id: userId,
    author_kind: "user",
    body,
    source: "telegram",
  });
  if (error) throw error;
  await sendMessage(chatId, "Передал вопрос администратору. Ответ придёт сюда и сохранится в истории поддержки приложения.");
}

async function handleTelegramUpdate(payload: Record<string, unknown>) {
  const updateId = payload.update_id as number | undefined;
  const message = payload.message as TelegramMessage | undefined;
  const callback = payload.callback_query as TelegramCallback | undefined;
  const chatId = message?.chat?.id ?? callback?.message?.chat?.id;
  const text = message?.text?.trim();
  if (!updateId || !chatId || (!text && !callback?.data)) return;

  const { error: updateError } = await supabase
    .from("telegram_support_updates")
    .insert({ update_id: updateId, telegram_chat_id: chatId });
  if (updateError?.code === "23505") return;
  if (updateError) throw updateError;

  const since = new Date(Date.now() - 60_000).toISOString();
  const { count } = await supabase
    .from("telegram_support_updates")
    .select("update_id", { count: "exact", head: true })
    .eq("telegram_chat_id", chatId)
    .gte("received_at", since);
  if ((count ?? 0) > 12) return;

  if (callback?.id && callback.data) {
    await answerCallback(callback.id);
    if (callback.data.startsWith("faq:")) {
      const answer = await faqAnswerBySlug(callback.data.slice(4));
      await sendMessage(chatId, answer ?? "Ответ временно недоступен.", true);
      return;
    }
    if (callback.data === "support:admin") {
      const userId = await linkedUser(chatId);
      if (!userId) {
        await sendMessage(chatId,
          "Сначала привяжите Telegram в разделе «Помощь и поддержка» приложения.", true);
        return;
      }
      await escalate(userId, chatId, "Пользователь запросил помощь администратора.");
      return;
    }
  }

  if (!text) return;

  const startCode = text.match(/^\/start(?:\s+([A-Fa-f0-9]{8}))?$/)?.[1];
  if (startCode) {
    const { data } = await supabase.rpc("consume_telegram_support_link_code", {
      p_code: startCode,
      p_chat_id: chatId,
      p_telegram_user_id: message?.from?.id ?? chatId,
      p_username: message?.from?.username ?? null,
    });
    await sendMessage(chatId, data
      ? "Готово — Telegram безопасно привязан к вашему аккаунту PK Management. Задайте вопрос."
      : "Код недействителен или истёк. Создайте новый код в приложении.");
    return;
  }

  if (text === "/start" || text === "/help") {
    await sendMessage(chatId,
      "Выберите тему или задайте вопрос текстом. Если ответа не хватит, подключу администратора. Для персонального обращения сначала привяжите Telegram в разделе поддержки приложения.", true);
    return;
  }

  const userId = await linkedUser(chatId);
  const wantsAdmin = /(^|\s)(администратор|оператор|человек|поддержка)(\s|$)/i.test(text);
  const answer = wantsAdmin ? null : await faqAnswer(text);
  if (answer) {
    await sendMessage(chatId, `${answer}\n\nЕсли это не помогло, выберите связь с администратором.`, true);
    return;
  }
  if (!userId) {
    await sendMessage(chatId,
      "Для передачи вопроса администратору привяжите Telegram в разделе «Помощь и поддержка» приложения. Привязка нужна, чтобы защитить данные вашего аккаунта.");
    return;
  }
  await escalate(userId, chatId, text);
}

async function handleDatabaseWebhook(payload: Record<string, unknown>) {
  const record = payload.record as Record<string, unknown> | undefined;
  if (payload.table !== "support_messages" || payload.type !== "INSERT" ||
      record?.author_kind !== "admin" || record?.is_internal === true) return;
  const { data: ticket } = await supabase
    .from("support_tickets")
    .select("user_id,channel")
    .eq("id", record.ticket_id)
    .single();
  if (ticket?.channel !== "telegram") return;
  const { data: link } = await supabase
    .from("telegram_support_links")
    .select("telegram_chat_id")
    .eq("user_id", ticket.user_id)
    .is("revoked_at", null)
    .maybeSingle();
  if (link?.telegram_chat_id) await sendMessage(link.telegram_chat_id, `Ответ администратора:\n${record.body}`);
}

async function configureWebhooks() {
  const webhookUrl = `${supabaseUrl}/functions/v1/telegram-support`;
  const response = await fetch(`https://api.telegram.org/bot${botToken}/setWebhook`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({
      url: webhookUrl,
      secret_token: telegramSecret,
      allowed_updates: ["message", "callback_query"],
      drop_pending_updates: false,
    }),
  });
  const telegramResult = await response.json();
  if (!response.ok || telegramResult?.ok !== true) {
    throw new Error(`Telegram webhook setup failed: ${response.status}`);
  }
  const { error } = await supabase.rpc("configure_telegram_support_delivery", {
    p_secret: dbWebhookSecret,
  });
  if (error) throw error;
  return { ok: true, webhook: webhookUrl };
}

Deno.serve(async (request) => {
  if (request.method !== "POST") return new Response("Method not allowed", { status: 405 });
  if (!botToken || !telegramSecret || !dbWebhookSecret) {
    return new Response("Server is not configured", { status: 503 });
  }
  try {
    const payload = await request.json() as Record<string, unknown>;
    const telegramHeader = request.headers.get("x-telegram-bot-api-secret-token");
    const dbHeader = request.headers.get("x-support-webhook-secret");
    if (telegramHeader === telegramSecret) await handleTelegramUpdate(payload);
    else if (dbHeader === dbWebhookSecret && payload.action === "configure") {
      return Response.json(await configureWebhooks());
    } else if (dbHeader === dbWebhookSecret) await handleDatabaseWebhook(payload);
    else return new Response("Unauthorized", { status: 401 });
    return Response.json({ ok: true });
  } catch (error) {
    console.error("telegram-support", error);
    return Response.json({ ok: false }, { status: 500 });
  }
});
