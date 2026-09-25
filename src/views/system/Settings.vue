<template>
  <div>
    <PageHeader title="ตั้งค่าทั่วไป" subtitle="ตั้งค่าทั่วไปของระบบ" />
    <div class="card" style="max-width:640px">
      <div class="field"><label>เป้าหมายจำนวนหลักสูตรต่อคนต่อปี (Training Target)</label>
        <div class="row"><input v-model.number="target" type="number" min="1" class="input" style="width:120px" /><button class="btn primary" @click="save">บันทึก</button></div>
        <p class="small muted">ค่าเริ่มต้น 2 ตาม Excel Dashboard เดิม ("completed of Target 2 Course : Year") — ใช้ใน Dashboard และ Training Target Report</p></div>
    </div>
  </div>
</template>
<script setup>
import { onMounted, ref } from 'vue'
import PageHeader from '../../components/PageHeader.vue'
import { supabase, must } from '../../lib/supabase'
import { toastOk, toastError } from '../../lib/toast'
const target = ref(2)
onMounted(async () => { const { data } = await supabase.from('app_settings').select('value').eq('key', 'training_target_per_year').maybeSingle(); if (data) target.value = Number(data.value) })
async function save() {
  try { await must(supabase.from('app_settings').upsert({ key: 'training_target_per_year', value: target.value })); toastOk('บันทึกแล้ว') } catch (e) { toastError(e) }
}
</script>
