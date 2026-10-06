import path from 'path';
import react from '@vitejs/plugin-react';
import { defineConfig } from 'vite';
import { VitePWA } from 'vite-plugin-pwa';
import { inspectAttr } from 'kimi-plugin-inspect-react';

export default defineConfig(({ mode }) => ({
  base: '/Dame-Card-Game/',
  plugins: [
    mode !== 'production' ? inspectAttr() : null,
    react(),
    VitePWA({
      registerType: 'autoUpdate',
      base: '/Dame-Card-Game/',
      manifest: {
        id: '/Dame-Card-Game/',
        name: 'DAME — Gedächtnis, Risiko & Bluff',
        short_name: 'DAME',
        description:
          'Taktisches Memory-Kartenspiel mit Bluff-Element für 2–6 Spieler. Mensch gegen Mensch oder gegen KI.',
        theme_color: '#0a0f0a',
        background_color: '#0a0f0a',
        display: 'standalone',
        orientation: 'portrait',
        start_url: '/Dame-Card-Game/',
        scope: '/Dame-Card-Game/',
        lang: 'de',
        icons: [
          {
            src: 'pwa-192x192.png',
            sizes: '192x192',
            type: 'image/png',
          },
          {
            src: 'pwa-512x512.png',
            sizes: '512x512',
            type: 'image/png',
          },
          {
            src: 'maskable-icon-192x192.png',
            sizes: '192x192',
            type: 'image/png',
            purpose: 'maskable',
          },
          {
            src: 'maskable-icon-512x512.png',
            sizes: '512x512',
            type: 'image/png',
            purpose: 'maskable',
          },
        ],
      },
      workbox: {
        globPatterns: ['**/*.{js,css,html,ico,png,svg,webp,woff2,mp3,wav}'],
        maximumFileSizeToCacheInBytes: 5 * 1024 * 1024,
      },
      includeAssets: [
        'favicon.svg',
        'favicon.ico',
        'pwa-192x192.png',
        'pwa-512x512.png',
        'maskable-icon-192x192.png',
        'maskable-icon-512x512.png',
        'apple-touch-icon-180x180.png',
      ],
    }),
  ].filter(Boolean),
  resolve: {
    alias: {
      '@': path.resolve(__dirname, './src'),
    },
  },
  build: {
    rollupOptions: {
      output: {
        manualChunks(id) {
          // node_modules in separate Chunks aufteilen
          if (id.includes('node_modules')) {
            if (id.includes('react') || id.includes('scheduler')) {
              return 'react-vendor';
            }
            if (id.includes('lucide')) {
              return 'icons';
            }
            if (id.includes('@radix-ui') || id.includes('class-variance')) {
              return 'ui-vendor';
            }
            return 'vendor';
          }
        },
      },
    },
    chunkSizeWarningLimit: 600,
  },
}));
