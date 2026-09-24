<template>
  <div>
    <div class="card no-print">
      <FilterBar v-model="filters" :fields="['years', 'companies', 'business_groups', 'departments', 'level_groups', 'training_types', 'categories']" />
      <div class="row mt">
        <label class="small">แสดง:</label>
        <select v-model="show" class="input" style="width:auto"><option value="all">ทั้งหมด</option><option value="met">ผ่านเป้า</option><option value="not">ยังไม่ผ่านเป้า</option></select>
        <span style="flex:1"></span><ExportMenu :handler="doExport" :pdf="false" />
      </div>
    </div>
    <div class="grid g4 mt">
      <KpiCard label="พนักงานที่เข้าอบรม" :value="num(rows.length)" />
      <KpiCard label="ผ่านเป้า" :value="num(met)" :sub="pct(rows.length ? (met / rows.length) * 100 : null)" color="var(--ok)" />
      <KpiCard label="ยังไม่ผ่านเป้า" :value="num(rows.length - met)" color="var(--danger)" />
      <KpiCard label="เฉลี่ยหลักสูตร/คน" :value="num(rows.length ? rows.reduce((a, r) => a + r.courses, 0) / rows.length : 0, 2)" />
    </div>
    <div class="card mt">
      <DataTable :columns="cols" :rows="shown" :loading="loading" row-key="key" @row-click="(r) => $router.push(`/master/employees/${r.employee_id}`)">
        <template #cell-met_target="{ row }"><span class="badge" :class="row.met_target ? 'green' : 'red'">{{ row.met_target ? 'ผ่าน' : 'ไม่ผ่าน' }}</span></template>
      </DataTable>
    </div>
  </div>
</template>
<script setup>
import { computed, onMounted, ref, watch } from 'vue'
import FilterBar from '../../components/FilterBar.vue'
import DataTable from '../../components/DataTable.vue'
import KpiCard from '../../components/KpiCard.vue'
import ExportMenu from '../../components/ExportMenu.vue'
import { employeeTarget } from '../../lib/api'
import { num, pct, be } from '../../lib/format'
import { exportExcel, exportCSV, fileStamp } from '../../lib/export'
const filters = ref({ years: [new Date().getFullYear()] }); const rows = ref([]); const loading = ref(false); const show = ref('all')
const cols = [{ key: 'year_be', label: 'ปี' }, { key: 'employee_code', label: 'รหัส' }, { key: 'employee_name', label: 'ชื่อ-นามสกุล' }, { key: 'department_name', label: 'ฝ่าย' },
  { key: 'level_group_name', label: 'กลุ่มระดับ' }, { key: 'courses', label: 'จำนวนหลักสูตร', type: 'number' }, { key: 'training_hours', label: 'ชั่วโมง', type: 'number', digits: 1 },
  { key: 'total_cost', label: 'Cost', type: 'money' }, { key: 'met_target', label: 'ผลเทียบเป้า' }]
const met = computed(() => rows.value.filter((r) => r.met_target).length)
const shown = computed(() => rows.value.filter((r) => show.value === 'all' || (show.value === 'met' ? r.met_target : !r.met_target)))
async function load() {
  loading.value = true
  try { rows.value = (await employeeTarget(filters.value)).map((r) => ({ ...r, key: `${r.employee_id}-${r.year}`, year_be: be(r.year) })).sort((a, b) => a.courses - b.courses) }
  finally { loading.value = false }
}
watch(filters, load, { deep: true }); onMounted(load)
async function doExport(kind) {
  const name = fileStamp('Training_Target_Report', [(filters.value.years || []).join('-')])
  const c = cols.map((x) => (x.key === 'met_target' ? { ...x, value: (r) => (r.met_target ? 'ผ่าน' : 'ไม่ผ่าน') } : x))
  if (kind === 'csv') return exportCSV(`${name}.csv`, c, shown.value)
  return exportExcel(`${name}.xlsx`, [{ name: 'Target', title: 'Training Target Report', columns: c, rows: shown.value }])
}
</script>
