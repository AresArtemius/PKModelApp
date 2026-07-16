const { test, expect } = require('@playwright/test');

const publicRoutes = [
  '/register',
  '/privacy',
  '/terms',
  '/cookies',
  '/processing-notice',
  '/requisites',
  '/search',
  '/castings',
];

async function openFlutterRoute(page, route) {
  const pageErrors = [];
  page.on('pageerror', (error) => pageErrors.push(error.message));

  await page.goto(`/#${route}`, { waitUntil: 'domcontentloaded' });
  await expect(page).toHaveTitle('PK Management');
  await expect(page.locator('flutter-view')).toBeAttached();
  await expect.poll(() => new URL(page.url()).hash).toContain(route);
  expect(pageErrors).toEqual([]);
}

for (const route of publicRoutes) {
  test(`public route opens: ${route}`, async ({ page }) => {
    await openFlutterRoute(page, route);
  });
}

test('anonymous user is redirected away from account', async ({ page }) => {
  await page.goto('/#/me', { waitUntil: 'domcontentloaded' });
  await expect(page.locator('flutter-view')).toBeAttached();
  await expect.poll(() => new URL(page.url()).hash).toContain('/auth-required');
});

test('anonymous user is redirected away from admin', async ({ page }) => {
  await page.goto('/#/admin', { waitUntil: 'domcontentloaded' });
  await expect(page.locator('flutter-view')).toBeAttached();
  await expect.poll(() => new URL(page.url()).hash).toContain('/login');
});

test('catalog cold start renders within the mobile budget', async ({
  browser,
}) => {
  const context = await browser.newContext({
    viewport: { width: 390, height: 844 },
    deviceScaleFactor: 2,
    isMobile: true,
    hasTouch: true,
  });
  const page = await context.newPage();
  const startedAt = Date.now();

  await page.goto('/#/search', { waitUntil: 'domcontentloaded' });
  await expect(page.locator('flutter-view')).toBeAttached();
  await expect.poll(() => new URL(page.url()).hash).toContain('/search');

  const renderMs = Date.now() - startedAt;
  expect(renderMs, `cold catalogue render took ${renderMs} ms`).toBeLessThan(
    15_000,
  );
  await context.close();
});

test('required static assets are available', async ({ request }) => {
  for (const path of [
    '/',
    '/manifest.json',
    '/flutter_bootstrap.js',
    '/main.dart.js',
    '/firebase-messaging-sw.js',
  ]) {
    const response = await request.get(path);
    expect(response.ok(), `${path} returned ${response.status()}`).toBeTruthy();
  }
});

test('public edge functions reject unauthorized calls', async ({ request }) => {
  const supabaseUrl = process.env.SUPABASE_URL;
  expect(supabaseUrl, 'SUPABASE_URL must be configured').toBeTruthy();

  const cases = [
    ['create-yookassa-payment', {}],
    ['yookassa-webhook', {}],
    ['telegram-support', {}],
  ];

  for (const [functionName, data] of cases) {
    const response = await request.post(
      `${supabaseUrl}/functions/v1/${functionName}`,
      { data },
    );
    expect(
      response.status(),
      `${functionName} must reject a request without credentials`,
    ).toBe(401);
  }
});
