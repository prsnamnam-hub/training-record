<template>
  <div>
    <PageHeader :title="page.title" :subtitle="page.subtitle" />
    <ReportRunner :key="r.id" :group="r.group" :title="page.title" :metrics="r.metrics" :chart="r.chart || 'participants'" :file-prefix="r.file" />
  </div>
</template>
<script setup>
import { computed } from 'vue'
import PageHeader from '../../components/PageHeader.vue'
import ReportRunner from '../../components/ReportRunner.vue'
import { REPORTS } from '../../lib/reports'

// One report from the Report Center shown as its own page (Report › รายงานหลักสูตร / รายงานฝ่าย)
const props = defineProps({ reportId: { type: String, required: true } })
const PAGES = {
  course: { title: 'รายงานหลักสูตร', subtitle: 'สรุปตามหลักสูตร (รวมทุกรุ่น) — จำนวนรุ่น ผู้เข้าอบรม ชั่วโมง ค่าใช้จ่าย · คลิกแถวเพื่อดูรายละเอียดหลักสูตร' },
  department: { title: 'รายงานฝ่าย', subtitle: 'สรุปตามฝ่าย — จำนวนพนักงาน ผู้เข้าอบรม หลักสูตร ชั่วโมง ค่าใช้จ่าย' },
}
const r = computed(() => REPORTS.find((x) => x.id === props.reportId))
const page = computed(() => PAGES[props.reportId] || { title: r.value?.label, subtitle: r.value?.desc })
</script>
