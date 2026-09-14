import { defineConfig } from 'vite'
import RubyPlugin from 'vite-plugin-ruby'

export default defineConfig({
  plugins: [
    RubyPlugin(),
  ],
  build: {
    assetsInlineLimit: (filePath: string) => (filePath.endsWith('.svg') ? false : undefined),
  },
})
