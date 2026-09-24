<template>
  <div>
    <PageHeader title="Training Record" subtitle="ประวัติการฝึกอบรมรายบุคคล (1 รายการ = พนักงาน 1 คน × 1 รอบอบรม) — Historical Excel + ข้อมูลใหม่ในฐานข้อมูลเดียวกัน">
      <ExportMenu :handler="doExport" :pdf="false" />
    </PageHeader>
    <div class="card">
      <div class="field mb"><label>ค้นหา</label>
        <input v-model="search" class="input" placeholder="รหัสพนักงาน / ชื่อพนักงาน / หลักสูตร / ฝ่าย / Provider" @input="debounced" /></div>
      <FilterBar v-model="filters" :fields="['years', 'months', 'date_from', 'date_to', 'departments', 'business_groups', 'companies', 'level_groups', 'training_types', 'categories', 'courses', 'providers', 'trainers']" />
    </div>
    <div class="card">
      <DataTable :columns="cols" :rows="rows" :loading="loading" :total="total" v-model:page="page" v-model:size="size" row-key="participant_id"
                 @sort="(s) => { order = s; load() }">
        <template #cell-employee_name="{ row }"><RouterLink :to="`/master/employees/${row.employee_id}`">{{ row.employee_name }}</RouterLink>
          <div class="small muted">{{ row.employee_code }}</div></template>
        <template #cell-session_name="{ row }"><RouterLink :to="`/training/sessions/${row.session_id}`">{{ row.session_name }}</RouterLink></template>
        <template #cell-training_type="{ row }"><span class="badge" :class="typeColor(row.training_type)">{{ row.training_type }}</span></template>
        <template #cell-attendance_status="{ row }"><span class="badge" :class="attendColor(row.attendance_status)">{{ row.attendance_status }}</span></template>
      </DataTable>
    </div>
  </div>
</template>
<script setup>
import { onMounted, ref, watch } from 'vue'
import PageHeader from '../../components/PageHeader.vue'
import DataTable from '../../components/DataTable.vue'
import FilterBar from '../../components/FilterBar.vue'
import ExportMenu from '../../components/ExportMenu.vue'
import { facts } from '../../lib/api'
import { typeColor, attendColor } from '../../lib/constants'
import { exportExcel, exportCSV, fileStamp } from '../../lib/export'
import { toast } from '../../lib/toast'

const rows = ref([]); const total = ref(0); const page = ref(1); const size = ref(50); const loading = ref(false)
const search = ref(''); const filters = ref({}); const order = ref({ key: 'start_date', asc: false })
const RECORD_COLS = [
  { key: 'start_date', label: 'วันที่อบรม', type: 'date' },
  { key: 'employee_name', label: 'พนักงาน' },
  { key: 'department_name', label: 'ฝ่าย' },
  { key: 'session_name', label: 'หลักสูตร / รอบอบรม' },
  { key: 'training_type', label: 'ประเภท' },
  { key: 'category_name', label: 'หมวดหมู่' },
  { key: 'training_hours', label: 'ชั่วโมง', type: 'number', digits: 1 },
  { key: 'attendance_status', label: 'การเข้าร่วม' },
  { key: 'completion_status', label: 'ผล' },
  { key: 'score', label: 'คะแนน', type: 'number', digits: 1 },
  { key: 'allocated_cost', label: 'Cost/คน', type: 'money' },
  { key: 'data_source', label: 'แหล่งข้อมูล' },
]
const cols = RECORD_COLS
async function load() {
  loading.value = true
  try { const r = await facts(filters.value, { page: page.value, size: size.value, search: search.value, order: order.value.key, asc: order.value.asc }); rows.value = r.rows; total.value = r.count }
  finally { loading.value = false }
}
let t; const debounced = () => { clearTimeout(t); t = setTimeout(() => { page.value = 1; load() }, 300) }
watch(filters, () => { page.value = 1; load() }, { deep: true })
watch([page, size], load)
onMounted(load)
async function doExport(kind) {
  if (total.value > 20000) toast(`กำลังดึงข้อมูล ${total.value.toLocaleString()} รายการ อาจใช้เวลาสักครู่`)
  const all = await facts(filters.value, { search: search.value, order: order.value.key, asc: order.value.asc, all: true })
  const ec = [{ key: 'employee_code', label: 'รหัสพนักงาน' }, { key: 'employee_name', label: 'ชื่อ-นามสกุล', width: 28 }, { key: 'nickname', label: 'ชื่อเล่น' },
    { key: 'company_name', label: 'บริษัท', width: 30 }, { key: 'business_group', label: 'กลุ่มธุรกิจ' }, { key: 'department_name', label: 'ฝ่าย', width: 30 },
    { key: 'level_group_name', label: 'กลุ่มระดับ' }, { key: 'position_name', label: 'ระดับตำแหน่ง' }, { key: 'course_name', label: 'Course', width: 45 },
    { key: 'session_name', label: 'รอบอบรม', width: 50 }, { key: 'start_date', label: 'วันที่เริ่ม', type: 'date' }, { key: 'end_date', label: 'วันที่สิ้นสุด', type: 'date' },
    { key: 'year', label: 'ปี (ค.ศ.)', type: 'number' }, { key: 'month', label: 'เดือน', type: 'number' }, { key: 'training_type', label: 'ประเภท' },
    { key: 'category_name', label: 'หมวดหมู่' }, { key: 'provider_name', label: 'Provider' }, { key: 'trainer_name', label: 'Trainer' },
    { key: 'training_hours', label: 'ชั่วโมง', type: 'number' }, { key: 'attendance_status', label: 'การเข้าร่วม' }, { key: 'completion_status', label: 'ผล' },
    { key: 'score', label: 'คะแนน', type: 'number' }, { key: 'evaluation_score', label: 'คะแนนประเมิน', type: 'number' }, { key: 'certificate_no', label: 'Certificate' },
    { key: 'allocated_cost', label: 'Cost/คน', type: 'money' }, { key: 'data_source', label: 'แหล่งข้อมูล' }]
  const name = fileStamp('Training_Record', [new Date().toISOString().slice(0, 10)])
  if (kind === 'csv') return exportCSV(`${name}.csv`, ec, all)
  return exportExcel(`${name}.xlsx`, [{ name: 'Training Record', title: 'Training Record', columns: ec, rows: all }])
}
</script>
