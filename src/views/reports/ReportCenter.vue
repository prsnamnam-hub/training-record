<template>
  <div>
    <PageHeader title="รายงานอื่น ๆ" subtitle="เลือกรายงาน → กรองข้อมูล (เลือกได้หลายค่า) → Export Excel / CSV / PDF · คลิกแถวเพื่อเจาะลึก">
      <RouterLink to="/reports/monthly" class="btn">รายงานประจำเดือน (Management)</RouterLink>
      <RouterLink to="/reports/custom" class="btn">Custom Report</RouterLink>
    </PageHeader>
    <div class="row mb" style="gap:6px">
      <button v-for="r in REPORTS" :key="r.id" class="btn sm" :class="{ primary: cur.id === r.id }" @click="select(r)">{{ r.label }}</button>
    </div>
    <p class="muted small mb">{{ cur.desc }}</p>
    <TargetReport v-if="cur.id === 'target'" :key="'t'" />
    <ReportRunner v-else :key="cur.id" :group="cur.group" :title="cur.label" :metrics="cur.metrics" :chart="cur.chart || 'participants'" :file-prefix="cur.file" />
  </div>
</template>
<script setup>
import { ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import PageHeader from '../../components/PageHeader.vue'
import ReportRunner from '../../components/ReportRunner.vue'
import TargetReport from './TargetReport.vue'
import { REPORTS } from '../../lib/reports'

const route = useRoute(); const router = useRouter()
const cur = ref(REPORTS.find((r) => r.id === route.query.r) || REPORTS[0])
function select(r) { cur.value = r; router.replace({ query: { r: r.id } }) }
</script>
