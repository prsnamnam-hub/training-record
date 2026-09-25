<template>
  <div>
    <PageHeader title="รายชื่อพนักงาน" subtitle="ฐานข้อมูลพนักงาน — ใช้ดึงชื่อและฝ่ายตอนคีย์รหัสพนักงานเข้าหลักสูตร · เพิ่มจำนวนมากได้ที่ นำเข้าพนักงาน (Excel)">
      <ExportMenu :handler="doExport" :pdf="false" />
      <button v-if="canEdit" class="btn primary" @click="open({})">+ เพิ่มพนักงาน</button>
    </PageHeader>
    <div class="card">
      <div class="filterbar">
        <div class="field" style="flex:2;max-width:none"><label>ค้นหา</label><input v-model="search" class="input" placeholder="รหัส / ชื่อ / ชื่อเล่น" @input="debounced" /></div>
        <div class="field"><label>บริษัท</label><MultiSelect v-model="f.company" :options="o.companies || []" /></div>
        <div class="field"><label>ฝ่าย</label><MultiSelect v-model="f.dept" :options="o.departments || []" /></div>
        <div class="field"><label>กลุ่มระดับ</label><MultiSelect v-model="f.level" :options="o.level_groups || []" /></div>
        <div class="field"><label>สถานะ</label><MultiSelect v-model="f.status" :options="STATUS_OPTS" /></div>
      </div>
    </div>
    <div class="card">
      <DataTable :columns="cols" :rows="rows" :loading="loading" :total="total" v-model:page="page" v-model:size="size"
                 @sort="(s) => { order = s; load() }" @row-click="(r) => $router.push(`/master/employees/${r.id}`)">
        <template #cell-employment_status="{ row }"><span class="badge" :class="row.employment_status === 'Active' ? 'green' : ''">{{ row.employment_status || '-' }}</span></template>
        <template #cell-name_check_result="{ row }"><span v-if="row.name_check_result && row.name_check_result !== 'OK'" class="badge amber" :title="row.name_check_result">ตรวจสอบ</span>
          <span v-if="!row.in_hr_master" class="badge red">ไม่พบใน HR</span></template>
        <template v-if="canEdit" #actions="{ row }"><button class="btn sm" @click="open(row)">แก้ไข</button></template>
      </DataTable>
    </div>
    <Modal :open="!!edit" :title="edit?.id ? 'แก้ไขพนักงาน' : 'เพิ่มพนักงาน'" wide @close="edit = null">
      <div v-if="edit" class="form-grid">
        <div class="field"><label>รหัสพนักงาน <span class="req">*</span></label><input v-model="edit.employee_code" class="input" :disabled="!!edit.id" /></div>
        <div class="field"><label>คำนำหน้า</label><input v-model="edit.title_th" class="input" /></div>
        <div class="field"><label>ชื่อ <span class="req">*</span></label><input v-model="edit.first_name_th" class="input" /></div>
        <div class="field"><label>นามสกุล</label><input v-model="edit.last_name_th" class="input" /></div>
        <div class="field"><label>ชื่อเล่น</label><input v-model="edit.nickname" class="input" /></div>
        <div class="field"><label>บริษัท</label><select v-model="edit.company_id" class="input"><option :value="null">-</option><option v-for="x in o.companies" :key="x.id" :value="x.id">{{ x.name }}</option></select></div>
        <div class="field"><label>ฝ่าย</label><select v-model="edit.department_id" class="input"><option :value="null">-</option><option v-for="x in o.departments" :key="x.id" :value="x.id">{{ x.name }}</option></select></div>
        <div class="field"><label>Section</label><select v-model="edit.section_id" class="input"><option :value="null">-</option><option v-for="x in o.sections" :key="x.id" :value="x.id">{{ x.name }}</option></select></div>
        <div class="field"><label>กลุ่มระดับพนักงาน</label><select v-model="edit.level_group_id" class="input"><option :value="null">-</option><option v-for="x in o.level_groups" :key="x.id" :value="x.id">{{ x.name }}</option></select></div>
        <div class="field"><label>ระดับตำแหน่ง</label><select v-model="edit.position_id" class="input"><option :value="null">-</option><option v-for="x in positions" :key="x.id" :value="x.id">{{ x.name }}</option></select></div>
        <div class="field"><label>ตำแหน่ง (Job title)</label><input v-model="edit.job_title" class="input" /></div>
        <div class="field"><label>ประเภทการจ้าง</label><input v-model="edit.employment_type" class="input" list="emp-type" /><datalist id="emp-type"><option>Permanent</option><option>Contract</option><option>Probation</option></datalist></div>
        <div class="field"><label>สถานะ</label><select v-model="edit.employment_status" class="input"><option v-for="s in STATUS_OPTS" :key="s.id">{{ s.id }}</option></select></div>
        <div class="field"><label>วันที่จ้างงาน</label><input v-model="edit.hire_date" type="date" class="input" /></div>
        <div class="field"><label>วันที่พ้นสภาพ</label><input v-model="edit.termination_date" type="date" class="input" /></div>
      </div>
      <div v-if="error" class="alert err mt">{{ error }}</div>
      <template #footer><button class="btn" @click="edit = null">ยกเลิก</button><button class="btn primary" @click="save">บันทึก</button></template>
    </Modal>
  </div>
</template>
<script setup>
import { onMounted, ref, watch } from 'vue'
import PageHeader from '../../components/PageHeader.vue'
import DataTable from '../../components/DataTable.vue'
import MultiSelect from '../../components/MultiSelect.vue'
import Modal from '../../components/Modal.vue'
import ExportMenu from '../../components/ExportMenu.vue'
import { supabase, must } from '../../lib/supabase'
import { filterOptions, fetchAll } from '../../lib/api'
import { canEdit } from '../../lib/auth'
import { toastOk } from '../../lib/toast'
import { exportExcel, exportCSV, fileStamp } from '../../lib/export'

const STATUS_OPTS = ['Active', 'In-Active', 'Title', 'คนขับรถ', 'Messenger'].map((s) => ({ id: s, name: s }))
const rows = ref([]); const total = ref(0); const page = ref(1); const size = ref(50); const loading = ref(false)
const search = ref(''); const order = ref({ key: 'employee_code', asc: true }); const o = ref({}); const positions = ref([])
const f = ref({ company: [], dept: [], level: [], status: [] })
const edit = ref(null); const error = ref('')
const cols = [
  { key: 'employee_code', label: 'รหัส' }, { key: 'full_name', label: 'ชื่อ-นามสกุล' }, { key: 'nickname', label: 'ชื่อเล่น' },
  { key: 'company', label: 'บริษัท', sortable: false }, { key: 'department', label: 'ฝ่าย', sortable: false }, { key: 'level_group', label: 'กลุ่มระดับ', sortable: false },
  { key: 'position', label: 'ระดับตำแหน่ง', sortable: false }, { key: 'employment_status', label: 'สถานะ' }, { key: 'hire_date', label: 'วันที่จ้าง', type: 'date' },
  { key: 'name_check_result', label: 'Data Quality', sortable: false },
]
function query(count) {
  let q = supabase.from('employees').select('*, companies(name), departments(name), level_groups(name), positions(name)', count ? { count: 'exact' } : undefined).is('deleted_at', null)
  const s = search.value.replace(/[%,()]/g, ' ').trim()
  if (s) q = q.or(`employee_code.ilike.%${s}%,full_name.ilike.%${s}%,nickname.ilike.%${s}%`)
  if (f.value.company.length) q = q.in('company_id', f.value.company)
  if (f.value.dept.length) q = q.in('department_id', f.value.dept)
  if (f.value.level.length) q = q.in('level_group_id', f.value.level)
  if (f.value.status.length) q = q.in('employment_status', f.value.status)
  return q.order(order.value.key, { ascending: order.value.asc, nullsFirst: false })
}
const flat = (r) => ({ ...r, company: r.companies?.name, department: r.departments?.name, level_group: r.level_groups?.name, position: r.positions?.name })
async function load() {
  loading.value = true
  try { const from = (page.value - 1) * size.value; const r = await must(query(true).range(from, from + size.value - 1)); rows.value = r.data.map(flat); total.value = r.count }
  finally { loading.value = false }
}
let t; const debounced = () => { clearTimeout(t); t = setTimeout(() => { page.value = 1; load() }, 300) }
watch(f, () => { page.value = 1; load() }, { deep: true })
watch([page, size], load)
function open(r) { error.value = ''; edit.value = { employment_status: 'Active', ...r } }
async function save() {
  const e = edit.value; error.value = ''
  if (!e.employee_code || !e.first_name_th) { error.value = 'กรุณากรอกรหัสพนักงานและชื่อ'; return }
  const patch = {}
  for (const k of ['employee_code', 'title_th', 'first_name_th', 'last_name_th', 'nickname', 'company_id', 'department_id', 'section_id', 'level_group_id',
    'position_id', 'job_title', 'employment_type', 'employment_status', 'hire_date', 'termination_date']) patch[k] = e[k] === '' ? null : e[k] ?? null
  try {
    if (e.id) await must(supabase.from('employees').update(patch).eq('id', e.id))
    else await must(supabase.from('employees').insert({ ...patch, employee_code: String(patch.employee_code).trim(), data_source: 'System Entry' }))
    toastOk('บันทึกเรียบร้อย'); edit.value = null; load()
  } catch (err) { error.value = err.message.includes('duplicate') ? 'รหัสพนักงานนี้มีอยู่แล้ว' : err.message }
}
async function doExport(kind) {
  const all = (await fetchAll(query(false))).map(flat)
  const c = [...cols.filter((x) => x.key !== 'name_check_result'), { key: 'job_title', label: 'ตำแหน่ง' }, { key: 'termination_date', label: 'วันที่พ้นสภาพ', type: 'date' }, { key: 'data_source', label: 'แหล่งข้อมูล' }]
  const name = fileStamp('Training_Employees', [new Date().toISOString().slice(0, 10)])
  if (kind === 'csv') return exportCSV(`${name}.csv`, c, all)
  return exportExcel(`${name}.xlsx`, [{ name: 'Employees', title: 'Employee Master', columns: c, rows: all }])
}
onMounted(async () => {
  o.value = await filterOptions()
  positions.value = await must(supabase.from('positions').select('id, name').order('code'))
  load()
})
</script>
