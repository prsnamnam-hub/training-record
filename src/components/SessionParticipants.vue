<template>
  <div>
    <div v-if="canEdit" class="code-entry no-print">
      <div style="flex:1;min-width:260px">
        <label class="small" style="font-weight:600;display:block;margin-bottom:6px">คีย์รหัสพนักงาน → กด Enter เพื่อเพิ่มเข้าหลักสูตร</label>
        <input ref="codeInput" v-model="code" class="input" autocomplete="off"
          placeholder="เช่น 59015 — วางหลายรหัสพร้อมกันได้ (คั่นด้วยเว้นวรรค / จุลภาค / ขึ้นบรรทัด)" @input="lookup" @keydown.enter.prevent="addCodes" />
        <div class="hit">
          <span v-if="preview?.state === 'found'">✔ <b>{{ preview.emp.full_name }}</b><span v-if="preview.emp.nickname"> ({{ preview.emp.nickname }})</span>
            · {{ preview.emp.departments?.name || 'ไม่ระบุฝ่าย' }} · {{ preview.emp.employment_status || '-' }}
            <span v-if="inSession(preview.emp.id)" style="color:var(--warn)"> — อยู่ในหลักสูตรนี้แล้ว</span></span>
          <span v-else-if="preview?.state === 'notfound'" style="color:var(--danger)">ไม่พบรหัส {{ preview.code }} ในฐานข้อมูลพนักงาน — เพิ่มได้ที่ Database › นำเข้าพนักงาน</span>
          <span v-else-if="preview?.state === 'multi'" class="muted">{{ preview.n }} รหัส — กด Enter เพื่อเพิ่มทั้งหมด</span>
          <span v-else class="muted">ชื่อ ฝ่าย และระดับตำแหน่งจะดึงจากฐานข้อมูลพนักงานให้อัตโนมัติ</span>
        </div>
      </div>
      <button class="btn primary" style="margin-top:26px" :disabled="!code.trim() || saving" @click="addCodes">เพิ่มเข้าหลักสูตร</button>
    </div>

    <div class="row mb no-print">
      <input v-model="q" class="input" style="max-width:260px" placeholder="ค้นหาในรายชื่อ" />
      <span style="flex:1"></span>
      <template v-if="canEdit">
        <button class="btn sm primary" :disabled="!dirty.size || saving" @click="saveResults">บันทึกผล{{ dirty.size ? ` (${dirty.size})` : '' }}</button>
        <button class="btn sm" :disabled="!rows.length" @click="setAll('Attended')">เข้าร่วมทั้งหมด</button>
        <button class="btn sm" @click="pickOpen = true">เลือกจากรายชื่อ</button>
        <label class="btn sm">อัปโหลด Excel<input type="file" accept=".xlsx" hidden @change="importFile" /></label>
        <button class="btn sm ghost" @click="downloadTemplate">ดาวน์โหลดแบบฟอร์ม Excel</button>
      </template>
      <ExportMenu :handler="doExport" :pdf="false" />
    </div>

    <DataTable :columns="cols" :rows="shown" :loading="loading" :size="100" empty-text="ยังไม่มีผู้เข้าอบรม — คีย์รหัสพนักงานด้านบน">
      <template #cell-employee_code="{ row }">
        <RouterLink :to="`/master/employees/${row.employee_id}`">{{ row.employee_code }}</RouterLink>
      </template>
      <template #cell-attendance_status="{ row }">
        <select v-if="canEdit" v-model="row.attendance_status" class="input" style="min-width:140px" @change="mark(row)">
          <option v-if="!ATTEND_OPTS.some((a) => a.id === row.attendance_status)" :value="row.attendance_status">- เลือก -</option>
          <option v-for="a in ATTEND_OPTS" :key="a.id" :value="a.id">{{ a.name }}</option>
        </select>
        <span v-else class="badge" :class="row.attendance_status === 'Attended' ? 'green' : row.attendance_status === 'Absent' ? 'red' : ''">{{ attendLabel(row.attendance_status) }}</span>
      </template>
      <template #cell-pre_test_score="{ row }">
        <input v-if="canEdit" v-model.number="row.pre_test_score" type="number" min="0" step="0.5" class="input num" style="width:90px" @input="mark(row)" />
        <span v-else>{{ row.pre_test_score ?? '-' }}</span>
      </template>
      <template #cell-post_test_score="{ row }">
        <input v-if="canEdit" v-model.number="row.post_test_score" type="number" min="0" step="0.5" class="input num" style="width:90px" @input="mark(row)" />
        <span v-else>{{ row.post_test_score ?? '-' }}</span>
      </template>
      <template #cell-certificate_url="{ row }">
        <div class="row" style="flex-wrap:nowrap;gap:6px">
          <button v-if="row.certificate_url" class="btn sm" @click="openCert(row)">ดูไฟล์</button>
          <label v-if="canEdit" class="btn sm" :class="{ primary: !row.certificate_url }">
            {{ uploading === row.id ? 'กำลังอัปโหลด...' : row.certificate_url ? 'เปลี่ยน' : 'อัปโหลด' }}
            <input type="file" accept=".pdf,image/png,image/jpeg,image/webp" hidden :disabled="uploading === row.id" @change="uploadCert(row, $event)" /></label>
          <span v-if="!row.certificate_url && !canEdit" class="muted">-</span>
        </div>
      </template>
      <template v-if="canEdit" #actions="{ row }">
        <button class="btn sm ghost danger" title="นำออกจากหลักสูตร" @click="remove(row)">นำออก</button>
      </template>
    </DataTable>

    <Modal :open="pickOpen" title="เลือกผู้เข้าอบรมจากรายชื่อ" wide @close="pickOpen = false">
      <EmployeePicker :exclude="rows.map((r) => r.employee_id)" @change="(l) => (picked = l)" />
      <template #footer>
        <button class="btn" @click="pickOpen = false">ยกเลิก</button>
        <button class="btn primary" :disabled="!picked.length || saving" @click="addPicked">เพิ่ม {{ picked.length }} คน</button>
      </template>
    </Modal>
  </div>
</template>
<script setup>
import { computed, nextTick, onMounted, reactive, ref } from 'vue'
import DataTable from './DataTable.vue'
import Modal from './Modal.vue'
import EmployeePicker from './EmployeePicker.vue'
import ExportMenu from './ExportMenu.vue'
import { supabase, must } from '../lib/supabase'
import { canEdit } from '../lib/auth'
import { toastOk, toastError, toast } from '../lib/toast'
import { exportExcel, exportCSV, fileStamp } from '../lib/export'

const props = defineProps({ sessionId: { type: [Number, String], required: true }, session: Object, autofocus: Boolean })
const emit = defineEmits(['changed'])
const rows = ref([]); const loading = ref(false); const q = ref('')
const pickOpen = ref(false); const picked = ref([]); const saving = ref(false); const uploading = ref(null)
const dirty = reactive(new Set())

const ATTEND_OPTS = [{ id: 'Attended', name: 'เข้าร่วม' }, { id: 'Absent', name: 'ไม่ได้เข้าร่วม' }]
const attendLabel = (s) => ATTEND_OPTS.find((a) => a.id === s)?.name || '-'
const cols = [
  { key: 'employee_code', label: 'รหัส' }, { key: 'first_name', label: 'ชื่อ' }, { key: 'last_name', label: 'นามสกุล' },
  { key: 'nickname', label: 'ชื่อเล่น' }, { key: 'department_name', label: 'ฝ่าย' }, { key: 'position_name', label: 'ระดับตำแหน่ง' },
  { key: 'attendance_status', label: 'การเข้าร่วม' }, { key: 'pre_test_score', label: 'Pre-Test', type: 'number' },
  { key: 'post_test_score', label: 'Post-Test', type: 'number' }, { key: 'certificate_url', label: 'Certificate', sortable: false },
]
const shown = computed(() => {
  const s = q.value.trim().toLowerCase()
  return s ? rows.value.filter((r) => [r.employee_code, r.first_name, r.last_name, r.nickname, r.department_name].some((x) => String(x || '').toLowerCase().includes(s))) : rows.value
})
async function load() {
  loading.value = true
  try {
    const data = await must(supabase.from('training_participants')
      .select('id, employee_id, attendance_status, completion_status, pre_test_score, post_test_score, certificate_url, employees(employee_code, first_name_th, last_name_th, legacy_first_name, legacy_last_name, nickname, legacy_nickname), departments(name), positions(name)')
      .eq('session_id', props.sessionId).is('deleted_at', null).order('id'))
    rows.value = data.map((r) => ({ ...r, employee_code: r.employees?.employee_code,
      first_name: r.employees?.first_name_th || r.employees?.legacy_first_name, last_name: r.employees?.last_name_th || r.employees?.legacy_last_name,
      nickname: r.employees?.nickname || r.employees?.legacy_nickname, department_name: r.departments?.name, position_name: r.positions?.name }))
    dirty.clear()
  } finally { loading.value = false }
}
const mark = (r) => dirty.add(r.id)
function setAll(v) { rows.value.forEach((r) => { if (r.attendance_status !== v) { r.attendance_status = v; mark(r) } }) }
const numOrNull = (v) => (v === '' || v === undefined || v === null || Number.isNaN(Number(v)) ? null : Number(v))
// attendance drives completion so reports stay consistent (not attended → not completed)
const completionFor = (a, cur) => (a === 'Attended' ? 'Completed' : a === 'Absent' ? 'Not Completed' : cur)
async function saveResults() {
  saving.value = true
  try {
    for (const id of dirty) {
      const r = rows.value.find((x) => x.id === id)
      await must(supabase.from('training_participants').update({ attendance_status: r.attendance_status,
        completion_status: completionFor(r.attendance_status, r.completion_status),
        pre_test_score: numOrNull(r.pre_test_score), post_test_score: numOrNull(r.post_test_score) }).eq('id', id))
    }
    toastOk(`บันทึกผล ${dirty.size} รายการ`)
    dirty.clear(); emit('changed')
  } catch (e) { toastError(e) } finally { saving.value = false }
}
// values: optional { [employee_id]: { attendance_status, pre_test_score, post_test_score } } from the Excel upload
async function insertEmployees(ids, values = {}) {
  const existing = new Set(rows.value.map((r) => r.employee_id))
  ids = ids.filter((id) => !existing.has(id))
  if (!ids.length) return 0
  const emp = await must(supabase.from('employees').select('id, company_id, department_id, level_group_id, position_id').in('id', ids))
  const future = props.session?.start_date && props.session.start_date > new Date().toISOString().slice(0, 10)
  await must(supabase.from('training_participants').insert(emp.map((e) => {
    const v = values[e.id] || {}
    const attend = v.attendance_status || (future ? 'Registered' : 'Attended')
    return { session_id: Number(props.sessionId), employee_id: e.id, company_id: e.company_id, department_id: e.department_id,
      level_group_id: e.level_group_id, position_id: e.position_id, attendance_status: attend,
      completion_status: completionFor(attend, future ? 'Pending' : 'Completed'),
      pre_test_score: v.pre_test_score ?? null, post_test_score: v.post_test_score ?? null, data_source: 'System Entry' }
  })))
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

// --- add participants by employee code (data comes from the employee master) ---
const code = ref(''); const preview = ref(null); const codeInput = ref(null)
const pad = (c) => (/^\d+$/.test(c) && c.length < 5 ? c.padStart(5, '0') : c)
const parseCodes = (t) => [...new Set(t.split(/[\s,;]+/).map((x) => x.trim()).filter(Boolean).map(pad))]
const inSession = (empId) => rows.value.some((r) => r.employee_id === empId)
let lookupTimer
function lookup() {
  clearTimeout(lookupTimer)
  const cs = parseCodes(code.value)
  if (cs.length !== 1) { preview.value = cs.length ? { state: 'multi', n: cs.length } : null; return }
  lookupTimer = setTimeout(async () => {
    const { data } = await supabase.from('employees').select('id, employee_code, full_name, nickname, employment_status, departments(name)')
      .eq('employee_code', cs[0]).is('deleted_at', null).maybeSingle()
    if (parseCodes(code.value)[0] !== cs[0]) return // typed on meanwhile
    preview.value = data ? { state: 'found', emp: data } : { state: 'notfound', code: cs[0] }
  }, 250)
}
async function addCodes() {
  const cs = parseCodes(code.value)
  if (!cs.length || saving.value) return
  saving.value = true
  try {
    const emp = await must(supabase.from('employees').select('id, employee_code, full_name').in('employee_code', cs).is('deleted_at', null))
    const missing = cs.filter((c) => !emp.some((e) => e.employee_code === c))
    const n = await insertEmployees(emp.map((e) => e.id))
    const dup = emp.length - n
    const parts = [n === 1 && emp.length === 1 ? `เพิ่ม ${emp[0].employee_code} ${emp[0].full_name} แล้ว` : `เพิ่ม ${n} คน`]
    if (dup) parts.push(`อยู่ในหลักสูตรแล้ว ${dup}`)
    if (missing.length) parts.push(`ไม่พบรหัส ${missing.join(', ')}`)
    toast(parts.join(' · '), missing.length || (dup && !n) ? 'err' : 'ok', missing.length ? 8000 : 3500)
    code.value = missing.join(' '); preview.value = null
    if (n) { await load(); emit('changed') }
  } catch (e) { toastError(e) } finally { saving.value = false; nextTick(() => codeInput.value?.focus()) }
}

// --- certificate files (private bucket "certificates", opened through a short-lived signed URL) ---
async function uploadCert(r, ev) {
  const file = ev.target.files[0]; ev.target.value = ''
  if (!file) return
  if (file.size > 10 * 1024 * 1024) return toastError(new Error('ไฟล์ใหญ่เกิน 10 MB'))
  uploading.value = r.id
  try {
    const ext = (file.name.split('.').pop() || 'pdf').toLowerCase()
    const path = `${props.sessionId}/${r.id}-${Date.now()}.${ext}`
    const { error } = await supabase.storage.from('certificates').upload(path, file, { contentType: file.type || undefined })
    if (error) throw error
    await must(supabase.from('training_participants').update({ certificate_url: path }).eq('id', r.id))
    if (r.certificate_url && !/^https?:/.test(r.certificate_url)) await supabase.storage.from('certificates').remove([r.certificate_url])
    r.certificate_url = path
    toastOk(`อัปโหลด Certificate ของ ${r.first_name || r.employee_code} แล้ว`)
  } catch (e) { toastError(e) } finally { uploading.value = null }
}
async function openCert(r) {
  if (/^https?:/.test(r.certificate_url)) return window.open(r.certificate_url, '_blank', 'noopener')
  const { data, error } = await supabase.storage.from('certificates').createSignedUrl(r.certificate_url, 120)
  if (error) return toastError(error)
  window.open(data.signedUrl, '_blank', 'noopener')
}

async function remove(r) {
  if (!confirm(`นำ ${r.first_name || ''} ${r.last_name || ''} ออกจากหลักสูตรนี้?\n(ข้อมูลจะถูกเก็บไว้ใน Audit Log และกู้คืนได้)`)) return
  try {
    await must(supabase.from('training_participants').update({ deleted_at: new Date().toISOString() }).eq('id', r.id))
    toastOk('นำออกเรียบร้อย'); await load(); emit('changed')
  } catch (e) { toastError(e) }
}

// --- Excel upload: รหัสพนักงาน · การเข้าร่วม · Pre-Test · Post-Test (same columns as the template) ---
const TEMPLATE_COLS = [{ key: 'employee_code', label: 'รหัสพนักงาน' }, { key: 'attendance', label: 'การเข้าร่วม' },
  { key: 'pre', label: 'Pre-Test', type: 'number' }, { key: 'post', label: 'Post-Test', type: 'number' }]
const pick = (r, names) => { for (const n of names) { const k = Object.keys(r).find((h) => h.replace(/[\s_-]/g, '').toLowerCase() === n); if (k && r[k] !== null && r[k] !== '') return r[k] } return null }
function parseAttend(v) {
  const s = String(v ?? '').trim().toLowerCase()
  if (!s) return null
  if (/ไม่|absent|^n$|^no$|^0$/.test(s)) return 'Absent'
  if (/เข้าร่วม|attend|^y$|^yes$|^1$|✓|✔/.test(s)) return 'Attended'
  return null
}
function downloadTemplate() {
  exportExcel(`แบบฟอร์มผู้เข้าอบรม_${props.session?.session_code || props.sessionId}.xlsx`, [{ name: 'ผู้เข้าอบรม', title: props.session?.session_name,
    columns: TEMPLATE_COLS, rows: rows.value.map((r) => ({ employee_code: r.employee_code, attendance: attendLabel(r.attendance_status), pre: r.pre_test_score, post: r.post_test_score })) }])
}
async function importFile(ev) {
  const file = ev.target.files[0]; ev.target.value = ''
  if (!file) return
  try {
    const { readSheetRows } = await import('../lib/excel')
    const { rows: xr } = await readSheetRows(file)
    const items = xr.map((r) => ({ code: pad(String(pick(r, ['รหัสพนักงาน', 'รหัส', 'employeecode', 'employeeid']) ?? '').trim()),
      attendance_status: parseAttend(pick(r, ['การเข้าร่วม', 'attendance'])),
      pre_test_score: numOrNull(pick(r, ['pretest', 'pre'])), post_test_score: numOrNull(pick(r, ['posttest', 'post'])) })).filter((x) => x.code)
    if (!items.length) return toast('ไม่พบคอลัมน์ "รหัสพนักงาน" — ใช้ปุ่ม "ดาวน์โหลดแบบฟอร์ม Excel"', 'err', 6000)
    const emp = await must(supabase.from('employees').select('id, employee_code').in('employee_code', [...new Set(items.map((x) => x.code))]).is('deleted_at', null))
    const idOf = Object.fromEntries(emp.map((e) => [e.employee_code, e.id]))
    const missing = [...new Set(items.filter((x) => !idOf[x.code]).map((x) => x.code))]
    const values = {}
    for (const x of items) if (idOf[x.code]) values[idOf[x.code]] = { attendance_status: x.attendance_status, pre_test_score: x.pre_test_score, post_test_score: x.post_test_score }
    const added = await insertEmployees(Object.keys(values).map(Number), values)
    // people already in this course: update the values the file provides
    let updated = 0
    for (const r of rows.value) {
      const v = values[r.employee_id]
      if (!v) continue
      const patch = {}
      if (v.attendance_status) { patch.attendance_status = v.attendance_status; patch.completion_status = completionFor(v.attendance_status, r.completion_status) }
      if (v.pre_test_score !== null) patch.pre_test_score = v.pre_test_score
      if (v.post_test_score !== null) patch.post_test_score = v.post_test_score
      if (Object.keys(patch).length) { await must(supabase.from('training_participants').update(patch).eq('id', r.id)); updated++ }
    }
    toast(`อัปโหลด Excel: เพิ่มใหม่ ${added} คน · อัปเดต ${updated} คน · ไม่พบรหัส ${missing.length}${missing.length ? ' (' + missing.slice(0, 10).join(', ') + ')' : ''}`, missing.length ? 'err' : 'ok', 8000)
    await load(); emit('changed')
  } catch (e) { toastError(e) }
}

async function doExport(kind) {
  const name = fileStamp('Training_Participants', [props.session?.session_code || props.sessionId])
  const c = cols.filter((x) => x.key !== 'certificate_url').map((x) => (x.key === 'attendance_status' ? { key: 'attendance', label: x.label } : x))
    .concat([{ key: 'certificate', label: 'Certificate' }])
  const data = rows.value.map((r) => ({ ...r, attendance: attendLabel(r.attendance_status), certificate: r.certificate_url ? 'มีไฟล์' : '' }))
  if (kind === 'csv') return exportCSV(`${name}.csv`, c, data)
  return exportExcel(`${name}.xlsx`, [{ name: 'Participants', title: props.session?.session_name, columns: c, rows: data }])
}
onMounted(async () => { await load(); if (props.autofocus) nextTick(() => codeInput.value?.focus()) })
defineExpose({ load })
</script>
