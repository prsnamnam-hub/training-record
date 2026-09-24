<template>
  <div>
    <div class="row mb no-print">
      <input v-model="q" class="input" style="max-width:280px" placeholder="ค้นหาในรายชื่อ" />
      <span class="spacer" style="flex:1"></span>
      <template v-if="canEdit">
        <button class="btn sm primary" @click="pickOpen = true">+ เพิ่มผู้เข้าอบรม</button>
        <label class="btn sm">⬆ Import Excel (รหัสพนักงาน)<input type="file" accept=".xlsx" hidden @change="importFile" /></label>
        <button class="btn sm" :disabled="!dirty.size || saving" @click="saveResults">บันทึกผลการอบรม ({{ dirty.size }})</button>
        <MultiSelect v-model="bulkAttend" :options="ATTENDANCE.map((a) => ({ id: a, name: 'ตั้งค่าทั้งหมด: ' + a }))" :multiple="false" placeholder="ตั้งค่าการเข้าร่วมทั้งหมด" style="min-width:210px" @update:model-value="applyBulk" />
      </template>
      <ExportMenu :handler="doExport" :pdf="false" />
    </div>
    <DataTable :columns="cols" :rows="shown" :loading="loading" :size="100">
      <template #cell-employee_name="{ row }">
        <RouterLink :to="`/master/employees/${row.employee_id}`">{{ row.employee_name }}</RouterLink>
        <div class="small muted">{{ row.employee_code }} · {{ row.nickname }}</div>
      </template>
      <template #cell-attendance_status="{ row }">
        <select v-if="canEdit" v-model="row.attendance_status" class="input" @change="mark(row)"><option v-for="a in ATTENDANCE" :key="a">{{ a }}</option></select>
        <span v-else class="badge" :class="attendColor(row.attendance_status)">{{ row.attendance_status }}</span>
      </template>
      <template #cell-completion_status="{ row }">
        <select v-if="canEdit" v-model="row.completion_status" class="input" @change="mark(row)"><option v-for="a in COMPLETION" :key="a">{{ a }}</option></select>
        <span v-else>{{ row.completion_status }}</span>
      </template>
      <template #cell-score="{ row }">
        <input v-if="canEdit" v-model.number="row.score" type="number" min="0" step="0.5" class="input num" style="width:80px" @input="mark(row)" />
        <span v-else>{{ row.score ?? '-' }}</span>
      </template>
      <template #cell-evaluation_score="{ row }">
        <input v-if="canEdit" v-model.number="row.evaluation_score" type="number" min="0" step="0.1" class="input num" style="width:80px" @input="mark(row)" />
        <span v-else>{{ row.evaluation_score ?? '-' }}</span>
      </template>
      <template #cell-certificate_no="{ row }">
        <input v-if="canEdit" v-model="row.certificate_no" class="input" style="width:130px" @input="mark(row)" />
        <span v-else>{{ row.certificate_no || '-' }}</span>
      </template>
      <template #cell-training_hours="{ row }">
        <input v-if="canEdit" v-model.number="row.training_hours" type="number" min="0" step="0.5" class="input num" style="width:80px" :placeholder="String(session?.training_hours ?? '')" @input="mark(row)" />
        <span v-else>{{ row.training_hours ?? session?.training_hours ?? '-' }}</span>
      </template>
      <template v-if="canEdit" #actions="{ row }">
        <button class="btn sm danger" title="นำออกจากรอบอบรม" @click="remove(row)">นำออก</button>
      </template>
    </DataTable>

    <Modal :open="pickOpen" title="เพิ่มผู้เข้าอบรม (Search / Filter Department / Bulk Add)" wide @close="pickOpen = false">
      <EmployeePicker :exclude="rows.map((r) => r.employee_id)" @change="(l) => (picked = l)" />
      <template #footer>
        <button class="btn" @click="pickOpen = false">ยกเลิก</button>
        <button class="btn primary" :disabled="!picked.length || saving" @click="addPicked">เพิ่ม {{ picked.length }} คน</button>
      </template>
    </Modal>
  </div>
</template>
<script setup>
import { computed, onMounted, reactive, ref } from 'vue'
import DataTable from './DataTable.vue'
import Modal from './Modal.vue'
import MultiSelect from './MultiSelect.vue'
import EmployeePicker from './EmployeePicker.vue'
import ExportMenu from './ExportMenu.vue'
import { supabase, must } from '../lib/supabase'
import { canEdit } from '../lib/auth'
import { ATTENDANCE, COMPLETION, attendColor } from '../lib/constants'
import { toastOk, toastError, toast } from '../lib/toast'
import { exportExcel, exportCSV, fileStamp } from '../lib/export'

const props = defineProps({ sessionId: { type: [Number, String], required: true }, session: Object })
const emit = defineEmits(['changed'])
const rows = ref([]); const loading = ref(false); const q = ref('')
const pickOpen = ref(false); const picked = ref([]); const saving = ref(false)
const dirty = reactive(new Set()); const bulkAttend = ref(null)

const cols = [
  { key: 'employee_name', label: 'พนักงาน' }, { key: 'department_name', label: 'ฝ่าย' }, { key: 'position_name', label: 'ระดับตำแหน่ง' },
  { key: 'attendance_status', label: 'การเข้าร่วม' }, { key: 'completion_status', label: 'ผลการอบรม' },
  { key: 'training_hours', label: 'ชั่วโมง', type: 'number' }, { key: 'score', label: 'คะแนน', type: 'number' },
  { key: 'evaluation_score', label: 'คะแนนประเมิน', type: 'number' }, { key: 'certificate_no', label: 'Certificate' },
]
const shown = computed(() => {
  const s = q.value.trim().toLowerCase()
  return s ? rows.value.filter((r) => [r.employee_code, r.employee_name, r.nickname, r.department_name].some((x) => String(x || '').toLowerCase().includes(s))) : rows.value
})
async function load() {
  loading.value = true
  try {
    const data = await must(supabase.from('training_participants')
      .select('id, employee_id, attendance_status, completion_status, training_hours, score, evaluation_score, certificate_no, remark, employees(employee_code, full_name, nickname), departments(name), positions(name)')
      .eq('session_id', props.sessionId).is('deleted_at', null).order('id'))
    rows.value = data.map((r) => ({ ...r, employee_code: r.employees?.employee_code, employee_name: r.employees?.full_name, nickname: r.employees?.nickname,
      department_name: r.departments?.name, position_name: r.positions?.name }))
    dirty.clear()
  } finally { loading.value = false }
}
const mark = (r) => dirty.add(r.id)
function applyBulk(v) { if (!v) return; rows.value.forEach((r) => { r.attendance_status = v; mark(r) }); bulkAttend.value = null }
async function saveResults() {
  saving.value = true
  try {
    for (const id of dirty) {
      const r = rows.value.find((x) => x.id === id)
      const num = (v) => (v === '' || v === undefined ? null : v)
      await must(supabase.from('training_participants').update({ attendance_status: r.attendance_status, completion_status: r.completion_status,
        training_hours: num(r.training_hours), score: num(r.score), evaluation_score: num(r.evaluation_score), certificate_no: r.certificate_no || null }).eq('id', id))
    }
    toastOk(`บันทึกผลการอบรม ${dirty.size} รายการ`)
    dirty.clear(); emit('changed')
  } catch (e) { toastError(e) } finally { saving.value = false }
}
async function insertEmployees(ids) {
  const existing = new Set(rows.value.map((r) => r.employee_id))
  ids = ids.filter((id) => !existing.has(id))
  if (!ids.length) return 0
  const emp = await must(supabase.from('employees').select('id, company_id, department_id, level_group_id, position_id').in('id', ids))
  const future = props.session?.start_date && props.session.start_date > new Date().toISOString().slice(0, 10)
  await must(supabase.from('training_participants').insert(emp.map((e) => ({ session_id: Number(props.sessionId), employee_id: e.id,
    company_id: e.company_id, department_id: e.department_id, level_group_id: e.level_group_id, position_id: e.position_id,
    attendance_status: future ? 'Registered' : 'Attended', completion_status: future ? 'Pending' : 'Completed', data_source: 'System Entry' }))))
  return emp.length
}
async function addPicked() {
  saving.value = true
  try {
    const n = await insertEmployees(picked.value.map((p) => p.id))
    toastOk(`เพิ่มผู้เข้าอบรม ${n} คน`); pickOpen.value = false; picked.value = []
    await load(); emit('changed')
  } catch (e) { toastError(e) } finally { saving.value = false }
}
async function remove(r) {
  if (!confirm(`นำ ${r.employee_name} ออกจากรอบอบรมนี้?\n(ข้อมูลจะถูกเก็บไว้ใน Audit Log และกู้คืนได้)`)) return
  try {
    await must(supabase.from('training_participants').update({ deleted_at: new Date().toISOString() }).eq('id', r.id))
    toastOk('นำออกเรียบร้อย'); await load(); emit('changed')
  } catch (e) { toastError(e) }
}
async function importFile(ev) {
  const file = ev.target.files[0]; ev.target.value = ''
  if (!file) return
  try {
    const { readSheetRows } = await import('../lib/excel')
    const { rows: xr } = await readSheetRows(file)
    const codes = [...new Set(xr.map((r) => String(r['รหัสพนักงาน'] ?? r['employee_code'] ?? r['Employee ID'] ?? Object.values(r)[0] ?? '').trim()).filter(Boolean))]
    if (!codes.length) return toast('ไม่พบคอลัมน์รหัสพนักงาน (รหัสพนักงาน / employee_code)', 'err')
    const padded = codes.map((c) => (/^\d+$/.test(c) && c.length < 5 ? c.padStart(5, '0') : c))
    const emp = await must(supabase.from('employees').select('id, employee_code').in('employee_code', padded))
    const missing = padded.filter((c) => !emp.find((e) => e.employee_code === c))
    const n = await insertEmployees(emp.map((e) => e.id))
    toast(`Import: เพิ่ม ${n} คน · ซ้ำ ${emp.length - n} · ไม่พบรหัส ${missing.length}${missing.length ? ' (' + missing.slice(0, 10).join(', ') + ')' : ''}`, missing.length ? 'err' : 'ok', 8000)
    await load(); emit('changed')
  } catch (e) { toastError(e) }
}
async function doExport(kind) {
  const name = fileStamp('Training_Participants', [props.session?.session_code || props.sessionId])
  const c = [{ key: 'employee_code', label: 'รหัสพนักงาน' }, ...cols.map((x) => ({ ...x, type: x.type === 'number' ? 'number' : undefined }))]
  if (kind === 'csv') return exportCSV(`${name}.csv`, c, rows.value)
  return exportExcel(`${name}.xlsx`, [{ name: 'Participants', title: props.session?.session_name, columns: c, rows: rows.value }])
}
onMounted(load)
defineExpose({ load })
</script>
