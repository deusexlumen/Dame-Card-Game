import { defineConfig, devices } from '@playwright/test';

// Online-Test: zwei Seiten des Godot-Web-Exports verbinden sich per WebRTC.
// Bewusst getrennt von playwright.godot.config.ts: der Deploy-Workflow fuehrt jene
// Specs aus, dieser Test gehoert erst hinein, wenn er sich mehrfach stabil gezeigt hat.
export default defineConfig({
  testDir: './e2e-online',
  fullyParallel: false,
  workers: 1,
  reporter: 'list',
  // Zwei 3D-Instanzen unter SwiftShader: grosszuegig.
  timeout: 600000,
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
        launchOptions: {
          // Ohne mDNS-Abschaltung bekam die Seite keine nutzbaren lokalen Kandidaten.
          args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--disable-features=WebRtcHideLocalIpsWithMdns'],
        },
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
