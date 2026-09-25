<template>
  <div class="login-wrap">
    <div class="login-card">
      <h2>ตั้งรหัสผ่านใหม่</h2>
      <p class="small muted">ASW Training Record</p>
      <form class="grid mt" style="gap:12px" @submit.prevent="save">
        <div class="field"><label>รหัสผ่านใหม่ (อย่างน้อย 6 ตัวอักษร)</label>
          <input v-model="pw" type="password" minlength="6" class="input" autocomplete="new-password" required /></div>
        <div v-if="msg" class="alert" :class="ok ? 'ok' : 'err'">{{ msg }}</div>
        <button class="btn primary" style="justify-content:center">บันทึก</button>
        <RouterLink to="/login" class="small">กลับไปหน้าเข้าสู่ระบบ</RouterLink>
      </form>
    </div>
  </div>
</template>
<script setup>
import { ref } from 'vue'
import { supabase } from '../lib/supabase'
const pw = ref(''); const msg = ref(''); const ok = ref(false)
async function save() {
  const { error } = await supabase.auth.updateUser({ password: pw.value })
  ok.value = !error
  msg.value = error ? error.message : 'เปลี่ยนรหัสผ่านเรียบร้อย'
}
</script>
