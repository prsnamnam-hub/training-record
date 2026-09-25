<template>
  <div>
    <div class="no-print">
      <PageHeader title="รายงานฝ่าย" subtitle="เลือกฝ่าย → แสดงหลักสูตรที่ฝ่ายเข้าอบรม ข้อมูลหลักสูตร และรายชื่อผู้เข้าอบรมของฝ่าย">
        <template v-if="rows.length">
          <button class="btn sm" @click="printPage">พิมพ์</button>
          <ExportMenu :handler="doExport" />
        </template>
      </PageHeader>
      <div class="card mb">
        <FilterBar v-model="filters" :fields="['departments', 'years', 'months', 'training_types', 'companies', 'categories']" :primary="3" />
      </div>
    </div>

    <div v-if="!filters.department_ids?.length" class="card empty">เลือก <b>ฝ่าย</b> อย่างน้อย 1 ฝ่าย เพื่อดูรายงาน</div>
    <div v-else-if="loading" class="loading-block"><span class="spinner"></span> กำลังโหลด...</div>
    <div v-else-if="!rows.length" class="card empty">ไม่พบการอบรมตามเงื่อนไขที่เลือก</div>

    <div v-else ref="sheet" class="dept-report">
      <section v-for="d in departments" :key="d.name" class="dept-block">
        <header class="dept-head">
          <div>
            <div class="dept-label">ฝ่าย</div>
            <h2>{{ d.name }}</h2>
          </div>
          <div class="dept-stats">
            <div><b>{{ num(d.courses.length) }}</b><span>หลักสูตร</span></div>
            <div><b>{{ num(d.participants) }}</b><span>คน-ครั้ง</span></div>
            <div><b>{{ num(d.people) }}</b><span>พนักงาน (คน)</span></div>
          </div>
        </header>

        <article v-for="c in d.courses" :key="c.session_id" class="course">
          <div class="course-head">
            <div class="course-title">
              <RouterLink :to="`/training/sessions/${c.session_id}`">{{ c.session_name }}</RouterLink>
              <span class="badge" :class="typeColor(c.training_type)">{{ c.training_type || '-' }}</span>
            </div>
            <dl class="course-info">
              <div><dt>วันที่อบรม</dt><dd>{{ dateRange(c) }}</dd></div>
              <div><dt>ชั่วโมง</dt><dd>{{ c.training_hours ? num(c.training_hours, 1) + ' ชม.' : '-' }}</dd></div>
              <div><dt>วิทยากร</dt><dd>{{ c.trainer_name || '-' }}</dd></div>
              <div><dt>สถานที่</dt><dd>{{ c.location || '-' }}</dd></div>
              <div><dt>หมวดหมู่</dt><dd>{{ c.category_name || '-' }}</dd></div>
              <div><dt>ผู้เข้าอบรมจากฝ่าย</dt><dd>{{ c.people.length }} คน</dd></div>
            </dl>
          </div>
          <table class="tbl people">
            <thead><tr><th style="width:36px">#</th><th>รหัส</th><th>ชื่อ-นามสกุล</th><th>ชื่อเล่น</th><th>ระดับตำแหน่ง</th><th>การเข้าร่วม</th></tr></thead>
            <tbody>
              <tr v-for="(p, i) in c.people" :key="p.participant_id">
                <td class="muted">{{ i + 1 }}</td><td>{{ p.employee_code }}</td><td>{{ p.employee_name }}</td><td>{{ p.nickname || '-' }}</td>
                <td>{{ p.position_name || '-' }}</td>
                <td><span class="badge" :class="p.attendance_status === 'Absent' ? 'red' : 'green'">{{ p.attendance_status === 'Absent' ? 'ไม่ได้เข้าร่วม' : 'เข้าร่วม' }}</span></td>
              </tr>
            </tbody>
          </table>
        </article>
      </section>
    </div>
  </div>
</template>
<script setup>
import { computed, ref, watch } from 'vue'
import PageHeader from '../../components/PageHeader.vue'
import FilterBar from '../../components/FilterBar.vue'
import ExportMenu from '../../components/ExportMenu.vue'
import { facts } from '../../lib/api'
import { num, dateTH } from '../../lib/format'
import { typeColor } from '../../lib/constants'
import { exportExcel, exportCSV, exportPDF, fileStamp } from '../../lib/export'
import { toastError } from '../../lib/toast'

const filters = ref({ years: [new Date().getFullYear()] })
const rows = ref([]); const loading = ref(false); const sheet = ref(null)

// department → course (session) → participants of that department
const departments = computed(() => {
  const byDept = {}
  for (const r of rows.value) {
    const dn = r.department_name || 'ไม่ระบุฝ่าย'
    const d = (byDept[dn] ||= { name: dn, sessions: {}, emp: new Set(), participants: 0 })
    const c = (d.sessions[r.session_id] ||= { ...r, people: [] })
    c.people.push(r); d.emp.add(r.employee_id); d.participants++
  }
  return Object.values(byDept).sort((a, b) => a.name.localeCompare(b.name, 'th')).map((d) => ({
    name: d.name, participants: d.participants, people: d.emp.size,
    courses: Object.values(d.sessions)
      .sort((a, b) => String(b.start_date || '').localeCompare(String(a.start_date || '')))
      .map((c) => ({ ...c, people: c.people.sort((a, b) => String(a.employee_code).localeCompare(String(b.employee_code))) })),
  }))
})
const dateRange = (c) => (!c.start_date ? 'ไม่ระบุวันที่' : c.end_date && c.end_date !== c.start_date ? `${dateTH(c.start_date)} – ${dateTH(c.end_date)}` : dateTH(c.start_date))

async function load() {
  if (!filters.value.department_ids?.length) { rows.value = []; return }
  loading.value = true
  try { rows.value = await facts(filters.value, { all: true, order: 'start_date', asc: false }) }
  catch (e) { toastError(e) } finally { loading.value = false }
}
watch(filters, load, { deep: true })

function printPage() { window.print() }
const flat = () => departments.value.flatMap((d) => d.courses.flatMap((c) => c.people.map((p) => ({
  department: d.name, course: c.session_name, date: c.start_date, type: c.training_type, hours: c.training_hours, trainer: c.trainer_name,
  location: c.location, employee_code: p.employee_code, employee_name: p.employee_name, nickname: p.nickname, position: p.position_name,
  attendance: p.attendance_status === 'Absent' ? 'ไม่ได้เข้าร่วม' : 'เข้าร่วม' }))))
const COLS = [{ key: 'department', label: 'ฝ่าย' }, { key: 'course', label: 'หลักสูตร / รุ่น' }, { key: 'date', label: 'วันที่อบรม', type: 'date' },
  { key: 'type', label: 'ประเภท' }, { key: 'hours', label: 'ชั่วโมง', type: 'number' }, { key: 'trainer', label: 'วิทยากร' }, { key: 'location', label: 'สถานที่' },
  { key: 'employee_code', label: 'รหัสพนักงาน' }, { key: 'employee_name', label: 'ชื่อ-นามสกุล' }, { key: 'nickname', label: 'ชื่อเล่น' },
  { key: 'position', label: 'ระดับตำแหน่ง' }, { key: 'attendance', label: 'การเข้าร่วม' }]
async function doExport(kind) {
  const name = fileStamp('Training_Department_Report', departments.value.map((d) => d.name).slice(0, 2))
  if (kind === 'pdf') return exportPDF(sheet.value, `${name}.pdf`, { landscape: false, avoid: ['.course-head', 'tr', '.dept-head'] })
  if (kind === 'csv') return exportCSV(`${name}.csv`, COLS, flat())
  return exportExcel(`${name}.xlsx`, [{ name: 'รายงานฝ่าย', title: `รายงานฝ่าย — ${departments.value.map((d) => d.name).join(', ')}`, columns: COLS, rows: flat() }])
}
</script>

<style scoped>
.dept-block + .dept-block { margin-top: 28px; }
.dept-head { display: flex; align-items: flex-end; justify-content: space-between; gap: 16px; flex-wrap: wrap; padding: 18px 22px; border-radius: var(--radius);
  background: linear-gradient(135deg, var(--brand), var(--brand-500)); color: #fff; margin-bottom: 14px; }
.dept-label { font-size: 12px; opacity: .8; text-transform: uppercase; letter-spacing: .08em; }
.dept-head h2 { font-size: 20px; }
.dept-stats { display: flex; gap: 22px; }
.dept-stats div { text-align: right; }
.dept-stats b { display: block; font-size: 22px; line-height: 1.1; }
.dept-stats span { font-size: 12px; opacity: .85; }
.course { background: #fff; border: 1px solid var(--line); border-radius: var(--radius); box-shadow: var(--shadow); margin-bottom: 14px; overflow: hidden; }
.course-head { padding: 16px 20px 12px; border-bottom: 1px solid var(--line-2); }
.course-title { display: flex; align-items: center; gap: 10px; flex-wrap: wrap; font-size: 16px; font-weight: 600; }
.course-title a { color: var(--ink); }
.course-info { margin: 10px 0 0; display: grid; grid-template-columns: repeat(auto-fill, minmax(170px, 1fr)); gap: 6px 18px; font-size: 13px; }
.course-info dt { color: var(--ink-3); font-size: 12px; }
.course-info dd { margin: 0; font-weight: 500; }
.people { font-size: 13px; }
.people th { background: #fafbfc; }
@media print {
  .dept-head, .badge { -webkit-print-color-adjust: exact; print-color-adjust: exact; }
  .course { box-shadow: none; break-inside: avoid; }
}
</style>
