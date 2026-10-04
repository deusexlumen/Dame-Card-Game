import { defineConfig, devices } from '@playwright/test';

// Smoke-Test fuer den Godot-Web-Export (build/web). Getrennt vom React-E2E.
export default defineConfig({
  testDir: './e2e-godot',
  fullyParallel: false,
  workers: 1,
  reporter: 'list',
  timeout: 90000,
  use: {
    baseURL: 'http://localhost:8060',
    headless: true,
    locale: 'de-DE',
  },
  projects: [
    {
      name: 'chromium',
      use: {
        ...devices['Desktop Chrome'],
        viewport: { width: 1280, height: 720 },
        launchOptions: { args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader'] },
      },
    },
  ],
  webServer: {
    command: 'node scripts/serve-static.mjs build/web 8060',
    url: 'http://localhost:8060',
    reuseExistingServer: !process.env.CI,
    stdout: 'pipe',
    stderr: 'pipe',
  },
});
