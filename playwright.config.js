const { defineConfig, devices } = require('@playwright/test');

module.exports = defineConfig({
  testDir: './tool/e2e',
  timeout: 45_000,
  expect: { timeout: 20_000 },
  retries: 1,
  workers: 1,
  reporter: [['list']],
  use: {
    baseURL: process.env.WEB_BASE_URL || 'https://app.pk.management',
    ...devices['Desktop Chrome'],
    navigationTimeout: 30_000,
    trace: 'retain-on-failure',
  },
});
