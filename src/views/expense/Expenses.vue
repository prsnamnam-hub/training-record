<template>
  <div>
    <PageHeader :title="meta.title" :subtitle="meta.subtitle">
      <ExportMenu :handler="doExport" :pdf="false" />
      <button v-if="canEdit" class="btn primary" @click="openAdd">+ เพิ่มค่าใช้จ่าย</button>
    </PageHeader>
    <div class="card">
      <div class="filterbar">
        <div class="field" style="flex:2;max-width:none"><label>ค้นหา</label><input v-model="search" class="input" placeholder="ชื่อหลักสูตร / รุ่น" @input="debounced" /></div>
        <div class="field"><label>ปี (พ.ศ.)</label><MultiSelect v-model="f.years" :options="yearOpts" /></div>
        <div class="field"><label>เดือน</label><MultiSelect v-model="f.months" :options="TH_MONTHS.map((m, i) => ({ id: i + 1, name: m }))" /></div>
        <div class="field"><label>ประเภทค่าใช้จ่าย</label><MultiSelect v-model="f.cats" :options="catOpts" /></div>
        <div v-if="kind === 'food'" class="field"><label>มื้ออาหาร</label><MultiSelect v-model="f.meals" :options="MEAL_TYPES.map((m) => ({ id: m, name: MEAL_TH[m] }))" /></div>
      </div>
    </div>
    <div class="grid g4 mb">
      <KpiCard label="รวมค่าใช้จ่าย" :value="money(sumAmount)" unit="บาท" color="var(--c4)" />
      <KpiCard label="จำนวนรายการ" :value="num(rows.length)" />
      <KpiCard label="จำนวนรอบอบรม" :value="num(new Set(rows.map((r) => r.session_id)).size)" />
      <KpiCard :label="kind === 'food' ? 'Quantity รวม (ที่/ชุด)' : 'ค่าเฉลี่ยต่อรอบ'" :value="kind === 'food' ? num(sumQty) : money(sumAmount / (new Set(rows.map((r) => r.session_id)).size || 1))" />
    </div>
    <div class="grid g2 mb" v-if="rows.length">
      <div class="card"><div class="card-title"><h3>ตามประเภทค่าใช้จ่าย</h3></div><EChart :option="chartCat" /></div>
      <div class="card"><div class="card-title"><h3>รายเดือน</h3></div><EChart :option="chartMonth" /></div>
    </div>
    <div class="card">
      <DataTable :columns="cols" :rows="rows" :loading="loading">
        <template #cell-session_name="{ row }"><RouterLink :to="`/training/sessions/${row.session_id}?tab=expense`">{{ row.session_name }}</RouterLink></template>
      </DataTable>
    </div>

    <Modal :open="adding" title="เพิ่มค่าใช้จ่าย — เลือกหลักสูตร" wide @close="adding = false">
      <div class="field mb"><label>หลักสูตร / รุ่น <span class="req">*</span></label>
        <input v-model="sq" class="input" placeholder="พิมพ์ชื่อหลักสูตรเพื่อค้นหา" @input="searchSessions" />
        <select v-model="newSession" class="input mt" size="5">
          <option v-for="s in sessionResults" :key="s.id" :value="s.id">{{ s.session_name }} · {{ dateTH(s.start_date) }} · {{ s.participant_count }} คน</option>
        </select></div>
      <ExpenseLines v-model="lines" :categories="allCats" />
      <button class="btn sm mt" @click="lines.push(blank())">+ เพิ่มบรรทัด</button>
      <template #footer><button class="btn" @click="adding = false">ยกเลิก</button><button class="btn primary" @click="saveNew">บันทึก</button></template>
    </Modal>
  </div>
</template>
<script setup>
import { computed, onMounted, ref, watch } from 'vue'
import { useRoute } from 'vue-router'
import PageHeader from '../../components/PageHeader.vue'
import DataTable from '../../components/DataTable.vue'
import MultiSelect from '../../components/MultiSelect.vue'
import KpiCard from '../../components/KpiCard.vue'
import EChart from '../../components/EChart.vue'
import Modal from '../../components/Modal.vue'
import ExpenseLines from '../../components/ExpenseLines.vue'
import ExportMenu from '../../components/ExportMenu.vue'
import { supabase, must } from '../../lib/supabase'
import { filterOptions, fetchAll } from '../../lib/api'
import { canEdit } from '../../lib/auth'
import { TH_MONTHS, num, money, dateTH } from '../../lib/format'
import { MEAL_TYPES, MEAL_TH } from '../../lib/constants'
import { toastOk, toastError } from '../../lib/toast'
import { exportExcel, exportCSV, fileStamp } from '../../lib/export'

const route = useRoute()
const kind = route.params.kind
const META = {
  all: { title: 'ค่าใช้จ่ายการอบรม', subtitle: 'ค่าใช้จ่ายของทุกหลักสูตร — เพิ่ม/แก้ไขได้ในหน้ารายละเอียดของแต่ละหลักสูตร' },
  food: { title: 'ค่าอาหาร', subtitle: 'ค่าอาหาร / เครื่องดื่ม ของทุกหลักสูตร' },
  other: { title: 'ค่าใช้จ่ายอื่น ๆ', subtitle: 'ค่าใช้จ่ายอื่น ๆ ของทุกหลักสูตร' },
}
const meta = META[kind] || META.all
const rows = ref([]); const loading = ref(false); const search = ref('')
const f = ref({ years: [], months: [], cats: [], meals: [] })
const yearOpts = ref([]); const allCats = ref([])
const catOpts = computed(() => allCats.value.filter(scopeCat).map((c) => ({ id: c.id, name: `${c.name}${c.name_th ? ' — ' + c.name_th : ''}` })))
const OTHER_GROUPS = ['Material', 'Transportation', 'Other']
function scopeCat(c) {
  if (kind === 'food') return c.is_food
  if (kind === 'other') return !c.is_food && OTHER_GROUPS.includes(c.cost_group) && c.name !== 'Transportation'
  return true
}
const cols = [
  { key: 'session_name', label: 'หลักสูตร / รุ่น' }, { key: 'category', label: 'ประเภทค่าใช้จ่าย' },
  { key: 'quantity', label: 'จำนวน', type: 'number' }, { key: 'unit_price', label: 'ราคา/หน่วย', type: 'money' }, { key: 'amount', label: 'รวม', type: 'money' },
]
const sumAmount = computed(() => rows.value.reduce((a, r) => a + Number(r.amount), 0))
const sumQty = computed(() => rows.value.reduce((a, r) => a + Number(r.quantity), 0))
const chartCat = computed(() => {
  const m = {}; rows.value.forEach((r) => { m[r.category] = (m[r.category] || 0) + Number(r.amount) })
  return { tooltip: { trigger: 'item' }, legend: { bottom: 0, type: 'scroll' }, series: [{ type: 'pie', radius: ['40%', '70%'], center: ['50%', '42%'], data: Object.entries(m).map(([name, value]) => ({ name, value: Math.round(value) })) }] }
})
const chartMonth = computed(() => {
  const m = {}; rows.value.forEach((r) => { const k = (r.expense_date || r.start_date || '').slice(0, 7) || 'ไม่ระบุ'; m[k] = (m[k] || 0) + Number(r.amount) })
  const keys = Object.keys(m).sort()
  return { xAxis: { type: 'category', data: keys }, yAxis: { type: 'value' }, series: [{ type: 'bar', name: 'บาท', data: keys.map((k) => Math.round(m[k])) }] }
})
async function load() {
  loading.value = true
  try {
    let q = supabase.from('training_expenses').select('*, expense_categories!inner(name, name_th, is_food, cost_group), training_sessions!inner(session_name, start_date, fiscal_year)').is('deleted_at', null)
    const scoped = allCats.value.filter(scopeCat).map((c) => c.id)
    const cats = f.value.cats.length ? f.value.cats : kind === 'all' ? [] : scoped
    if (cats.length) q = q.in('expense_category_id', cats)
    if (f.value.years.length) q = q.in('training_sessions.fiscal_year', f.value.years)
    if (f.value.meals.length) q = q.in('meal_type', f.value.meals)
    let data = await fetchAll(q.order('id', { ascending: false }))
    data = data.map((r) => ({ ...r, session_name: r.training_sessions.session_name, start_date: r.training_sessions.start_date,
      category: r.expense_categories.name + (r.expense_categories.name_th ? ` (${r.expense_categories.name_th})` : '') }))
    if (f.value.months.length) data = data.filter((r) => f.value.months.includes(Number((r.expense_date || r.start_date || '').slice(5, 7))))
    const s = search.value.trim().toLowerCase()
    if (s) data = data.filter((r) => [r.session_name, r.description, r.vendor, r.invoice_no].some((x) => String(x || '').toLowerCase().includes(s)))
    rows.value = data
  } finally { loading.value = false }
}
let t; const debounced = () => { clearTimeout(t); t = setTimeout(load, 300) }
watch(f, load, { deep: true })

// add
const adding = ref(false); const sq = ref(''); const sessionResults = ref([]); const newSession = ref(null); const lines = ref([])
const blank = () => ({ expense_category_id: kind === 'food' ? allCats.value.find((c) => c.name === 'Food')?.id : null, description: '', meal_type: null, quantity: 1, unit_price: 0 })
function openAdd() { adding.value = true; lines.value = [blank()]; searchSessions() }
async function searchSessions() {
  let q = supabase.from('v_session_summary').select('id, session_name, start_date, participant_count')
  const s = sq.value.replace(/[%,()]/g, ' ').trim()
  if (s) q = q.ilike('session_name', `%${s}%`)
  sessionResults.value = await must(q.order('start_date', { ascending: false, nullsFirst: false }).limit(30))
}
async function saveNew() {
  if (!newSession.value) return toastError(new Error('กรุณาเลือก Training Session'))
  if (lines.value.some((l) => !l.expense_category_id)) return toastError(new Error('กรุณาเลือกประเภทค่าใช้จ่ายให้ครบ'))
  try {
    await must(supabase.from('training_expenses').insert(lines.value.map((l) => ({ ...l, session_id: newSession.value, data_source: 'System Entry' }))))
    toastOk('บันทึกค่าใช้จ่ายเรียบร้อย'); adding.value = false; load()
  } catch (e) { toastError(e) }
}
async function doExport(k) {
  const name = fileStamp(kind === 'food' ? 'Training_Food_Expense' : kind === 'other' ? 'Training_Other_Expense' : 'Training_Expense', [new Date().toISOString().slice(0, 10)])
  const c = [...cols, { key: 'remark', label: 'หมายเหตุ' }]
  if (k === 'csv') return exportCSV(`${name}.csv`, c, rows.value)
  return exportExcel(`${name}.xlsx`, [{ name: meta.title, title: meta.title, columns: c, rows: rows.value }])
}
onMounted(async () => {
  const o = await filterOptions()
  yearOpts.value = o.years.map((y) => ({ id: y, name: String(y + 543) }))
  allCats.value = o.expense_categories
  load()
})
</script>
