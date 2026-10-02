// og-page — link previews for public profile and selection links.
//
// Caddy sends requests from link-preview bots (Telegram, WhatsApp, VK, …)
// for /p/:id and /s/:id here (see deploy/Caddyfile). The function answers
// with a tiny HTML page carrying Open Graph tags (title, description, photo)
// so the messenger renders a card instead of a bare URL. Humans never land
// here: non-bot traffic gets the Flutter app from Caddy as usual, and the
// page still redirects to the app just in case.
import { createClient } from 'npm:@supabase/supabase-js@2.48.1';

const APP_ORIGIN = Deno.env.get('PUBLIC_APP_ORIGIN') ?? 'https://app.pk.management';
const SITE_NAME = 'PK Management';
const OG_IMAGE_WIDTH = 1200;

type ProfileRow = {
  id: string;
  full_name: string | null;
  age: number | null;
  height: number | null;
  city: string | null;
  status: string | null;
  photo_urls: string[] | null;
  cover_photo_url: string | null;
};

type SelectionRow = {
  id: string;
  title: string | null;
  is_public: boolean | null;
};

function supabase() {
  const url = Deno.env.get('SUPABASE_URL');
  const key = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (!url || !key) throw new Error('SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY are not set');
  return createClient(url, key, { auth: { persistSession: false } });
}

function escapeHtml(value: string): string {
  return value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#39;');
}

/// Public Storage object → resized render URL (Supabase image transforms).
function ogImage(url: string | null | undefined): string | null {
  const clean = (url ?? '').trim();
  if (!clean) return null;
  const marker = '/storage/v1/object/public/';
  if (!clean.includes(marker)) return clean;
  const [base] = clean.split('?');
  const rendered = base.replace(marker, '/storage/v1/render/image/public/');
  return `${rendered}?width=${OG_IMAGE_WIDTH}&quality=80`;
}

function yearsRu(n: number): string {
  const mod10 = n % 10;
  const mod100 = n % 100;
  if (mod10 === 1 && mod100 !== 11) return `${n} год`;
  if (mod10 >= 2 && mod10 <= 4 && (mod100 < 10 || mod100 >= 20)) return `${n} года`;
  return `${n} лет`;
}

function page(opts: {
  title: string;
  description: string;
  image: string | null;
  url: string;
  type?: string;
}): Response {
  const title = escapeHtml(opts.title);
  const description = escapeHtml(opts.description);
  const url = escapeHtml(opts.url);
  const image = opts.image ? escapeHtml(opts.image) : null;
  const html = `<!doctype html>
<html lang="ru">
<head>
<meta charset="utf-8">
<title>${title}</title>
<meta name="description" content="${description}">
<meta property="og:type" content="${opts.type ?? 'profile'}">
<meta property="og:site_name" content="${SITE_NAME}">
<meta property="og:title" content="${title}">
<meta property="og:description" content="${description}">
<meta property="og:url" content="${url}">
${image ? `<meta property="og:image" content="${image}">
<meta property="og:image:width" content="${OG_IMAGE_WIDTH}">
<meta name="twitter:card" content="summary_large_image">
<meta name="twitter:image" content="${image}">` : '<meta name="twitter:card" content="summary">'}
<meta name="twitter:title" content="${title}">
<meta name="twitter:description" content="${description}">
<link rel="canonical" href="${url}">
<meta http-equiv="refresh" content="0;url=${url}">
</head>
<body>
<p><a href="${url}">${title}</a></p>
</body>
</html>`;
  return new Response(html, {
    status: 200,
    headers: {
      'content-type': 'text/html; charset=utf-8',
      'cache-control': 'public, max-age=300',
    },
  });
}

function fallback(path: string): Response {
  return page({
    title: SITE_NAME,
    description: 'Кастинги, модели и подборки — в одном кабинете',
    image: `${APP_ORIGIN}/icons/Icon-512.png`,
    url: `${APP_ORIGIN}${path}`,
    type: 'website',
  });
}

async function profilePage(id: string, path: string): Promise<Response> {
  const sb = supabase();
  const { data, error } = await sb
    .from('profiles')
    .select('id, full_name, age, height, city, status, photo_urls, cover_photo_url')
    .eq('id', id)
    .maybeSingle<ProfileRow>();
  if (error || !data || (data.status && data.status !== 'approved')) {
    return fallback(path);
  }
  const name = (data.full_name ?? '').trim() || 'Анкета модели';
  const parts: string[] = [];
  if (data.age && data.age > 0) parts.push(yearsRu(data.age));
  if (data.height && data.height > 0) parts.push(`${data.height} см`);
  if ((data.city ?? '').trim()) parts.push((data.city ?? '').trim());
  const photo = data.cover_photo_url || data.photo_urls?.[0] || null;
  return page({
    title: `${name} — ${SITE_NAME}`,
    description: parts.length ? parts.join(' · ') : `Анкета модели на ${SITE_NAME}`,
    image: ogImage(photo),
    url: `${APP_ORIGIN}${path}`,
  });
}

async function selectionPage(id: string, path: string): Promise<Response> {
  const sb = supabase();
  const { data, error } = await sb
    .from('selections')
    .select('id, title, is_public')
    .eq('id', id)
    .maybeSingle<SelectionRow>();
  if (error || !data) return fallback(path);

  const { data: items } = await sb
    .from('selection_items')
    .select('profile:profiles(full_name, photo_urls, cover_photo_url, status)')
    .eq('selection_id', id)
    .limit(12);
  const profiles = (items ?? [])
    .map((row) => (row as { profile: ProfileRow | null }).profile)
    .filter((p): p is ProfileRow => !!p && (!p.status || p.status === 'approved'));
  const first = profiles[0];
  const photo = first ? first.cover_photo_url || first.photo_urls?.[0] || null : null;
  const count = profiles.length;
  const title = (data.title ?? '').trim() || 'Подборка моделей';
  return page({
    title: `${title} — ${SITE_NAME}`,
    description: count > 0 ? `Подборка: ${count} ${count === 1 ? 'модель' : count < 5 ? 'модели' : 'моделей'}` : 'Подборка моделей',
    image: ogImage(photo),
    url: `${APP_ORIGIN}${path}`,
    type: 'website',
  });
}

Deno.serve(async (req) => {
  const url = new URL(req.url);
  // Caddy rewrites /p/<id> → /og-page?path=/p/<id>; direct calls may pass it too.
  const path = (url.searchParams.get('path') ?? url.pathname.replace(/^\/og-page/, '')).trim();
  const m = path.match(/^\/(p|s)\/([^/?#]+)/);
  try {
    if (m) {
      const id = decodeURIComponent(m[2]);
      return m[1] === 'p' ? await profilePage(id, path) : await selectionPage(id, path);
    }
    return fallback(path || '/');
  } catch (error) {
    console.error('og-page failed', error);
    return fallback(path || '/');
  }
});
