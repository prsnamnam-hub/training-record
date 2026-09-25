<template>
  <div>
    <PageHeader title="ผู้ใช้งาน (Users)" subtitle="เพิ่ม / ลบผู้ใช้งาน · กำหนด Role (Admin / HR-Training / Viewer) · เปิด/ปิดการใช้งาน · ตั้งรหัสผ่านใหม่">
      <button class="btn primary" @click="openCreate">+ เพิ่มผู้ใช้</button>
    </PageHeader>
    <div class="alert mb">Admin เพิ่มผู้ใช้พร้อมรหัสผ่านได้ที่ปุ่ม <b>+ เพิ่มผู้ใช้</b> (ใช้งานได้ทันที ไม่ต้องยืนยันอีเมล) · ผู้ที่ลงทะเบียนเองที่หน้า Login จะได้สิทธิ์ <b>Viewer</b> — Admin เปลี่ยน Role ได้ที่ตารางนี้ · ผู้ใช้คนแรกของระบบเป็น Admin</div>
    <div class="card">
      <DataTable :columns="cols" :rows="rows" :loading="loading">
        <template #cell-role="{ row }">
          <select v-model="row.role" class="input" style="width:auto" :disabled="row.id === auth.profile?.id" @change="save(row)">
            <option value="admin">Admin</option><option value="hr_training">HR / Training</option><option value="viewer">Viewer</option></select>
        </template>
        <template #cell-is_active="{ row }">
          <label><input type="checkbox" v-model="row.is_active" :disabled="row.id === auth.profile?.id" @change="save(row)" /> {{ row.is_active ? 'Active' : 'Disabled' }}</label>
        </template>
        <template #actions="{ row }">
          <button class="btn sm" @click="pw = { user_id: row.id, email: row.email, password: '' }">ตั้งรหัสผ่าน</button>
          <button v-if="row.id !== auth.profile?.id" class="btn sm danger" :disabled="busy" @click="removeUser(row)">ลบ</button>
        </template>
      </DataTable>
    </div>

    <Modal :open="!!form" title="เพิ่มผู้ใช้" @close="form = null">
      <div v-if="form" class="form-grid">
        <div class="field"><label>อีเมล <span class="req">*</span></label><input v-model="form.email" type="email" class="input" autocomplete="off" /></div>
        <div class="field"><label>ชื่อ-นามสกุล</label><input v-model="form.full_name" class="input" /></div>
        <div class="field"><label>รหัสผ่าน <span class="req">*</span></label><input v-model="form.password" type="password" class="input" autocomplete="new-password" :placeholder="`อย่างน้อย ${MIN_PASSWORD} ตัวอักษร`" /></div>
        <div class="field"><label>Role</label><select v-model="form.role" class="input">
          <option value="admin">Admin</option><option value="hr_training">HR / Training</option><option value="viewer">Viewer</option></select></div>
      </div>
      <template #footer>
        <button class="btn" @click="form = null">ยกเลิก</button>
        <button class="btn primary" :disabled="busy || !form?.email || (form?.password || '').length < MIN_PASSWORD" @click="createUser">บันทึก</button>
      </template>
    </Modal>

    <Modal :open="!!pw" :title="`ตั้งรหัสผ่านใหม่ — ${pw?.email || ''}`" @close="pw = null">
      <div v-if="pw" class="field"><label>รหัสผ่านใหม่ <span class="req">*</span></label>
        <input v-model="pw.password" type="password" class="input" autocomplete="new-password" :placeholder="`อย่างน้อย ${MIN_PASSWORD} ตัวอักษร`" /></div>
      <template #footer>
        <button class="btn" @click="pw = null">ยกเลิก</button>
        <button class="btn primary" :disabled="busy || (pw?.password || '').length < MIN_PASSWORD" @click="setPassword">บันทึก</button>
      </template>
    </Modal>
  </div>
</template>
<script setup>
import { onMounted, ref } from 'vue'
import PageHeader from '../../components/PageHeader.vue'
import DataTable from '../../components/DataTable.vue'
import Modal from '../../components/Modal.vue'
import { supabase, must } from '../../lib/supabase'
import { auth } from '../../lib/auth'
import { dateTimeTH } from '../../lib/format'
import { toastOk, toastError } from '../../lib/toast'
const MIN_PASSWORD = 8
const rows = ref([]); const loading = ref(true); const busy = ref(false)
const form = ref(null); const pw = ref(null)
const cols = [{ key: 'email', label: 'อีเมล' }, { key: 'full_name', label: 'ชื่อ' }, { key: 'role', label: 'Role' }, { key: 'is_active', label: 'สถานะ' },
  { key: 'created_at', label: 'สร้างเมื่อ', format: (r) => dateTimeTH(r.created_at) }]
async function load() { loading.value = true; try { rows.value = await must(supabase.from('profiles').select('*').order('created_at')) } finally { loading.value = false } }
async function save(r) {
  try { await must(supabase.from('profiles').update({ role: r.role, is_active: r.is_active }).eq('id', r.id)); toastOk(`อัปเดต ${r.email} แล้ว`) }
  catch (e) { toastError(e); load() }
}
// Creating users / setting passwords needs the service_role key → Edge Function "admin-users" (admin only).
async function adminUsers(body) {
  const { data, error } = await supabase.functions.invoke('admin-users', { body })
  if (error) {
    const detail = await error.context?.json?.().catch(() => null)
    throw new Error(detail?.error || error.message)
  }
  return data
}
function openCreate() { form.value = { email: '', full_name: '', password: '', role: 'viewer' } }
async function createUser() {
  busy.value = true
  try { await adminUsers({ action: 'create', ...form.value }); toastOk(`เพิ่มผู้ใช้ ${form.value.email} แล้ว`); form.value = null; load() }
  catch (e) { toastError(e) } finally { busy.value = false }
}
async function setPassword() {
  busy.value = true
  try { await adminUsers({ action: 'set_password', user_id: pw.value.user_id, password: pw.value.password }); toastOk(`ตั้งรหัสผ่านใหม่ให้ ${pw.value.email} แล้ว`); pw.value = null }
  catch (e) { toastError(e) } finally { busy.value = false }
}
async function removeUser(r) {
  if (!confirm(`ลบผู้ใช้ ${r.email}?\nผู้ใช้นี้จะเข้าสู่ระบบไม่ได้อีก (ประวัติการแก้ไขใน Audit Log ยังคงอยู่)`)) return
  busy.value = true
  try { await adminUsers({ action: 'delete', user_id: r.id }); toastOk(`ลบผู้ใช้ ${r.email} แล้ว`); load() }
  catch (e) { toastError(e) } finally { busy.value = false }
}
onMounted(load)
</script>
