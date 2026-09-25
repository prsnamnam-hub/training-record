<template>
  <div v-if="c" ref="page">
    <PageHeader :title="c.course_name" :crumb="`Course Analysis · ${c.course_code || ''}`" :subtitle="[c.training_types?.name, c.training_categories?.name, c.training_providers?.name].filter(Boolean).join(' · ')">
      <RouterLink to="/master/courses" class="btn">‹ รายการ</RouterLink>
      <RouterLink v-if="canEdit" :to="`/training/sessions/new?course=${c.id}`" class="btn primary">+ สร้างรอบอบรมใหม่</RouterLink>
      <ExportMenu :handler="doExport" />
    </PageHeader>
    <div class="grid g3 mb" style="grid-template-columns:repeat(6,minmax(0,1fr))">
      <KpiCard label="Number of Sessions" :value="num(sessions.length)" unit="รอบ" />
      <KpiCard label="Participants" :value="num(totals.participants)" unit="คน-ครั้ง" color="var(--c3)" />
      <KpiCard label="Training Hours" :value="num(totals.personHours, 1)" unit="ชม." sub="ชั่วโมง × คน" color="var(--c6)" />
      <KpiCard label="Total Cost" :value="money(totals.cost)" unit="บาท" color="var(--c4)" />
      <KpiCard label="Cost / Person" :value="totals.participants ? money(totals.cost / totals.participants) : '-'" unit="บาท" color="var(--c4)" />
      <KpiCard label="Cost / Training Hour" :value="totals.sessionHours ? money(totals.cost / totals.sessionHours) : '-'" unit="บาท" color="var(--c4)" />
    </div>
    <div v-if="c.objective" class="card mb"><b>Objective:</b> {{ c.objective }}</div>
    <div class="card mt">
      <div class="card-title"><h3>รอบอบรม (Training Session)</h3></div>
      <DataTable :columns="cols" :rows="sessions" :paginate="false" @row-click="(r) => $router.push(`/training/sessions/${r.id}`)">
        <template #cell-status="{ row }"><span class="badge" :class="statusColor(row.status)">{{ row.status }}</span></template>
      </DataTable>
    </div>
  </div>
  <div v-else class="loading-block"><span class="spinner"></span></div>
</template>
<script setup>
import { computed, onMounted, ref } from 'vue'
import { useRoute } from 'vue-router'
import PageHeader from '../../components/PageHeader.vue'
import KpiCard from '../../components/KpiCard.vue'
import DataTable from '../../components/DataTable.vue'
import ExportMenu from '../../components/ExportMenu.vue'
import { supabase, must } from '../../lib/supabase'
import { report } from '../../lib/api'
import { canEdit } from '../../lib/auth'
import { num, money } from '../../lib/format'
import { statusColor } from '../../lib/constants'
import { exportExcel, exportCSV, exportPDF, fileStamp } from '../../lib/export'

const route = useRoute()
const c = ref(null); const sessions = ref([]); const byDept = ref([]); const page = ref(null)
const cols = [
  { key: 'session_name', label: 'รอบอบรม' }, { key: 'start_date', label: 'วันที่', type: 'date' }, { key: 'training_type', label: 'ประเภท' },
  { key: 'trainer_name', label: 'Trainer' }, { key: 'participant_count', label: 'ผู้เข้าอบรม', type: 'number' }, { key: 'training_hours', label: 'ชม.', type: 'number', digits: 1 },
  { key: 'total_cost', label: 'Cost', type: 'money' }, { key: 'cost_per_participant', label: 'Cost/Person', type: 'money' }, { key: 'cost_per_hour', label: 'Cost/Hour', type: 'money' }, { key: 'status', label: 'สถานะ' },
]
const totals = computed(() => sessions.value.reduce((a, s) => ({
  participants: a.participants + s.participant_count, cost: a.cost + Number(s.total_cost || 0),
  sessionHours: a.sessionHours + Number(s.training_hours || 0), personHours: a.personHours + Number(s.training_hours || 0) * s.participant_count,
}), { participants: 0, cost: 0, sessionHours: 0, personHours: 0 }))
async function doExport(kind) {
  const name = fileStamp('Training_Course', [c.value.course_code])
  if (kind === 'pdf') return exportPDF(page.value, `${name}.pdf`)
  if (kind === 'csv') return exportCSV(`${name}.csv`, cols, sessions.value)
  return exportExcel(`${name}.xlsx`, [{ name: 'Sessions', title: `Course Analysis — ${c.value.course_name}`, columns: cols, rows: sessions.value },
    { name: 'By Department', title: 'ผู้เข้าอบรมตามฝ่าย', columns: [{ key: 'group_label', label: 'ฝ่าย' }, { key: 'participants', label: 'คน-ครั้ง', type: 'number' }, { key: 'employees', label: 'พนักงาน', type: 'number' }], rows: byDept.value }])
}
onMounted(async () => {
  const id = Number(route.params.id)
  c.value = await must(supabase.from('training_courses').select('*, training_types(name), training_categories(name), training_providers(name)').eq('id', id).single())
  sessions.value = await must(supabase.from('v_session_summary').select('*').eq('course_id', id).order('start_date', { ascending: false, nullsFirst: false }))
  byDept.value = (await report({ course_ids: [id] }, 'department')).sort((a, b) => b.participants - a.participants).slice(0, 12)
})
</script>
