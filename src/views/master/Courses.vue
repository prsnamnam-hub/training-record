<template>
  <div>
    <PageHeader title="หลักสูตร" subtitle="รายชื่อหลักสูตรทั้งหมด (1 หลักสูตรมีได้หลายรุ่น) — คลิกเพื่อดูสถิติของหลักสูตร">
      <ExportMenu :handler="doExport" :pdf="false" />
      <button v-if="canEdit" class="btn primary" @click="open({})">+ เพิ่มหลักสูตร</button>
    </PageHeader>
    <div class="card">
      <div class="filterbar">
        <div class="field" style="flex:2;max-width:none"><label>ค้นหา</label><input v-model="q" class="input" placeholder="ชื่อหลักสูตร / Course ID" /></div>
        <div class="field"><label>ประเภท</label><MultiSelect v-model="fType" :options="o.training_types || []" /></div>
        <div class="field"><label>หมวดหมู่</label><MultiSelect v-model="fCat" :options="o.categories || []" /></div>
        <div class="field"><label>สถานะ</label><MultiSelect v-model="fStatus" :options="[{ id: 'Active', name: 'Active' }, { id: 'Inactive', name: 'Inactive' }]" /></div>
      </div>
    </div>
    <div class="card">
      <DataTable :columns="cols" :rows="shown" :loading="loading" @row-click="(r) => $router.push(`/master/courses/${r.id}`)">
        <template #cell-status="{ row }"><span class="badge" :class="row.status === 'Active' ? 'green' : ''">{{ row.status }}</span></template>
        <template v-if="canEdit" #actions="{ row }"><button class="btn sm" @click="open(row)">แก้ไข</button></template>
      </DataTable>
    </div>
    <Modal :open="!!edit" :title="edit?.id ? 'แก้ไขหลักสูตร' : 'เพิ่มหลักสูตร'" wide @close="edit = null">
      <div v-if="edit" class="form-grid">
        <div class="field"><label>Course ID</label><input v-model="edit.course_code" class="input" placeholder="สร้างอัตโนมัติ" /></div>
        <div class="field wide"><label>ชื่อหลักสูตร <span class="req">*</span></label><input v-model="edit.course_name" class="input" /></div>
        <div class="field"><label>ประเภท</label><select v-model="edit.training_type_id" class="input"><option :value="null">-</option><option v-for="x in o.training_types" :key="x.id" :value="x.id">{{ x.name }}</option></select></div>
        <div class="field"><label>หมวดหมู่</label><select v-model="edit.category_id" class="input"><option :value="null">-</option><option v-for="x in o.categories" :key="x.id" :value="x.id">{{ x.name }}</option></select></div>
        <div class="field"><label>Provider</label><select v-model="edit.provider_id" class="input"><option :value="null">-</option><option v-for="x in o.providers" :key="x.id" :value="x.id">{{ x.name }}</option></select></div>
        <div class="field"><label>Trainer</label><select v-model="edit.trainer_id" class="input"><option :value="null">-</option><option v-for="x in o.trainers" :key="x.id" :value="x.id">{{ x.name }}</option></select></div>
        <div class="field"><label>ชั่วโมงมาตรฐาน</label><input v-model.number="edit.standard_hours" type="number" min="0" step="0.5" class="input" /></div>
        <div class="field"><label>ค่าใช้จ่ายมาตรฐาน (บาท)</label><input v-model.number="edit.standard_cost" type="number" min="0" step="0.01" class="input" /></div>
        <div class="field"><label>สถานะ</label><select v-model="edit.status" class="input"><option>Active</option><option>Inactive</option></select></div>
        <div class="field wide"><label>วัตถุประสงค์ (Objective)</label><textarea v-model="edit.objective" class="input"></textarea></div>
        <div class="field wide"><label>หมายเหตุ</label><input v-model="edit.remark" class="input" /></div>
      </div>
      <div v-if="error" class="alert err mt">{{ error }}</div>
      <template #footer><button class="btn" @click="edit = null">ยกเลิก</button><button class="btn primary" @click="save">บันทึก</button></template>
    </Modal>
  </div>
</template>
<script setup>
import { computed, onMounted, ref } from 'vue'
import PageHeader from '../../components/PageHeader.vue'
import DataTable from '../../components/DataTable.vue'
import MultiSelect from '../../components/MultiSelect.vue'
import Modal from '../../components/Modal.vue'
import ExportMenu from '../../components/ExportMenu.vue'
import { supabase, must } from '../../lib/supabase'
import { filterOptions, invalidateOptions, fetchAll } from '../../lib/api'
import { canEdit } from '../../lib/auth'
import { courseKey } from '../../lib/format'
import { toastOk } from '../../lib/toast'
import { exportExcel, exportCSV, fileStamp } from '../../lib/export'

const rows = ref([]); const loading = ref(false); const o = ref({}); const q = ref('')
const fType = ref([]); const fCat = ref([]); const fStatus = ref(['Active'])
const edit = ref(null); const error = ref('')
const cols = [
  { key: 'course_code', label: 'Course ID' }, { key: 'course_name', label: 'ชื่อหลักสูตร' }, { key: 'type', label: 'ประเภท' }, { key: 'category', label: 'หมวดหมู่' },
  { key: 'provider', label: 'Provider' }, { key: 'sessions', label: 'จำนวนรอบ', type: 'number' }, { key: 'participants', label: 'ผู้เข้าอบรม', type: 'number' },
  { key: 'last_date', label: 'อบรมล่าสุด', type: 'date' }, { key: 'standard_hours', label: 'ชม.มาตรฐาน', type: 'number', digits: 1 }, { key: 'status', label: 'สถานะ' },
]
const shown = computed(() => {
  const s = q.value.trim().toLowerCase()
  return rows.value.filter((r) => (!s || r.course_name.toLowerCase().includes(s) || String(r.course_code || '').toLowerCase().includes(s))
    && (!fType.value.length || fType.value.includes(r.training_type_id)) && (!fCat.value.length || fCat.value.includes(r.category_id))
    && (!fStatus.value.length || fStatus.value.includes(r.status)))
})
async function load() {
  loading.value = true
  try {
    const [courses, stats] = await Promise.all([
      fetchAll(supabase.from('training_courses').select('*, training_types(name), training_categories(name), training_providers(name)').is('deleted_at', null).order('course_name')),
      fetchAll(supabase.from('v_session_summary').select('course_id, participant_count, start_date')),
    ])
    const agg = {}
    for (const s of stats) {
      const a = (agg[s.course_id] ||= { sessions: 0, participants: 0, last_date: null })
      a.sessions++; a.participants += s.participant_count
      if (s.start_date && (!a.last_date || s.start_date > a.last_date)) a.last_date = s.start_date
    }
    rows.value = courses.map((c) => ({ ...c, type: c.training_types?.name, category: c.training_categories?.name, provider: c.training_providers?.name, ...(agg[c.id] || { sessions: 0, participants: 0 }) }))
  } finally { loading.value = false }
}
function open(r) { error.value = ''; edit.value = { status: 'Active', ...r } }
async function save() {
  const e = edit.value; error.value = ''
  if (!e.course_name?.trim()) { error.value = 'กรุณากรอกชื่อหลักสูตร'; return }
  const patch = {}
  for (const k of ['course_code', 'course_name', 'training_type_id', 'category_id', 'provider_id', 'trainer_id', 'standard_hours', 'standard_cost', 'status', 'objective', 'remark']) patch[k] = e[k] === '' ? null : e[k] ?? null
  patch.course_key = courseKey(patch.course_name)
  try {
    if (e.id) await must(supabase.from('training_courses').update(patch).eq('id', e.id))
    else await must(supabase.from('training_courses').insert({ ...patch, data_source: 'System Entry' }))
    toastOk('บันทึกเรียบร้อย'); edit.value = null; invalidateOptions(); load()
  } catch (err) { error.value = err.message.includes('duplicate') ? 'มีหลักสูตรนี้อยู่แล้ว (ชื่อหรือ Course ID ซ้ำ)' : err.message }
}
async function doExport(kind) {
  const name = fileStamp('Training_Courses', [new Date().toISOString().slice(0, 10)])
  const c = [...cols, { key: 'objective', label: 'Objective' }, { key: 'data_source', label: 'แหล่งข้อมูล' }]
  if (kind === 'csv') return exportCSV(`${name}.csv`, c, shown.value)
  return exportExcel(`${name}.xlsx`, [{ name: 'Courses', title: 'Training Course Master', columns: c, rows: shown.value }])
}
onMounted(async () => { o.value = await filterOptions(); load() })
</script>
