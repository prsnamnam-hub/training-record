<template>
  <div class="login-wrap">
    <div class="login-card">
      <div class="logo">
        <img class="logo-img" :src="logo" alt="ASSET WISE" />
        <div class="small muted" style="margin-top:6px">{{ APP_NAME }} — {{ APP_TAGLINE }}</div>
      </div>
      <div class="tabs">
        <button :class="{ on: mode === 'in' }" @click="mode = 'in'">เข้าสู่ระบบ</button>
        <button :class="{ on: mode === 'up' }" @click="mode = 'up'">ลงทะเบียน</button>
        <button :class="{ on: mode === 'reset' }" @click="mode = 'reset'">ลืมรหัสผ่าน</button>
      </div>
      <form @submit.prevent="submit" class="grid" style="gap:12px">
        <div v-if="mode === 'up'" class="field"><label>ชื่อ-นามสกุล</label><input v-model="name" class="input" required /></div>
        <div class="field"><label>อีเมล</label><input v-model="email" type="email" class="input" autocomplete="username" required /></div>
        <div v-if="mode !== 'reset'" class="field"><label>รหัสผ่าน</label>
          <input v-model="password" type="password" class="input" :autocomplete="mode === 'up' ? 'new-password' : 'current-password'" minlength="8" required /></div>
        <div v-if="error" class="alert err">{{ error }}</div>
        <div v-if="info" class="alert ok">{{ info }}</div>
        <button class="btn primary" :disabled="busy" style="justify-content:center">
          {{ mode === 'in' ? 'เข้าสู่ระบบ' : mode === 'up' ? 'ลงทะเบียน' : 'ส่งลิงก์ตั้งรหัสผ่านใหม่' }}
        </button>
        <p v-if="mode === 'up'" class="small muted">ผู้ลงทะเบียนใหม่จะได้สิทธิ์ Viewer — Admin สามารถเปลี่ยน Role ได้ที่เมนู Settings › Users</p>
      </form>
    </div>
  </div>
</template>
<script setup>
import { ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { APP_NAME, APP_TAGLINE } from '../lib/config'
import { signIn, signUp, resetPassword } from '../lib/auth'

const logo = import.meta.env.BASE_URL + 'logo-assetwise.png'

const router = useRouter()
const route = useRoute()
const mode = ref('in')
const email = ref('')
const password = ref('')
const name = ref('')
const error = ref('')
const info = ref('')
const busy = ref(false)
const TH_ERR = {
  'Invalid login credentials': 'อีเมลหรือรหัสผ่านไม่ถูกต้อง',
  'Email not confirmed': 'ยังไม่ได้ยืนยันอีเมล — กรุณาเปิดลิงก์ยืนยันในอีเมลของคุณ',
  'User already registered': 'อีเมลนี้ลงทะเบียนแล้ว',
}
async function submit() {
  error.value = ''; info.value = ''; busy.value = true
  try {
    if (mode.value === 'in') {
      await signIn(email.value, password.value)
      router.replace(route.query.next || '/dashboard')
    } else if (mode.value === 'up') {
      const r = await signUp(email.value, password.value, name.value)
      if (r.session) router.replace('/dashboard')
      else info.value = 'ลงทะเบียนสำเร็จ — กรุณายืนยันอีเมลจากลิงก์ที่ส่งไป แล้วกลับมาเข้าสู่ระบบ'
    } else {
      await resetPassword(email.value)
      info.value = 'ส่งลิงก์ตั้งรหัสผ่านใหม่ไปที่อีเมลแล้ว'
    }
  } catch (e) {
    error.value = TH_ERR[e.message] || e.message
  } finally { busy.value = false }
}
</script>
