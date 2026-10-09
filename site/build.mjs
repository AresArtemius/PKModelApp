// Builds the public site into site/dist:
//   • copies site/public as is (landing, styles, assets);
//   • step 24: generates /p/<id>/ (approved profiles) and /s/<id>/ (public
//     selections) from Supabase through the anon key — the same RLS that the
//     app's public pages use;
//   • sitemap.xml, robots.txt, 404.html.
// Zero dependencies — runs with plain Node 20+ (fetch is built in).
//
// Env: SITE_URL (default https://pk.management), APP_URL (default
// https://app.pk.management), SUPABASE_URL + SUPABASE_ANON_KEY (without them
// the dynamic pages are skipped and only the landing is built).
import { cpSync, mkdirSync, rmSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = dirname(fileURLToPath(import.meta.url));
const dist = join(root, 'dist');
const siteUrl = (process.env.SITE_URL || 'https://pk.management').replace(/\/$/, '');
const appUrl = (process.env.APP_URL || 'https://app.pk.management').replace(/\/$/, '');
const supabaseUrl = (process.env.SUPABASE_URL || '').replace(/\/$/, '');
const supabaseKey = process.env.SUPABASE_ANON_KEY || '';

rmSync(dist, { recursive: true, force: true });
mkdirSync(dist, { recursive: true });
cpSync(join(root, 'public'), dist, { recursive: true });

const pages = [{ loc: '/', priority: '1.0', changefreq: 'weekly' }];

// ------------------------------------------------------------------ helpers

const esc = (s) =>
  String(s ?? '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');

const trim = (s) => String(s ?? '').trim();

/** Supabase Storage image transform (same as the app's storageImageVariant). */
function imageVariant(url, width, quality = 80) {
  const u = trim(url);
  const seg = '/storage/v1/object/public/';
  if (!u.includes(seg)) return u;
  try {
    const parsed = new URL(u);
    if (/\.(mp4|mov|webm|m4v|avi)$/i.test(parsed.pathname)) return u;
    parsed.pathname = parsed.pathname.replace(seg, '/storage/v1/render/image/public/');
    parsed.searchParams.set('width', String(width));
    parsed.searchParams.set('resize', 'contain');
    parsed.searchParams.set('quality', String(quality));
    return parsed.toString();
  } catch {
    return u;
  }
}

function photosOf(p) {
  const list = Array.isArray(p.photo_urls) ? p.photo_urls.map(trim).filter(Boolean) : [];
  const cover = trim(p.cover_photo_url);
  if (cover && !list.includes(cover)) list.unshift(cover);
  else if (cover) {
    list.splice(list.indexOf(cover), 1);
    list.unshift(cover);
  }
  return list;
}

function ageOf(p) {
  const explicit = Number(p.age);
  if (Number.isFinite(explicit) && explicit > 0) return explicit;
  const bd = trim(p.birth_date);
  if (!bd) return 0;
  const d = new Date(bd);
  if (Number.isNaN(d.getTime())) return 0;
  const now = new Date();
  let age = now.getFullYear() - d.getFullYear();
  const m = now.getMonth() - d.getMonth();
  if (m < 0 || (m === 0 && now.getDate() < d.getDate())) age -= 1;
  return age > 0 ? age : 0;
}

const yearsRu = (n) => {
  const m10 = n % 10;
  const m100 = n % 100;
  if (m10 === 1 && m100 !== 11) return `${n} год`;
  if (m10 >= 2 && m10 <= 4 && (m100 < 10 || m100 >= 20)) return `${n} года`;
  return `${n} лет`;
};

const roleLabel = {
  model: 'Модель',
  actor: 'Актёр',
  photographer: 'Фотограф',
  videographer: 'Видеограф',
  stylist: 'Стилист',
  makeup_artist: 'Визажист',
  hair_stylist: 'Парикмахер',
};

function metaLine(p) {
  const parts = [];
  const role = roleLabel[trim(p.profile_type)] || 'Модель';
  parts.push(role);
  const age = ageOf(p);
  if (age) parts.push(yearsRu(age));
  if (Number(p.height) > 0) parts.push(`${p.height} см`);
  if (trim(p.city)) parts.push(trim(p.city));
  return parts.join(' · ');
}

function layout({ title, description, canonical, ogImage, body, jsonLd, noindex = false, rel = './' }) {
  // `rel` points at the site root from the page ("../../" for /p/<id>/), so
  // the pages also work under a sub-path such as app.pk.management/landing/.
  return `<!doctype html>
<html lang="ru">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>${esc(title)}</title>
  <meta name="description" content="${esc(description)}">
  <link rel="canonical" href="${esc(canonical)}">
  ${noindex ? '<meta name="robots" content="noindex">' : ''}
  <link rel="icon" href="${rel}favicon.png" type="image/png">
  <meta name="theme-color" content="#ffffff">
  <meta property="og:type" content="profile">
  <meta property="og:site_name" content="PK Management">
  <meta property="og:title" content="${esc(title)}">
  <meta property="og:description" content="${esc(description)}">
  <meta property="og:url" content="${esc(canonical)}">
  ${ogImage ? `<meta property="og:image" content="${esc(ogImage)}">` : ''}
  <meta property="og:locale" content="ru_RU">
  <meta name="twitter:card" content="${ogImage ? 'summary_large_image' : 'summary'}">
  <link rel="preload" href="${rel}fonts/GolosText-Regular.woff" as="font" type="font/woff" crossorigin>
  <link rel="preload" href="${rel}fonts/GolosText-Bold.woff" as="font" type="font/woff" crossorigin>
  <link rel="stylesheet" href="${rel}styles.css">
  ${jsonLd ? `<script type="application/ld+json">${JSON.stringify(jsonLd)}</script>` : ''}
</head>
<body>
  <a class="skip" href="#main">К содержанию</a>
  <header class="site-header">
    <div class="wrap">
      <a class="brand" href="${rel}" aria-label="PK Management — на главную"><img src="${rel}assets/logo-96.png" width="32" height="32" alt="">PK Management</a>
      <nav class="nav" aria-label="Разделы">
        <a href="${appUrl}/search">Каталог</a>
        <a href="${appUrl}/castings">Кастинги</a>
        <a href="${rel}#pricing">Тарифы</a>
      </nav>
      <div class="header-actions">
        <a class="btn btn-ghost" href="${appUrl}/login">Войти</a>
        <a class="btn btn-primary" href="${appUrl}/register">Создать анкету</a>
      </div>
    </div>
  </header>
  <main id="main">
${body}
  </main>
  <footer class="site-footer">
    <div class="wrap">
      <div class="footer-grid">
        <div class="footer-col">
          <a class="brand" href="${rel}" aria-label="PK Management"><img src="${rel}assets/logo-96.png" width="32" height="32" alt="">PK Management</a>
          <p>Платформа для моделей, родителей, агентств и заказчиков.</p>
        </div>
        <div class="footer-col">
          <b>Приложение</b>
          <div class="footer-links">
            <a href="${appUrl}/search">Каталог</a>
            <a href="${appUrl}/castings">Кастинги</a>
            <a href="${appUrl}/login">Войти</a>
          </div>
        </div>
        <div class="footer-col">
          <b>Документы</b>
          <div class="footer-links">
            <a href="${appUrl}/privacy">Политика конфиденциальности</a>
            <a href="${appUrl}/terms">Пользовательское соглашение</a>
            <a href="${appUrl}/child-safety">Безопасность детей</a>
          </div>
        </div>
      </div>
      <div class="legal">© 2026 ООО «Модельное агентство “Биг Вест”»</div>
    </div>
  </footer>
</body>
</html>
`;
}

// ------------------------------------------------------------------ pages

function profilePage(p) {
  const name = trim(p.full_name) || 'Анкета';
  const photos = photosOf(p);
  const cover = photos[0] || '';
  const meta = metaLine(p);
  const canonical = `${siteUrl}/p/${p.id}/`;
  const facts = [
    ['Город', [trim(p.city), trim(p.country)].filter(Boolean).join(', ')],
    ['Возраст', ageOf(p) ? yearsRu(ageOf(p)) : ''],
    ['Рост', Number(p.height) > 0 ? `${p.height} см` : ''],
    [
      'Параметры',
      Number(p.bust) > 0 || Number(p.waist) > 0 || Number(p.hips) > 0
        ? `${p.bust || '–'} / ${p.waist || '–'} / ${p.hips || '–'}`
        : '',
    ],
    ['Обувь', Number(p.shoe_size) > 0 ? String(p.shoe_size) : ''],
    ['Глаза', trim(p.eye_color)],
    ['Волосы', trim(p.hair_color)],
  ].filter(([, v]) => v);
  const sections = [
    ['О себе', trim(p.resume)],
    ['Опыт', trim(p.experience)],
    ['Навыки', trim(p.skills)],
  ].filter(([, v]) => v);
  const description = [name, meta, trim(p.resume)].filter(Boolean).join(' — ').slice(0, 180);
  const appLink = `${appUrl}/model/${p.id}`;

  const body = `
    <section class="profile">
      <div class="wrap">
        <p class="crumbs"><a href="../../">Главная</a> · <a href="${appUrl}/search">Каталог</a></p>
        <div class="profile-grid">
          <div class="profile-gallery">
            ${
              photos.length
                ? `<div class="photo-grid">${photos
                    .slice(0, 12)
                    .map(
                      (u, i) =>
                        `<a class="photo" href="${esc(u)}" target="_blank" rel="noopener"><img src="${esc(
                          imageVariant(u, 600),
                        )}" alt="${esc(name)} — фото ${i + 1}" loading="${i < 2 ? 'eager' : 'lazy'}" width="600" height="800"></a>`,
                    )
                    .join('')}</div>`
                : '<div class="photo-empty">Фото пока нет</div>'
            }
          </div>
          <aside class="profile-side">
            <h1>${esc(name)}</h1>
            <p class="muted">${esc(meta)}</p>
            <div class="profile-actions">
              <a class="btn btn-accent" href="${appLink}">Пригласить на кастинг</a>
              <a class="btn btn-outline" href="${appLink}">Открыть в приложении</a>
            </div>
            ${
              facts.length
                ? `<dl class="facts">${facts
                    .map(([k, v]) => `<div><dt>${esc(k)}</dt><dd>${esc(v)}</dd></div>`)
                    .join('')}</dl>`
                : ''
            }
            ${sections
              .map(([k, v]) => `<h2 class="h-small">${esc(k)}</h2><p class="text">${esc(v)}</p>`)
              .join('')}
            <p class="note">Контакты и бронирование — только через приложение. Анкета проверена модерацией PK Management.</p>
          </aside>
        </div>
      </div>
    </section>`;

  const jsonLd = {
    '@context': 'https://schema.org',
    '@type': 'Person',
    name,
    url: canonical,
    ...(cover ? { image: imageVariant(cover, 1200) } : {}),
    ...(trim(p.city) ? { address: { '@type': 'PostalAddress', addressLocality: trim(p.city) } } : {}),
    jobTitle: roleLabel[trim(p.profile_type)] || 'Модель',
  };

  return layout({
    title: `${name} — ${meta} · PK Management`,
    description,
    canonical,
    ogImage: cover ? imageVariant(cover, 1200) : `${siteUrl}/assets/og.jpg`,
    body,
    jsonLd,
    rel: '../../',
  });
}

function selectionPage(s, profiles) {
  const title = trim(s.title) || 'Подборка';
  const canonical = `${siteUrl}/s/${s.id}/`;
  const client = [trim(s.client_name), trim(s.brand_name)].filter(Boolean).join(' · ');
  const first = profiles.find((p) => photosOf(p).length);
  const body = `
    <section class="profile">
      <div class="wrap">
        <p class="crumbs"><a href="../../">Главная</a> · Подборка</p>
        <div class="section-head">
          <p class="eyebrow">Подборка${client ? ` · ${esc(client)}` : ''}</p>
          <h1>${esc(title)}</h1>
          <p>${profiles.length} ${profiles.length === 1 ? 'анкета' : profiles.length < 5 ? 'анкеты' : 'анкет'}. Открыть в приложении, чтобы оставить отзыв по кандидатам.</p>
          <div class="profile-actions"><a class="btn btn-primary" href="${appUrl}/s/${s.id}">Открыть в приложении</a></div>
        </div>
        <div class="model-grid">
          ${profiles
            .map((p) => {
              const photos = photosOf(p);
              const name = trim(p.full_name) || 'Анкета';
              return `<a class="model-card" href="../../p/${p.id}/">
                <span class="model-photo">${
                  photos[0]
                    ? `<img src="${esc(imageVariant(photos[0], 600))}" alt="${esc(name)}" loading="lazy" width="600" height="800">`
                    : ''
                }</span>
                <b>${esc(name)}</b>
                <span class="muted">${esc(metaLine(p))}</span>
              </a>`;
            })
            .join('')}
        </div>
      </div>
    </section>`;
  return layout({
    title: `${title} · подборка PK Management`,
    description: `Подборка «${title}»: ${profiles.length} анкет. Открыть в приложении PK Management.`,
    canonical,
    ogImage: first ? imageVariant(photosOf(first)[0], 1200) : `${siteUrl}/assets/og.jpg`,
    body,
    noindex: true, // selections are shared by link, not meant for search
    rel: '../../',
  });
}

function modelCard(p, rel) {
  const photos = photosOf(p);
  const name = trim(p.full_name) || 'Анкета';
  return `<a class="model-card" href="${rel}p/${p.id}/">
    <span class="model-photo">${
      photos[0]
        ? `<img src="${esc(imageVariant(photos[0], 600))}" alt="${esc(name)}" loading="lazy" width="600" height="800">`
        : ''
    }</span>
    <b>${esc(name)}</b>
    <span class="muted">${esc(metaLine(p))}</span>
  </a>`;
}

function modelsPage(profiles) {
  const canonical = `${siteUrl}/models/`;
  const cities = [...new Set(profiles.map((p) => trim(p.city)).filter(Boolean))].slice(0, 12);
  const body = `
    <section class="profile">
      <div class="wrap">
        <div class="section-head">
          <p class="eyebrow">Витрина</p>
          <h1>Модели и таланты</h1>
          <p>${profiles.length} ${profiles.length === 1 ? 'анкета' : profiles.length < 5 ? 'анкеты' : 'анкет'} прошли модерацию PK Management${cities.length ? ` · ${esc(cities.join(', '))}` : ''}. Параметры, фильтры по росту и возрасту, подборки и приглашения — в приложении.</p>
          <div class="profile-actions"><a class="btn btn-primary" href="${appUrl}/search">Открыть каталог с фильтрами</a></div>
        </div>
        <div class="model-grid">${profiles.map((p) => modelCard(p, '../')).join('')}</div>
      </div>
    </section>`;
  return layout({
    title: 'Модели и таланты — каталог PK Management',
    description: `Каталог проверенных анкет детских и взрослых моделей, актёров и специалистов: ${profiles.length} анкет с фото и параметрами. Подборки и приглашения на кастинг — в приложении.`,
    canonical,
    ogImage: `${siteUrl}/assets/og.jpg`,
    body,
    rel: '../',
    jsonLd: {
      '@context': 'https://schema.org',
      '@type': 'CollectionPage',
      name: 'Модели и таланты — PK Management',
      url: canonical,
    },
  });
}

const monthsGen = ['января','февраля','марта','апреля','мая','июня','июля','августа','сентября','октября','ноября','декабря'];

/** "2026-10-02T00:00:00,2026-10-03T00:00:00" → "2–3 октября 2026"; free text stays. */
function datesLabel(raw) {
  const text = trim(raw);
  if (!text) return '';
  const parts = text.split(/[,;\s]+/).map(trim).filter(Boolean);
  const dates = parts.map((x) => new Date(x)).filter((d) => !Number.isNaN(d.getTime()));
  if (!dates.length || dates.length !== parts.length) return text;
  dates.sort((a, b) => a - b);
  const f = (d) => `${d.getDate()} ${monthsGen[d.getMonth()]} ${d.getFullYear()}`;
  const a = dates[0];
  const b = dates[dates.length - 1];
  if (dates.length === 1) return f(a);
  if (a.getMonth() === b.getMonth() && a.getFullYear() === b.getFullYear()) {
    return `${a.getDate()}–${b.getDate()} ${monthsGen[a.getMonth()]} ${a.getFullYear()}`;
  }
  return `${f(a)} — ${f(b)}`;
}

function feeLabel(raw) {
  const text = trim(raw);
  if (!text) return '';
  const n = Number(text.replace(/\s/g, ''));
  if (!Number.isFinite(n) || n <= 0) return text;
  return `${n.toLocaleString('ru-RU')} ₽`;
}

const stageLabel = {
  intake: 'Набор',
  accepting_applications: 'Открыт приём откликов',
  shortlist: 'Шорт-лист',
  callback: 'Колбэк',
  approval: 'Утверждение',
  shoot: 'Съёмка',
  completed: 'Завершён',
};

function castingsPage(castings) {
  const canonical = `${siteUrl}/castings/`;
  const body = `
    <section class="profile">
      <div class="wrap">
        <div class="section-head">
          <p class="eyebrow">Кастинги</p>
          <h1>Открытые кастинги</h1>
          <p>Отклик отправляется из приложения с выбранной анкетой; статус отклика виден в аккаунте.</p>
        </div>
        ${
          castings.length
            ? `<div class="casting-list">${castings
                .map(
                  (c) => `<a class="casting" href="${appUrl}/castings?casting=${c.id}">
                    <span class="casting-stage">${esc(stageLabel[trim(c.project_stage)] || 'Открыт')}</span>
                    <b>${esc(trim(c.title) || 'Кастинг')}</b>
                    ${trim(c.description) ? `<p>${esc(trim(c.description).slice(0, 220))}${trim(c.description).length > 220 ? '…' : ''}</p>` : ''}
                    <span class="muted">${[datesLabel(c.dates), feeLabel(c.fee)].filter(Boolean).map(esc).join(' · ')}</span>
                  </a>`,
                )
                .join('')}</div>`
            : '<p class="muted">Сейчас открытых кастингов нет — новые появляются в приложении.</p>'
        }
      </div>
    </section>`;
  return layout({
    title: 'Открытые кастинги — PK Management',
    description: 'Актуальные кастинги для моделей и актёров: даты, гонорар, условия. Откликнуться можно из приложения PK Management.',
    canonical,
    ogImage: `${siteUrl}/assets/og.jpg`,
    body,
    rel: '../',
  });
}

// ------------------------------------------------------------------ data

async function rest(path) {
  const res = await fetch(`${supabaseUrl}/rest/v1/${path}`, {
    headers: { apikey: supabaseKey, Authorization: `Bearer ${supabaseKey}` },
  });
  if (!res.ok) throw new Error(`${path} → ${res.status} ${await res.text()}`);
  return res.json();
}

const profileColumns =
  'id,full_name,birth_date,age,height,city,country,eye_color,hair_color,bust,waist,hips,shoe_size,profile_type,resume,experience,skills,photo_urls,cover_photo_url,updated_at';

async function generate() {
  if (!supabaseUrl || !supabaseKey) {
    console.log('SUPABASE_URL / SUPABASE_ANON_KEY not set — dynamic pages skipped');
    return;
  }
  let profiles = [];
  try {
    profiles = await rest(`catalog_profiles?select=${profileColumns}&order=updated_at.desc&limit=2000`);
  } catch (e) {
    // Older schema without some columns: fall back to the essentials.
    console.warn(`catalog_profiles full select failed (${e.message.slice(0, 120)}), retrying with fewer columns`);
    profiles = await rest(
      'catalog_profiles?select=id,full_name,age,height,city,photo_urls,cover_photo_url&limit=2000',
    );
  }
  profiles = profiles.filter((p) => p.id && trim(p.full_name));
  for (const p of profiles) {
    const dir = join(dist, 'p', p.id);
    mkdirSync(dir, { recursive: true });
    writeFileSync(join(dir, 'index.html'), profilePage(p));
    pages.push({ loc: `/p/${p.id}/`, priority: '0.7', changefreq: 'weekly', lastmod: p.updated_at });
  }
  console.log(`profiles: ${profiles.length}`);
  mkdirSync(join(dist, 'models'), { recursive: true });
  writeFileSync(join(dist, 'models', 'index.html'), modelsPage(profiles));
  pages.push({ loc: '/models/', priority: '0.9', changefreq: 'daily' });

  // Castings: readable by anon only if the table's RLS allows it; otherwise
  // the page says there are none right now.
  let castings = [];
  try {
    castings = await rest('castings?select=id,title,description,fee,dates,project_stage,created_at&order=created_at.desc&limit=100');
    castings = castings.filter((c) => ['intake', 'accepting_applications', ''].includes(trim(c.project_stage)));
  } catch (e) {
    console.warn(`castings not readable: ${e.message.slice(0, 120)}`);
  }
  mkdirSync(join(dist, 'castings'), { recursive: true });
  writeFileSync(join(dist, 'castings', 'index.html'), castingsPage(castings));
  pages.push({ loc: '/castings/', priority: '0.8', changefreq: 'daily' });
  console.log(`castings: ${castings.length}`);

  const byId = new Map(profiles.map((p) => [p.id, p]));
  let selections = [];
  try {
    selections = await rest('selections?select=id,title,client_name,brand_name,created_at&is_public=eq.true&limit=500');
  } catch (e) {
    console.warn(`selections with campaign fields failed, retrying: ${e.message.slice(0, 120)}`);
    selections = await rest('selections?select=id,title,created_at&is_public=eq.true&limit=500');
  }
  let written = 0;
  for (const s of selections) {
    const items = await rest(`selection_items?select=profile_id,created_at&selection_id=eq.${s.id}&order=created_at.asc`);
    const list = items.map((i) => byId.get(i.profile_id)).filter(Boolean);
    if (!list.length) continue;
    const dir = join(dist, 's', s.id);
    mkdirSync(dir, { recursive: true });
    writeFileSync(join(dir, 'index.html'), selectionPage(s, list));
    written += 1;
  }
  console.log(`selections: ${written} of ${selections.length}`);
}

await generate();

// ------------------------------------------------------------------ extras

writeFileSync(
  join(dist, '404.html'),
  layout({
    title: 'Страница не найдена — PK Management',
    description: 'Такой страницы нет.',
    canonical: `${siteUrl}/404.html`,
    noindex: true,
    body: `<section><div class="wrap"><p class="eyebrow">404</p><h1>Страница не найдена</h1><p class="lead">Такой страницы нет, или анкета больше не опубликована.</p><a class="btn btn-primary" href="./">На главную</a></div></section>`,
  }),
);

writeFileSync(join(dist, 'robots.txt'), `User-agent: *\nAllow: /\nDisallow: /s/\nSitemap: ${siteUrl}/sitemap.xml\n`);

writeFileSync(
  join(dist, 'sitemap.xml'),
  `<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n${pages
    .map(
      (p) =>
        `  <url><loc>${siteUrl}${p.loc}</loc>${p.lastmod ? `<lastmod>${String(p.lastmod).slice(0, 10)}</lastmod>` : ''}<changefreq>${p.changefreq}</changefreq><priority>${p.priority}</priority></url>`,
    )
    .join('\n')}\n</urlset>\n`,
);

console.log(`site built → ${dist} (${pages.length} urls in sitemap)`);
