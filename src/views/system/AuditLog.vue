<template>
  <div>
    <PageHeader title="Audit Log" subtitle="บันทึกการสร้าง / แก้ไข / ลบ — Original Value, Updated Value, Updated By, Updated Date" crumb="System">
      <ExportMenu :handler="doExport" :pdf="false" />
    </PageHeader>
    <div class="card">
      <div class="filterbar">
        <div class="field"><label>ตาราง</label><MultiSelect v-model="tables" :options="TABLES.map((t) => ({ id: t, name: t }))" /></div>
        <div class="field"><label>Action</label><MultiSelect v-model="actions" :options="['INSERT', 'UPDATE', 'SOFT_DELETE', 'RESTORE', 'DELETE'].map((t) => ({ id: t, name: t }))" /></div>
        <div class="field"><label>ผู้ใช้ (อีเมล)</label><input v-model="who" class="input" @change="load" /></div>
        <div class="field"><label>ตั้งแต่</label><input v-model="from" type="date" class="input" @change="load" /></div>
        <div class="field"><label>ถึง</label><input v-model="to" type="date" class="input" @change="load" /></div>
      </div>
    </div>
    <div class="card">
      <DataTable :columns="cols" :rows="rows" :loading="loading" :total="total" v-model:page="page" v-model:size="size">
        <template #cell-action="{ row }"><span class="badge" :class="{ INSERT: 'green', UPDATE: 'blue', SOFT_DELETE: 'red', DELETE: 'red', RESTORE: 'amber' }[row.action]">{{ row.action }}</span></template>
        <template #cell-diff="{ row }">
          <div v-if="row.action === 'UPDATE' || row.action === 'SOFT_DELETE' || row.action === 'RESTORE'" class="small">
            <div v-for="f in row.changed_fields || []" :key="f"><b>{{ f }}</b>: <span style="color:var(--danger)">{{ show(row.old_data?.[f]) }}</span> → <span style="color:var(--ok)">{{ show(row.new_data?.[f]) }}</span></div>
          </div>
          <div v-else class="small muted" style="max-width:520px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis">{{ summary(row.new_data || row.old_data) }}</div>
        </template>
      </DataTable>
    </div>
  </div>
</template>
<script setup>
import { onMounted, ref, watch } from 'vue'
import PageHeader from '../../components/PageHeader.vue'
import DataTable from '../../components/DataTable.vue'
import MultiSelect from '../../components/MultiSelect.vue'
import ExportMenu from '../../components/ExportMenu.vue'
import { supabase, must } from '../../lib/supabase'
import { fetchAll } from '../../lib/api'
import { dateTimeTH } from '../../lib/format'
import { exportExcel, exportCSV, fileStamp } from '../../lib/export'
const TABLES = ['training_sessions', 'training_participants', 'training_expenses', 'training_courses', 'employees', 'departments', 'sections', 'companies',
  'training_categories', 'training_types', 'trainers', 'training_providers', 'expense_categories', 'training_budgets', 'profiles', 'app_settings']
const rows = ref([]); const total = ref(0); const page = ref(1); const size = ref(50); const loading = ref(false)
const tables = ref([]); const actions = ref([]); const who = ref(''); const from = ref(''); const to = ref('')
const cols = [{ key: 'changed_at', label: 'Updated Date', format: (r) => dateTimeTH(r.changed_at) }, { key: 'changed_by_email', label: 'Updated By' },
  { key: 'table_name', label: 'ตาราง' }, { key: 'record_id', label: 'Record ID' }, { key: 'action', label: 'Action' }, { key: 'diff', label: 'Original → Updated Value', sortable: false }]
const show = (v) => (v === null || v === undefined ? '∅' : typeof v === 'object' ? JSON.stringify(v) : String(v))
const summary = (o) => (o ? Object.entries(o).filter(([k, v]) => v !== null && !/_at$|_by$|^id$/.test(k)).slice(0, 6).map(([k, v]) => `${k}: ${show(v)}`).join(' · ') : '')
function query(count) {
  let q = supabase.from('audit_logs').select('*', count ? { count: 'exact' } : undefined)
  if (tables.value.length) q = q.in('table_name', tables.value)
  if (actions.value.length) q = q.in('action', actions.value)
  if (who.value) q = q.ilike('changed_by_email', `%${who.value}%`)
  if (from.value) q = q.gte('changed_at', from.value)
  if (to.value) q = q.lte('changed_at', to.value + 'T23:59:59')
  return q.order('changed_at', { ascending: false })
}
async function load() {
  loading.value = true
  try { const f = (page.value - 1) * size.value; const r = await must(query(true).range(f, f + size.value - 1)); rows.value = r.data; total.value = r.count }
  finally { loading.value = false }
}
watch([tables, actions], () => { page.value = 1; load() }); watch([page, size], load); onMounted(load)
async function doExport(kind) {
  const all = await fetchAll(query(false))
  const c = [{ key: 'changed_at', label: 'Updated Date' }, { key: 'changed_by_email', label: 'Updated By' }, { key: 'table_name', label: 'Table' }, { key: 'record_id', label: 'Record ID' },
    { key: 'action', label: 'Action' }, { key: 'changed_fields', label: 'Fields', value: (r) => (r.changed_fields || []).join(', ') },
    { key: 'old_data', label: 'Original Value', value: (r) => JSON.stringify(r.old_data) }, { key: 'new_data', label: 'Updated Value', value: (r) => JSON.stringify(r.new_data) }]
  const name = fileStamp('Training_Audit_Log', [new Date().toISOString().slice(0, 10)])
  if (kind === 'csv') return exportCSV(`${name}.csv`, c, all)
  return exportExcel(`${name}.xlsx`, [{ name: 'Audit Log', title: 'Audit Log', columns: c, rows: all }])
}
</script>
