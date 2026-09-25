<template>
  <div>
    <PageHeader title="Export ข้อมูล" subtitle="ส่งออกข้อมูลและรายงานทั้งหมดของ ASW Training Record — Excel / CSV / PDF" />
    <div class="grid g3">
      <div v-for="x in items" :key="x.to" class="card">
        <h3>{{ x.title }}</h3>
        <p class="small muted">{{ x.desc }}</p>
        <RouterLink :to="x.to" class="btn sm">เปิดและ Export ›</RouterLink>
      </div>
    </div>
    <div class="card mt">
      <h3>รูปแบบชื่อไฟล์</h3>
      <ul class="small">
        <li><code>ASW_Training_Record_Report_2026_09.xlsx</code> — Monthly Report</li>
        <li><code>ASW_Training_Employee_12345.xlsx</code> — Employee Training History</li>
        <li><code>ASW_Training_Cost_Report_2026.xlsx</code> — Training Cost Report</li>
      </ul>
    </div>
  </div>
</template>
<script setup>
import PageHeader from '../../components/PageHeader.vue'
const items = [
  { title: 'Dashboard', desc: 'KPI, Trend, Department, Course, Expense, Insights (Excel หลายชีต / PDF)', to: '/dashboard' },
  { title: 'Monthly Training Management Report', desc: 'รายงานผู้บริหารประจำเดือน 12 หัวข้อ', to: '/reports/monthly' },
  { title: 'Training Record (ข้อมูลดิบทั้งหมด)', desc: 'ทุกรายการอบรม พร้อมตัวกรองทุกมิติ', to: '/training/records' },
  { title: 'Training Session', desc: 'รายการรอบอบรม + ผู้เข้าอบรม + ค่าใช้จ่าย', to: '/training/sessions' },
  { title: 'Course Report', desc: 'สรุปรายหลักสูตร', to: '/reports/center?r=course' },
  { title: 'Department Report', desc: 'Employee Count, Participants, Hours, Cost/Employee', to: '/reports/center?r=department' },
  { title: 'Training Cost Report', desc: 'Cost / Participant / Hour รายรอบ', to: '/reports/center?r=cost' },
  { title: 'Employee Training History', desc: 'ประวัติรายบุคคล', to: '/reports/employee' },
  { title: 'Training Expense', desc: 'ค่าใช้จ่ายทั้งหมด / ค่าอาหาร / อื่น ๆ', to: '/expense/all' },
  { title: 'Training Target Report', desc: 'ผ่าน/ไม่ผ่านเป้า ≥ 2 หลักสูตร/ปี', to: '/reports/center?r=target' },
  { title: 'Employee Master', desc: 'รายชื่อพนักงาน', to: '/master/employees' },
  { title: 'Custom Report', desc: 'เลือกมิติและตัวชี้วัดเอง', to: '/reports/custom' },
]
</script>
