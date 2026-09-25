<template>
  <div class="login-wrap">
    <header class="login-brand">
      <img class="login-logo" :src="logo" alt="ASSET WISE" />
      <div class="login-app">{{ APP_NAME }}</div>
      <p class="login-tagline">แอสเซทไวส์ นิยามของการทำงานอย่างมี <b>“ความสุข”</b></p>
    </header>
    <div class="login-card">
      <h2 class="login-title">เข้าสู่ระบบ</h2>
      <form @submit.prevent="submit" class="grid" style="gap:14px">
        <div class="field"><label>อีเมล</label><input v-model="email" type="email" class="input" autocomplete="username" required /></div>
        <div class="field"><label>รหัสผ่าน</label>
          <input v-model="password" type="password" class="input" autocomplete="current-password" required /></div>
        <div v-if="error" class="alert err">{{ error }}</div>
        <button class="btn primary login-submit" :disabled="busy">{{ busy ? 'กำลังเข้าสู่ระบบ...' : 'เข้าสู่ระบบ' }}</button>
        <!-- accounts are created by an Admin (Settings › ผู้ใช้งาน), who can also set a new password -->
        <p class="small muted" style="text-align:center;margin:0">ยังไม่มีบัญชี หรือลืมรหัสผ่าน — ติดต่อผู้ดูแลระบบ (Admin)</p>
      </form>
    </div>
  </div>
</template>
<script setup>
import { ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { APP_NAME } from '../lib/config'
import { signIn } from '../lib/auth'

const logo = import.meta.env.BASE_URL + 'logo-assetwise-stacked.png'

const router = useRouter()
const route = useRoute()
const email = ref('')
const password = ref('')
const error = ref('')
const busy = ref(false)
const TH_ERR = {
  'Invalid login credentials': 'อีเมลหรือรหัสผ่านไม่ถูกต้อง',
  'Email not confirmed': 'บัญชียังไม่ได้ยืนยันอีเมล — กรุณาติดต่อผู้ดูแลระบบ',
}
async function submit() {
  error.value = ''; busy.value = true
  try {
    await signIn(email.value, password.value)
    router.replace(route.query.next || '/dashboard')
  } catch (e) {
    error.value = TH_ERR[e.message] || e.message
  } finally { busy.value = false }
}
</script>
