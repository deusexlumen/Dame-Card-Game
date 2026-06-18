import path from 'path';
import react from '@vitejs/plugin-react';
import { defineConfig } from 'vite';
import { inspectAttr } from 'kimi-plugin-inspect-react';

export default defineConfig(({ mode }) => ({
  base: './',
  plugins: [mode !== 'production' ? inspectAttr() : null, react()].filter(Boolean),
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
