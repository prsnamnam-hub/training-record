<template>
  <div>
    <div class="row">
      <input v-model="q" class="input" style="flex:1;min-width:200px" placeholder="ค้นหารหัส / ชื่อ / ชื่อเล่นพนักงาน" @input="debounced" />
      <MultiSelect v-model="deptFilter" :options="depts" placeholder="ทุกฝ่าย" style="min-width:200px" @update:model-value="search" />
      <button class="btn sm" @click="selectAllShown" :disabled="!results.length">เลือกทั้งหมดที่แสดง ({{ results.length }})</button>
    </div>
    <div class="tbl-wrap mt" style="max-height:320px;overflow:auto">
      <table class="tbl">
        <thead><tr><th></th><th>รหัส</th><th>ชื่อ-นามสกุล</th><th>ชื่อเล่น</th><th>ฝ่าย</th><th>สถานะ</th></tr></thead>
        <tbody>
          <tr v-if="loading"><td colspan="6"><div class="loading-block"><span class="spinner"></span></div></td></tr>
          <tr v-for="e in results" :key="e.id" class="clickable" @click="toggle(e)">
            <td><input type="checkbox" :checked="selected.has(e.id)" :disabled="exclude.includes(e.id)" /></td>
            <td>{{ e.employee_code }}</td><td>{{ e.full_name }}</td><td>{{ e.nickname }}</td>
            <td>{{ e.departments?.name }}</td>
            <td><span class="badge" :class="e.employment_status === 'Active' ? 'green' : ''">{{ e.employment_status || '-' }}</span></td>
          </tr>
        </tbody>
      </table>
    </div>
    <div class="small muted mt">เลือกแล้ว {{ selected.size }} คน<span v-if="exclude.length"> · ผู้ที่อยู่ในรอบนี้แล้วจะถูกข้าม</span></div>
  </div>
</template>
<script setup>
import { onMounted, ref, reactive } from 'vue'
import MultiSelect from './MultiSelect.vue'
import { supabase, must } from '../lib/supabase'
import { filterOptions } from '../lib/api'

const props = defineProps({ exclude: { type: Array, default: () => [] } })
const emit = defineEmits(['change'])
const q = ref('')
const deptFilter = ref([])
const depts = ref([])
const results = ref([])
const loading = ref(false)
const selected = reactive(new Map())
let t
const debounced = () => { clearTimeout(t); t = setTimeout(search, 250) }
async function search() {
  loading.value = true
  try {
    let qb = supabase.from('employees').select('id, employee_code, full_name, nickname, employment_status, department_id, departments(name)').is('deleted_at', null)
    const s = q.value.replace(/[%,()]/g, ' ').trim()
    if (s) qb = qb.or(`employee_code.ilike.%${s}%,full_name.ilike.%${s}%,nickname.ilike.%${s}%`)
    if (deptFilter.value.length) qb = qb.in('department_id', deptFilter.value)
    else if (!s) qb = qb.eq('employment_status', 'Active')
    results.value = await must(qb.order('employee_code').limit(deptFilter.value.length ? 500 : 100))
  } finally { loading.value = false }
}
function toggle(e) {
  if (props.exclude.includes(e.id)) return
  selected.has(e.id) ? selected.delete(e.id) : selected.set(e.id, e)
  emit('change', [...selected.values()])
}
function selectAllShown() {
  results.value.forEach((e) => { if (!props.exclude.includes(e.id)) selected.set(e.id, e) })
  emit('change', [...selected.values()])
}
onMounted(async () => {
  const o = await filterOptions()
  depts.value = o.departments.map((d) => ({ id: d.id, name: d.name }))
  search()
})
</script>
