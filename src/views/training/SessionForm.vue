<template>
  <div>
    <PageHeader :title="isEdit ? 'แก้ไข Training Session' : 'สร้าง Training ใหม่'"
      :subtitle="isEdit ? form.session_name : 'Create Training → Select Course → Training Date → Add Participants → Training Expense → Save'">
      <RouterLink :to="isEdit ? `/training/sessions/${id}` : '/training/sessions'" class="btn">ยกเลิก</RouterLink>
    </PageHeader>

    <div v-if="!isEdit" class="tabs">
      <button v-for="(s, i) in steps" :key="s" :class="{ on: step === i }" @click="step = i">{{ i + 1 }}. {{ s }}</button>
    </div>

    <!-- step 1: course + session info -->
    <div v-show="step === 0" class="card">
      <div class="form-grid">
        <div class="field wide"><label>หลักสูตร (Course) <span class="req">*</span></label>
          <input v-model="courseName" class="input" list="course-list" placeholder="พิมพ์เพื่อค้นหา หรือพิมพ์ชื่อหลักสูตรใหม่" @change="onCourse" />
          <datalist id="course-list"><option v-for="c in courses" :key="c.id" :value="c.course_name" /></datalist>
          <span v-if="courseName && !selectedCourse" class="small" style="color:var(--warn)">หลักสูตรใหม่ — ระบบจะสร้างใน Course Master ให้อัตโนมัติ</span>
        </div>
        <div class="field wide"><label>ชื่อรอบอบรม / รุ่น (Session name) <span class="req">*</span></label>
          <input v-model="form.session_name" class="input" placeholder="เช่น Leader as Coach รุ่นที่ 3" /></div>
        <div class="field"><label>วันที่เริ่ม <span class="req">*</span></label><input v-model="form.start_date" type="date" class="input" /></div>
        <div class="field"><label>วันที่สิ้นสุด</label><input v-model="form.end_date" type="date" class="input" :min="form.start_date" /></div>
        <div class="field"><label>เวลาเริ่ม</label><input v-model="form.start_time" type="time" class="input" /></div>
        <div class="field"><label>เวลาสิ้นสุด</label><input v-model="form.end_time" type="time" class="input" /></div>
        <div class="field"><label>ชั่วโมงอบรม (ต่อคน)</label>
          <div class="row"><input v-model.number="form.training_hours" type="number" step="0.5" min="0" class="input" style="flex:1" />
            <button type="button" class="btn sm" @click="calcHours" title="คำนวณจากเวลา × จำนวนวัน">คำนวณ</button></div></div>
        <div class="field"><label>ประเภท (Training Type)</label>
          <select v-model="form.training_type_id" class="input"><option :value="null">-</option><option v-for="t in opts.training_types" :key="t.id" :value="t.id">{{ t.name }}</option></select></div>
        <div class="field"><label>หมวดหมู่ (Category)</label>
          <select v-model="categoryId" class="input"><option :value="null">-</option><option v-for="t in opts.categories" :key="t.id" :value="t.id">{{ t.name }}</option></select></div>
        <div class="field"><label>วิทยากร (Trainer)</label>
          <input v-model="trainerName" class="input" list="trainer-list" /><datalist id="trainer-list"><option v-for="t in opts.trainers" :key="t.id" :value="t.name" /></datalist></div>
        <div class="field"><label>ผู้จัด (Provider)</label>
          <input v-model="providerName" class="input" list="provider-list" /><datalist id="provider-list"><option v-for="t in opts.providers" :key="t.id" :value="t.name" /></datalist></div>
        <div class="field"><label>สถานที่ (Location)</label><input v-model="form.location" class="input" /></div>
        <div class="field"><label>สถานะ</label><select v-model="form.status" class="input"><option v-for="s in STATUS" :key="s">{{ s }}</option></select></div>
        <div class="field"><label>งบประมาณ (Budget) บาท</label><input v-model.number="form.budget_amount" type="number" min="0" step="0.01" class="input" /></div>
        <div class="field wide"><label>หมายเหตุ</label><textarea v-model="form.remark" class="input"></textarea></div>
      </div>
    </div>

    <!-- step 2: participants -->
    <div v-if="!isEdit" v-show="step === 1" class="card">
      <div class="card-title"><h3>เพิ่มผู้เข้าอบรม</h3><span class="hint">ค้นหา / กรองตามฝ่าย / เลือกหลายคน (Bulk Add) — เพิ่มภายหลังได้ในหน้า Session</span></div>
      <EmployeePicker @change="(list) => (participants = list)" />
    </div>

    <!-- step 3: expenses -->
    <div v-if="!isEdit" v-show="step === 2" class="card">
      <div class="card-title"><h3>ค่าใช้จ่าย (Training Expense)</h3><button class="btn sm" @click="addExpense">+ เพิ่มรายการ</button></div>
      <ExpenseLines v-model="expenses" :categories="opts.expense_categories || []" />
    </div>

    <div v-if="error" class="alert err mt">{{ error }}</div>
    <div class="row mt" style="justify-content:flex-end">
      <button v-if="!isEdit && step > 0" class="btn" @click="step--">‹ ย้อนกลับ</button>
      <button v-if="!isEdit && step < 2" class="btn" @click="step++">ถัดไป ›</button>
      <button class="btn primary" :disabled="saving" @click="save">{{ saving ? 'กำลังบันทึก...' : 'บันทึก' }}</button>
    </div>
  </div>
</template>
<script setup>
import { computed, onMounted, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import PageHeader from '../../components/PageHeader.vue'
import EmployeePicker from '../../components/EmployeePicker.vue'
import ExpenseLines from '../../components/ExpenseLines.vue'
import { supabase, must } from '../../lib/supabase'
import { filterOptions, invalidateOptions, getOne, insertRow, updateRow, insertRows } from '../../lib/api'
import { STATUS } from '../../lib/constants'
import { courseKey, normalizeCourseName } from '../../lib/format'
import { toastOk } from '../../lib/toast'

const route = useRoute(); const router = useRouter()
const id = route.params.id
const isEdit = computed(() => !!id)
const steps = ['ข้อมูลหลักสูตร / วันที่', 'ผู้เข้าอบรม', 'ค่าใช้จ่าย']
const step = ref(0)
const opts = ref({})
const courses = ref([])
const courseName = ref('')
const categoryId = ref(null)
const trainerName = ref('')
const providerName = ref('')
const participants = ref([])
const expenses = ref([])
const saving = ref(false)
const error = ref('')
const form = ref({ session_name: '', start_date: '', end_date: '', start_time: '09:00', end_time: '16:00', training_hours: null,
  training_type_id: null, location: '', status: 'Scheduled', budget_amount: null, remark: '' })
const selectedCourse = computed(() => courses.value.find((c) => c.course_name.trim().toLowerCase() === courseName.value.trim().toLowerCase()))

function onCourse() {
  const c = selectedCourse.value
  if (!c) { if (!form.value.session_name) form.value.session_name = courseName.value; return }
  if (!form.value.session_name) form.value.session_name = c.course_name
  form.value.training_type_id ??= c.training_type_id
  categoryId.value ??= c.category_id
  if (!form.value.training_hours && c.standard_hours) form.value.training_hours = Number(c.standard_hours)
  if (!trainerName.value && c.trainer_id) trainerName.value = opts.value.trainers.find((t) => t.id === c.trainer_id)?.name || ''
  if (!providerName.value && c.provider_id) providerName.value = opts.value.providers.find((t) => t.id === c.provider_id)?.name || ''
}
function calcHours() {
  const { start_time: a, end_time: b, start_date: s, end_date: e } = form.value
  if (!a || !b) return
  const [h1, m1] = a.split(':').map(Number); const [h2, m2] = b.split(':').map(Number)
  let perDay = (h2 * 60 + m2 - h1 * 60 - m1) / 60
  if (perDay > 6) perDay -= 1 // lunch break
  const days = s && e ? Math.round((new Date(e) - new Date(s)) / 86400000) + 1 : 1
  form.value.training_hours = Math.max(0, Math.round(perDay * days * 2) / 2)
}
const addExpense = () => expenses.value.push({ expense_category_id: null, description: '', meal_type: null, quantity: 1, unit_price: 0 })

async function resolveByName(table, name, extra = {}) {
  const n = name.trim()
  if (!n) return null
  const { data } = await supabase.from(table).select('id').eq('name', n).maybeSingle()
  if (data) return data.id
  return (await insertRow(table, { name: n, ...extra })).id
}

async function save() {
  error.value = ''
  if (!courseName.value.trim()) { step.value = 0; error.value = 'กรุณาระบุหลักสูตร'; return }
  if (!form.value.start_date) { step.value = 0; error.value = 'กรุณาระบุวันที่อบรม'; return }
  if (form.value.end_date && form.value.end_date < form.value.start_date) { error.value = 'วันที่สิ้นสุดต้องไม่ก่อนวันที่เริ่ม'; return }
  if (form.value.training_hours !== null && form.value.training_hours < 0) { error.value = 'ชั่วโมงอบรมต้องไม่ติดลบ'; return }
  for (const e of expenses.value) if (!e.expense_category_id) { step.value = 2; error.value = 'กรุณาเลือกประเภทค่าใช้จ่ายให้ครบ'; return }
  saving.value = true
  try {
    const providerId = await resolveByName('training_providers', providerName.value)
    const trainerId = await resolveByName('trainers', trainerName.value, providerId ? { provider_id: providerId } : {})
    let courseId = selectedCourse.value?.id
    if (!courseId) {  // same course master for every round ("... รุ่นที่ N")
      const { data: same } = await supabase.from('training_courses').select('id').eq('course_key', courseKey(courseName.value)).maybeSingle()
      courseId = same?.id
    }
    if (!courseId) {
      courseId = (await insertRow('training_courses', { course_name: normalizeCourseName(courseName.value), course_key: courseKey(courseName.value),
        training_type_id: form.value.training_type_id, category_id: categoryId.value, provider_id: providerId, trainer_id: trainerId,
        standard_hours: form.value.training_hours, data_source: 'System Entry' })).id
    } else if (categoryId.value && categoryId.value !== selectedCourse.value.category_id) {
      await updateRow('training_courses', courseId, { category_id: categoryId.value })
    }
    const payload = { ...form.value, course_id: courseId, trainer_id: trainerId, provider_id: providerId,
      session_name: (form.value.session_name || courseName.value).trim(),
      end_date: form.value.end_date || form.value.start_date,
      fiscal_year: Number(form.value.start_date.slice(0, 4)),
      start_time: form.value.start_time || null, end_time: form.value.end_time || null }
    let sessionId = id
    if (isEdit.value) await updateRow('training_sessions', id, payload)
    else {
      sessionId = (await insertRow('training_sessions', { ...payload, data_source: 'System Entry' })).id
      if (participants.value.length) {
        const emp = await must(supabase.from('employees').select('id, company_id, department_id, level_group_id, position_id').in('id', participants.value.map((p) => p.id)))
        const future = payload.start_date > new Date().toISOString().slice(0, 10)
        await insertRows('training_participants', emp.map((e) => ({ session_id: sessionId, employee_id: e.id, company_id: e.company_id,
          department_id: e.department_id, level_group_id: e.level_group_id, position_id: e.position_id,
          attendance_status: future ? 'Registered' : 'Attended', completion_status: future ? 'Pending' : 'Completed', data_source: 'System Entry' })))
      }
      if (expenses.value.length) await insertRows('training_expenses', expenses.value.map((e) => ({ ...e, session_id: sessionId, data_source: 'System Entry' })))
    }
    invalidateOptions()
    toastOk('บันทึกเรียบร้อย')
    router.replace(`/training/sessions/${sessionId}`)
  } catch (e) { error.value = e.message } finally { saving.value = false }
}

onMounted(async () => {
  opts.value = await filterOptions(true)
  courses.value = await must(supabase.from('training_courses').select('id, course_name, training_type_id, category_id, standard_hours, trainer_id, provider_id').is('deleted_at', null).eq('status', 'Active').order('course_name'))
  if (route.query.course) {
    const c = courses.value.find((x) => x.id === Number(route.query.course))
    if (c) { courseName.value = c.course_name; onCourse() }
  }
  if (isEdit.value) {
    const s = await getOne('training_sessions', id, '*, training_courses(course_name, category_id), trainers(name), training_providers(name)')
    Object.keys(form.value).forEach((k) => { form.value[k] = s[k] ?? form.value[k] })
    form.value.start_time = s.start_time?.slice(0, 5) || ''
    form.value.end_time = s.end_time?.slice(0, 5) || ''
    courseName.value = s.training_courses?.course_name || ''
    categoryId.value = s.training_courses?.category_id || null
    trainerName.value = s.trainers?.name || ''
    providerName.value = s.training_providers?.name || ''
    if (!courses.value.find((c) => c.id === s.course_id)) courses.value.push({ id: s.course_id, course_name: courseName.value })
  }
})
</script>
