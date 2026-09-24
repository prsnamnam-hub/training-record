<template>
  <div>
    <PageHeader :title="`ผลการค้นหา: ${q}`" subtitle="ค้นหาจาก Employee ID / ชื่อ / หลักสูตร / ฝ่าย / Training ID / Provider" />
    <div v-if="loading" class="loading-block"><span class="spinner"></span></div>
    <template v-else>
      <div class="card">
        <div class="card-title"><h3>พนักงาน ({{ emps.length }})</h3></div>
        <DataTable :columns="[{ key: 'employee_code', label: 'รหัส' }, { key: 'full_name', label: 'ชื่อ' }, { key: 'nickname', label: 'ชื่อเล่น' }, { key: 'dept', label: 'ฝ่าย' }, { key: 'employment_status', label: 'สถานะ' }]"
          :rows="emps" :paginate="false" @row-click="(r) => $router.push(`/master/employees/${r.id}`)" />
      </div>
      <div class="card">
        <div class="card-title"><h3>รอบอบรม / Training ID ({{ sessions.length }})</h3></div>
        <DataTable :columns="[{ key: 'session_code', label: 'Training ID' }, { key: 'session_name', label: 'หลักสูตร' }, { key: 'start_date', label: 'วันที่', type: 'date' }, { key: 'provider_name', label: 'Provider' }, { key: 'participant_count', label: 'ผู้เข้าอบรม', type: 'number' }]"
          :rows="sessions" :paginate="false" @row-click="(r) => $router.push(`/training/sessions/${r.id}`)" />
      </div>
      <div class="grid g3">
        <div class="card"><div class="card-title"><h3>หลักสูตร ({{ courses.length }})</h3></div>
          <div v-for="c in courses" :key="c.id"><RouterLink :to="`/master/courses/${c.id}`">{{ c.course_name }}</RouterLink></div></div>
        <div class="card"><div class="card-title"><h3>ฝ่าย ({{ depts.length }})</h3></div>
          <div v-for="d in depts" :key="d.id"><RouterLink :to="{ path: '/reports/center', query: { r: 'department' } }">{{ d.code }} {{ d.name }}</RouterLink></div></div>
        <div class="card"><div class="card-title"><h3>Provider ({{ providers.length }})</h3></div>
          <div v-for="p in providers" :key="p.id">{{ p.name }}</div></div>
      </div>
    </template>
  </div>
</template>
<script setup>
import { onMounted, ref } from 'vue'
import { useRoute } from 'vue-router'
import PageHeader from '../components/PageHeader.vue'
import DataTable from '../components/DataTable.vue'
import { supabase, must } from '../lib/supabase'
import { searchEmployees } from '../lib/api'
const route = useRoute(); const q = String(route.query.q || '')
const loading = ref(true); const emps = ref([]); const sessions = ref([]); const courses = ref([]); const depts = ref([]); const providers = ref([])
onMounted(async () => {
  const s = q.replace(/[%,()]/g, ' ').trim()
  try {
    const [e, ss, c, d, p] = await Promise.all([
      searchEmployees(s, 50),
      must(supabase.from('v_session_summary').select('id, session_code, session_name, start_date, provider_name, participant_count')
        .or(`session_name.ilike.%${s}%,session_code.ilike.%${s}%,provider_name.ilike.%${s}%,location.ilike.%${s}%${/^\d+$/.test(s) ? `,legacy_course_id.eq.${s},id.eq.${s}` : ''}`)
        .order('start_date', { ascending: false, nullsFirst: false }).limit(50)),
      must(supabase.from('training_courses').select('id, course_name').ilike('course_name', `%${s}%`).is('deleted_at', null).limit(30)),
      must(supabase.from('departments').select('id, code, name').or(`name.ilike.%${s}%,code.ilike.%${s}%`).limit(30)),
      must(supabase.from('training_providers').select('id, name').ilike('name', `%${s}%`).limit(30)),
    ])
    emps.value = e.map((x) => ({ ...x, dept: x.departments?.name })); sessions.value = ss; courses.value = c; depts.value = d; providers.value = p
  } finally { loading.value = false }
})
</script>
