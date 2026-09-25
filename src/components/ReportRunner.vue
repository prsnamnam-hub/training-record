<template>
  <div ref="page">
    <div class="card no-print">
      <div v-if="search" class="field mb"><label>ค้นหาชื่อหลักสูตร</label>
        <input v-model="searchText" class="input" :placeholder="search" @input="onSearch" />
        <span v-if="searchText.trim()" class="small muted">พบ {{ searchIds.length }} หลักสูตรที่ชื่อตรงกับ "{{ searchText.trim() }}"</span></div>
      <FilterBar v-model="filters" :fields="filterFields" />
      <div class="row mt">
        <slot name="controls" />
        <span style="flex:1"></span>
        <ExportMenu :handler="doExport" />
      </div>
    </div>
    <div class="print-only"><h2>ASW Training Record — {{ title }}</h2><div class="small">{{ filterText }}</div></div>
    <div v-if="err" class="alert err mt">{{ err }}</div>
    <div class="grid g4 mt">
      <KpiCard label="รอบอบรม (Sessions)" :value="num(totSessions)" />
      <KpiCard label="ผู้เข้าอบรม (คน-ครั้ง)" :value="num(tot.participants)" color="var(--c3)" />
      <KpiCard label="Training Hours" :value="num(tot.hours, 1)" unit="ชม." color="var(--c6)" />
      <KpiCard label="Training Cost" :value="money(tot.cost)" unit="บาท" :sub="tot.participants ? `Cost/Participant ${money(tot.cost / tot.participants)}` : ''" color="var(--c4)" />
    </div>
    <div class="card mt" v-if="rows.length && chart">
      <EChart :option="chartOption" tall />
    </div>
    <div class="card mt">
      <div class="card-title"><h2>{{ title }}</h2><span class="hint">{{ rows.length }} รายการ</span></div>
      <DataTable :columns="columns" :rows="rows" :loading="loading" row-key="group_key" :size="100"
                 @row-click="drill">
        <template #foot>
          <tr><td>รวม</td><td v-for="c in columns.slice(1)" :key="c.key" class="num">{{ footer(c) }}</td></tr>
        </template>
      </DataTable>
    </div>
  </div>
</template>
<script setup>
import { computed, onMounted, ref, watch } from 'vue'
import { useRouter } from 'vue-router'
import FilterBar from './FilterBar.vue'
import DataTable from './DataTable.vue'
import KpiCard from './KpiCard.vue'
import EChart from './EChart.vue'
import ExportMenu from './ExportMenu.vue'
import { report, filterOptions, fetchAll } from '../lib/api'
import { supabase } from '../lib/supabase'
import { num, money, TH_MONTHS, be } from '../lib/format'
import { exportExcel, exportCSV, exportPDF, fileStamp } from '../lib/export'

const props = defineProps({
  group: { type: String, required: true },
  title: { type: String, required: true },
  metrics: { type: Array, default: () => ['sessions', 'courses', 'participants', 'employees', 'training_hours', 'avg_hours_per_person', 'total_cost', 'cost_per_participant', 'cost_per_hour'] },
  chart: { type: String, default: 'participants' },
  filePrefix: { type: String, default: 'Training_Record_Report' },
  initialFilters: { type: Object, default: () => ({}) },
  // placeholder text → show a course-name search box (report-wide: it becomes a course filter)
  search: { type: String, default: '' },
})
const router = useRouter()
const filters = ref({ ...props.initialFilters })
// course-name search → course_ids filter, so KPIs, chart and totals follow the search too
const searchText = ref(''); const courseOpts = ref([])
const norm = (x) => String(x || '').toLowerCase().replace(/\s+/g, '')
const searchIds = computed(() => { const t = norm(searchText.value); return t ? courseOpts.value.filter((c) => norm(c.name).includes(t)).map((c) => c.id) : [] })
let searchTimer
function onSearch() {
  clearTimeout(searchTimer)
  searchTimer = setTimeout(() => {
    const f = { ...filters.value }
    if (searchText.value.trim()) f.course_ids = searchIds.value.length ? searchIds.value : [-1] // -1 = nothing matches
    else delete f.course_ids
    filters.value = f
  }, 300)
}
const raw = ref([]); const loading = ref(false); const err = ref(''); const page = ref(null)
const headcount = ref({})
const filterFields = ['years', 'months', 'date_from', 'date_to', 'companies', 'business_groups', 'departments', 'sections', 'level_groups', 'training_types', 'categories', 'courses', 'providers', 'trainers']
const GROUP_LABEL = { year: 'ปี (พ.ศ.)', month: 'เดือน', year_month: 'ปี-เดือน', department: 'ฝ่าย', company: 'บริษัท', business_group: 'กลุ่มธุรกิจ', section: 'Section',
  level_group: 'กลุ่มระดับพนักงาน', position: 'ระดับตำแหน่ง', course: 'หลักสูตร', session: 'รอบอบรม', training_type: 'ประเภท', category: 'หมวดหมู่',
  provider: 'Provider', trainer: 'Trainer', employee: 'พนักงาน' }
const METRIC = {
  sessions: { label: 'Sessions', type: 'number' }, courses: { label: 'Courses', type: 'number' }, participants: { label: 'Participants (คน-ครั้ง)', type: 'number' },
  employees: { label: 'พนักงาน (คน)', type: 'number' }, training_hours: { label: 'Training Hours', type: 'number', digits: 1 },
  avg_hours_per_person: { label: 'ชม./คน', type: 'number', digits: 1 }, total_cost: { label: 'Training Cost', type: 'money' },
  cost_per_participant: { label: 'Cost / Person', type: 'money' }, cost_per_hour: { label: 'Cost / Hour', type: 'money' },
  inhouse: { label: 'Inhouse', type: 'number' }, public_cnt: { label: 'Public', type: 'number' }, online: { label: 'Online', type: 'number' },
  last_date: { label: 'อบรมล่าสุด', type: 'date' }, headcount: { label: 'Employee Count', type: 'number' }, cost_per_employee: { label: 'Cost / Employee', type: 'money' },
  pct_trained: { label: '% พนักงานที่ได้อบรม', type: 'percent' },
}
const columns = computed(() => [{ key: 'group_label', label: GROUP_LABEL[props.group] || 'กลุ่ม' }, ...props.metrics.map((m) => ({ key: m, ...METRIC[m] }))])
const rows = computed(() => raw.value.map((r) => {
  const out = { ...r }
  if (props.group === 'month') out.group_label = TH_MONTHS[Number(r.group_key) - 1] || 'ไม่ระบุวันที่'
  if (props.group === 'year_month') { const [y, m] = String(r.group_key).split('-'); out.group_label = Number(m) ? `${TH_MONTHS[Number(m) - 1]} ${be(y)}` : `ไม่ระบุวันที่ ${be(y)}` }
  if (props.group === 'department') {
    out.headcount = headcount.value[r.group_key] ?? null
    out.cost_per_employee = out.headcount ? r.total_cost / out.headcount : null
    out.pct_trained = out.headcount ? Math.min(100, (r.employees / out.headcount) * 100) : null
  }
  for (const k of ['training_hours', 'total_cost', 'cost_per_participant', 'cost_per_hour', 'avg_hours_per_person']) if (out[k] !== null) out[k] = Number(out[k])
  return out
}).sort((a, b) => (['month', 'year_month', 'year'].includes(props.group) ? String(a.sort_key ?? a.group_key).localeCompare(String(b.sort_key ?? b.group_key), undefined, { numeric: true })
  : props.group === 'level_group' ? String(b.sort_key).localeCompare(String(a.sort_key)) : b.participants - a.participants)))
const tot = computed(() => ({
  participants: raw.value.reduce((a, r) => a + r.participants, 0),
  hours: raw.value.reduce((a, r) => a + Number(r.training_hours || 0), 0), cost: raw.value.reduce((a, r) => a + Number(r.total_cost || 0), 0),
}))
// sessions total must not double count across groups (a session spans departments) → ask the server once
const sessionsTotal = ref(0)
const totSessions = computed(() => sessionsTotal.value)
function footer(c) {
  if (['sessions'].includes(c.key)) return num(totSessions.value)
  if (['participants', 'training_hours', 'total_cost', 'inhouse', 'public_cnt', 'online', 'headcount'].includes(c.key)) {
    const v = rows.value.reduce((a, r) => a + Number(r[c.key] || 0), 0)
    return c.type === 'money' ? money(v) : num(v, c.digits || 0)
  }
  if (c.key === 'cost_per_participant') return tot.value.participants ? money(tot.value.cost / tot.value.participants) : '-'
  return ''
}
const chartOption = computed(() => {
  const top = rows.value.slice(0, ['month', 'year_month', 'year'].includes(props.group) ? 60 : 20)
  const horizontal = !['month', 'year_month', 'year'].includes(props.group)
  const m = METRIC[props.chart]
  const cat = { type: 'category', data: top.map((r) => r.group_label), ...(horizontal ? { inverse: true, axisLabel: { width: 200, overflow: 'truncate' } } : {}) }
  return {
    grid: { left: 8, right: 40, top: 30, bottom: 8, containLabel: true },
    legend: { top: 0 },
    tooltip: { trigger: 'axis', axisPointer: { type: 'shadow' } },
    xAxis: horizontal ? { type: 'value' } : cat, yAxis: horizontal ? cat : { type: 'value' },
    series: [{ name: m.label, type: 'bar', data: top.map((r) => r[props.chart]), label: { show: top.length <= 20, position: horizontal ? 'right' : 'top' } }],
  }
})
const filterText = ref('')
async function load() {
  loading.value = true; err.value = ''
  try {
    raw.value = await report(filters.value, props.group)
    const s = await report(filters.value, 'year')
    sessionsTotal.value = s.reduce((a, r) => a + Number(r.sessions), 0)
  } catch (e) { err.value = e.message } finally { loading.value = false }
}
watch(filters, load, { deep: true })
onMounted(async () => {
  if (props.group === 'department') {
    const emp = await fetchAll(supabase.from('employees').select('department_id').eq('employment_status', 'Active').is('deleted_at', null))
    const m = {}; emp.forEach((e) => { m[e.department_id] = (m[e.department_id] || 0) + 1 }); headcount.value = m
  }
  courseOpts.value = (await filterOptions()).courses || []
  load()
})
function drill(r) {
  const map = { department: 'department_ids', course: 'course_ids', company: 'company_ids', level_group: 'level_group_ids', training_type: 'training_type_ids',
    category: 'category_ids', provider: 'provider_ids', trainer: 'trainer_ids' }
  if (props.group === 'employee') return router.push(`/master/employees/${r.group_key}`)
  if (props.group === 'session') return router.push(`/training/sessions/${r.group_key}`)
  if (props.group === 'course') return router.push(`/master/courses/${r.group_key}`)
  if (map[props.group] && r.group_key) filters.value = { ...filters.value, [map[props.group]]: [Number(r.group_key)] }
}
async function doExport(kind) {
  const yrs = filters.value.years?.length ? filters.value.years.join('-') : ''
  const mth = filters.value.months?.length === 1 ? String(filters.value.months[0]).padStart(2, '0') : ''
  const name = fileStamp(props.filePrefix, [yrs, mth])
  if (kind === 'pdf') return exportPDF(page.value, `${name}.pdf`)
  if (kind === 'csv') return exportCSV(`${name}.csv`, columns.value, rows.value)
  return exportExcel(`${name}.xlsx`, [{ name: props.title.slice(0, 31), title: props.title, columns: columns.value.map((c) => (c.key === 'group_label' ? { ...c, width: 45 } : c)), rows: rows.value,
    filters: summarizeFilters() }])
}
function summarizeFilters() {
  const f = filters.value; const parts = []
  if (f.years?.length) parts.push('ปี ' + f.years.map(be).join(', '))
  if (f.months?.length) parts.push('เดือน ' + f.months.map((m) => TH_MONTHS[m - 1]).join(', '))
  if (f.date_from || f.date_to) parts.push(`วันที่ ${f.date_from || ''} – ${f.date_to || ''}`)
  const n = Object.entries(f).filter(([k, v]) => k.endsWith('_ids') && v?.length).length
  if (n) parts.push(`ตัวกรองอื่น ${n} รายการ`)
  filterText.value = parts.join(' · ')
  return filterText.value
}
defineExpose({ filters })
</script>
