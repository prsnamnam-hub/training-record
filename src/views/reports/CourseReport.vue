<template>
  <div>
    <div class="no-print">
      <PageHeader title="รายงานหลักสูตร" subtitle="ค้นหาชื่อหลักสูตร → แสดงข้อมูลหลักสูตรแต่ละรุ่น และรายชื่อผู้เข้าอบรม">
        <template v-if="rows.length">
          <button class="btn sm" @click="printPage">พิมพ์</button>
          <ExportMenu :handler="doExport" />
        </template>
      </PageHeader>
      <div class="card mb">
        <div class="field mb"><label>ค้นหาชื่อหลักสูตร</label>
          <input v-model="searchText" class="input" placeholder="พิมพ์ชื่อหลักสูตร เช่น ปฐมนิเทศ, Leadership" @input="onSearch" />
          <span v-if="searchText.trim()" class="small muted">พบ {{ matchIds.length }} หลักสูตรที่ชื่อตรงกับ "{{ searchText.trim() }}"</span></div>
        <FilterBar v-model="filters" :fields="['years', 'months', 'training_types', 'departments', 'categories', 'trainers']" :primary="3" />
      </div>
    </div>

    <div v-if="loading" class="loading-block"><span class="spinner"></span> กำลังโหลด...</div>
    <div v-else-if="!rows.length" class="card empty">ไม่พบการอบรมตามเงื่อนไขที่เลือก — ลองพิมพ์ชื่อหลักสูตร หรือเปลี่ยนปี</div>

    <div v-else ref="sheet">
      <p class="small muted mb">{{ courses.length }} หลักสูตร · {{ num(sessionCount) }} รุ่น · {{ num(rows.length) }} คน-ครั้ง</p>
      <section v-for="c in courses" :key="c.course_id" class="block">
        <header class="block-head">
          <div>
            <div class="block-label">หลักสูตร</div>
            <h2>{{ c.course_name }}</h2>
            <div class="block-sub">{{ c.category_name || 'ไม่ระบุหมวดหมู่' }}</div>
          </div>
          <div class="block-stats">
            <div><b>{{ num(c.sessions.length) }}</b><span>รุ่น</span></div>
            <div><b>{{ num(c.participants) }}</b><span>คน-ครั้ง</span></div>
            <div><b>{{ num(c.people) }}</b><span>พนักงาน (คน)</span></div>
          </div>
        </header>

        <article v-for="s in c.sessions" :key="s.session_id" class="course">
          <div class="course-head">
            <div class="course-title">
              <RouterLink :to="`/training/sessions/${s.session_id}`">{{ s.session_name }}</RouterLink>
              <span class="badge" :class="typeColor(s.training_type)">{{ s.training_type || '-' }}</span>
            </div>
            <dl class="course-info">
              <div><dt>วันที่อบรม</dt><dd>{{ dateRange(s) }}</dd></div>
              <div><dt>ชั่วโมง</dt><dd>{{ s.training_hours ? num(s.training_hours, 1) + ' ชม.' : '-' }}</dd></div>
              <div><dt>วิทยากร</dt><dd>{{ s.trainer_name || '-' }}</dd></div>
              <div><dt>สถานที่</dt><dd>{{ s.location || '-' }}</dd></div>
              <div><dt>ผู้จัด</dt><dd>{{ s.provider_name || '-' }}</dd></div>
              <div><dt>ผู้เข้าอบรม</dt><dd>{{ s.people.length }} คน</dd></div>
            </dl>
          </div>
          <div class="tbl-scroll">
            <table class="tbl people">
              <thead><tr><th style="width:36px">#</th><th>รหัส</th><th>ชื่อ-นามสกุล</th><th>ชื่อเล่น</th><th>ฝ่าย</th><th>ระดับตำแหน่ง</th><th>การเข้าร่วม</th><th class="num">Pre-Test</th><th class="num">Post-Test</th></tr></thead>
              <tbody>
                <tr v-for="(p, i) in s.people" :key="p.participant_id">
                  <td class="muted">{{ i + 1 }}</td><td>{{ p.employee_code }}</td><td>{{ p.employee_name }}</td><td>{{ p.nickname || '-' }}</td>
                  <td>{{ p.department_name || '-' }}</td><td>{{ p.position_name || '-' }}</td>
                  <td><span class="badge" :class="p.attendance_status === 'Absent' ? 'red' : 'green'">{{ p.attendance_status === 'Absent' ? 'ไม่ได้เข้าร่วม' : 'เข้าร่วม' }}</span></td>
                  <td class="num">{{ p.pre_test_score ?? '-' }}</td><td class="num">{{ p.post_test_score ?? '-' }}</td>
                </tr>
              </tbody>
            </table>
          </div>
        </article>
      </section>
    </div>
  </div>
</template>
<script setup>
import { computed, onMounted, ref, watch } from 'vue'
import PageHeader from '../../components/PageHeader.vue'
import FilterBar from '../../components/FilterBar.vue'
import ExportMenu from '../../components/ExportMenu.vue'
import { supabase, must } from '../../lib/supabase'
import { facts, filterOptions } from '../../lib/api'
import { num, dateTH } from '../../lib/format'
import { typeColor } from '../../lib/constants'
import { exportExcel, exportCSV, exportPDF, fileStamp } from '../../lib/export'
import { toastError } from '../../lib/toast'

// default: this year's trainings; typing a course name narrows to matching courses
const filters = ref({ years: [new Date().getFullYear()] })
const rows = ref([]); const loading = ref(false); const sheet = ref(null)
const searchText = ref(''); const courseOpts = ref([])
const norm = (x) => String(x || '').toLowerCase().replace(/\s+/g, '')
const matchIds = computed(() => { const t = norm(searchText.value); return t ? courseOpts.value.filter((c) => norm(c.name).includes(t)).map((c) => c.id) : [] })
let timer
function onSearch() {
  clearTimeout(timer)
  timer = setTimeout(() => {
    const f = { ...filters.value }
    if (searchText.value.trim()) f.course_ids = matchIds.value.length ? matchIds.value : [-1] // -1 = nothing matches
    else delete f.course_ids
    filters.value = f
  }, 300)
}

// course → session (รุ่น) → participants
const courses = computed(() => {
  const byCourse = {}
  for (const r of rows.value) {
    const c = (byCourse[r.course_id] ||= { course_id: r.course_id, course_name: r.course_name, category_name: r.category_name, sessions: {}, emp: new Set(), participants: 0 })
    const s = (c.sessions[r.session_id] ||= { ...r, people: [] })
    s.people.push(r); c.emp.add(r.employee_id); c.participants++
  }
  return Object.values(byCourse).sort((a, b) => a.course_name.localeCompare(b.course_name, 'th')).map((c) => ({
    ...c, people: c.emp.size,
    sessions: Object.values(c.sessions).sort((a, b) => String(b.start_date || '').localeCompare(String(a.start_date || '')))
      .map((s) => ({ ...s, people: s.people.sort((a, b) => String(a.employee_code).localeCompare(String(b.employee_code))) })),
  }))
})
const sessionCount = computed(() => courses.value.reduce((a, c) => a + c.sessions.length, 0))
const dateRange = (s) => (!s.start_date ? 'ไม่ระบุวันที่' : s.end_date && s.end_date !== s.start_date ? `${dateTH(s.start_date)} – ${dateTH(s.end_date)}` : dateTH(s.start_date))

async function load() {
  loading.value = true
  try {
    const data = await facts(filters.value, { all: true, order: 'start_date', asc: false })
    // Pre/Post-Test live on training_participants (not in the fact view)
    const ids = data.map((r) => r.participant_id); const extra = {}
    for (let i = 0; i < ids.length; i += 300) {
      const part = await must(supabase.from('training_participants').select('id, pre_test_score, post_test_score').in('id', ids.slice(i, i + 300)))
      part.forEach((p) => { extra[p.id] = p })
    }
    rows.value = data.map((r) => ({ ...r, pre_test_score: extra[r.participant_id]?.pre_test_score ?? null, post_test_score: extra[r.participant_id]?.post_test_score ?? null }))
  } catch (e) { toastError(e) } finally { loading.value = false }
}
watch(filters, load, { deep: true })
onMounted(async () => { courseOpts.value = (await filterOptions()).courses || []; load() })

function printPage() { window.print() }
const flat = () => courses.value.flatMap((c) => c.sessions.flatMap((s) => s.people.map((p) => ({
  course: c.course_name, session: s.session_name, date: s.start_date, type: s.training_type, hours: s.training_hours, trainer: s.trainer_name,
  location: s.location, employee_code: p.employee_code, employee_name: p.employee_name, nickname: p.nickname, department: p.department_name,
  position: p.position_name, attendance: p.attendance_status === 'Absent' ? 'ไม่ได้เข้าร่วม' : 'เข้าร่วม', pre: p.pre_test_score, post: p.post_test_score }))))
const COLS = [{ key: 'course', label: 'หลักสูตร' }, { key: 'session', label: 'รุ่น / ชื่อรอบ' }, { key: 'date', label: 'วันที่อบรม', type: 'date' },
  { key: 'type', label: 'ประเภท' }, { key: 'hours', label: 'ชั่วโมง', type: 'number' }, { key: 'trainer', label: 'วิทยากร' }, { key: 'location', label: 'สถานที่' },
  { key: 'employee_code', label: 'รหัสพนักงาน' }, { key: 'employee_name', label: 'ชื่อ-นามสกุล' }, { key: 'nickname', label: 'ชื่อเล่น' },
  { key: 'department', label: 'ฝ่าย' }, { key: 'position', label: 'ระดับตำแหน่ง' }, { key: 'attendance', label: 'การเข้าร่วม' },
  { key: 'pre', label: 'Pre-Test', type: 'number' }, { key: 'post', label: 'Post-Test', type: 'number' }]
async function doExport(kind) {
  const name = fileStamp('Training_Course_Report', [searchText.value.trim() || 'all'])
  if (kind === 'pdf') return exportPDF(sheet.value, `${name}.pdf`, { landscape: false, avoid: ['.course-head', 'tr', '.block-head'] })
  if (kind === 'csv') return exportCSV(`${name}.csv`, COLS, flat())
  return exportExcel(`${name}.xlsx`, [{ name: 'รายงานหลักสูตร', title: `รายงานหลักสูตร${searchText.value.trim() ? ' — ' + searchText.value.trim() : ''}`, columns: COLS, rows: flat() }])
}
</script>

<style scoped>
.block + .block { margin-top: 28px; }
.block-head { display: flex; align-items: flex-end; justify-content: space-between; gap: 16px; flex-wrap: wrap; padding: 18px 22px; border-radius: var(--radius);
  background: linear-gradient(135deg, var(--brand), var(--brand-500)); color: #fff; margin-bottom: 14px; }
.block-label { font-size: 12px; opacity: .8; text-transform: uppercase; letter-spacing: .08em; }
.block-head h2 { font-size: 20px; }
.block-sub { font-size: 13px; opacity: .85; }
.block-stats { display: flex; gap: 22px; }
.block-stats div { text-align: right; }
.block-stats b { display: block; font-size: 22px; line-height: 1.1; }
.block-stats span { font-size: 12px; opacity: .85; }
.course { background: #fff; border: 1px solid var(--line); border-radius: var(--radius); box-shadow: var(--shadow); margin-bottom: 14px; overflow: hidden; }
.course-head { padding: 16px 20px 12px; border-bottom: 1px solid var(--line-2); }
.course-title { display: flex; align-items: center; gap: 10px; flex-wrap: wrap; font-size: 16px; font-weight: 600; }
.course-title a { color: var(--ink); }
.course-info { margin: 10px 0 0; display: grid; grid-template-columns: repeat(auto-fill, minmax(170px, 1fr)); gap: 6px 18px; font-size: 13px; }
.course-info dt { color: var(--ink-3); font-size: 12px; }
.course-info dd { margin: 0; font-weight: 500; }
.tbl-scroll { overflow-x: auto; }
.people { font-size: 13px; }
.people th { background: #fafbfc; }
@media print {
  .block-head, .badge { -webkit-print-color-adjust: exact; print-color-adjust: exact; }
  .course { box-shadow: none; break-inside: avoid; }
}
</style>
