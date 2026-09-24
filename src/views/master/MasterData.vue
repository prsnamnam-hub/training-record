<template>
  <div v-if="cfg">
    <PageHeader :title="cfg.title" :subtitle="cfg.subtitle" crumb="Master Data">
      <ExportMenu :handler="doExport" :pdf="false" />
      <button v-if="canEdit" class="btn primary" @click="open({})">+ เพิ่ม</button>
    </PageHeader>
    <div class="card">
      <div class="row mb"><input v-model="q" class="input" style="max-width:320px" placeholder="ค้นหา..." />
        <label v-if="cfg.hasActive" class="small"><input type="checkbox" v-model="showInactive" /> แสดงรายการที่ปิดใช้งาน</label></div>
      <DataTable :columns="cfg.columns" :rows="shown" :loading="loading">
        <template #cell-is_active="{ row }"><span class="badge" :class="row.is_active ? 'green' : ''">{{ row.is_active ? 'Active' : 'Inactive' }}</span></template>
        <template #cell-is_internal="{ row }">{{ row.is_internal ? 'Internal' : 'External' }}</template>
        <template #cell-is_food="{ row }">{{ row.is_food ? '✓' : '' }}</template>
        <template v-if="canEdit" #actions="{ row }"><button class="btn sm" @click="open(row)">แก้ไข</button>
          <button v-if="entity === 'budgets'" class="btn sm danger" @click="del(row)">ลบ</button></template>
      </DataTable>
    </div>
    <Modal :open="!!edit" :title="(edit?.id ? 'แก้ไข ' : 'เพิ่ม ') + cfg.title" @close="edit = null">
      <div v-if="edit" class="form-grid">
        <div v-for="f in cfg.fields" :key="f.key" class="field" :class="{ wide: f.wide }">
          <label>{{ f.label }} <span v-if="f.required" class="req">*</span></label>
          <select v-if="f.type === 'select'" v-model="edit[f.key]" class="input">
            <option :value="null">-</option><option v-for="o in optionsFor(f)" :key="o.id ?? o" :value="o.id ?? o">{{ o.name ?? o }}</option></select>
          <label v-else-if="f.type === 'bool'" class="row"><input type="checkbox" v-model="edit[f.key]" /> {{ f.hint || 'ใช่' }}</label>
          <textarea v-else-if="f.type === 'textarea'" v-model="edit[f.key]" class="input"></textarea>
          <input v-else v-model="edit[f.key]" :type="f.type || 'text'" class="input" :step="f.type === 'number' ? 'any' : undefined" />
        </div>
      </div>
      <div v-if="error" class="alert err mt">{{ error }}</div>
      <template #footer><button class="btn" @click="edit = null">ยกเลิก</button><button class="btn primary" @click="save">บันทึก</button></template>
    </Modal>
  </div>
</template>
<script setup>
import { computed, onMounted, ref } from 'vue'
import { useRoute } from 'vue-router'
import PageHeader from '../../components/PageHeader.vue'
import DataTable from '../../components/DataTable.vue'
import Modal from '../../components/Modal.vue'
import ExportMenu from '../../components/ExportMenu.vue'
import { supabase, must } from '../../lib/supabase'
import { filterOptions, invalidateOptions } from '../../lib/api'
import { canEdit } from '../../lib/auth'
import { COST_GROUPS } from '../../lib/constants'
import { toastOk, toastError } from '../../lib/toast'
import { exportExcel, exportCSV, fileStamp } from '../../lib/export'

const route = useRoute()
const entity = route.params.entity
const active = { key: 'is_active', label: 'สถานะ', type: 'bool', hint: 'Active' }
const CONFIG = {
  categories: { table: 'training_categories', title: 'Training Category', subtitle: 'หมวดหมู่หลักสูตร', hasActive: true,
    columns: [{ key: 'name', label: 'ชื่อหมวดหมู่' }, { key: 'description', label: 'คำอธิบาย' }, { key: 'is_active', label: 'สถานะ' }],
    fields: [{ key: 'name', label: 'ชื่อหมวดหมู่', required: true }, { key: 'description', label: 'คำอธิบาย', wide: true }, active] },
  'training-types': { table: 'training_types', title: 'Training Type', subtitle: 'ประเภทการอบรม (จาก Excel: Inhouse / Public / Online)', hasActive: true, order: 'sort_order',
    columns: [{ key: 'name', label: 'ประเภท' }, { key: 'is_internal', label: 'Internal / External' }, { key: 'sort_order', label: 'ลำดับ', type: 'number' }, { key: 'is_active', label: 'สถานะ' }],
    fields: [{ key: 'name', label: 'ชื่อประเภท', required: true }, { key: 'is_internal', label: 'Internal Training', type: 'bool', hint: 'จัดภายใน (Internal)' }, { key: 'sort_order', label: 'ลำดับ', type: 'number' }, active] },
  trainers: { table: 'trainers', title: 'Trainer', subtitle: 'วิทยากร', hasActive: true, select: '*, training_providers(name)',
    columns: [{ key: 'name', label: 'ชื่อวิทยากร' }, { key: 'is_internal', label: 'ภายใน/ภายนอก' }, { key: 'provider', label: 'สังกัด Provider' }, { key: 'expertise', label: 'ความเชี่ยวชาญ' }, { key: 'is_active', label: 'สถานะ' }],
    fields: [{ key: 'name', label: 'ชื่อวิทยากร', required: true }, { key: 'is_internal', label: 'วิทยากรภายใน', type: 'bool', hint: 'พนักงานภายใน' },
      { key: 'provider_id', label: 'Provider', type: 'select', source: 'providers' }, { key: 'expertise', label: 'ความเชี่ยวชาญ', wide: true }, { key: 'remark', label: 'หมายเหตุ', wide: true }, active] },
  providers: { table: 'training_providers', title: 'Training Provider', subtitle: 'ผู้จัดอบรม / สถาบัน', hasActive: true,
    columns: [{ key: 'name', label: 'ชื่อ Provider' }, { key: 'contact', label: 'ผู้ติดต่อ' }, { key: 'phone', label: 'โทรศัพท์' }, { key: 'email', label: 'อีเมล' }, { key: 'is_active', label: 'สถานะ' }],
    fields: [{ key: 'name', label: 'ชื่อ Provider', required: true }, { key: 'contact', label: 'ผู้ติดต่อ' }, { key: 'phone', label: 'โทรศัพท์' }, { key: 'email', label: 'อีเมล', type: 'email' }, { key: 'remark', label: 'หมายเหตุ', wide: true }, active] },
  departments: { table: 'departments', title: 'Department', subtitle: 'ฝ่าย (รหัสหน่วยงาน + ชื่อฝ่าย จาก Excel)', hasActive: true, order: 'name', select: '*, business_groups(code)',
    columns: [{ key: 'code', label: 'รหัสหน่วยงาน' }, { key: 'name', label: 'ชื่อฝ่าย' }, { key: 'bg', label: 'กลุ่มธุรกิจ' }, { key: 'is_active', label: 'สถานะ' }],
    fields: [{ key: 'code', label: 'รหัสหน่วยงาน' }, { key: 'name', label: 'ชื่อฝ่าย', required: true }, { key: 'business_group_id', label: 'กลุ่มธุรกิจ', type: 'select', source: 'business_groups' }, active] },
  sections: { table: 'sections', title: 'Section', subtitle: 'หน่วยงานย่อยภายใต้ฝ่าย (Excel เดิมไม่มีระดับ Section — เพิ่มได้ที่นี่)', hasActive: true, order: 'name', select: '*, departments(name)',
    columns: [{ key: 'name', label: 'Section' }, { key: 'dept', label: 'ฝ่าย' }, { key: 'is_active', label: 'สถานะ' }],
    fields: [{ key: 'name', label: 'ชื่อ Section', required: true }, { key: 'department_id', label: 'ฝ่าย', type: 'select', source: 'departments', required: true }, active] },
  companies: { table: 'companies', title: 'Company', subtitle: 'บริษัทในกลุ่ม (จาก Employee Info Report)', hasActive: true, order: 'code',
    columns: [{ key: 'code', label: 'รหัสบริษัท' }, { key: 'name', label: 'ชื่อบริษัท' }, { key: 'area_code', label: 'Area Code' }, { key: 'is_active', label: 'สถานะ' }],
    fields: [{ key: 'code', label: 'รหัสบริษัท', required: true }, { key: 'name', label: 'ชื่อบริษัท', required: true, wide: true }, { key: 'area_code', label: 'Area Code' }, { key: 'area_name', label: 'Area Name' }, active] },
  'expense-categories': { table: 'expense_categories', title: 'Expense Category', subtitle: 'ประเภทค่าใช้จ่าย — เพิ่มประเภทใหม่ได้เอง', hasActive: true, order: 'sort_order',
    columns: [{ key: 'name', label: 'ประเภท' }, { key: 'name_th', label: 'ชื่อไทย' }, { key: 'cost_group', label: 'กลุ่มต้นทุน' }, { key: 'is_food', label: 'ค่าอาหาร' }, { key: 'is_active', label: 'สถานะ' }],
    fields: [{ key: 'name', label: 'ชื่อ (EN)', required: true }, { key: 'name_th', label: 'ชื่อไทย' }, { key: 'cost_group', label: 'กลุ่มต้นทุน (ใช้ใน Cost Calculation)', type: 'select', source: 'cost_groups', required: true },
      { key: 'is_food', label: 'เป็นค่าอาหาร/เครื่องดื่ม', type: 'bool', hint: 'แสดงช่องมื้ออาหาร' }, { key: 'sort_order', label: 'ลำดับ', type: 'number' }, active] },
  budgets: { table: 'training_budgets', title: 'Training Budget', subtitle: 'งบประมาณการอบรม (Budget vs Actual)', order: 'fiscal_year', asc: false,
    select: '*, departments(name), companies(name), expense_categories(name)',
    columns: [{ key: 'fiscal_year_be', label: 'ปี (พ.ศ.)' }, { key: 'company', label: 'บริษัท' }, { key: 'dept', label: 'ฝ่าย' }, { key: 'cat', label: 'ประเภทค่าใช้จ่าย' }, { key: 'budget_amount', label: 'งบประมาณ', type: 'money' }, { key: 'remark', label: 'หมายเหตุ' }],
    fields: [{ key: 'fiscal_year', label: 'ปี (ค.ศ.) เช่น 2026', type: 'number', required: true }, { key: 'company_id', label: 'บริษัท (ว่าง = ทั้งหมด)', type: 'select', source: 'companies' },
      { key: 'department_id', label: 'ฝ่าย (ว่าง = ทั้งหมด)', type: 'select', source: 'departments' }, { key: 'expense_category_id', label: 'ประเภทค่าใช้จ่าย (ว่าง = ทั้งหมด)', type: 'select', source: 'expense_categories' },
      { key: 'budget_amount', label: 'งบประมาณ (บาท)', type: 'number', required: true }, { key: 'remark', label: 'หมายเหตุ', wide: true }] },
}
const cfg = CONFIG[entity]
const rows = ref([]); const loading = ref(false); const q = ref(''); const showInactive = ref(false)
const edit = ref(null); const error = ref(''); const opts = ref({})
const shown = computed(() => {
  let r = rows.value
  if (cfg?.hasActive && !showInactive.value) r = r.filter((x) => x.is_active !== false)
  const s = q.value.trim().toLowerCase()
  return s ? r.filter((x) => Object.values(x).some((v) => typeof v === 'string' && v.toLowerCase().includes(s))) : r
})
function optionsFor(f) {
  if (f.source === 'cost_groups') return COST_GROUPS
  return opts.value[f.source] || []
}
async function load() {
  loading.value = true
  try {
    const data = await must(supabase.from(cfg.table).select(cfg.select || '*').order(cfg.order || 'name', { ascending: cfg.asc ?? true }))
    rows.value = data.map((r) => ({ ...r, provider: r.training_providers?.name, bg: r.business_groups?.code, dept: r.departments?.name,
      company: r.companies?.name, cat: r.expense_categories?.name, fiscal_year_be: r.fiscal_year ? r.fiscal_year + 543 : undefined }))
  } finally { loading.value = false }
}
function open(r) {
  error.value = ''
  const base = { is_active: true }
  edit.value = { ...base, ...Object.fromEntries(cfg.fields.map((f) => [f.key, r[f.key] ?? (f.type === 'bool' ? base[f.key] ?? false : null)])), id: r.id }
}
async function save() {
  error.value = ''
  for (const f of cfg.fields) if (f.required && (edit.value[f.key] === null || edit.value[f.key] === '')) { error.value = `กรุณากรอก ${f.label}`; return }
  const { id, ...patch } = edit.value
  for (const f of cfg.fields) if (f.type === 'number' && patch[f.key] !== null && patch[f.key] !== '') patch[f.key] = Number(patch[f.key])
  for (const k in patch) if (patch[k] === '') patch[k] = null
  try {
    if (id) await must(supabase.from(cfg.table).update(patch).eq('id', id))
    else await must(supabase.from(cfg.table).insert(patch))
    toastOk('บันทึกเรียบร้อย'); edit.value = null; invalidateOptions(); load()
  } catch (e) { error.value = e.message.includes('duplicate') ? 'มีข้อมูลนี้อยู่แล้ว (ซ้ำ)' : e.message }
}
async function del(r) {
  if (!confirm('ลบงบประมาณรายการนี้?')) return
  try { await must(supabase.from(cfg.table).delete().eq('id', r.id)); load() } catch (e) { toastError(e) }
}
async function doExport(kind) {
  const name = fileStamp(cfg.title.replace(/\s+/g, '_'), [new Date().toISOString().slice(0, 10)])
  const c = cfg.columns.map((x) => ({ ...x, value: x.key === 'is_active' ? (r) => (r.is_active ? 'Active' : 'Inactive') : undefined }))
  if (kind === 'csv') return exportCSV(`${name}.csv`, c, shown.value)
  return exportExcel(`${name}.xlsx`, [{ name: cfg.title, title: cfg.title, columns: c, rows: shown.value }])
}
onMounted(async () => {
  if (!cfg) return
  const o = await filterOptions(true)
  opts.value = { providers: o.providers, business_groups: o.business_groups, departments: o.departments, companies: o.companies, expense_categories: o.expense_categories }
  load()
})
</script>
