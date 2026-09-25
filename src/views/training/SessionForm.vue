<template>
  <div>
    <PageHeader :title="isEdit ? 'แก้ไขข้อมูลหลักสูตร' : 'บันทึกฝึกอบรม'"
      :subtitle="isEdit ? form.session_name : 'กรอกข้อมูลหลักสูตร แล้วบันทึก — ขั้นต่อไปคีย์รหัสพนักงานเพื่อเพิ่มผู้เข้าอบรม'">
      <RouterLink v-if="isEdit" :to="`/training/sessions/${id}`" class="btn">ยกเลิก</RouterLink>
    </PageHeader>

    <ol v-if="!isEdit" class="stepper">
      <li class="on"><b>1</b> ข้อมูลหลักสูตร</li>
      <li><b>2</b> ผู้เข้าอบรม</li>
    </ol>

    <div class="card">
      <div class="card-title"><h3>ข้อมูลหลักสูตร</h3></div>
      <div class="form-grid">
        <div class="field wide"><label>หลักสูตร <span class="req">*</span></label>
          <!-- free text (no suggestion dropdown); an existing course with the same name is still matched on save -->
          <input v-model="courseName" class="input" autocomplete="off" placeholder="พิมพ์ชื่อหลักสูตร" @change="onCourse" />
        </div>
        <div class="field"><label>รุ่นที่</label>
          <input v-model="batchNo" class="input" placeholder="เช่น 3 (ไม่มีรุ่นให้เว้นว่าง)" @input="composeName" /></div>
        <div class="field span-rest"><label>ชื่อที่แสดง (หลักสูตร + รุ่น)</label>
          <input v-model="form.session_name" class="input" placeholder="สร้างให้อัตโนมัติ — แก้ไขได้" @input="nameTouched = true" /></div>
        <div class="field"><label>วันที่อบรม <span class="req">*</span></label><input v-model="form.start_date" type="date" class="input" /></div>
        <div class="field"><label>ถึงวันที่ (ถ้าอบรมหลายวัน)</label><input v-model="form.end_date" type="date" class="input" :min="form.start_date" /></div>
        <div class="field"><label>สถานที่</label><input v-model="form.location" class="input" placeholder="เช่น ห้องประชุมชั้น 5 / Online / โรงแรม..." /></div>
        <div class="field"><label>วิทยากร</label>
          <input v-model="trainerName" class="input" list="trainer-list" placeholder="พิมพ์ชื่อวิทยากร" /><datalist id="trainer-list"><option v-for="t in opts.trainers" :key="t.id" :value="t.name" /></datalist></div>
        <div class="field wide"><label>ประเภท</label>
          <div class="seg">
            <button v-for="t in types" :key="t.id" type="button" :class="{ on: form.training_type_id === t.id }" @click="form.training_type_id = t.id">{{ t.name }}</button>
          </div></div>
      </div>

      <template v-if="!isEdit">
        <div class="card-title mt"><h3>ค่าใช้จ่าย</h3><span class="hint">ไม่บังคับ — เพิ่มภายหลังได้</span><button class="btn sm" @click="addExpense">+ เพิ่มรายการ</button></div>
        <ExpenseLines v-if="expenses.length" v-model="expenses" :categories="opts.expense_categories || []" />
        <div v-else class="small muted">ยังไม่มีรายการค่าใช้จ่าย — กด "+ เพิ่มรายการ" เช่น ค่าวิทยากร ค่าอาหาร ค่าสถานที่</div>
      </template>

      <details class="more mt">
        <summary>ข้อมูลเพิ่มเติม (ไม่บังคับ) — เวลา ชั่วโมงอบรม หมวดหมู่ ผู้จัด สถานะ งบประมาณ หมายเหตุ</summary>
        <div class="form-grid mt">
          <div class="field"><label>เวลาเริ่ม</label><input v-model="form.start_time" type="time" class="input" /></div>
          <div class="field"><label>เวลาสิ้นสุด</label><input v-model="form.end_time" type="time" class="input" /></div>
          <div class="field"><label>ชั่วโมงอบรม (ต่อคน)</label>
            <div class="row"><input v-model.number="form.training_hours" type="number" step="0.5" min="0" class="input" style="flex:1" />
              <button type="button" class="btn sm" @click="calcHours" title="คำนวณจากเวลา × จำนวนวัน">คำนวณ</button></div></div>
          <div class="field"><label>หมวดหมู่ (Category)</label>
            <select v-model="categoryId" class="input"><option :value="null">-</option><option v-for="t in opts.categories" :key="t.id" :value="t.id">{{ t.name }}</option></select></div>
          <div class="field"><label>ผู้จัด (Provider)</label>
            <input v-model="providerName" class="input" list="provider-list" /><datalist id="provider-list"><option v-for="t in opts.providers" :key="t.id" :value="t.name" /></datalist></div>
          <div class="field"><label>สถานะ</label><select v-model="form.status" class="input" @change="statusTouched = true"><option v-for="s in STATUS" :key="s">{{ s }}</option></select></div>
          <div class="field"><label>งบประมาณ (บาท)</label><input v-model.number="form.budget_amount" type="number" min="0" step="0.01" class="input" /></div>
          <div class="field wide"><label>หมายเหตุ</label><textarea v-model="form.remark" class="input"></textarea></div>
        </div>
      </details>
    </div>

    <div v-if="error" class="alert err mt">{{ error }}</div>
    <div class="row mt" style="justify-content:flex-end">
      <button class="btn primary" :disabled="saving" @click="save">
        {{ saving ? 'กำลังบันทึก...' : isEdit ? 'บันทึก' : 'บันทึก และเพิ่มผู้เข้าอบรม ›' }}</button>
    </div>
  </div>
</template>
<script setup>
import { computed, onMounted, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import PageHeader from '../../components/PageHeader.vue'
import ExpenseLines from '../../components/ExpenseLines.vue'
import { supabase, must } from '../../lib/supabase'
import { filterOptions, invalidateOptions, getOne, insertRow, updateRow, insertRows } from '../../lib/api'
import { STATUS } from '../../lib/constants'
import { courseKey, normalizeCourseName } from '../../lib/format'
import { toastOk } from '../../lib/toast'

const route = useRoute(); const router = useRouter()
const id = route.params.id
const isEdit = computed(() => !!id)
const opts = ref({})
const courses = ref([])
const courseName = ref('')
const categoryId = ref(null)
const trainerName = ref('')
const providerName = ref('')
const expenses = ref([])
const saving = ref(false)
const error = ref('')
const form = ref({ session_name: '', start_date: '', end_date: '', start_time: '09:00', end_time: '16:00', training_hours: null,
  training_type_id: null, location: '', status: 'Scheduled', budget_amount: null, remark: '' })
const batchNo = ref('')
const nameTouched = ref(false)
const statusTouched = ref(false)
const types = computed(() => (opts.value.training_types || []).filter((t) => t.is_active !== false))
// ชื่อที่แสดง = หลักสูตร + " รุ่นที่ N" (until the user edits it by hand)
function composeName() {
  if (nameTouched.value) return
  const n = String(batchNo.value || '').trim()
  form.value.session_name = courseName.value.trim() + (n ? ` รุ่นที่ ${n}` : '')
}
const selectedCourse = computed(() => courses.value.find((c) => c.course_name.trim().toLowerCase() === courseName.value.trim().toLowerCase()))

function onCourse() {
  composeName()
  const c = selectedCourse.value
  if (!c) return
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
  if (!courseName.value.trim()) { error.value = 'กรุณาระบุหลักสูตร'; return }
  if (!form.value.start_date) { error.value = 'กรุณาระบุวันที่อบรม'; return }
  if (form.value.end_date && form.value.end_date < form.value.start_date) { error.value = 'วันที่สิ้นสุดต้องไม่ก่อนวันที่เริ่ม'; return }
  if (form.value.training_hours !== null && form.value.training_hours < 0) { error.value = 'ชั่วโมงอบรมต้องไม่ติดลบ'; return }
  for (const e of expenses.value) if (!e.expense_category_id) { error.value = 'กรุณาเลือกประเภทค่าใช้จ่ายให้ครบ'; return }
  // recording a past training → Completed; a future one → Scheduled (unless chosen by hand)
  if (!isEdit.value && !statusTouched.value) form.value.status = form.value.start_date > new Date().toISOString().slice(0, 10) ? 'Scheduled' : 'Completed'
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
      if (expenses.value.length) await insertRows('training_expenses', expenses.value.map((e) => ({ ...e, session_id: sessionId, data_source: 'System Entry' })))
    }
    invalidateOptions()
    toastOk(isEdit.value ? 'บันทึกเรียบร้อย' : 'บันทึกข้อมูลหลักสูตรแล้ว — ต่อไปเพิ่มผู้เข้าอบรม')
    router.replace(isEdit.value ? `/training/sessions/${sessionId}` : `/training/sessions/${sessionId}?step=2`)
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
    nameTouched.value = true
    batchNo.value = (s.session_name.match(/รุ่น(?:ที่)?\s*(\d+)/) || [])[1] || ''
    categoryId.value = s.training_courses?.category_id || null
    trainerName.value = s.trainers?.name || ''
    providerName.value = s.training_providers?.name || ''
    if (!courses.value.find((c) => c.id === s.course_id)) courses.value.push({ id: s.course_id, course_name: courseName.value })
  }
})
</script>
