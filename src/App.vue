<template>
  <div v-if="!IS_CONFIGURED" class="login-wrap">
    <div class="login-card">
      <h2>ASW Training Record</h2>
      <p class="alert warn mt">ระบบยังไม่ได้ตั้งค่าการเชื่อมต่อฐานข้อมูล (VITE_SUPABASE_URL / VITE_SUPABASE_ANON_KEY)</p>
    </div>
  </div>
  <div v-else-if="!auth.ready" class="loading-block" style="min-height:100vh"><span class="spinner"></span> กำลังโหลด ASW Training Record...</div>
  <template v-else>
    <RouterView />
  </template>
  <Toasts />
</template>
<script setup>
import Toasts from './components/Toasts.vue'
import { auth } from './lib/auth'
import { IS_CONFIGURED } from './lib/config'
</script>
