<template>
  <div v-if="s">
    <PageHeader :title="s.session_name" :crumb="`${s.session_code || ''}${s.legacy_course_id ? ' · Excel ID ' + s.legacy_course_id : ''}`"
      :subtitle="`${s.course_name} · ${dateRange}`">
      <RouterLink to="/training/sessions" class="btn">‹ ประวัติการฝึกอบรม</RouterLink>
      <RouterLink v-if="canEdit" :to="`/training/sessions/${s.id}/edit`" class="btn">แก้ไขข้อมูล</RouterLink>
      <button v-if="canEdit && s.status !== 'Cancelled'" class="btn danger" @click="cancel">ยกเลิกรอบอบรม</button>
    </PageHeader>
    <ol v-if="route.query.step === '2'" class="stepper">
      <li class="done"><b>✓</b> ข้อมูลหลักสูตร</li>
      <li class="on"><b>2</b> ผู้เข้าอบรม — คีย์รหัสพนักงานด้านล่าง</li>
    </ol>
    <div class="grid g5 mb">
      <KpiCard label="ผู้เข้าอบรม" :value="num(s.participant_count)" unit="คน" />
      <KpiCard label="ชั่วโมงอบรม" :value="s.training_hours ? num(s.training_hours, 1) : '-'" unit="ชม." color="var(--c6)" />
      <KpiCard label="ค่าใช้จ่ายรวม" :value="money(s.total_cost)" unit="บาท" color="var(--c4)" />
      <KpiCard label="ค่าใช้จ่ายต่อคน" :value="money(s.cost_per_participant)" unit="บาท" color="var(--c4)" />
      <KpiCard label="ค่าใช้จ่ายต่อชั่วโมง" :value="money(s.cost_per_hour)" unit="บาท" color="var(--c4)" />
    </div>
    <div class="card mb">
      <div class="card-title"><h3>ข้อมูลหลักสูตร</h3>
        <RouterLink v-if="canEdit" :to="`/training/sessions/${s.id}/edit`" class="btn sm">แก้ไข</RouterLink></div>
      <div class="form-grid">
        <div><div class="small muted">หลักสูตร</div><RouterLink :to="`/master/courses/${s.course_id}`">{{ s.course_name }}</RouterLink></div>
        <div><div class="small muted">ประเภท</div><span class="badge" :class="typeColor(s.training_type)">{{ s.training_type || '-' }}</span></div>
        <div><div class="small muted">หมวดหมู่</div>{{ s.category_name || '-' }}</div>
        <div><div class="small muted">สถานะ</div><span class="badge" :class="statusColor(s.status)">{{ s.status }}</span></div>
        <div><div class="small muted">วันที่ / เวลา</div>{{ dateRange }} <span v-if="s.start_time">· {{ s.start_time.slice(0, 5) }}–{{ (s.end_time || '').slice(0, 5) }}</span></div>
        <div><div class="small muted">วิทยากร (Trainer)</div>{{ s.trainer_name || '-' }}</div>
        <div><div class="small muted">ผู้จัด (Provider)</div>{{ s.provider_name || '-' }}</div>
        <div><div class="small muted">สถานที่</div>{{ s.location || '-' }}</div>
        <div><div class="small muted">งบประมาณ</div>{{ s.budget_amount ? money(s.budget_amount) + ' บาท' : '-' }}</div>
        <div><div class="small muted">แหล่งข้อมูล</div>{{ s.data_source }}<span v-if="s.legacy_month_text" class="small muted"> (เดือนเดิม: {{ s.legacy_month_text }})</span></div>
        <div class="wide" v-if="s.remark"><div class="small muted">หมายเหตุ</div>{{ s.remark }}</div>
      </div>
    </div>
    <div class="tabs">
      <button :class="{ on: tab === 'p' }" @click="tab = 'p'">ผู้เข้าอบรม ({{ s.participant_count }})</button>
      <button :class="{ on: tab === 'e' }" @click="tab = 'e'">ค่าใช้จ่าย</button>
    </div>
    <div class="card">
      <SessionParticipants v-if="tab === 'p'" :session-id="s.id" :session="s" :autofocus="route.query.step === '2'" @changed="load" />
      <SessionExpenses v-else :session-id="s.id" :session="s" @changed="load" />
    </div>
  </div>
  <div v-else-if="err" class="alert err">{{ err }}</div>
  <div v-else class="loading-block"><span class="spinner"></span></div>
</template>
<script setup>
import { computed, onMounted, ref } from 'vue'
import { useRoute } from 'vue-router'
import PageHeader from '../../components/PageHeader.vue'
import KpiCard from '../../components/KpiCard.vue'
import SessionParticipants from '../../components/SessionParticipants.vue'
import SessionExpenses from '../../components/SessionExpenses.vue'
import { supabase, must } from '../../lib/supabase'
import { canEdit } from '../../lib/auth'
import { num, money, dateTH } from '../../lib/format'
import { statusColor, typeColor } from '../../lib/constants'
import { toastOk, toastError } from '../../lib/toast'

const route = useRoute()
const s = ref(null); const err = ref(''); const tab = ref(route.query.tab === 'expense' ? 'e' : 'p')
const dateRange = computed(() => (!s.value?.start_date ? `ไม่ระบุวันที่ (ปี ${s.value?.fiscal_year + 543})`
  : s.value.end_date && s.value.end_date !== s.value.start_date ? `${dateTH(s.value.start_date)} – ${dateTH(s.value.end_date)}` : dateTH(s.value.start_date)))
async function load() {
  try { s.value = await must(supabase.from('v_session_summary').select('*').eq('id', route.params.id).single()) }
  catch (e) { err.value = e.message }
}
async function cancel() {
  if (!confirm('ยืนยันยกเลิกรอบอบรมนี้? ข้อมูลยังคงอยู่ในระบบ (สถานะ Cancelled)')) return
  try { await must(supabase.from('training_sessions').update({ status: 'Cancelled' }).eq('id', s.value.id)); toastOk('ยกเลิกรอบอบรมแล้ว'); load() }
  catch (e) { toastError(e) }
}
onMounted(load)
</script>
