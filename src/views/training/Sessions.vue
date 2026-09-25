<template>
  <div>
    <PageHeader title="ประวัติการฝึกอบรม" subtitle="รายหลักสูตร — คลิกรายการเพื่อดูรายละเอียด แก้ไข หรือเพิ่มผู้เข้าอบรม">
      <ExportMenu :handler="doExport" :pdf="false" />
    </PageHeader>
    <HistorySwitch />
    <div class="card">
      <div class="filterbar">
        <div class="field" style="max-width:none;flex:2"><label>ค้นหา</label>
          <input v-model="search" class="input" placeholder="ชื่อหลักสูตร / Training ID / สถานที่ / Provider" @input="debounced" /></div>
        <div class="field"><label>ปี (พ.ศ.)</label><MultiSelect v-model="f.years" :options="yearOpts" /></div>
        <div class="field"><label>เดือน</label><MultiSelect v-model="f.months" :options="monthOpts" /></div>
        <div class="field"><label>ประเภท</label><MultiSelect v-model="f.types" :options="typeOpts" /></div>
        <div class="field"><label>สถานะ</label><MultiSelect v-model="f.status" :options="STATUS.map((s) => ({ id: s, name: s }))" /></div>
        <div class="field"><label>แหล่งข้อมูล</label><MultiSelect v-model="f.source" :options="SOURCES.map((s) => ({ id: s, name: s }))" /></div>
      </div>
    </div>
    <div class="card">
      <DataTable :columns="cols" :rows="rows" :loading="loading" :total="total" v-model:page="page" v-model:size="size"
                 @sort="(s) => { order = s; load() }" @row-click="(r) => $router.push(`/training/sessions/${r.id}`)">
        <template #cell-session_name="{ row }">
          <div><b>{{ row.session_name }}</b></div>
          <div class="small muted">{{ row.session_code }}<span v-if="row.legacy_course_id"> · Excel ID {{ row.legacy_course_id }}</span></div>
        </template>
        <template #cell-status="{ row }"><span class="badge" :class="statusColor(row.status)">{{ row.status }}</span></template>
        <template #cell-training_type="{ row }"><span class="badge" :class="typeColor(row.training_type)">{{ row.training_type || '-' }}</span></template>
        <template v-if="canEdit" #actions="{ row }">
          <div class="row" style="flex-wrap:nowrap;gap:6px">
            <RouterLink :to="`/training/sessions/${row.id}/edit`" class="btn sm" @click.stop>แก้ไข</RouterLink>
            <button class="btn sm danger" title="ลบหลักสูตรนี้" @click.stop="remove(row)">ลบ</button>
          </div>
        </template>
      </DataTable>
    </div>
  </div>
</template>
<script setup>
import { onMounted, ref, watch } from 'vue'
import HistorySwitch from '../../components/HistorySwitch.vue'
import PageHeader from '../../components/PageHeader.vue'
import DataTable from '../../components/DataTable.vue'
import MultiSelect from '../../components/MultiSelect.vue'
import ExportMenu from '../../components/ExportMenu.vue'
import { supabase, must } from '../../lib/supabase'
import { filterOptions, fetchAll, deleteSession } from '../../lib/api'
import { toastOk, toastError } from '../../lib/toast'
import { canEdit } from '../../lib/auth'
import { TH_MONTHS, dateTH } from '../../lib/format'
import { exportExcel, exportCSV, fileStamp } from '../../lib/export'
import { STATUS, SOURCES, statusColor, typeColor } from '../../lib/constants'

const rows = ref([]); const total = ref(0); const page = ref(1); const size = ref(50); const loading = ref(false)
const search = ref(''); const order = ref({ key: 'start_date', asc: false })
const f = ref({ years: [], months: [], types: [], status: [], source: [] })
const yearOpts = ref([]); const typeOpts = ref([])
const monthOpts = TH_MONTHS.map((m, i) => ({ id: i + 1, name: m }))
const cols = [
  { key: 'session_name', label: 'หลักสูตร / รอบอบรม' },
  { key: 'start_date', label: 'วันที่อบรม', type: 'date' },
  { key: 'training_type', label: 'ประเภท' },
  { key: 'training_hours', label: 'ชั่วโมง', type: 'number', digits: 1 },
  { key: 'participant_count', label: 'ผู้เข้าอบรม', type: 'number' },
  { key: 'total_cost', label: 'ค่าใช้จ่าย', type: 'money' },
  { key: 'cost_per_participant', label: 'Cost/Person', type: 'money' },
  { key: 'provider_name', label: 'Provider' },
  { key: 'location', label: 'สถานที่' },
  { key: 'status', label: 'สถานะ' },
  { key: 'data_source', label: 'แหล่งข้อมูล' },
]
function query(countMode) {
  let q = supabase.from('v_session_summary').select('*', countMode ? { count: 'exact' } : undefined)
  const v = f.value
  if (v.years.length) q = q.in('fiscal_year', v.years)
  if (v.months.length) q = q.in('month', v.months)
  if (v.types.length) q = q.in('training_type_id', v.types)
  if (v.status.length) q = q.in('status', v.status)
  if (v.source.length) q = q.in('data_source', v.source)
  const s = search.value.replace(/[%,()]/g, ' ').trim()
  if (s) q = q.or(`session_name.ilike.%${s}%,course_name.ilike.%${s}%,session_code.ilike.%${s}%,location.ilike.%${s}%,provider_name.ilike.%${s}%${/^\d+$/.test(s) ? `,legacy_course_id.eq.${s},id.eq.${s}` : ''}`)
  return q.order(order.value.key, { ascending: order.value.asc, nullsFirst: false }).order('id', { ascending: false })
}
async function remove(r) {
  try { if (await deleteSession(r)) { toastOk(`ลบ "${r.session_name}" แล้ว`); load() } } catch (e) { toastError(e) }
}
async function load() {
  loading.value = true
  try {
    const from = (page.value - 1) * size.value
    const r = await must(query(true).range(from, from + size.value - 1))
    rows.value = r.data; total.value = r.count
  } finally { loading.value = false }
}
let t; const debounced = () => { clearTimeout(t); t = setTimeout(() => { page.value = 1; load() }, 300) }
watch(f, () => { page.value = 1; load() }, { deep: true })
watch([page, size], load)
onMounted(async () => {
  const o = await filterOptions()
  yearOpts.value = o.years.map((y) => ({ id: y, name: String(y + 543) }))
  typeOpts.value = o.training_types
  load()
})
async function doExport(kind) {
  const all = await fetchAll(query(false))
  const name = fileStamp('Training_Sessions', [new Date().toISOString().slice(0, 10)])
  const ec = [...cols.filter((c) => c.key !== 'session_name'), { key: 'session_code', label: 'Training ID' }, { key: 'legacy_course_id', label: 'Excel Course ID', type: 'number' }]
  ec.unshift({ key: 'session_name', label: 'หลักสูตร / รอบอบรม', width: 60 }, { key: 'course_name', label: 'Course', width: 50 })
  if (kind === 'csv') return exportCSV(`${name}.csv`, ec, all)
  return exportExcel(`${name}.xlsx`, [{ name: 'Sessions', title: 'Training Session', columns: ec, rows: all }])
}
</script>
