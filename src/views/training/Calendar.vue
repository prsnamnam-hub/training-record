<template>
  <div>
    <PageHeader title="Training Calendar" subtitle="ปฏิทินการอบรม — วันที่ / หลักสูตร / วิทยากร / สถานที่ / ผู้เข้าอบรม / สถานะ">
      <div class="tabs" style="margin:0;border:none">
        <button v-for="m in ['month', 'week', 'day']" :key="m" :class="{ on: view === m }" @click="view = m">{{ { month: 'เดือน', week: 'สัปดาห์', day: 'วัน' }[m] }}</button>
      </div>
      <button class="btn" @click="shift(-1)">‹</button><button class="btn" @click="cur = new Date()">วันนี้</button><button class="btn" @click="shift(1)">›</button>
      <RouterLink v-if="canEdit" to="/training/sessions/new" class="btn primary">+ บันทึกหลักสูตรใหม่</RouterLink>
    </PageHeader>
    <div class="card">
      <h2 class="mb">{{ title }}</h2>
      <div v-if="view === 'month'" class="cal">
        <div v-for="d in DOW" :key="d" class="dow">{{ d }}</div>
        <div v-for="day in monthDays" :key="day.key" class="day" :class="{ out: !day.inMonth, today: day.key === todayKey }">
          <div class="d">{{ day.date.getDate() }}</div>
          <a v-for="e in eventsOn(day.key)" :key="e.id" class="ev" :class="e.training_type" :title="tip(e)" @click="$router.push(`/training/sessions/${e.id}`)">{{ e.session_name }}</a>
        </div>
      </div>
      <div v-else>
        <div v-for="day in listDays" :key="day.key" class="mb">
          <h3 :style="day.key === todayKey ? 'color:var(--brand)' : ''">{{ DOW_FULL[day.date.getDay()] }} {{ dateTH(day.key) }}</h3>
          <DataTable v-if="eventsOn(day.key).length" :columns="cols" :rows="eventsOn(day.key)" :paginate="false" :sortable="false"
                     @row-click="(r) => $router.push(`/training/sessions/${r.id}`)">
            <template #cell-status="{ row }"><span class="badge" :class="statusColor(row.status)">{{ row.status }}</span></template>
          </DataTable>
          <div v-else class="small muted">ไม่มีการอบรม</div>
        </div>
      </div>
    </div>
  </div>
</template>
<script setup>
import { computed, ref, watch } from 'vue'
import PageHeader from '../../components/PageHeader.vue'
import DataTable from '../../components/DataTable.vue'
import { supabase, must } from '../../lib/supabase'
import { canEdit } from '../../lib/auth'
import { TH_MONTHS_FULL, dateTH, isoDate } from '../../lib/format'
import { statusColor } from '../../lib/constants'
const DOW = ['อา', 'จ', 'อ', 'พ', 'พฤ', 'ศ', 'ส']
const DOW_FULL = ['วันอาทิตย์', 'วันจันทร์', 'วันอังคาร', 'วันพุธ', 'วันพฤหัสบดี', 'วันศุกร์', 'วันเสาร์']
const view = ref('month'); const cur = ref(new Date()); const events = ref([])
const todayKey = isoDate(new Date())
const cols = [{ key: 'session_name', label: 'หลักสูตร' }, { key: 'time', label: 'เวลา' }, { key: 'trainer_name', label: 'วิทยากร' },
  { key: 'location', label: 'สถานที่' }, { key: 'participant_count', label: 'ผู้เข้าอบรม', type: 'number' }, { key: 'status', label: 'สถานะ' }]
const range = computed(() => {
  const d = new Date(cur.value)
  if (view.value === 'month') { const s = new Date(d.getFullYear(), d.getMonth(), 1); s.setDate(s.getDate() - s.getDay()); const e = new Date(s); e.setDate(e.getDate() + 41); return [s, e] }
  if (view.value === 'week') { const s = new Date(d); s.setDate(s.getDate() - s.getDay()); const e = new Date(s); e.setDate(e.getDate() + 6); return [s, e] }
  return [d, d]
})
const title = computed(() => view.value === 'month' ? `${TH_MONTHS_FULL[cur.value.getMonth()]} ${cur.value.getFullYear() + 543}`
  : view.value === 'week' ? `${dateTH(range.value[0])} – ${dateTH(range.value[1])}` : dateTH(cur.value))
const daysBetween = (s, e) => { const out = []; const d = new Date(s); while (d <= e) { out.push({ date: new Date(d), key: isoDate(d), inMonth: d.getMonth() === cur.value.getMonth() }); d.setDate(d.getDate() + 1) } return out }
const monthDays = computed(() => daysBetween(...range.value))
const listDays = computed(() => daysBetween(...range.value))
function shift(n) {
  const d = new Date(cur.value)
  if (view.value === 'month') d.setMonth(d.getMonth() + n); else if (view.value === 'week') d.setDate(d.getDate() + 7 * n); else d.setDate(d.getDate() + n)
  cur.value = d
}
const eventsOn = (key) => events.value.filter((e) => e.start_date <= key && (e.end_date || e.start_date) >= key)
const tip = (e) => `${e.session_name}\n${e.trainer_name || ''} ${e.location ? '@ ' + e.location : ''}\nผู้เข้าอบรม ${e.participant_count} คน · ${e.status}`
async function load() {
  const [s, e] = range.value.map(isoDate)
  const data = await must(supabase.from('v_session_summary').select('id, session_name, start_date, end_date, start_time, end_time, trainer_name, location, participant_count, status, training_type')
    .lte('start_date', e).gte('end_date', s).order('start_date'))
  events.value = data.map((x) => ({ ...x, time: x.start_time ? `${x.start_time.slice(0, 5)}–${(x.end_time || '').slice(0, 5)}` : '-' }))
}
watch([cur, view], load, { immediate: true })
</script>
