<template>
  <div ref="page">
    <PageHeader title="Dashboard"
      :subtitle="`รายงานสรุปการฝึกอบรม · ช่วงสะสม ม.ค. – ${TH_MONTHS[month - 1]} ${be(year)}`">
      <ExportMenu :handler="doExport" />
    </PageHeader>

    <div class="card no-print">
      <div class="filterbar">
        <div class="field"><label>ปีที่รายงาน (พ.ศ.)</label>
          <select v-model.number="year" class="input"><option v-for="y in years" :key="y" :value="y">{{ be(y) }}</option></select></div>
        <div class="field"><label>เดือนที่รายงาน</label>
          <select v-model.number="month" class="input"><option v-for="(m, i) in TH_MONTHS" :key="i" :value="i + 1">{{ m }}</option></select></div>
      </div>
      <div class="mt"><FilterBar v-model="filters" :fields="['departments', 'sections', 'training_types', 'categories', 'courses', 'companies', 'level_groups']" /></div>
    </div>
    <div class="print-only"><h2>ASW Training Record Dashboard — {{ TH_MONTHS_FULL[month - 1] }} {{ be(year) }}</h2></div>

    <div v-if="loading" class="loading-block"><span class="spinner"></span> กำลังคำนวณ Dashboard...</div>
    <div v-else-if="err" class="alert err mt">{{ err }}</div>
    <template v-else-if="d">
      <!-- 1. monthly overview (Excel rows 7-10) -->
      <h2 class="mt mb">ภาพรวมเดือน {{ TH_MONTHS[month - 1] }} {{ be(year) }}</h2>
      <div class="grid g5">
        <KpiCard label="หลักสูตรที่จัด" :value="num(k.month.sessions)" unit="รอบ" :sub="`หลักสูตร (เดือน ${TH_MONTHS[month - 1]})`" />
        <KpiCard label="จำนวนผู้เข้าอบรม (คน-ครั้ง)" :value="num(k.month.participants)" :delta="changePct(k.month.participants, k.prev_month.participants) ?? undefined"
          :sub="`เดือนก่อนหน้า: ${num(k.prev_month.participants)}`" color="var(--c3)" />
        <KpiCard label="พนักงานที่เข้าอบรม (คน)" :value="num(k.month.employees)" sub="ไม่นับซ้ำ ตามรหัสพนักงาน" color="var(--c5)" />
        <KpiCard label="สัดส่วน Inhouse : Public" :value="pct(safeDiv(k.month.inhouse, k.month.participants) * 100)"
          :sub="`Inhouse ${num(k.month.inhouse)} | Public ${num(k.month.public)} | Online ${num(k.month.online)}`" color="var(--c2)" />
        <KpiCard label="Training Cost เดือนนี้" :value="num(costMonth)" unit="บาท" :sub="`ชั่วโมงอบรม ${num(k.month.hours, 1)} ชม.`" color="var(--c4)" />
      </div>

      <!-- 2. YTD (Excel rows 12-15) -->
      <h2 class="mt mb">สะสมทั้งปี {{ be(year) }} (ม.ค. – {{ TH_MONTHS[month - 1] }})</h2>
      <div class="grid g4">
        <KpiCard label="หลักสูตรสะสม" :value="num(k.ytd.sessions)" unit="รอบ" :sub="`ทั้งปี (รวมที่กำหนดไว้แล้ว): ${num(k.planned_sessions_year)}`" />
        <KpiCard label="ผู้เข้าอบรมสะสม (คน-ครั้ง)" :value="num(k.ytd.participants)" :delta="changePct(k.ytd.participants, k.ytd_last_year.participants) ?? undefined"
          :sub="`ปีก่อนช่วงเดียวกัน: ${num(k.ytd_last_year.participants)}`" color="var(--c3)" />
        <KpiCard label="พนักงานที่เข้าอบรมทั้งปี (คน)" :value="num(k.year.employees)"
          :sub="`เฉลี่ย ${num(safeDiv(k.year.participants, k.year.employees), 1)} หลักสูตร/คน`" color="var(--c5)" />
        <KpiCard :label="`ผ่านเป้า ≥ ${k.target.target} หลักสูตร/ปี (คน)`" :value="num(k.target.met)"
          :sub="`${pct(safeDiv(k.target.met, k.target.trained) * 100)} ของพนักงานที่เข้าอบรมในปี`" color="var(--ok)" />
      </div>

      <!-- 3. Training KPI (full year) -->
      <h2 class="mt mb">Training KPI ปี {{ be(year) }}</h2>
      <div class="grid g5">
        <KpiCard label="Total Training Courses" :value="num(k.year.courses)" :sub="`${num(k.year.sessions)} รอบอบรม (Session)`" />
        <KpiCard label="Total Participants (คน)" :value="num(k.year.employees)" color="var(--c5)" />
        <KpiCard label="Total Training Records" :value="num(k.year.participants)" sub="คน-ครั้ง" color="var(--c3)" />
        <KpiCard label="Total Training Hours" :value="num(k.year.hours, 1)" unit="ชม." :sub="hoursNote" color="var(--c6)" />
        <KpiCard label="Avg Training Hours / Person" :value="num(safeDiv(k.year.hours, k.year.employees), 1)" unit="ชม." color="var(--c6)" />
        <KpiCard label="Total Training Cost" :value="num(costYear)" unit="บาท" :sub="costNote" color="var(--c4)" />
        <KpiCard label="Average Cost / Person" :value="num(safeDiv(costYear, k.year.participants))" unit="บาท" sub="ต่อคน-ครั้ง" color="var(--c4)" />
        <KpiCard label="Average Cost / Course" :value="num(safeDiv(costYear, k.year.sessions))" unit="บาท" sub="ต่อรอบอบรม" color="var(--c4)" />
        <KpiCard label="Internal Training" :value="num(k.year.internal_sessions)" unit="รอบ" :sub="`${num(k.year.internal)} คน-ครั้ง`" color="var(--c1)" />
        <KpiCard label="External Training" :value="num(k.year.external_sessions)" unit="รอบ" :sub="`${num(k.year.external)} คน-ครั้ง (Public/Online)`" color="var(--c2)" />
      </div>

      <!-- insights -->
      <div class="card mt">
        <div class="card-title"><h2>KEY INSIGHTS</h2><span class="hint">คำนวณจากข้อมูลจริงตามตัวกรอง</span></div>
        <ul class="insights"><li v-for="(t, i) in insights" :key="i" v-html="t"></li></ul>
      </div>

      <!-- trend -->
      <div class="grid g2 mt">
        <div class="card">
          <div class="card-title"><h2>แนวโน้มรายเดือน ปี {{ be(year) }}</h2><span class="hint">คน-ครั้งตามประเภท และจำนวนหลักสูตรรายเดือน</span></div>
          <EChart :option="chartMonthly" tall />
        </div>
        <div class="card">
          <div class="card-title"><h2>Training Hours / Cost รายเดือน</h2><span class="hint">Cost / Participant</span></div>
          <EChart :option="chartCostTrend" tall />
        </div>
      </div>
      <div class="card mt">
        <DataTable :columns="monthlyCols" :rows="monthlyRows" :paginate="false" :sortable="false" row-key="month">
          <template #foot><tr><td>รวม</td><td class="num">{{ num(sum(d.monthly, 'sessions')) }}</td><td class="num">{{ num(sum(d.monthly, 'participants')) }}</td>
            <td class="num">{{ num(sum(d.monthly, 'inhouse')) }}</td><td class="num">{{ num(sum(d.monthly, 'public')) }}</td><td class="num">{{ num(sum(d.monthly, 'online')) }}</td>
            <td class="num">{{ num(k.year.employees - 0) }}</td><td class="num">{{ num(sum(d.monthly, 'hours'), 1) }}</td><td class="num">{{ money(sum(d.monthly, 'cost')) }}</td><td></td></tr></template>
        </DataTable>
        <p v-if="k.year.no_date_sessions" class="small muted">ไม่มีวันที่อบรม (ไม่อยู่ในรายเดือน): {{ k.year.no_date_sessions }} หลักสูตร / {{ num(k.year.no_date_participants) }} คน-ครั้ง</p>
      </div>

      <!-- yearly -->
      <div class="grid g2 mt">
        <div class="card">
          <div class="card-title"><h2>เปรียบเทียบรายปี</h2><span class="hint">คน-ครั้ง / พนักงาน และ % ผ่านเป้า</span></div>
          <EChart :option="chartYearly" />
        </div>
        <div class="card">
          <div class="card-title"><h2>ตารางเปรียบเทียบรายปี</h2></div>
          <DataTable :columns="yearlyCols" :rows="yearlyRows" :paginate="false" row-key="year" />
          <p class="small muted">เป้าหมาย {{ k.target.target }} หลักสูตร/คน/ปี — % ผ่านเป้าคิดจากพนักงานที่เข้าอบรมอย่างน้อย 1 ครั้งในปีนั้น</p>
        </div>
      </div>

      <!-- type / company / level -->
      <div class="grid g3 mt">
        <div class="card"><div class="card-title"><h2>สัดส่วนคน-ครั้งตามประเภท</h2></div><EChart :option="chartType" /></div>
        <div class="card"><div class="card-title"><h2>คน-ครั้งตามบริษัท</h2></div><EChart :option="chartCompany" /></div>
        <div class="card"><div class="card-title"><h2>คน-ครั้งตามกลุ่มระดับพนักงาน</h2></div><EChart :option="chartLevel" /></div>
      </div>

      <!-- department dashboard -->
      <div class="grid g2 mt">
        <div class="card"><div class="card-title"><h2>Top 10 ฝ่าย (คน-ครั้ง)</h2></div><EChart :option="chartDept" tall /></div>
        <div class="card">
          <div class="card-title"><h2>Department Dashboard</h2><span class="hint">10 อันดับฝ่ายที่เข้าอบรมมากที่สุด</span></div>
          <DataTable :columns="deptCols" :rows="d.top_departments || []" :paginate="false" row-key="label" />
        </div>
      </div>

      <!-- course dashboard -->
      <div class="grid g2 mt">
        <div class="card">
          <div class="card-title"><h2>10 อันดับหลักสูตร (รอบอบรม) ที่มีผู้เข้าอบรมมากที่สุด</h2></div>
          <DataTable :columns="topCourseCols" :rows="d.top_courses || []" :paginate="false" @row-click="(r) => $router.push(`/training/sessions/${r.id}`)" />
        </div>
        <div class="card">
          <div class="card-title"><h2>Course Dashboard — Top Courses</h2><span class="hint">รวมทุกรุ่นของหลักสูตร</span></div>
          <DataTable :columns="courseMasterCols" :rows="d.top_course_masters || []" :paginate="false" @row-click="(r) => $router.push(`/master/courses/${r.id}`)" />
        </div>
      </div>

      <!-- expense dashboard -->
      <div class="grid g2 mt">
        <div class="card">
          <div class="card-title"><h2>Expense Dashboard ปี {{ be(year) }}</h2><span class="hint">Total {{ money(expenseTotal) }} บาท</span></div>
          <EChart v-if="expenseTotal" :option="chartExpense" />
          <div v-else class="empty">ยังไม่มีการบันทึกค่าใช้จ่ายของปีนี้<br><span class="small">ข้อมูลย้อนหลังจาก Excel ไม่มีค่าใช้จ่าย — บันทึกได้ที่ Training Session › Expense</span></div>
        </div>
        <div class="card">
          <div class="card-title"><h2>Budget vs Actual</h2></div>
          <div class="grid g3">
            <KpiCard label="Budget" :value="money(budget)" unit="บาท" color="var(--c6)" />
            <KpiCard label="Actual" :value="money(costYear)" unit="บาท" color="var(--c4)" />
            <KpiCard label="Variance" :value="budget ? money(budget - costYear) : '-'" unit="บาท" :color="budget - costYear < 0 ? 'var(--danger)' : 'var(--ok)'" />
          </div>
          <div class="mt">
            <div class="row small"><span style="flex:1">% Utilization</span><b>{{ budget ? pct((costYear / budget) * 100, 1) : '-' }}</b></div>
            <div class="progress mt"><div :style="{ width: Math.min(100, budget ? (costYear / budget) * 100 : 0) + '%', background: costYear > budget ? 'var(--danger)' : 'var(--brand)' }"></div></div>
            <p v-if="!budget" class="small muted mt">ยังไม่ได้ตั้งงบประมาณ — ตั้งได้ที่ Master Data › Training Budget หรือช่อง Budget ของแต่ละ Session</p>
          </div>
          <div v-if="(d.cost_by_department || []).length" class="mt">
            <h3 class="mb">Training Cost by Department</h3>
            <DataTable :columns="costDeptCols" :rows="d.cost_by_department" :paginate="false" row-key="label" />
          </div>
        </div>
      </div>

      <div class="card mt small muted">
        <b>หมายเหตุข้อมูล</b>
        <div>• คน-ครั้ง = จำนวน Training Record (1 คน × 1 รอบอบรม) | พนักงาน (คน) = นับไม่ซ้ำตามรหัสพนักงาน</div>
        <div>• ปีและเดือนอิงจากวันที่อบรม (วันเริ่ม) — หลักสูตรที่ไม่มีวันที่ใช้ปีจากข้อมูลเดิม และไม่ถูกนับในตารางรายเดือน</div>
        <div>• หลักสูตรปี {{ be(year) }} ที่กำหนดวันหลังวันนี้ (อยู่ในแผน/ลงทะเบียนแล้ว): {{ k.future_sessions }} รอบ</div>
        <div>• คน-ครั้งปี {{ be(year) }} ที่ไม่พบรหัสใน Employee Info Report: {{ k.year.not_in_hr }}</div>
        <div>• Cost / Participant = ค่าใช้จ่ายของรอบอบรม ÷ จำนวนผู้เข้าอบรมของรอบนั้น (กระจายค่าใช้จ่ายตามคน)</div>
      </div>
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
import { dashboard, filterOptions } from '../lib/api'
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

async function load() {
  loading.value = true; err.value = ''
  try { d.value = await dashboard(filters.value, year.value, month.value) }
  catch (e) { err.value = e.message } finally { loading.value = false }
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
const labelsM = TH_MONTHS
const chartMonthly = computed(() => ({
  legend: { top: 0 },
  xAxis: { type: 'category', data: labelsM },
  yAxis: [{ type: 'value', name: 'คน-ครั้ง' }, { type: 'value', name: 'หลักสูตร', splitLine: { show: false } }],
  series: [
    { name: 'Inhouse', type: 'bar', stack: 't', data: d.value.monthly.map((m) => m.inhouse) },
    { name: 'Public', type: 'bar', stack: 't', data: d.value.monthly.map((m) => m.public) },
    { name: 'Online', type: 'bar', stack: 't', data: d.value.monthly.map((m) => m.online) },
    { name: 'หลักสูตร', type: 'line', yAxisIndex: 1, smooth: true, data: d.value.monthly.map((m) => m.sessions), color: '#e76f51' },
  ],
}))
const chartCostTrend = computed(() => ({
  legend: { top: 0 },
  xAxis: { type: 'category', data: labelsM },
  yAxis: [{ type: 'value', name: 'บาท' }, { type: 'value', name: 'ชม.', splitLine: { show: false } }],
  series: [
    { name: 'Training Cost', type: 'bar', data: d.value.monthly.map((m) => Math.round(m.cost)) },
    { name: 'Cost / Participant', type: 'line', data: d.value.monthly.map((m) => (m.participants ? Math.round(m.cost / m.participants) : 0)) },
    { name: 'Training Hours', type: 'line', yAxisIndex: 1, smooth: true, data: d.value.monthly.map((m) => m.hours) },
    { name: 'Participants', type: 'line', yAxisIndex: 1, smooth: true, lineStyle: { type: 'dashed' }, data: d.value.monthly.map((m) => m.participants) },
  ],
}))
const yearlyRows = computed(() => (d.value.yearly || []).map((y) => ({ ...y, be: y.year + 543, pct_met: safeDiv(y.met_target, y.employees) * 100 })))
const chartYearly = computed(() => ({
  legend: { top: 0 },
  xAxis: { type: 'category', data: yearlyRows.value.map((y) => String(y.be)) },
  yAxis: [{ type: 'value' }, { type: 'value', max: 100, axisLabel: { formatter: '{value}%' }, splitLine: { show: false } }],
  series: [
    { name: 'คน-ครั้ง', type: 'bar', data: yearlyRows.value.map((y) => y.participants) },
    { name: 'พนักงาน (คน)', type: 'bar', data: yearlyRows.value.map((y) => y.employees) },
    { name: '% ผ่านเป้า', type: 'line', yAxisIndex: 1, data: yearlyRows.value.map((y) => Math.round(y.pct_met)) },
  ],
}))
const pie = (rows, key = 'participants') => ({
  tooltip: { trigger: 'item', formatter: '{b}: {c} ({d}%)' },
  legend: { bottom: 0, type: 'scroll' },
  series: [{ type: 'pie', radius: ['45%', '72%'], center: ['50%', '45%'], data: rows.map((r) => ({ name: r.label, value: r[key] })), label: { formatter: '{d}%' } }],
})
const hbar = (rows, key, name) => ({
  grid: { left: 8, right: 30, top: 10, bottom: 8, containLabel: true },
  tooltip: { trigger: 'axis', axisPointer: { type: 'shadow' } },
  xAxis: { type: 'value' },
  yAxis: { type: 'category', inverse: true, data: rows.map((r) => r.label), axisLabel: { width: 170, overflow: 'truncate' } },
  series: [{ name, type: 'bar', data: rows.map((r) => r[key]), label: { show: true, position: 'right' } }],
})
const chartType = computed(() => pie(d.value.by_type || []))
const chartCompany = computed(() => hbar(d.value.by_company || [], 'participants', 'คน-ครั้ง'))
const chartLevel = computed(() => hbar(d.value.by_level || [], 'participants', 'คน-ครั้ง'))
const chartDept = computed(() => hbar(d.value.top_departments || [], 'participants', 'คน-ครั้ง'))
const EXP_TH = { 'Course Fee': 'ค่าหลักสูตร', 'Trainer Fee': 'ค่าวิทยากร', Food: 'ค่าอาหาร/เครื่องดื่ม', Accommodation: 'ที่พัก', Transportation: 'เดินทาง', Venue: 'สถานที่', Material: 'เอกสาร/อุปกรณ์', Other: 'อื่น ๆ' }
const chartExpense = computed(() => pie((d.value.expense_by_group || []).map((x) => ({ label: `${x.label} (${EXP_TH[x.label] || ''})`, amount: Math.round(x.amount) })), 'amount'))

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
