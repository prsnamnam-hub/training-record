<template>
  <div>
    <PageHeader :title="preset === 'employee' ? 'นำเข้าข้อมูลพนักงาน (Excel)' : 'นำเข้าข้อมูล (Import Center)'"
      :subtitle="preset === 'employee' ? 'อัปโหลดไฟล์ Excel รายชื่อพนักงาน → ตรวจสอบ → ยืนยัน — พนักงานใหม่จะถูกเพิ่ม พนักงานเดิม (รหัสเดียวกัน) จะถูกอัปเดต ใช้เป็นฐานข้อมูลตอนคีย์รหัสพนักงานเข้าหลักสูตร' : 'เลือกไฟล์ Excel → จับคู่คอลัมน์ → ตรวจสอบ → ยืนยัน → Import'">
      <button class="btn" @click="downloadTemplate">⬇ Template ({{ def.label }})</button>
    </PageHeader>

    <div class="tabs">
      <button v-for="(t, k) in shownTypes" :key="k" :class="{ on: type === k }" :disabled="busy" @click="setType(k)">{{ t.label }}</button>
      <button :class="{ on: type === 'history' }" @click="type = 'history'; loadBatches()">ประวัติการ Import</button>
    </div>

    <template v-if="type !== 'history'">
      <p class="muted">{{ def.desc }}</p>
      <!-- 1. select file -->
      <div class="card">
        <div class="card-title"><h3>1. เลือกไฟล์ Excel</h3></div>
        <div class="row">
          <input type="file" accept=".xlsx" :disabled="busy" @change="onFile" />
          <select v-if="sheets.length > 1" v-model="sheet" class="input" style="width:auto" @change="readSheet">
            <option v-for="s in sheets" :key="s">{{ s }}</option></select>
          <span v-if="parsed" class="muted">อ่านได้ {{ num(parsed.rows.length) }} แถว · {{ parsed.headers.length }} คอลัมน์ (หัวตารางแถวที่ {{ parsed.headerRow }})</span>
        </div>
      </div>

      <!-- 2. mapping -->
      <div v-if="parsed" class="card">
        <div class="card-title"><h3>2. จับคู่คอลัมน์ (Mapping)</h3><span class="hint">ระบบจับคู่ให้อัตโนมัติจากชื่อหัวคอลัมน์ — แก้ไขได้</span></div>
        <div class="form-grid">
          <div v-for="f in def.fields" :key="f.key" class="field">
            <label>{{ f.label }}</label>
            <select v-model="mapping[f.key]" class="input" :style="f.required && !mapping[f.key] ? 'border-color:var(--danger)' : ''">
              <option :value="undefined">— ไม่ใช้ —</option>
              <option v-for="h in parsed.headers" :key="h" :value="h">{{ h }}</option></select>
          </div>
        </div>
        <div class="row mt">
          <button class="btn primary" :disabled="busy || !requiredOk" @click="validate">3. ตรวจสอบข้อมูล & Preview</button>
          <span v-if="!requiredOk" class="small" style="color:var(--danger)">กรุณาจับคู่คอลัมน์ที่มี * ให้ครบ</span>
        </div>
      </div>

      <div v-if="busy" class="card"><div class="row"><span class="spinner"></span><b>{{ stage }}</b></div>
        <div class="progress mt"><div :style="{ width: progress + '%' }"></div></div></div>
      <div v-if="error" class="alert err mt">{{ error }}</div>

      <!-- 4. preview -->
      <div v-if="preview" class="card">
        <div class="card-title"><h3>{{ done ? '5. Import Summary' : '4. Preview — ผลการตรวจสอบ' }}</h3>
          <span v-if="done" class="badge green">Import สำเร็จ</span></div>
        <div class="grid g5">
          <KpiCard label="Total Records" :value="num(summary.total_records)" />
          <KpiCard label="Valid Records" :value="num(summary.valid_records)" color="var(--ok)" />
          <KpiCard label="Invalid Records" :value="num(summary.invalid_records)" color="var(--danger)" />
          <KpiCard label="Duplicate Records" :value="num(summary.duplicate_records)" color="var(--warn)" />
          <KpiCard :label="done ? 'Imported Records' : 'Records to Import'" :value="num(summary.records_to_import)"
            :sub="`ใหม่ ${num(summary.new_records)} · อัปเดต ${num(summary.updated_records)}`" color="var(--brand)" />
        </div>
        <div v-if="summary.new_sessions !== undefined" class="small muted mt">
          Training Session ใหม่ {{ num(summary.new_sessions) }} · หลักสูตรใหม่ {{ num(summary.new_courses) }} · พนักงานใหม่ {{ num(summary.new_employees) }}
        </div>
        <div class="row mt">
          <select v-model="statusFilter" class="input" style="width:auto">
            <option value="">ทุกสถานะ</option><option value="new">New</option><option value="updated">Updated</option>
            <option value="duplicate">Duplicate</option><option value="invalid">Invalid</option><option value="session_only">Session only</option></select>
          <button class="btn sm" :disabled="!issueRows.length" @click="downloadErrors">⬇ Error Report ({{ issueRows.length }})</button>
          <span style="flex:1"></span>
          <button v-if="!done" class="btn" @click="reset">ยกเลิก</button>
          <button v-if="!done" class="btn primary" :disabled="busy || !summary.records_to_import" @click="confirmImport">✔ Confirm Import {{ num(summary.records_to_import) }} รายการ</button>
          <button v-else class="btn" @click="reset">Import ไฟล์ใหม่</button>
        </div>
        <DataTable class="mt" :columns="previewCols" :rows="previewRows" row-key="row_no" :size="50">
          <template #cell-_status="{ row }"><span class="badge" :class="STATUS_COLOR[row._status]">{{ row._status }}</span></template>
        </DataTable>
      </div>
    </template>

    <div v-else class="card">
      <DataTable :columns="batchCols" :rows="batches" :loading="busy">
        <template #cell-status="{ row }"><span class="badge" :class="row.status === 'completed' ? 'green' : 'amber'">{{ row.status }}</span></template>
      </DataTable>
    </div>
  </div>
</template>
<script setup>
import { computed, ref } from 'vue'
import PageHeader from '../../components/PageHeader.vue'
import DataTable from '../../components/DataTable.vue'
import KpiCard from '../../components/KpiCard.vue'
import { IMPORT_TYPES, autoMap, transform, templateColumns } from '../../lib/importMaps'
import { readWorkbook, sheetToRows } from '../../lib/excel'
import { supabase, must } from '../../lib/supabase'
import { rpc, invalidateOptions } from '../../lib/api'
import { num, dateTimeTH } from '../../lib/format'
import { courseKey, normalizeCourseName } from '../../lib/format'
import { exportExcel } from '../../lib/export'
import { toastOk } from '../../lib/toast'

const STATUS_COLOR = { new: 'green', updated: 'blue', duplicate: 'amber', invalid: 'red', session_only: 'purple' }
const props = defineProps({ preset: String })
const type = ref(props.preset || 'training_record')
// Database › นำเข้าพนักงาน shows only the employee import (+ its history); /import shows every type
const shownTypes = computed(() => (props.preset ? { [props.preset]: IMPORT_TYPES[props.preset] } : IMPORT_TYPES))
const def = computed(() => IMPORT_TYPES[type.value] || IMPORT_TYPES.training_record)
const wb = ref(null); const sheets = ref([]); const sheet = ref(''); const parsed = ref(null); const fileName = ref('')
const mapping = ref({}); const busy = ref(false); const stage = ref(''); const progress = ref(0); const error = ref('')
const rows = ref([]); const preview = ref(null); const done = ref(false); const statusFilter = ref('')
const batches = ref([])

const requiredOk = computed(() => def.value.fields.every((f) => !f.required || mapping.value[f.key]))
function setType(k) { type.value = k; reset(true); if (parsed.value) mapping.value = autoMap(k, parsed.value.headers) }
function reset(keepFile = false) {
  preview.value = null; done.value = false; error.value = ''; statusFilter.value = ''
  if (keepFile !== true) { parsed.value = null; wb.value = null; sheets.value = []; mapping.value = {} }
}
async function onFile(e) {
  const f = e.target.files[0]; if (!f) return
  reset(); busy.value = true; stage.value = 'กำลังอ่านไฟล์ Excel...'; progress.value = 10; fileName.value = f.name
  try {
    wb.value = await readWorkbook(f)
    sheets.value = wb.value.worksheets.map((w) => w.name)
    sheet.value = sheets.value.find((s) => s === def.value.sheetHint) || sheets.value[0]
    readSheet()
  } catch (err) { error.value = 'อ่านไฟล์ไม่ได้: ' + err.message } finally { busy.value = false }
}
function readSheet() {
  preview.value = null
  parsed.value = sheetToRows(wb.value.getWorksheet(sheet.value))
  mapping.value = autoMap(type.value, parsed.value.headers)
}

async function runChunks(dry) {
  const size = def.value.chunk
  const total = { total_records: 0, valid_records: 0, invalid_records: 0, duplicate_records: 0, new_records: 0, updated_records: 0,
    records_to_import: 0, new_sessions: 0, new_courses: 0, new_employees: 0, rows: [], issues: [] }
  for (let i = 0; i < rows.value.length; i += size) {
    const chunk = rows.value.slice(i, i + size)
    stage.value = `${dry ? 'กำลังตรวจสอบ' : 'กำลัง Import'} ${num(Math.min(i + size, rows.value.length))} / ${num(rows.value.length)} แถว`
    progress.value = Math.round(((i + chunk.length) / rows.value.length) * 100)
    const r = await rpc(def.value.rpc, { p_rows: chunk, p_options: { dry_run: dry, data_source: 'Excel Import', source_file: fileName.value, import_type: type.value } })
    for (const k of Object.keys(total)) if (typeof total[k] === 'number' && typeof r[k] === 'number') total[k] += r[k]
    if (r.rows) total.rows.push(...r.rows)
    else (r.issues || []).forEach((x) => total.rows.push({ row: x.row, status: 'invalid', message: x.message }))
    total.issues.push(...(r.issues || []))
  }
  return total
}

// Course import has no server function: classify against existing course keys and insert new ones.
async function runCourses(dry) {
  const existing = new Set((await must(supabase.from('training_courses').select('course_key'))).map((c) => c.course_key))
  const o = await rpc('rpc_filter_options')
  const byName = (list, n) => list.find((x) => x.name.toLowerCase() === String(n || '').toLowerCase())?.id || null
  const seen = new Set(); const out = []; const res = { total_records: rows.value.length, valid_records: 0, invalid_records: 0, duplicate_records: 0, new_records: 0, updated_records: 0, records_to_import: 0, rows: [], issues: [] }
  for (const r of rows.value) {
    if (!r.course_name) { res.invalid_records++; res.rows.push({ row: r.row_no, status: 'invalid', message: 'ไม่มีชื่อหลักสูตร' }); continue }
    res.valid_records++
    const key = courseKey(r.course_name)
    if (existing.has(key) || seen.has(key)) { res.duplicate_records++; res.rows.push({ row: r.row_no, status: 'duplicate', message: 'มีหลักสูตรนี้แล้ว' }); continue }
    seen.add(key); res.new_records++; res.rows.push({ row: r.row_no, status: 'new' })
    out.push({ course_name: normalizeCourseName(r.course_name), course_key: key, course_code: r.course_code || null, training_type_id: byName(o.training_types, r.training_type),
      category_id: byName(o.categories, r.category), provider_id: byName(o.providers, r.provider), standard_hours: r.standard_hours || null,
      standard_cost: r.standard_cost || null, objective: r.objective || null, data_source: 'Excel Import' })
  }
  res.records_to_import = out.length
  if (!dry && out.length) {
    for (let i = 0; i < out.length; i += 500) await must(supabase.from('training_courses').insert(out.slice(i, i + 500)))
    await must(supabase.from('import_batches').insert({ import_type: 'course', data_source: 'Excel Import', source_file: fileName.value, total_records: res.total_records,
      valid_records: res.valid_records, invalid_records: res.invalid_records, duplicate_records: res.duplicate_records, new_records: res.new_records, imported_records: out.length }))
  }
  return res
}

async function validate() {
  error.value = ''; busy.value = true; done.value = false; progress.value = 0
  try {
    rows.value = transform(type.value, parsed.value.rows, mapping.value)
    preview.value = def.value.rpc ? await runChunks(true) : await runCourses(true)
  } catch (e) { error.value = e.message } finally { busy.value = false }
}
async function confirmImport() {
  if (!confirm(`ยืนยัน Import ${num(preview.value.records_to_import)} รายการจากไฟล์ ${fileName.value}?`)) return
  error.value = ''; busy.value = true; progress.value = 0
  try {
    preview.value = def.value.rpc ? await runChunks(false) : await runCourses(false)
    done.value = true; invalidateOptions(); toastOk('Import เรียบร้อย')
  } catch (e) { error.value = 'Import ไม่สำเร็จ: ' + e.message + ' — ข้อมูลที่ Import แล้วในรอบก่อนหน้ายังอยู่ สามารถ Import ไฟล์เดิมซ้ำได้ ระบบจะข้ามรายการที่มีอยู่แล้ว' }
  finally { busy.value = false }
}

const summary = computed(() => preview.value || {})
const statusByRow = computed(() => { const m = {}; (preview.value?.rows || []).forEach((x) => { m[x.row] = x }); return m })
const previewRows = computed(() => rows.value.map((r) => ({ ...r, _status: statusByRow.value[r.row_no]?.status || '-', _message: statusByRow.value[r.row_no]?.message || '' }))
  .filter((r) => !statusFilter.value || r._status === statusFilter.value))
const previewCols = computed(() => {
  const keys = { training_record: ['employee_code', 'first_name_th', 'last_name_th', 'department_name', 'course_name', 'start_date', 'training_type'],
    employee: ['employee_code', 'first_name_th', 'last_name_th', 'department_name', 'employment_status'], course: ['course_name', 'training_type', 'category', 'provider'],
    session: ['course_name', 'start_date', 'training_type', 'trainer', 'location'], expense: ['session_code', 'legacy_course_id', 'expense_category', 'quantity', 'unit_price'] }[type.value]
  const label = Object.fromEntries(def.value.fields.map((f) => [f.key, f.label.replace(' *', '')]))
  return [{ key: 'row_no', label: 'แถว', type: 'number' }, { key: '_status', label: 'สถานะ' }, ...keys.map((k) => ({ key: k, label: label[k] || k })), { key: '_message', label: 'ข้อความ' }]
})
const issueRows = computed(() => rows.value.map((r) => ({ ...r, ...statusByRow.value[r.row_no] })).filter((r) => ['invalid', 'duplicate'].includes(r.status)))
function downloadErrors() {
  exportExcel(`ASW_Training_Import_Errors_${new Date().toISOString().slice(0, 10)}.xlsx`, [{ name: 'Errors', title: `Import Error Report — ${fileName.value}`,
    columns: [{ key: 'row_no', label: 'แถวใน Excel', type: 'number' }, { key: 'status', label: 'สถานะ' }, { key: 'message', label: 'รายละเอียด', width: 50 },
      ...previewCols.value.filter((c) => !c.key.startsWith('_') && c.key !== 'row_no')], rows: issueRows.value }])
}
function downloadTemplate() {
  const cols = templateColumns(type.value)
  exportExcel(`ASW_Training_Record_Import_Template_${type.value}.xlsx`, [{ name: 'Template', title: `Import Template — ${def.value.label}`, columns: cols, rows: [] }])
}
const batchCols = [{ key: 'imported_at', label: 'วันที่', format: (r) => dateTimeTH(r.imported_at) }, { key: 'import_type', label: 'ประเภท' }, { key: 'source_file', label: 'ไฟล์' },
  { key: 'data_source', label: 'แหล่งข้อมูล' }, { key: 'total_records', label: 'Total', type: 'number' }, { key: 'invalid_records', label: 'Invalid', type: 'number' },
  { key: 'duplicate_records', label: 'Duplicate', type: 'number' }, { key: 'imported_records', label: 'Imported', type: 'number' }, { key: 'status', label: 'สถานะ' }]
async function loadBatches() {
  busy.value = true
  try { batches.value = await must(supabase.from('import_batches').select('*').eq('status', 'completed').order('imported_at', { ascending: false }).limit(200)) }
  finally { busy.value = false }
}
</script>
