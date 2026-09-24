<template>
  <div>
    <PageHeader title="Custom Report" subtitle="สร้างรายงานเอง — เลือกมิติ (Group by) และตัวชี้วัด แล้วกรองข้อมูลได้ทุกมิติ" />
    <div class="card mb">
      <div class="form-grid">
        <div class="field"><label>จัดกลุ่มตาม (Group by)</label>
          <select v-model="group" class="input"><option v-for="(l, k) in GROUPS" :key="k" :value="k">{{ l }}</option></select></div>
        <div class="field wide"><label>ตัวชี้วัด (Metrics)</label>
          <div class="row"><label v-for="(l, k) in METRICS" :key="k" class="small"><input type="checkbox" :value="k" v-model="metrics" /> {{ l }}</label></div></div>
        <div class="field"><label>กราฟแสดง</label><select v-model="chart" class="input"><option v-for="k in metrics" :key="k" :value="k">{{ METRICS[k] }}</option></select></div>
      </div>
    </div>
    <ReportRunner :key="group + metrics.join() + chart" :group="group" title="Custom Report" :metrics="metrics" :chart="chart" file-prefix="Training_Custom_Report" />
  </div>
</template>
<script setup>
import { ref, watch } from 'vue'
import PageHeader from '../../components/PageHeader.vue'
import ReportRunner from '../../components/ReportRunner.vue'
const GROUPS = { department: 'ฝ่าย', company: 'บริษัท', business_group: 'กลุ่มธุรกิจ', section: 'Section', level_group: 'กลุ่มระดับพนักงาน', position: 'ระดับตำแหน่ง',
  course: 'หลักสูตร', session: 'รอบอบรม', training_type: 'ประเภท', category: 'หมวดหมู่', provider: 'Provider', trainer: 'Trainer', employee: 'พนักงาน',
  year: 'ปี', month: 'เดือน', year_month: 'ปี-เดือน' }
const METRICS = { sessions: 'Sessions', courses: 'Courses', participants: 'Participants', employees: 'พนักงาน', training_hours: 'Training Hours', avg_hours_per_person: 'ชม./คน',
  total_cost: 'Cost', cost_per_participant: 'Cost/Person', cost_per_hour: 'Cost/Hour', inhouse: 'Inhouse', public_cnt: 'Public', online: 'Online', last_date: 'อบรมล่าสุด' }
const group = ref('department'); const metrics = ref(['sessions', 'participants', 'employees', 'training_hours', 'total_cost']); const chart = ref('participants')
watch(metrics, (m) => { if (!m.includes(chart.value)) chart.value = m.find((x) => x !== 'last_date') || 'participants' })
</script>
