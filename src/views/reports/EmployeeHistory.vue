<template>
  <div>
    <div class="no-print">
      <PageHeader title="รายงานรายบุคคล" subtitle="ประวัติการฝึกอบรมรายบุคคลในรูปแบบเอกสาร A4 — ค้นหาด้วยรหัสพนักงานหรือชื่อ">
        <template v-if="emp">
          <button class="btn sm" @click="printSheet">พิมพ์</button>
          <ExportMenu :handler="doExport" />
        </template>
      </PageHeader>
      <div class="card mb">
        <div class="field"><label>ค้นหาพนักงาน (รหัส / ชื่อ / ชื่อเล่น)</label>
          <input v-model="q" class="input" placeholder="เช่น 59015 หรือ ชื่อ" @input="debounced" /></div>
        <div v-if="results.length && showResults" class="tbl-wrap mt" style="max-height:260px;overflow:auto">
          <table class="tbl"><tbody>
            <tr v-for="e in results" :key="e.id" class="clickable" @click="pick(e.id)">
              <td>{{ e.employee_code }}</td><td>{{ e.full_name }}</td><td>{{ e.nickname }}</td><td>{{ e.departments?.name }}</td><td>{{ e.employment_status }}</td>
            </tr></tbody></table>
        </div>
      </div>
    </div>

    <div v-if="loading" class="loading-block"><span class="spinner"></span> กำลังโหลด...</div>

    <!-- A4 portrait sheet (screen preview = print = PDF) -->
    <div v-else-if="emp" class="a4-scroll">
      <article ref="sheet" class="a4-sheet">
        <header class="rs-top">
          <img :src="logo" alt="ASSET WISE" class="rs-logo" />
          <div class="rs-doc">
            <div class="rs-doc-title">ประวัติการฝึกอบรม</div>
            <div>Employee Training Record</div>
          </div>
        </header>

        <section class="rs-profile">
          <div class="rs-avatar">{{ initials }}</div>
          <div class="rs-id">
            <h1>{{ [emp.title_th, emp.full_name].filter(Boolean).join(' ') }}</h1>
            <div class="rs-nick" v-if="emp.nickname">ชื่อเล่น {{ emp.nickname }}</div>
            <div class="rs-role">{{ emp.job_title || emp.positions?.name || '-' }}</div>
            <div class="rs-dept">{{ emp.departments?.name || '-' }}<span v-if="emp.companies?.name"> · {{ emp.companies.name }}</span></div>
          </div>
          <dl class="rs-facts">
            <div><dt>รหัสพนักงาน</dt><dd>{{ emp.employee_code }}</dd></div>
            <div><dt>ระดับ</dt><dd>{{ emp.level_groups?.name || '-' }}</dd></div>
            <div><dt>ระดับตำแหน่ง</dt><dd>{{ emp.positions?.name || '-' }}</dd></div>
            <div><dt>วันที่เริ่มงาน</dt><dd>{{ emp.hire_date ? dateTH(emp.hire_date) : '-' }}</dd></div>
            <div><dt>อายุงาน</dt><dd>{{ tenure }}</dd></div>
            <div><dt>สถานะ</dt><dd>{{ emp.employment_status || '-' }}</dd></div>
          </dl>
        </section>

        <div class="rs-body">
          <aside class="rs-side">
            <h2>สรุป</h2>
            <div class="rs-stats">
              <div><b>{{ num(hist.length) }}</b><span>หลักสูตรที่อบรม</span></div>
              <div><b>{{ num(sumBy('training_hours'), 1) }}</b><span>ชั่วโมงรวม</span></div>
              <div><b>{{ num(attendedCount) }}</b><span>เข้าร่วมแล้ว</span></div>
              <div><b>{{ num(certCount) }}</b><span>Certificate</span></div>
            </div>
            <p class="rs-note">อบรมล่าสุด {{ lastDate ? dateTH(lastDate) : '-' }}</p>

            <h2>รายปี <small>เป้าหมาย {{ target }} หลักสูตร/ปี</small></h2>
            <ul class="rs-bars">
              <li v-for="y in byYear" :key="y.label">
                <span class="k">{{ y.label }}</span>
                <span class="bar"><i :style="{ width: pct(y.n, maxYear) }"></i></span>
                <span class="v">{{ y.n }}<em :class="y.n >= target ? 'ok' : 'no'">{{ y.n >= target ? '✓' : '–' }}</em></span>
              </li>
            </ul>

            <h2>ตามประเภท</h2>
            <ul class="rs-bars">
              <li v-for="t in byType" :key="t.label">
                <span class="k">{{ t.label }}</span>
                <span class="bar"><i :style="{ width: pct(t.n, hist.length) }"></i></span>
                <span class="v">{{ t.n }}</span>
              </li>
            </ul>

            <template v-if="byCategory.length">
              <h2>หมวดหมู่</h2>
              <ul class="rs-tags"><li v-for="c in byCategory" :key="c.label">{{ c.label }} <b>{{ c.n }}</b></li></ul>
            </template>
          </aside>

          <main class="rs-main">
            <h2>ประวัติการฝึกอบรม</h2>
            <p v-if="!hist.length" class="rs-note">ยังไม่มีประวัติการฝึกอบรม</p>
            <section v-for="g in timeline" :key="g.year" class="rs-year">
              <h3>{{ g.year }} <small>{{ g.items.length }} หลักสูตร</small></h3>
              <div v-for="h in g.items" :key="h.participant_id" class="tl-item">
                <div class="tl-date">{{ h.start_date ? shortDate(h.start_date) : 'ไม่ระบุวันที่' }}</div>
                <div class="tl-body">
                  <div class="tl-name">{{ h.session_name }}</div>
                  <div class="tl-meta">
                    <span class="tl-type" :class="(h.training_type || '').toLowerCase()">{{ h.training_type || '-' }}</span>
                    <span v-if="h.training_hours">{{ num(h.training_hours, 1) }} ชม.</span>
                    <span v-if="h.pre_test_score !== null && h.pre_test_score !== undefined">Pre {{ h.pre_test_score }}</span>
                    <span v-if="h.post_test_score !== null && h.post_test_score !== undefined">Post {{ h.post_test_score }}</span>
                    <span v-if="h.attendance_status === 'Absent'" class="tl-absent">ไม่ได้เข้าร่วม</span>
                    <span v-if="h.certificate_url || h.certificate_no" class="tl-cert">✓ Certificate</span>
                  </div>
                </div>
              </div>
            </section>
          </main>
        </div>

        <footer class="rs-foot">
          <span>ASW Training Record · ASSET WISE</span>
          <span>พิมพ์เมื่อ {{ dateTH(today) }}</span>
        </footer>
      </article>
    </div>
  </div>
</template>
<script setup>
import { computed, onMounted, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import PageHeader from '../../components/PageHeader.vue'
import ExportMenu from '../../components/ExportMenu.vue'
import { supabase, must } from '../../lib/supabase'
import { searchEmployees, facts } from '../../lib/api'
import { num, dateTH, be, TH_MONTHS } from '../../lib/format'
import { exportExcel, exportCSV, exportPDF } from '../../lib/export'

const logo = import.meta.env.BASE_URL + 'logo-assetwise.png'
const route = useRoute(); const router = useRouter()
const q = ref(''); const results = ref([]); const showResults = ref(true); const loading = ref(false)
const emp = ref(null); const hist = ref([]); const sheet = ref(null); const target = ref(2)
const today = new Date().toISOString().slice(0, 10)

const cols = [
  { key: 'start_date', label: 'วันที่อบรม', type: 'date' }, { key: 'session_name', label: 'หลักสูตร / รุ่น' }, { key: 'training_type', label: 'ประเภท' },
  { key: 'category_name', label: 'หมวดหมู่' }, { key: 'training_hours', label: 'ชั่วโมง', type: 'number', digits: 1 },
  { key: 'attendance', label: 'การเข้าร่วม' }, { key: 'pre_test_score', label: 'Pre-Test', type: 'number' }, { key: 'post_test_score', label: 'Post-Test', type: 'number' },
  { key: 'certificate', label: 'Certificate' },
]
const sumBy = (k) => hist.value.reduce((a, h) => a + Number(h[k] || 0), 0)
const pct = (n, max) => `${max ? Math.max(4, Math.round((n / max) * 100)) : 0}%`
const count = (key) => Object.entries(hist.value.reduce((m, h) => { const k = key(h); m[k] = (m[k] || 0) + 1; return m }, {}))
  .map(([label, n]) => ({ label, n }))
const initials = computed(() => (emp.value?.first_name_th || emp.value?.full_name || '?').trim().slice(0, 1))
const attendedCount = computed(() => hist.value.filter((h) => h.attendance_status !== 'Absent').length)
const certCount = computed(() => hist.value.filter((h) => h.certificate_url || h.certificate_no).length)
const lastDate = computed(() => hist.value.map((h) => h.start_date).filter((d) => d && d <= today).sort().pop())
const byYear = computed(() => count((h) => String(be(h.year))).sort((a, b) => a.label.localeCompare(b.label)))
const maxYear = computed(() => Math.max(target.value, ...byYear.value.map((y) => y.n)))
const byType = computed(() => count((h) => h.training_type || 'ไม่ระบุ').sort((a, b) => b.n - a.n))
const byCategory = computed(() => count((h) => h.category_name || '').filter((c) => c.label).sort((a, b) => b.n - a.n).slice(0, 8))
const timeline = computed(() => {
  const g = {}
  hist.value.forEach((h) => { const y = `พ.ศ. ${be(h.year)}`; (g[y] ||= []).push(h) })
  return Object.entries(g).sort((a, b) => b[0].localeCompare(a[0])).map(([year, items]) => ({ year, items }))
})
const tenure = computed(() => {
  const d = emp.value?.hire_date
  if (!d) return '-'
  const end = emp.value.termination_date ? new Date(emp.value.termination_date) : new Date()
  const m = (end.getFullYear() - +d.slice(0, 4)) * 12 + end.getMonth() - (+d.slice(5, 7) - 1)
  return m < 12 ? `${m} เดือน` : `${Math.floor(m / 12)} ปี${m % 12 ? ` ${m % 12} เดือน` : ''}`
})
const shortDate = (d) => `${+d.slice(8, 10)} ${TH_MONTHS[+d.slice(5, 7) - 1]}`

let t; const debounced = () => { clearTimeout(t); t = setTimeout(async () => { showResults.value = true; results.value = await searchEmployees(q.value, 30) }, 250) }
async function pick(id) {
  showResults.value = false
  // the view is keyed by URL: navigate and let the new instance load the employee
  if (String(route.params.id || route.query.id) !== String(id)) return router.replace(route.path.startsWith('/master') ? `/master/employees/${id}` : { query: { id } })
  loading.value = true
  try {
    emp.value = await must(supabase.from('employees').select('*, companies(name), departments(name), sections(name), level_groups(name), positions(name)').eq('id', id).single())
    const [rows, extra, setting] = await Promise.all([
      facts({ employee_ids: [id] }, { all: true, order: 'start_date', asc: false }),
      must(supabase.from('training_participants').select('id, pre_test_score, post_test_score, certificate_url').eq('employee_id', id).is('deleted_at', null)),
      supabase.from('app_settings').select('value').eq('key', 'training_target_per_year').maybeSingle(),
    ])
    const ex = Object.fromEntries(extra.map((x) => [x.id, x]))
    hist.value = rows.map((r) => ({ ...r, ...(ex[r.participant_id] ? { pre_test_score: ex[r.participant_id].pre_test_score, post_test_score: ex[r.participant_id].post_test_score, certificate_url: ex[r.participant_id].certificate_url } : {}) }))
    target.value = Number(setting.data?.value ?? 2)
  } finally { loading.value = false }
}
function printSheet() { window.print() }
async function doExport(kind) {
  const name = `ASW_Training_Profile_${emp.value.employee_code}`
  if (kind === 'pdf') return exportPDF(sheet.value, `${name}.pdf`, { landscape: false, margin: 0, avoid: ['.tl-item', '.rs-profile', '.rs-year h3'] })
  const rows = hist.value.map((h) => ({ ...h, attendance: h.attendance_status === 'Absent' ? 'ไม่ได้เข้าร่วม' : 'เข้าร่วม', certificate: h.certificate_url || h.certificate_no ? 'มี' : '' }))
  if (kind === 'csv') return exportCSV(`${name}.csv`, cols, rows)
  const profile = [{ k: 'รหัสพนักงาน', v: emp.value.employee_code }, { k: 'ชื่อ-นามสกุล', v: emp.value.full_name }, { k: 'ชื่อเล่น', v: emp.value.nickname },
    { k: 'ตำแหน่ง', v: emp.value.job_title }, { k: 'ฝ่าย', v: emp.value.departments?.name }, { k: 'บริษัท', v: emp.value.companies?.name },
    { k: 'วันที่เริ่มงาน', v: emp.value.hire_date }, { k: 'อายุงาน', v: tenure.value }, { k: 'หลักสูตรที่อบรม', v: hist.value.length },
    { k: 'ชั่วโมงรวม', v: sumBy('training_hours') }, { k: 'อบรมล่าสุด', v: lastDate.value }]
  return exportExcel(`${name}.xlsx`, [
    { name: 'Profile', title: `ประวัติการฝึกอบรม — ${emp.value.employee_code}`, columns: [{ key: 'k', label: 'รายการ', width: 24 }, { key: 'v', label: 'ข้อมูล', width: 50 }], rows: profile },
    { name: 'History', title: `ประวัติการฝึกอบรม — ${emp.value.full_name}`, columns: cols, rows },
  ])
}
onMounted(() => { const id = route.params.id || route.query.id; if (id) pick(Number(id)) })
</script>

<style scoped>
.a4-scroll { overflow-x: auto; padding: 4px 0 24px; }
.a4-sheet {
  width: 210mm; min-height: 297mm; margin: 0 auto; background: #fff; color: var(--ink);
  padding: 13mm 14mm 12mm; box-shadow: 0 4px 24px rgba(17, 26, 38, .12); border-radius: 4px;
  display: flex; flex-direction: column; font-size: 10.5pt; line-height: 1.45;
}
.rs-top { display: flex; align-items: center; justify-content: space-between; padding-bottom: 5mm; border-bottom: 2px solid var(--brand); }
.rs-logo { width: 46mm; height: auto; }
.rs-doc { text-align: right; color: var(--ink-3); font-size: 8.5pt; }
.rs-doc-title { color: var(--brand); font-size: 13pt; font-weight: 700; }

.rs-profile { display: grid; grid-template-columns: 22mm 1fr 62mm; gap: 6mm; align-items: center; padding: 6mm 0 5mm; border-bottom: 1px solid var(--line); }
.rs-avatar { width: 22mm; height: 22mm; border-radius: 50%; background: linear-gradient(135deg, var(--brand-500), var(--brand)); color: #fff; display: grid; place-items: center; font-size: 22pt; font-weight: 700; }
.rs-id h1 { font-size: 17pt; line-height: 1.25; color: var(--ink); }
.rs-nick { color: var(--ink-3); font-size: 9.5pt; }
.rs-role { margin-top: 2mm; font-weight: 600; color: var(--brand); }
.rs-dept { color: var(--ink-2); font-size: 9.5pt; }
.rs-facts { margin: 0; display: grid; gap: 1.2mm; font-size: 9pt; }
.rs-facts > div { display: grid; grid-template-columns: 24mm 1fr; }
.rs-facts dt { color: var(--ink-3); }
.rs-facts dd { margin: 0; font-weight: 600; }

.rs-body { display: grid; grid-template-columns: 58mm 1fr; gap: 7mm; padding-top: 5mm; flex: 1; }
.rs-side { background: #f6f8fb; border-radius: 3mm; padding: 4mm; align-self: start; }
.rs-body h2 { font-size: 10.5pt; color: var(--brand); text-transform: none; margin: 0 0 2.5mm; padding-bottom: 1.5mm; border-bottom: 1px solid var(--brand-100); }
.rs-body h2 small { font-weight: 400; color: var(--ink-3); font-size: 8pt; margin-left: 1mm; }
.rs-side h2 + * { margin-bottom: 5mm; }
.rs-stats { display: grid; grid-template-columns: 1fr 1fr; gap: 2mm; }
.rs-stats div { background: #fff; border-radius: 2mm; padding: 2.5mm; text-align: center; }
.rs-stats b { display: block; font-size: 15pt; color: var(--brand); line-height: 1.1; }
.rs-stats span { font-size: 7.5pt; color: var(--ink-3); }
.rs-note { margin: 0 0 5mm; font-size: 8.5pt; color: var(--ink-3); }
.rs-bars { list-style: none; margin: 0; padding: 0; display: grid; gap: 1.6mm; font-size: 8.5pt; }
.rs-bars li { display: grid; grid-template-columns: 15mm 1fr 10mm; align-items: center; gap: 2mm; }
.rs-bars .k { color: var(--ink-2); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.rs-bars .bar { height: 2.2mm; background: #e4e9f0; border-radius: 99px; overflow: hidden; }
.rs-bars .bar i { display: block; height: 100%; background: var(--brand-500); border-radius: 99px; }
.rs-bars .v { text-align: right; font-weight: 600; font-variant-numeric: tabular-nums; }
.rs-bars em { font-style: normal; margin-left: 1mm; }
.rs-bars em.ok { color: var(--ok); } .rs-bars em.no { color: var(--ink-3); }
.rs-tags { list-style: none; margin: 0; padding: 0; display: flex; flex-wrap: wrap; gap: 1.5mm; font-size: 8pt; }
.rs-tags li { background: #fff; border: 1px solid var(--line); border-radius: 99px; padding: .6mm 2.5mm; }

.rs-year { margin-bottom: 4mm; }
.rs-year h3 { font-size: 10pt; color: var(--ink); margin: 0 0 2mm; }
.rs-year h3 small { font-weight: 400; color: var(--ink-3); font-size: 8pt; margin-left: 1mm; }
.tl-item { display: grid; grid-template-columns: 17mm 1fr; gap: 3mm; padding: 1.8mm 0 1.8mm; border-left: 2px solid var(--brand-100); padding-left: 3mm; position: relative; break-inside: avoid; }
.tl-item::before { content: ''; position: absolute; left: -1.35mm; top: 3mm; width: 2.2mm; height: 2.2mm; border-radius: 50%; background: var(--brand-500); }
.tl-date { font-size: 8.5pt; color: var(--ink-3); font-variant-numeric: tabular-nums; padding-top: .3mm; }
.tl-name { font-weight: 600; font-size: 9.5pt; line-height: 1.35; }
.tl-meta { display: flex; flex-wrap: wrap; gap: 1mm 2.5mm; font-size: 8pt; color: var(--ink-2); margin-top: .6mm; }
.tl-type { padding: 0 2mm; border-radius: 99px; background: #eef1f5; }
.tl-type.inhouse { background: #e4eefb; color: #1b5aa6; } .tl-type.public { background: #fcf0d8; color: #8f5a00; } .tl-type.online { background: #e1f3ea; color: #10704f; }
.tl-absent { color: var(--danger); }
.tl-cert { color: var(--ok); font-weight: 600; }

.rs-foot { display: flex; justify-content: space-between; margin-top: 6mm; padding-top: 3mm; border-top: 1px solid var(--line); font-size: 7.5pt; color: var(--ink-3); }
</style>

<style>
/* print: only the A4 sheet, full bleed on an A4 portrait page */
@page resume { size: A4 portrait; margin: 0; }
@media print {
  .a4-scroll { overflow: visible; padding: 0; }
  .a4-sheet { page: resume; box-shadow: none; border-radius: 0; margin: 0; min-height: 0; }
  .rs-side { -webkit-print-color-adjust: exact; print-color-adjust: exact; }
  .rs-avatar, .rs-bars .bar i, .tl-type, .tl-item::before { -webkit-print-color-adjust: exact; print-color-adjust: exact; }
}
</style>
