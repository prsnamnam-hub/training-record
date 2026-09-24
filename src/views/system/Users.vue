<template>
  <div>
    <PageHeader title="Users" subtitle="ผู้ใช้งานระบบ — กำหนด Role (Admin / HR-Training / Viewer) และเปิด/ปิดการใช้งาน" crumb="System" />
    <div class="alert mb">ผู้ใช้ใหม่ลงทะเบียนที่หน้า Login (หรือเพิ่มใน Supabase › Authentication) แล้วจะได้สิทธิ์ <b>Viewer</b> อัตโนมัติ — Admin เปลี่ยน Role ได้ที่ตารางนี้ · ผู้ใช้คนแรกของระบบเป็น Admin</div>
    <div class="card">
      <DataTable :columns="cols" :rows="rows" :loading="loading">
        <template #cell-role="{ row }">
          <select v-model="row.role" class="input" style="width:auto" :disabled="row.id === auth.profile?.id" @change="save(row)">
            <option value="admin">Admin</option><option value="hr_training">HR / Training</option><option value="viewer">Viewer</option></select>
        </template>
        <template #cell-is_active="{ row }">
          <label><input type="checkbox" v-model="row.is_active" :disabled="row.id === auth.profile?.id" @change="save(row)" /> {{ row.is_active ? 'Active' : 'Disabled' }}</label>
        </template>
      </DataTable>
    </div>
  </div>
</template>
<script setup>
import { onMounted, ref } from 'vue'
import PageHeader from '../../components/PageHeader.vue'
import DataTable from '../../components/DataTable.vue'
import { supabase, must } from '../../lib/supabase'
import { auth } from '../../lib/auth'
import { dateTimeTH } from '../../lib/format'
import { toastOk, toastError } from '../../lib/toast'
const rows = ref([]); const loading = ref(true)
const cols = [{ key: 'email', label: 'อีเมล' }, { key: 'full_name', label: 'ชื่อ' }, { key: 'role', label: 'Role' }, { key: 'is_active', label: 'สถานะ' },
  { key: 'created_at', label: 'สร้างเมื่อ', format: (r) => dateTimeTH(r.created_at) }]
async function load() { loading.value = true; try { rows.value = await must(supabase.from('profiles').select('*').order('created_at')) } finally { loading.value = false } }
async function save(r) {
  try { await must(supabase.from('profiles').update({ role: r.role, is_active: r.is_active }).eq('id', r.id)); toastOk(`อัปเดต ${r.email} แล้ว`) }
  catch (e) { toastError(e); load() }
}
onMounted(load)
</script>
