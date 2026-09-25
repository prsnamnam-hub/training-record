<template>
  <div ref="page">
    <div class="dash-head no-print">
      <div>
        <h1>Dashboard</h1>
        <p class="muted">ภาพรวมการฝึกอบรม ปี {{ be(year) }} · สะสม ม.ค. – {{ TH_MONTHS[month - 1] }}</p>
      </div>
      <div class="dash-controls">
        <select v-model.number="year" class="input" aria-label="ปี"><option v-for="y in years" :key="y" :value="y">ปี {{ be(y) }}</option></select>
        <select v-model.number="month" class="input" aria-label="เดือน"><option v-for="(m, i) in TH_MONTHS" :key="i" :value="i + 1">ถึงเดือน {{ m }}</option></select>
        <ExportMenu :handler="doExport" />
      </div>
    </div>
    <div class="no-print mb"><FilterBar v-model="filters" :primary="0" :fields="['departments', 'training_types', 'categories', 'courses', 'companies', 'level_groups', 'sections']" /></div>
    <div class="print-only"><h2>ASW Training Record Dashboard — {{ TH_MONTHS_FULL[month - 1] }} {{ be(year) }}</h2></div>

    <div v-if="loading" class="loading-block"><span class="spinner"></span> กำลังคำนวณ Dashboard...</div>
    <div v-else-if="err" class="alert err mt">{{ err }}</div>
    <template v-else-if="d">
      <!-- ① headline numbers, year-to-date vs the same period last year -->
      <div class="grid g4">
        <KpiCard label="หลักสูตรที่จัด (สะสม)" :value="num(k.ytd.sessions)" unit="รุ่น" :delta="changePct(k.ytd.sessions, k.ytd_last_year.sessions)"
          :sub="`ปีก่อนช่วงเดียวกัน ${num(k.ytd_last_year.sessions)} · ทั้งปีตามแผน ${num(k.planned_sessions_year)}`" />
        <KpiCard label="ผู้เข้าอบรม (คน-ครั้ง)" :value="num(k.ytd.participants)" :delta="changePct(k.ytd.participants, k.ytd_last_year.participants)"
          :sub="`ปีก่อนช่วงเดียวกัน ${num(k.ytd_last_year.participants)}`" color="var(--c3)" />
        <KpiCard label="พนักงานที่เข้าอบรม (คน)" :value="num(k.ytd.employees)" :delta="changePct(k.ytd.employees, k.ytd_last_year.employees)"
          :sub="`เฉลี่ย ${num(safeDiv(k.ytd.participants, k.ytd.employees), 1)} หลักสูตร/คน`" color="var(--c7)" />
        <KpiCard :label="`ผ่านเป้า ≥ ${k.target.target} หลักสูตร/ปี`" :value="pct(safeDiv(k.target.met, k.target.trained) * 100)"
          :sub="`${num(k.target.met)} จาก ${num(k.target.trained)} คนที่เข้าอบรม`" color="var(--c4)" />
      </div>
      <!-- hours / cost appear only once there is data for them -->
      <div v-if="k.year.hours || costYear" class="grid g4 mt">
        <KpiCard v-if="k.year.hours" label="ชั่วโมงอบรมรวม" :value="num(k.year.hours, 1)" unit="ชม." :sub="`เฉลี่ย ${num(safeDiv(k.year.hours, k.year.employees), 1)} ชม./คน`" color="var(--c6)" />
        <KpiCard v-if="costYear" label="ค่าใช้จ่ายรวม" :value="money(costYear)" unit="บาท" :sub="`เฉลี่ย ${money(safeDiv(costYear, k.year.participants))} บาท/คน-ครั้ง`" color="var(--c2)" />
        <KpiCard v-if="costYear && budget" label="งบประมาณคงเหลือ" :value="money(budget - costYear)" unit="บาท" :sub="`ใช้ไป ${pct(safeDiv(costYear, budget) * 100)} ของงบ ${money(budget)}`"
          :color="budget - costYear < 0 ? 'var(--danger)' : 'var(--ok)'" />
      </div>
      <p class="month-strip">
        <b>เดือน {{ TH_MONTHS_FULL[month - 1] }}:</b> {{ num(k.month.sessions) }} รุ่น · {{ num(k.month.participants) }} คน-ครั้ง · {{ num(k.month.employees) }} คน
        <span v-if="changePct(k.month.participants, k.prev_month.participants) !== null" :class="k.month.participants >= k.prev_month.participants ? 'delta-up' : 'delta-down'">
          {{ k.month.participants >= k.prev_month.participants ? '▲' : '▼' }} {{ Math.abs(changePct(k.month.participants, k.prev_month.participants)).toFixed(0) }}%</span>
        <span class="muted">เทียบเดือนก่อน ({{ num(k.prev_month.participants) }})</span>
      </p>

      <!-- ② monthly trend: this year vs last year, one axis -->
      <div class="card mt">
        <div class="card-title"><h2>ผู้เข้าอบรมรายเดือน (คน-ครั้ง)</h2><span class="hint">ปี {{ be(year) }} เทียบปี {{ be(year - 1) }}</span></div>
        <EChart :option="chartTrend" />
      </div>

      <!-- ③ where the training goes -->
      <div class="grid g2 mt">
        <div class="card">
          <div class="card-title"><h2>ฝ่ายที่เข้าอบรมมากที่สุด</h2><RouterLink to="/reports/department" class="hint">ดูรายงานฝ่าย ›</RouterLink></div>
          <EChart :option="chartDept" tall />
        </div>
        <div class="card">
          <div class="card-title"><h2>หลักสูตรยอดนิยม</h2><RouterLink to="/reports/course" class="hint">ดูรายงานหลักสูตร ›</RouterLink></div>
          <ol class="rank">
            <li v-for="c in topCourses" :key="c.label">
              <div class="rank-name">{{ c.label }}</div>
              <div class="rank-bar"><i :style="{ width: `${Math.max(4, (c.participants / topCourses[0].participants) * 100)}%` }"></i></div>
              <div class="rank-val"><b>{{ num(c.participants) }}</b> คน-ครั้ง<span class="muted"> · {{ num(c.sessions) }} รุ่น</span></div>
            </li>
          </ol>
        </div>
      </div>

      <!-- ④ things to act on -->
      <div class="card mt">
        <div class="card-title"><h2>สิ่งที่ต้องติดตาม</h2></div>
        <ul class="actions-list">
          <li v-if="k.target.trained - k.target.met > 0">
            <span class="dot warn"></span><div><b>{{ num(k.target.trained - k.target.met) }} คน</b> ยังไม่ผ่านเป้า {{ k.target.target }} หลักสูตร/ปี</div>
            <RouterLink to="/reports/center?r=target" class="btn sm">ดูรายชื่อ ›</RouterLink></li>
          <li v-if="untrainedDepts.length">
            <span class="dot warn"></span><div><b>{{ untrainedDepts.length }} ฝ่าย</b> ยังไม่มีพนักงานเข้าอบรมในปี {{ be(year) }}
              <div class="small muted">{{ untrainedDepts.slice(0, 6).join(' · ') }}{{ untrainedDepts.length > 6 ? ` และอีก ${untrainedDepts.length - 6} ฝ่าย` : '' }}</div></div>
            <RouterLink to="/reports/department" class="btn sm">ดูรายงานฝ่าย ›</RouterLink></li>
          <li v-if="k.future_sessions">
            <span class="dot info"></span><div><b>{{ num(k.future_sessions) }} รุ่น</b> กำหนดจัดหลังวันนี้ในปี {{ be(year) }}</div>
            <RouterLink to="/training/calendar" class="btn sm">ดูปฏิทิน ›</RouterLink></li>
          <li v-if="missingCerts">
            <span class="dot info"></span><div><b>{{ num(missingCerts) }} คน</b> เข้าร่วมแล้วแต่ยังไม่อัปโหลด Certificate (หลักสูตรที่บันทึกในระบบ)</div>
            <RouterLink to="/training/sessions" class="btn sm">ไปที่ประวัติ ›</RouterLink></li>
          <li v-if="k.year.not_in_hr">
            <span class="dot muted-dot"></span><div><b>{{ num(k.year.not_in_hr) }} คน-ครั้ง</b> รหัสพนักงานไม่พบในฐานข้อมูล HR</div>
            <RouterLink to="/database/employee-import" class="btn sm">นำเข้าพนักงาน ›</RouterLink></li>
          <li v-if="!hasActions"><span class="dot ok"></span><div>ไม่มีรายการที่ต้องติดตาม</div></li>
        </ul>
      </div>

      <!-- details (kept, but out of the way) -->
      <details class="card mt dash-more">
        <summary>รายละเอียดเพิ่มเติม — เปรียบเทียบรายปี · ตามประเภท / บริษัท / กลุ่มระดับ · ค่าใช้จ่าย · ข้อสังเกต</summary>
        <h3 class="mt mb">เปรียบเทียบรายปี</h3>
        <DataTable :columns="yearlyCols" :rows="yearlyRows" :paginate="false" row-key="be" />
        <div class="grid g3 mt">
          <div><h3 class="mb">ตามประเภท</h3><DataTable :columns="splitCols('ประเภท')" :rows="d.by_type || []" :paginate="false" row-key="label" /></div>
          <div><h3 class="mb">ตามบริษัท</h3><DataTable :columns="splitCols('บริษัท')" :rows="d.by_company || []" :paginate="false" row-key="label" /></div>
          <div><h3 class="mb">ตามกลุ่มระดับพนักงาน</h3><DataTable :columns="splitCols('กลุ่มระดับ')" :rows="d.by_level || []" :paginate="false" row-key="label" /></div>
        </div>
        <template v-if="expenseTotal">
          <h3 class="mt mb">ค่าใช้จ่ายตามประเภท</h3>
          <DataTable :columns="[{ key: 'label', label: 'ประเภทค่าใช้จ่าย' }, { key: 'amount', label: 'จำนวนเงิน', type: 'money' }, { key: 'items', label: 'รายการ', type: 'number' }]" :rows="d.expense_by_group || []" :paginate="false" row-key="label" />
        </template>
        <template v-if="insights.length">
          <h3 class="mt mb">ข้อสังเกต</h3>
          <ul class="insights"><li v-for="(t, i) in insights" :key="i" v-html="t"></li></ul>
        </template>
        <div class="small muted mt">
          คน-ครั้ง = จำนวนรายการอบรม (1 คน × 1 รุ่น) · พนักงาน (คน) = นับไม่ซ้ำตามรหัสพนักงาน · ปี/เดือนอิงวันที่อบรม ·
          ค่าใช้จ่ายต่อคน = ค่าใช้จ่ายของรุ่น ÷ ผู้เข้าอบรมของรุ่น
        </div>
      </details>
    </template>
  </div>
</template>

<script setup>
import { computed, onMounted, ref, watch } from 'vue'
import PageHeader from '../components/PageHeader.vue'
import KpiCard from '../components/KpiCard.vue'
import EChart from '../components/EChart.vue'
import DataTable from '../components/DataTable.vue'
import FilterBar from '../components/FilterBar.vue'
import ExportMenu from '../components/ExportMenu.vue'
import { dashboard, filterOptions, report, fetchAll } from '../lib/api'
import { supabase } from '../lib/supabase'
import { TH_MONTHS, TH_MONTHS_FULL, be, num, money, pct, safeDiv, changePct, dateTH } from '../lib/format'
import { exportExcel, exportCSV, exportPDF, fileStamp } from '../lib/export'
import { buildInsights } from '../lib/insights'

const now = new Date()
const year = ref(now.getFullYear())
const month = ref(now.getMonth() + 1)
const years = ref([now.getFullYear()])
const filters = ref({})
const d = ref(null)
const loading = ref(true)
const err = ref('')
const page = ref(null)
const k = computed(() => d.value?.kpi)

const prev = ref(null)            // same filters, previous year (for the trend comparison)
const untrainedDepts = ref([])     // departments with active staff but no training this year
const missingCerts = ref(0)
async function load() {
  loading.value = true; err.value = ''
  try {
    const [cur, last] = await Promise.all([dashboard(filters.value, year.value, month.value), dashboard(filters.value, year.value - 1, 12)])
    d.value = cur; prev.value = last
    loadActions()
  } catch (e) { err.value = e.message } finally { loading.value = false }
}
async function loadActions() {
  try {
    const [depts, staff, certs] = await Promise.all([
      report({ ...filters.value, years: [year.value] }, 'department'),
      fetchAll(supabase.from('employees').select('department_id, departments(name)').eq('employment_status', 'Active').is('deleted_at', null).not('department_id', 'is', null)),
      supabase.from('training_participants').select('id, training_sessions!inner(fiscal_year, data_source, deleted_at)', { count: 'exact', head: true })
        .is('deleted_at', null).is('certificate_url', null).eq('attendance_status', 'Attended')
        .eq('training_sessions.fiscal_year', year.value).eq('training_sessions.data_source', 'System Entry').is('training_sessions.deleted_at', null),
    ])
    const trained = new Set(depts.map((x) => String(x.group_key)))
    const names = {}
    staff.forEach((e) => { if (!trained.has(String(e.department_id))) names[e.department_id] = e.departments?.name || 'ไม่ระบุ' })
    untrainedDepts.value = Object.values(names).sort((a, b) => a.localeCompare(b))
    missingCerts.value = certs.count || 0
  } catch { untrainedDepts.value = []; missingCerts.value = 0 }
}
onMounted(async () => {
  const o = await filterOptions()
  years.value = o.years.length ? o.years : [now.getFullYear()]
  if (!years.value.includes(year.value)) year.value = years.value[years.value.length - 1]
  load()
})
watch([year, month, filters], load, { deep: true })

const sum = (arr, key) => (arr || []).reduce((a, x) => a + Number(x[key] || 0), 0)
const partFilter = computed(() => d.value?.participant_filter)
const costYear = computed(() => (partFilter.value ? k.value.year.cost : d.value.session_cost.year))
const costMonth = computed(() => (partFilter.value ? k.value.month.cost : d.value.session_cost.month))
const budget = computed(() => Number(d.value?.budget?.budget || 0) || Number(d.value?.budget?.session_budget || 0))
const expenseTotal = computed(() => sum(d.value?.expense_by_group, 'amount'))
const hoursNote = computed(() => (k.value.year.hours ? 'ชั่วโมง × คน' : 'ยังไม่มีข้อมูลชั่วโมง (ไม่มีใน Excel เดิม)'))
const costNote = computed(() => (costYear.value ? (partFilter.value ? 'กระจายตามผู้เข้าอบรมที่กรอง' : 'รวมทุก Session ในปี') : 'ยังไม่มีการบันทึกค่าใช้จ่าย'))

// ---------- insights (no hard-coded numbers) ----------
const insights = computed(() => (d.value ? buildInsights(d.value, year.value, month.value) : []))

// ---------- charts ----------
const chartTrend = computed(() => ({
  legend: { top: 0 },
  tooltip: { trigger: 'axis', axisPointer: { type: 'shadow' } },
  xAxis: { type: 'category', data: TH_MONTHS },
  yAxis: { type: 'value' },
  series: [
    { name: `ปี ${be(year.value)}`, type: 'bar', barGap: '10%', itemStyle: { borderRadius: [4, 4, 0, 0] }, data: d.value.monthly.map((m) => m.participants) },
    { name: `ปี ${be(year.value - 1)}`, type: 'bar', itemStyle: { borderRadius: [4, 4, 0, 0], opacity: 0.55 }, data: (prev.value?.monthly || []).map((m) => m.participants) },
  ],
}))
const chartDept = computed(() => {
  const rows = (d.value.top_departments || []).slice(0, 10)
  return {
    grid: { left: 8, right: 36, top: 6, bottom: 6, containLabel: true },
    tooltip: { trigger: 'axis', axisPointer: { type: 'shadow' } },
    xAxis: { type: 'value', splitLine: { lineStyle: { color: '#eef1f5' } } },
    yAxis: { type: 'category', inverse: true, data: rows.map((r) => r.label), axisLabel: { width: 190, overflow: 'truncate' }, axisTick: { show: false } },
    series: [{ name: 'คน-ครั้ง', type: 'bar', barWidth: 14, itemStyle: { borderRadius: [0, 4, 4, 0] }, data: rows.map((r) => r.participants), label: { show: true, position: 'right' } }],
  }
})
const topCourses = computed(() => (d.value.top_course_masters || []).slice(0, 8))
const hasActions = computed(() => (k.value.target.trained - k.value.target.met > 0) || untrainedDepts.value.length || k.value.future_sessions || missingCerts.value || k.value.year.not_in_hr)
const splitCols = (label) => [{ key: 'label', label }, { key: 'participants', label: 'คน-ครั้ง', type: 'number' }, { key: 'employees', label: 'พนักงาน', type: 'number' }]

// ---------- tables ----------
const monthlyRows = computed(() => d.value.monthly.map((m) => ({ ...m, label: TH_MONTHS[m.month - 1], cpp: m.participants ? m.cost / m.participants : null })))
const monthlyCols = [
  { key: 'label', label: 'เดือน' }, { key: 'sessions', label: 'หลักสูตร', type: 'number' }, { key: 'participants', label: 'คน-ครั้ง', type: 'number' },
  { key: 'inhouse', label: 'Inhouse', type: 'number' }, { key: 'public', label: 'Public', type: 'number' }, { key: 'online', label: 'Online', type: 'number' },
  { key: 'employees', label: 'พนักงาน (คน)', type: 'number' }, { key: 'hours', label: 'Training Hours', type: 'number', digits: 1 },
  { key: 'cost', label: 'Training Cost', type: 'money' }, { key: 'cpp', label: 'Cost / Participant', type: 'money' },
]
const yearlyCols = [
  { key: 'be', label: 'ปี (พ.ศ.)' }, { key: 'sessions', label: 'หลักสูตร', type: 'number' }, { key: 'participants', label: 'คน-ครั้ง', type: 'number' },
  { key: 'employees', label: 'พนักงาน (คน)', type: 'number' }, { key: 'avg_per_person', label: 'เฉลี่ย/คน', type: 'number', digits: 2 },
  { key: 'met_target', label: 'ผ่านเป้า (คน)', type: 'number' }, { key: 'pct_met', label: '% ผ่านเป้า', type: 'percent', digits: 0 },
  { key: 'pct_inhouse', label: '% Inhouse', type: 'percent', digits: 0 }, { key: 'hours', label: 'ชั่วโมง', type: 'number', digits: 1 }, { key: 'cost', label: 'Cost', type: 'money' },
]
const deptCols = [
  { key: 'label', label: 'ฝ่าย' }, { key: 'participants', label: 'คน-ครั้ง', type: 'number' }, { key: 'employees', label: 'พนักงาน', type: 'number' },
  { key: 'avg_per_person', label: 'เฉลี่ย/คน', type: 'number', digits: 2 }, { key: 'courses', label: 'หลักสูตร', type: 'number' },
  { key: 'hours', label: 'ชั่วโมง', type: 'number', digits: 1 }, { key: 'cost', label: 'Cost', type: 'money' }, { key: 'cost_per_employee', label: 'Cost/Employee', type: 'money' },
]
const topCourseCols = [
  { key: 'label', label: 'ชื่อหลักสูตร' }, { key: 'start_date', label: 'วันที่อบรม', type: 'date' }, { key: 'training_type', label: 'ประเภท' },
  { key: 'participants', label: 'คน-ครั้ง', type: 'number' }, { key: 'cost', label: 'Cost', type: 'money' }, { key: 'cost_per_person', label: 'Cost/Person', type: 'money' },
]
const courseMasterCols = [
  { key: 'label', label: 'หลักสูตร' }, { key: 'sessions', label: 'รุ่น/รอบ', type: 'number' }, { key: 'participants', label: 'Participants', type: 'number' },
  { key: 'hours', label: 'Training Hours', type: 'number', digits: 1 }, { key: 'cost', label: 'Cost', type: 'money' }, { key: 'cost_per_person', label: 'Cost/Person', type: 'money' },
]
const costDeptCols = [
  { key: 'label', label: 'ฝ่าย' }, { key: 'participants', label: 'คน-ครั้ง', type: 'number' }, { key: 'cost', label: 'Cost', type: 'money' }, { key: 'cost_per_employee', label: 'Cost/Employee', type: 'money' },
]

// ---------- export ----------
async function doExport(kind) {
  const name = fileStamp('Training_Record_Dashboard', [year.value, String(month.value).padStart(2, '0')])
  if (kind === 'pdf') return exportPDF(page.value, `${name}.pdf`)
  if (kind === 'csv') return exportCSV(`${name}.csv`, monthlyCols, monthlyRows.value)
  const kv = (label, value) => ({ label, value })
  const kpiRows = [
    kv(`หลักสูตรที่จัด (เดือน ${TH_MONTHS[month.value - 1]})`, k.value.month.sessions), kv('คน-ครั้ง (เดือน)', k.value.month.participants),
    kv('พนักงาน (เดือน)', k.value.month.employees), kv('หลักสูตรสะสม', k.value.ytd.sessions), kv('คน-ครั้งสะสม', k.value.ytd.participants),
    kv('ปีก่อนช่วงเดียวกัน', k.value.ytd_last_year.participants), kv('พนักงานทั้งปี', k.value.year.employees), kv('ผ่านเป้า (คน)', k.value.target.met),
    kv('Total Training Courses', k.value.year.courses), kv('Total Training Records', k.value.year.participants), kv('Total Training Hours', k.value.year.hours),
    kv('Total Training Cost', costYear.value), kv('Budget', budget.value),
  ]
  await exportExcel(`${name}.xlsx`, [
    { name: 'KPI', title: `Dashboard ${TH_MONTHS_FULL[month.value - 1]} ${be(year.value)}`, columns: [{ key: 'label', label: 'KPI', width: 40 }, { key: 'value', label: 'ค่า', type: 'number', width: 18 }], rows: kpiRows },
    { name: 'Insights', title: 'Key Insights', columns: [{ key: 't', label: 'Insight', width: 120 }], rows: insights.value.map((t) => ({ t: t.replace(/<[^>]+>/g, '') })) },
    { name: 'Monthly', title: `แนวโน้มรายเดือน ${be(year.value)}`, columns: monthlyCols, rows: monthlyRows.value },
    { name: 'Yearly', title: 'เปรียบเทียบรายปี', columns: yearlyCols, rows: yearlyRows.value },
    { name: 'By Type', title: 'แยกตามประเภท', columns: [{ key: 'label', label: 'ประเภท' }, { key: 'sessions', label: 'หลักสูตร', type: 'number' }, { key: 'participants', label: 'คน-ครั้ง', type: 'number' }], rows: d.value.by_type || [] },
    { name: 'By Company', title: 'แยกตามบริษัท', columns: [{ key: 'label', label: 'บริษัท', width: 45 }, { key: 'participants', label: 'คน-ครั้ง', type: 'number' }, { key: 'employees', label: 'พนักงาน', type: 'number' }, { key: 'cost', label: 'Cost', type: 'money' }], rows: d.value.by_company || [] },
    { name: 'By Level', title: 'แยกตามกลุ่มระดับ', columns: [{ key: 'label', label: 'กลุ่มระดับพนักงาน', width: 30 }, { key: 'participants', label: 'คน-ครั้ง', type: 'number' }, { key: 'employees', label: 'พนักงาน', type: 'number' }, { key: 'avg_per_person', label: 'เฉลี่ย/คน', type: 'number' }], rows: d.value.by_level || [] },
    { name: 'Top Departments', title: '10 อันดับฝ่าย', columns: deptCols, rows: d.value.top_departments || [] },
    { name: 'Top Courses', title: '10 อันดับหลักสูตร', columns: topCourseCols, rows: d.value.top_courses || [] },
    { name: 'Expense', title: 'ค่าใช้จ่ายตามประเภท', columns: [{ key: 'label', label: 'Expense Group' }, { key: 'amount', label: 'Amount', type: 'money' }, { key: 'items', label: 'รายการ', type: 'number' }], rows: d.value.expense_by_group || [] },
  ])
}
</script>

<style scoped>
.dash-head { display: flex; align-items: flex-end; justify-content: space-between; gap: 16px; flex-wrap: wrap; margin-bottom: 12px; }
.dash-head p { margin: 4px 0 0; }
.dash-controls { display: flex; gap: 8px; align-items: center; flex-wrap: wrap; }
.dash-controls .input { width: auto; min-width: 130px; }
.month-strip { margin: 14px 2px 0; font-size: 13.5px; color: var(--ink-2); display: flex; gap: 8px; align-items: center; flex-wrap: wrap; }
.rank { list-style: none; margin: 0; padding: 0; counter-reset: r; display: grid; gap: 12px; }
.rank li { counter-increment: r; display: grid; grid-template-columns: 26px 1fr; grid-template-areas: 'n name' 'n bar' 'n val'; column-gap: 10px; row-gap: 3px; }
.rank li::before { content: counter(r); grid-area: n; width: 24px; height: 24px; border-radius: 50%; background: var(--brand-50); color: var(--brand); font-weight: 700; font-size: 12px; display: grid; place-items: center; }
.rank-name { grid-area: name; font-weight: 500; line-height: 1.35; }
.rank-bar { grid-area: bar; height: 6px; background: #eef1f5; border-radius: 99px; overflow: hidden; }
.rank-bar i { display: block; height: 100%; background: var(--c1); border-radius: 99px; }
.rank-val { grid-area: val; font-size: 12.5px; color: var(--ink-2); }
.actions-list { list-style: none; margin: 0; padding: 0; }
.actions-list li { display: grid; grid-template-columns: 12px 1fr auto; gap: 12px; align-items: center; padding: 12px 2px; border-bottom: 1px solid var(--line-2); }
.actions-list li:last-child { border-bottom: none; }
.dot { width: 10px; height: 10px; border-radius: 50%; }
.dot.warn { background: #e8a33d; } .dot.info { background: var(--c1); } .dot.ok { background: var(--ok); } .dot.muted-dot { background: #b8c1cc; }
.dash-more summary { cursor: pointer; font-weight: 600; color: var(--brand-500); }
.dash-more[open] summary { margin-bottom: 4px; }
</style>
