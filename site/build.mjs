// Builds the public site into site/dist: copies site/public as is and
// (steps 24–25) will add generated pages, sitemap.xml and robots.txt.
// Zero dependencies — runs with plain Node 20+.
import { cpSync, mkdirSync, rmSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = dirname(fileURLToPath(import.meta.url));
const dist = join(root, 'dist');
const siteUrl = process.env.SITE_URL || 'https://pk.management';

rmSync(dist, { recursive: true, force: true });
mkdirSync(dist, { recursive: true });
cpSync(join(root, 'public'), dist, { recursive: true });

// 404 page: the landing shell with a short message (Caddy serves it for
// unknown paths).
writeFileSync(
  join(dist, '404.html'),
  `<!doctype html><html lang="ru"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Страница не найдена — PK Management</title><meta name="robots" content="noindex"><link rel="stylesheet" href="styles.css"></head><body><main class="wrap" style="padding:96px 16px"><p class="eyebrow">404</p><h1>Страница не найдена</h1><p class="lead">Такой страницы нет или она была удалена.</p><a class="btn btn-primary" href="./">На главную</a></main></body></html>\n`,
);

writeFileSync(
  join(dist, 'robots.txt'),
  `User-agent: *\nAllow: /\nSitemap: ${siteUrl}/sitemap.xml\n`,
);

const pages = ['/'];
writeFileSync(
  join(dist, 'sitemap.xml'),
  `<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n${pages
    .map((p) => `  <url><loc>${siteUrl}${p}</loc></url>`)
    .join('\n')}\n</urlset>\n`,
);

console.log(`site built → ${dist}`);
