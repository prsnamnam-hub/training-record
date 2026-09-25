<template>
  <div>
    <PageHeader title="Monthly Training Management Report" :subtitle="`รายงานการฝึกอบรมประจำเดือน ${TH_MONTHS_FULL[month - 1]} ${be(year)} — สำหรับผู้บริหาร`">
      <ExportMenu :handler="doExport" />
    </PageHeader>
    <div class="card no-print mb">
      <div class="filterbar">
        <div class="field"><label>ปี (พ.ศ.)</label><select v-model.number="year" class="input"><option v-for="y in years" :key="y" :value="y">{{ be(y) }}</option></select></div>
        <div class="field"><label>เดือน</label><select v-model.number="month" class="input"><option v-for="(m, i) in TH_MONTHS" :key="i" :value="i + 1">{{ m }}</option></select></div>
      </div>
      <div class="mt"><FilterBar v-model="filters" :fields="['companies', 'departments', 'training_types', 'categories']" /></div>
    </div>

    <div v-if="loading" class="loading-block"><span class="spinner"></span></div>
    <div v-else-if="d" ref="page" class="report">
      <div class="card">
        <div class="row"><img :src="logo" style="width:40px" alt="" /><div><h2>ASW Training Record</h2>
          <div class="muted">Monthly Training Management Report · {{ TH_MONTHS_FULL[month - 1] }} {{ be(year) }}</div></div></div>
      </div>

      <div class="card"><h2 class="mb">1. Executive Summary</h2>
        <p style="margin:0">{{ execSummary }}</p></div>

      <div class="card"><h2 class="mb">2. Training KPI</h2>
        <div class="grid g4">
          <KpiCard label="รอบอบรมเดือนนี้" :value="num(k.month.sessions)" :sub="`สะสม ${num(k.ytd.sessions)} รอบ`" />
          <KpiCard label="ผู้เข้าอบรมเดือนนี้ (คน-ครั้ง)" :value="num(k.month.participants)" :delta="changePct(k.month.participants, k.prev_month.participants) ?? undefined" sub="เทียบเดือนก่อน" color="var(--c3)" />
          <KpiCard label="พนักงานเดือนนี้ (คน)" :value="num(k.month.employees)" :sub="`ทั้งปี ${num(k.year.employees)} คน`" color="var(--c5)" />
          <KpiCard :label="`ผ่านเป้า ≥ ${k.target.target} หลักสูตร/ปี`" :value="num(k.target.met)" unit="คน" :sub="pct(safeDiv(k.target.met, k.target.trained) * 100)" color="var(--ok)" />
        </div></div>

      <div class="card"><h2 class="mb">3. Department Analysis</h2>
        <DataTable :columns="deptCols" :rows="d.top_departments || []" :paginate="false" :sortable="false" row-key="label" /></div>

      <div class="card"><h2 class="mb">4. Top Training Courses (ปี {{ be(year) }})</h2>
        <DataTable :columns="courseCols" :rows="d.top_courses || []" :paginate="false" :sortable="false" /></div>

      <div class="grid g2">
        <div class="card"><h2 class="mb">5. Training Hours</h2>
          <div class="grid g2"><KpiCard label="เดือนนี้" :value="num(k.month.hours, 1)" unit="ชม." /><KpiCard label="สะสมทั้งปี" :value="num(k.ytd.hours, 1)" unit="ชม." /></div>
          <p class="small muted mt">เฉลี่ย {{ num(safeDiv(k.year.hours, k.year.employees), 1) }} ชม./คน/ปี</p></div>
        <div class="card"><h2 class="mb">6. Training Cost</h2>
          <div class="grid g2"><KpiCard label="เดือนนี้" :value="money(cost.month)" unit="บาท" color="var(--c4)" /><KpiCard label="สะสมทั้งปี" :value="money(cost.ytd)" unit="บาท" color="var(--c4)" /></div>
          <p class="small muted mt">Cost / Participant เฉลี่ย {{ money(safeDiv(cost.year, k.year.participants)) }} บาท</p></div>
      </div>

      <div class="grid g2">
        <div class="card"><h2 class="mb">7. Cost by Expense Type</h2>
          <DataTable v-if="(d.expense_by_group || []).length" :columns="[{ key: 'label', label: 'ประเภท' }, { key: 'items', label: 'รายการ', type: 'number' }, { key: 'amount', label: 'จำนวนเงิน', type: 'money' }]" :rows="d.expense_by_group" :paginate="false" row-key="label" />
          <div v-else class="empty">ยังไม่มีการบันทึกค่าใช้จ่าย</div></div>
        <div class="card"><h2 class="mb">8. Cost by Department</h2>
          <DataTable v-if="(d.cost_by_department || []).length" :columns="[{ key: 'label', label: 'ฝ่าย' }, { key: 'participants', label: 'คน-ครั้ง', type: 'number' }, { key: 'cost', label: 'Cost', type: 'money' }, { key: 'cost_per_employee', label: 'Cost/Employee', type: 'money' }]" :rows="d.cost_by_department" :paginate="false" row-key="label" />
          <div v-else class="empty">ยังไม่มีการบันทึกค่าใช้จ่าย</div></div>
      </div>

      <div class="card"><h2 class="mb">9. Budget vs Actual</h2>
        <div class="grid g4">
          <KpiCard label="Budget" :value="money(budget)" unit="บาท" color="var(--c6)" />
          <KpiCard label="Actual (YTD)" :value="money(cost.ytd)" unit="บาท" color="var(--c4)" />
          <KpiCard label="Variance" :value="budget ? money(budget - cost.ytd) : '-'" unit="บาท" />
          <KpiCard label="% Utilization" :value="budget ? pct((cost.ytd / budget) * 100, 1) : '-'" />
        </div></div>

      <div class="card"><h2 class="mb">10. Key Insights</h2><ul class="insights"><li v-for="(t, i) in insights" :key="i" v-html="t"></li></ul></div>

      <div class="card"><h2 class="mb">11. Detailed Training List — {{ TH_MONTHS_FULL[month - 1] }} {{ be(year) }}</h2>
        <DataTable :columns="listCols" :rows="list" :paginate="false" empty-text="ไม่มีการอบรมในเดือนนี้" /></div>
      <p class="small muted">ออกรายงานโดย ASW Training Record · {{ dateTimeTH(new Date()) }}</p>
    </div>
  </div>
</template>
<script setup>
import { computed, onMounted, ref, watch } from 'vue'
import PageHeader from '../../components/PageHeader.vue'
import KpiCard from '../../components/KpiCard.vue'
import DataTable from '../../components/DataTable.vue'
import FilterBar from '../../components/FilterBar.vue'
import ExportMenu from '../../components/ExportMenu.vue'
import { dashboard, filterOptions, cleanFilters } from '../../lib/api'
import { supabase, must } from '../../lib/supabase'
import { TH_MONTHS, TH_MONTHS_FULL, be, num, money, pct, safeDiv, changePct, dateTimeTH } from '../../lib/format'
import { buildInsights, dashboardCosts } from '../../lib/insights'
import { exportExcel, exportCSV, exportPDF, fileStamp } from '../../lib/export'

const logo = import.meta.env.BASE_URL + 'favicon.svg'
const now = new Date()
const year = ref(now.getFullYear()); const month = ref(now.getMonth() + 1); const years = ref([now.getFullYear()])
const filters = ref({}); const d = ref(null); const list = ref([]); const loading = ref(true); const page = ref(null)
const k = computed(() => d.value.kpi)
const cost = computed(() => dashboardCosts(d.value))
const budget = computed(() => Number(d.value?.budget?.budget || 0) || Number(d.value?.budget?.session_budget || 0))
const insights = computed(() => buildInsights(d.value, year.value, month.value))
const execSummary = computed(() => {
  const m = TH_MONTHS_FULL[month.value - 1]
  const ch = changePct(k.value.month.participants, k.value.prev_month.participants)
  return `เดือน${m} ${be(year.value)} มีการจัดอบรม ${num(k.value.month.sessions)} รอบ ผู้เข้าอบรม ${num(k.value.month.participants)} คน-ครั้ง (${num(k.value.month.employees)} คน)` +
    (ch !== null ? ` ${ch >= 0 ? 'เพิ่มขึ้น' : 'ลดลง'} ${Math.abs(ch).toFixed(1)}% จากเดือนก่อน` : '') +
    ` · สะสมตั้งแต่ต้นปี ${num(k.value.ytd.sessions)} รอบ ${num(k.value.ytd.participants)} คน-ครั้ง` +
    ` · ค่าใช้จ่ายเดือนนี้ ${money(cost.value.month)} บาท สะสม ${money(cost.value.ytd)} บาท` +
    ` · พนักงานผ่านเป้า ${k.value.target.target} หลักสูตร/ปี แล้ว ${num(k.value.target.met)} คน`
})
const deptCols = [{ key: 'label', label: 'ฝ่าย' }, { key: 'participants', label: 'คน-ครั้ง', type: 'number' }, { key: 'employees', label: 'พนักงาน', type: 'number' },
  { key: 'courses', label: 'หลักสูตร', type: 'number' }, { key: 'hours', label: 'ชั่วโมง', type: 'number', digits: 1 }, { key: 'cost', label: 'Cost', type: 'money' }, { key: 'cost_per_employee', label: 'Cost/Employee', type: 'money' }]
const courseCols = [{ key: 'label', label: 'หลักสูตร' }, { key: 'start_date', label: 'วันที่', type: 'date' }, { key: 'training_type', label: 'ประเภท' },
  { key: 'participants', label: 'คน-ครั้ง', type: 'number' }, { key: 'cost', label: 'Cost', type: 'money' }, { key: 'cost_per_person', label: 'Cost/Person', type: 'money' }]
const listCols = [{ key: 'start_date', label: 'วันที่', type: 'date' }, { key: 'session_name', label: 'หลักสูตร' }, { key: 'training_type', label: 'ประเภท' },
  { key: 'trainer_name', label: 'Trainer' }, { key: 'provider_name', label: 'Provider' }, { key: 'participant_count', label: 'ผู้เข้าอบรม', type: 'number' },
  { key: 'training_hours', label: 'ชม.', type: 'number', digits: 1 }, { key: 'total_cost', label: 'Cost', type: 'money' }, { key: 'cost_per_participant', label: 'Cost/Person', type: 'money' }, { key: 'status', label: 'สถานะ' }]
async function load() {
  loading.value = true
  try {
    d.value = await dashboard(filters.value, year.value, month.value)
    let q = supabase.from('v_session_summary').select('*').eq('fiscal_year', year.value).eq('month', month.value)
    const f = cleanFilters(filters.value)
    if (f.training_type_ids) q = q.in('training_type_id', f.training_type_ids)
    if (f.category_ids) q = q.in('category_id', f.category_ids)
    let rows = await must(q.order('start_date'))
    if (f.department_ids || f.company_ids) {
      const ids = new Set()
      const { data } = await supabase.from('v_participant_fact').select('session_id').eq('year', year.value).eq('month', month.value)
        .in(f.department_ids ? 'department_id' : 'company_id', f.department_ids || f.company_ids)
      ;(data || []).forEach((x) => ids.add(x.session_id))
      rows = rows.filter((r) => ids.has(r.id))
    }
    list.value = rows
  } finally { loading.value = false }
}
watch([year, month, filters], load, { deep: true })
onMounted(async () => {
  const o = await filterOptions()
  years.value = o.years.length ? o.years : years.value
  if (!years.value.includes(year.value)) year.value = years.value[years.value.length - 1]
  load()
})
async function doExport(kind) {
  const name = fileStamp('Training_Record_Report', [year.value, String(month.value).padStart(2, '0')])
  if (kind === 'pdf') return exportPDF(page.value, `${name}.pdf`, { landscape: false })
  if (kind === 'csv') return exportCSV(`${name}.csv`, listCols, list.value)
  const kpi = [
    ['รอบอบรมเดือนนี้', k.value.month.sessions], ['ผู้เข้าอบรมเดือนนี้ (คน-ครั้ง)', k.value.month.participants], ['เดือนก่อน (คน-ครั้ง)', k.value.prev_month.participants],
    ['พนักงานเดือนนี้', k.value.month.employees], ['รอบอบรมสะสม', k.value.ytd.sessions], ['คน-ครั้งสะสม', k.value.ytd.participants],
    ['ชั่วโมงเดือนนี้', k.value.month.hours], ['ชั่วโมงสะสม', k.value.ytd.hours], ['Cost เดือนนี้', cost.value.month], ['Cost สะสม', cost.value.ytd],
    ['Budget', budget.value], ['ผ่านเป้า (คน)', k.value.target.met],
  ].map(([label, value]) => ({ label, value }))
  await exportExcel(`${name}.xlsx`, [
    { name: 'Executive Summary', title: `Monthly Training Management Report ${TH_MONTHS_FULL[month.value - 1]} ${be(year.value)}`,
      columns: [{ key: 'label', label: 'หัวข้อ', width: 40 }, { key: 'value', label: 'ค่า', type: 'number', width: 20 }], rows: [{ label: execSummary.value }, ...kpi] },
    { name: 'Key Insights', columns: [{ key: 't', label: 'Insight', width: 120 }], rows: insights.value.map((t) => ({ t: t.replace(/<[^>]+>/g, '') })) },
    { name: 'Monthly Trend', columns: [{ key: 'm', label: 'เดือน' }, { key: 'sessions', label: 'รอบ', type: 'number' }, { key: 'participants', label: 'คน-ครั้ง', type: 'number' }, { key: 'employees', label: 'พนักงาน', type: 'number' }, { key: 'hours', label: 'ชม.', type: 'number' }, { key: 'cost', label: 'Cost', type: 'money' }],
      rows: d.value.monthly.map((x) => ({ ...x, m: TH_MONTHS[x.month - 1] })) },
    { name: 'Department', columns: deptCols, rows: d.value.top_departments || [] },
    { name: 'Top Courses', columns: courseCols, rows: d.value.top_courses || [] },
    { name: 'Cost by Expense', columns: [{ key: 'label', label: 'ประเภท' }, { key: 'amount', label: 'จำนวนเงิน', type: 'money' }], rows: d.value.expense_by_group || [] },
    { name: 'Cost by Department', columns: [{ key: 'label', label: 'ฝ่าย' }, { key: 'cost', label: 'Cost', type: 'money' }, { key: 'cost_per_employee', label: 'Cost/Employee', type: 'money' }], rows: d.value.cost_by_department || [] },
    { name: 'Training List', columns: listCols, rows: list.value },
  ])
}
</script>
