import { defineConfig, minimal2023Preset } from '@vite-pwa/assets-generator/config'

export default defineConfig({
  headLinkOptions: {
    preset: '2023',
    basePath: '/Dame-Card-Game/',
  },
  preset: {
    transparent: {
      sizes: [192, 512],
      favicons: [[48, 'favicon.ico']],
      padding: 0.05,
    },
    maskable: {
      sizes: [192, 512],
      padding: 0.3,
      resizeOptions: { background: '#0a0f0a', fit: 'contain' },
    },
    apple: {
      sizes: [180],
      padding: 0.3,
      resizeOptions: { background: '#0a0f0a', fit: 'contain' },
    },
  },
  images: ['public/favicon.svg'],
})
