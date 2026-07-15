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

async function sendMessage(chatId: number, text: string) {
  const response = await fetch(`https://api.telegram.org/bot${botToken}/sendMessage`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ chat_id: chatId, text, disable_web_page_preview: true }),
  });
  if (!response.ok) throw new Error(`Telegram send failed: ${response.status}`);
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
  const chatId = message?.chat?.id;
  const text = message?.text?.trim();
  if (!updateId || !chatId || !text) return;

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
      "Я отвечаю на вопросы об анкетах, модерации, оплате и кастингах. Если ответа не хватит, напишите «администратор». Для персонального обращения сначала привяжите Telegram в разделе поддержки приложения.");
    return;
  }

  const userId = await linkedUser(chatId);
  const wantsAdmin = /(^|\s)(администратор|оператор|человек|поддержка)(\s|$)/i.test(text);
  const answer = wantsAdmin ? null : await faqAnswer(text);
  if (answer) {
    await sendMessage(chatId, `${answer}\n\nЕсли это не помогло, напишите «администратор».`);
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
    else if (dbHeader === dbWebhookSecret) await handleDatabaseWebhook(payload);
    else return new Response("Unauthorized", { status: 401 });
    return Response.json({ ok: true });
  } catch (error) {
    console.error("telegram-support", error);
    return Response.json({ ok: false }, { status: 500 });
  }
});
