<template>
  <div ref="page">
    <PageHeader title="รายงานรายบุคคล" subtitle="ประวัติการฝึกอบรมรายบุคคล (Employee Training History) — ค้นหาด้วยรหัสพนักงานหรือชื่อ">
      <ExportMenu v-if="emp" :handler="doExport" />
    </PageHeader>
    <div class="card mb no-print">
      <div class="field"><label>ค้นหาพนักงาน (รหัส / ชื่อ / ชื่อเล่น)</label>
        <input v-model="q" class="input" placeholder="เช่น 00001 หรือ ชื่อ" @input="debounced" /></div>
      <div v-if="results.length && showResults" class="tbl-wrap mt" style="max-height:260px;overflow:auto">
        <table class="tbl"><tbody>
          <tr v-for="e in results" :key="e.id" class="clickable" @click="pick(e.id)">
            <td>{{ e.employee_code }}</td><td>{{ e.full_name }}</td><td>{{ e.nickname }}</td><td>{{ e.departments?.name }}</td><td>{{ e.employment_status }}</td>
          </tr></tbody></table>
      </div>
    </div>
    <template v-if="emp">
      <div class="card mb">
        <div class="card-title"><h2>Employee Profile</h2><span class="badge" :class="emp.employment_status === 'Active' ? 'green' : ''">{{ emp.employment_status }}</span></div>
        <div class="form-grid">
          <div><div class="small muted">รหัสพนักงาน</div><b>{{ emp.employee_code }}</b></div>
          <div><div class="small muted">ชื่อ-นามสกุล</div><b>{{ emp.title_th }} {{ emp.full_name }}</b> <span class="muted">({{ emp.nickname || '-' }})</span></div>
          <div><div class="small muted">บริษัท</div>{{ emp.companies?.name || '-' }}</div>
          <div><div class="small muted">ฝ่าย</div>{{ emp.departments?.name || '-' }}</div>
          <div><div class="small muted">Section</div>{{ emp.sections?.name || '-' }}</div>
          <div><div class="small muted">กลุ่มระดับ / ระดับตำแหน่ง</div>{{ emp.level_groups?.name || '-' }} / {{ emp.positions?.name || '-' }}</div>
          <div><div class="small muted">ตำแหน่ง</div>{{ emp.job_title || '-' }}</div>
          <div><div class="small muted">วันที่จ้างงาน</div>{{ dateTH(emp.hire_date) }}</div>
          <div v-if="emp.termination_date"><div class="small muted">วันที่พ้นสภาพ</div>{{ dateTH(emp.termination_date) }}</div>
        </div>
      </div>
      <h2 class="mb">Training Summary</h2>
      <div class="grid g4 mb">
        <KpiCard label="Total Courses" :value="num(hist.length)" unit="รายการ" :sub="`${new Set(hist.map((h) => h.course_id)).size} หลักสูตร`" />
        <KpiCard label="Total Training Hours" :value="num(sumBy('training_hours'), 1)" unit="ชม." color="var(--c6)" />
        <KpiCard label="Total Training Cost" :value="money(sumBy('allocated_cost'))" unit="บาท" color="var(--c4)" />
        <KpiCard label="Last Training Date" :value="dateTH(lastDate)" color="var(--c5)" />
      </div>
      <div class="grid g2 mb">
        <div class="card"><div class="card-title"><h3>จำนวนหลักสูตรรายปี</h3><span class="hint">เป้าหมาย {{ target }} หลักสูตร/ปี</span></div><EChart :option="chartYear" /></div>
        <div class="card"><div class="card-title"><h3>ตามประเภท</h3></div><EChart :option="chartType" /></div>
      </div>
      <div class="card">
        <div class="card-title"><h2>Training History</h2></div>
        <DataTable :columns="cols" :rows="hist" row-key="participant_id" @row-click="(r) => $router.push(`/training/sessions/${r.session_id}`)">
          <template #cell-completion_status="{ row }"><span class="badge" :class="row.completion_status === 'Completed' ? 'green' : 'amber'">{{ row.completion_status }}</span></template>
        </DataTable>
      </div>
    </template>
  </div>
</template>
<script setup>
import { computed, onMounted, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import PageHeader from '../../components/PageHeader.vue'
import KpiCard from '../../components/KpiCard.vue'
import DataTable from '../../components/DataTable.vue'
import EChart from '../../components/EChart.vue'
import ExportMenu from '../../components/ExportMenu.vue'
import { supabase, must } from '../../lib/supabase'
import { searchEmployees, facts } from '../../lib/api'
import { num, money, dateTH, be } from '../../lib/format'
import { exportExcel, exportCSV, exportPDF } from '../../lib/export'

const route = useRoute(); const router = useRouter()
const q = ref(''); const results = ref([]); const showResults = ref(true)
const emp = ref(null); const hist = ref([]); const page = ref(null); const target = ref(2)
const cols = [
  { key: 'start_date', label: 'Date', type: 'date' }, { key: 'session_name', label: 'Course' }, { key: 'category_name', label: 'Category' },
  { key: 'training_type', label: 'Type' }, { key: 'provider_name', label: 'Provider' }, { key: 'training_hours', label: 'Hours', type: 'number', digits: 1 },
  { key: 'completion_status', label: 'Result' }, { key: 'score', label: 'Score', type: 'number', digits: 1 }, { key: 'certificate_no', label: 'Certificate' },
  { key: 'allocated_cost', label: 'Cost', type: 'money' },
]
const sumBy = (k) => hist.value.reduce((a, h) => a + Number(h[k] || 0), 0)
const lastDate = computed(() => hist.value.map((h) => h.start_date).filter((d) => d && d <= new Date().toISOString().slice(0, 10)).sort().pop())
const chartYear = computed(() => {
  const m = {}; hist.value.forEach((h) => { m[be(h.year)] = (m[be(h.year)] || 0) + 1 })
  return { xAxis: { type: 'category', data: Object.keys(m) }, yAxis: { type: 'value', minInterval: 1 },
    series: [{ type: 'bar', name: 'หลักสูตร', data: Object.values(m), label: { show: true, position: 'top' },
      markLine: { symbol: 'none', data: [{ yAxis: target.value, name: 'เป้าหมาย' }], lineStyle: { color: '#c0392b', type: 'dashed' } } }] }
})
const chartType = computed(() => {
  const m = {}; hist.value.forEach((h) => { m[h.training_type || 'ไม่ระบุ'] = (m[h.training_type || 'ไม่ระบุ'] || 0) + 1 })
  return { tooltip: { trigger: 'item' }, legend: { bottom: 0 }, series: [{ type: 'pie', radius: ['40%', '70%'], center: ['50%', '42%'], data: Object.entries(m).map(([name, value]) => ({ name, value })) }] }
})
let t; const debounced = () => { clearTimeout(t); t = setTimeout(async () => { showResults.value = true; results.value = await searchEmployees(q.value, 30) }, 250) }
async function pick(id) {
  showResults.value = false
  // the view is keyed by URL: navigate and let the new instance load the employee
  if (String(route.params.id || route.query.id) !== String(id)) return router.replace(route.path.startsWith('/master') ? `/master/employees/${id}` : { query: { id } })
  emp.value = await must(supabase.from('employees').select('*, companies(name), departments(name), sections(name), level_groups(name), positions(name)').eq('id', id).single())
  hist.value = await facts({ employee_ids: [id] }, { all: true, order: 'start_date', asc: false })
  const { data } = await supabase.from('app_settings').select('value').eq('key', 'training_target_per_year').maybeSingle()
  target.value = Number(data?.value ?? 2)
}
async function doExport(kind) {
  const name = `ASW_Training_Employee_${emp.value.employee_code}`
  if (kind === 'pdf') return exportPDF(page.value, `${name}.pdf`)
  if (kind === 'csv') return exportCSV(`${name}.csv`, cols, hist.value)
  const summary = [{ k: 'รหัสพนักงาน', v: emp.value.employee_code }, { k: 'ชื่อ-นามสกุล', v: emp.value.full_name }, { k: 'ฝ่าย', v: emp.value.departments?.name },
    { k: 'Total Courses', v: hist.value.length }, { k: 'Total Training Hours', v: sumBy('training_hours') }, { k: 'Total Training Cost', v: sumBy('allocated_cost') },
    { k: 'Last Training Date', v: lastDate.value }]
  return exportExcel(`${name}.xlsx`, [
    { name: 'Profile', title: `Employee Training History — ${emp.value.employee_code}`, columns: [{ key: 'k', label: 'รายการ', width: 28 }, { key: 'v', label: 'ข้อมูล', width: 50 }], rows: summary },
    { name: 'History', title: `Training History — ${emp.value.full_name}`, columns: cols, rows: hist.value },
  ])
}
onMounted(() => { const id = route.params.id || route.query.id; if (id) pick(Number(id)) })
</script>
