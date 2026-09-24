import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'

// Relative base + hash router → the build works on GitHub Pages (sub-path) and any static host.
export default defineConfig({
  base: './',
  plugins: [vue()],
  build: {
    chunkSizeWarningLimit: 2000,
    rollupOptions: {
      output: {
        manualChunks(id) {
          if (id.includes('node_modules/echarts') || id.includes('node_modules/zrender')) return 'echarts'
          if (id.includes('node_modules/exceljs')) return 'exceljs'
          if (id.includes('node_modules/html2pdf') || id.includes('node_modules/jspdf') || id.includes('node_modules/html2canvas')) return 'pdf'
        },
      },
    },
  },
})
