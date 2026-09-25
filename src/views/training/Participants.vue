<template>
  <div>
    <PageHeader title="ผู้เข้าอบรม" subtitle="จัดการผู้เข้าอบรมรายรอบ — Add / Remove / Search Employee / Filter Department / Bulk Add / Import Excel" />
    <div class="card mb">
      <div class="field"><label>เลือก Training Session</label>
        <div class="row">
          <input v-model="q" class="input" style="flex:1" placeholder="พิมพ์ชื่อหลักสูตร / Training ID เพื่อค้นหา" @input="debounced" />
          <label class="small"><input type="checkbox" v-model="upcoming" @change="search" /> เฉพาะรอบที่ยังไม่จบ</label>
        </div>
      </div>
      <div class="tbl-wrap mt" style="max-height:260px;overflow:auto">
        <table class="tbl"><tbody>
          <tr v-for="r in results" :key="r.id" class="clickable" :style="r.id === sel?.id ? 'background:var(--brand-50)' : ''" @click="choose(r)">
            <td>{{ r.session_name }} <span class="small muted">{{ r.session_code }}</span></td><td class="nowrap">{{ dateTH(r.start_date) }}</td>
            <td><span class="badge" :class="statusColor(r.status)">{{ r.status }}</span></td><td class="num">{{ r.participant_count }} คน</td>
          </tr>
          <tr v-if="!results.length"><td class="empty">ไม่พบรอบอบรม</td></tr>
        </tbody></table>
      </div>
    </div>
    <div v-if="sel" class="card">
      <div class="card-title"><h2>{{ sel.session_name }}</h2><RouterLink :to="`/training/sessions/${sel.id}`" class="btn sm">เปิดหน้า Session ›</RouterLink></div>
      <SessionParticipants :key="sel.id" :session-id="sel.id" :session="sel" @changed="refresh" />
    </div>
  </div>
</template>
<script setup>
import { onMounted, ref } from 'vue'
import PageHeader from '../../components/PageHeader.vue'
import SessionParticipants from '../../components/SessionParticipants.vue'
import { supabase, must } from '../../lib/supabase'
import { dateTH } from '../../lib/format'
import { statusColor } from '../../lib/constants'
const q = ref(''); const results = ref([]); const sel = ref(null); const upcoming = ref(true)
let t; const debounced = () => { clearTimeout(t); t = setTimeout(search, 250) }
async function search() {
  let qb = supabase.from('v_session_summary').select('id, session_name, session_code, start_date, status, participant_count, training_hours')
  const s = q.value.replace(/[%,()]/g, ' ').trim()
  if (s) qb = qb.or(`session_name.ilike.%${s}%,session_code.ilike.%${s}%`)
  if (upcoming.value && !s) qb = qb.in('status', ['Draft', 'Planned', 'Scheduled', 'In Progress'])
  results.value = await must(qb.order('start_date', { ascending: false, nullsFirst: false }).limit(50))
  if (!results.value.length && upcoming.value && !s) { upcoming.value = false; return search() }
}
const choose = (r) => { sel.value = r }
async function refresh() { const r = await must(supabase.from('v_session_summary').select('*').eq('id', sel.value.id).single()); sel.value = r; search() }
onMounted(search)
</script>
