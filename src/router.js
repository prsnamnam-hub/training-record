import { createRouter, createWebHashHistory } from 'vue-router'
import { watch } from 'vue'
import { auth, canEdit, isAdmin } from './lib/auth'
import { APP_NAME } from './lib/config'
import AppLayout from './layouts/AppLayout.vue'

const pages = import.meta.glob('./views/**/*.vue')
const v = (p) => {
  const loader = pages[`./views/${p}.vue`]
  if (!loader) throw new Error(`missing view ${p}`)
  return loader
}

const routes = [
  { path: '/login', component: v('Login'), meta: { public: true, title: 'เข้าสู่ระบบ' } },
  { path: '/reset-password', component: v('ResetPassword'), meta: { public: true, title: 'ตั้งรหัสผ่านใหม่' } },
  {
    path: '/', component: AppLayout, children: [
      { path: '', redirect: '/dashboard' },
      { path: 'dashboard', component: v('Dashboard'), meta: { title: 'Dashboard' } },
      { path: 'search', component: v('Search'), meta: { title: 'ค้นหา' } },
      { path: 'training/records', component: v('training/TrainingRecords'), meta: { title: 'Training Record' } },
      { path: 'training/sessions', component: v('training/Sessions'), meta: { title: 'ประวัติการฝึกอบรม' } },
      { path: 'training/sessions/new', component: v('training/SessionForm'), meta: { title: 'บันทึกฝึกอบรม', edit: true } },
      { path: 'training/sessions/:id', component: v('training/SessionDetail'), meta: { title: 'Training Session' } },
      { path: 'training/sessions/:id/edit', component: v('training/SessionForm'), meta: { title: 'แก้ไข Training', edit: true } },
      { path: 'training/participants', component: v('training/Participants'), meta: { title: 'Participants' } },
      { path: 'training/calendar', component: v('training/Calendar'), meta: { title: 'Training Calendar' } },
      { path: 'master/employees', component: v('master/Employees'), meta: { title: 'Employee' } },
      { path: 'master/employees/:id', component: v('reports/EmployeeHistory'), meta: { title: 'Employee Training History' } },
      { path: 'master/courses', component: v('master/Courses'), meta: { title: 'Course' } },
      { path: 'master/courses/:id', component: v('master/CourseDetail'), meta: { title: 'Course Analysis' } },
      { path: 'master/:entity', component: v('master/MasterData'), meta: { title: 'Master Data' } },
      { path: 'expense/:kind', component: v('expense/Expenses'), meta: { title: 'Training Expense' } },
      { path: 'reports/center', component: v('reports/ReportCenter'), meta: { title: 'Report Center' } },
      { path: 'reports/course', component: v('reports/ReportPreset'), props: { reportId: 'course' }, meta: { title: 'รายงานหลักสูตร' } },
      { path: 'reports/department', component: v('reports/ReportPreset'), props: { reportId: 'department' }, meta: { title: 'รายงานฝ่าย' } },
      { path: 'reports/employee', component: v('reports/EmployeeHistory'), meta: { title: 'Employee Training History' } },
      { path: 'reports/monthly', component: v('reports/MonthlyReport'), meta: { title: 'Monthly Training Management Report' } },
      { path: 'reports/custom', component: v('reports/CustomReport'), meta: { title: 'Custom Report' } },
      { path: 'import', component: v('io/ImportCenter'), meta: { title: 'Import Center', edit: true } },
      { path: 'database/employee-import', component: v('io/ImportCenter'), props: { preset: 'employee' }, meta: { title: 'นำเข้าข้อมูลพนักงาน', edit: true } },
      { path: 'export', component: v('io/ExportCenter'), meta: { title: 'Export Report' } },
      { path: 'system/users', component: v('system/Users'), meta: { title: 'Users', admin: true } },
      { path: 'system/roles', component: v('system/Roles'), meta: { title: 'Roles' } },
      { path: 'system/audit', component: v('system/AuditLog'), meta: { title: 'Audit Log', admin: true } },
      { path: 'system/settings', component: v('system/Settings'), meta: { title: 'General Settings', admin: true } },
    ],
  },
  { path: '/:pathMatch(.*)*', redirect: '/dashboard' },
]

const router = createRouter({ history: createWebHashHistory(), routes, scrollBehavior: () => ({ top: 0 }) })

function waitReady() {
  if (auth.ready) return Promise.resolve()
  return new Promise((res) => { const stop = watch(() => auth.ready, (r) => { if (r) { stop(); res() } }) })
}

router.beforeEach(async (to) => {
  await waitReady()
  if (!to.meta.public && !auth.session) return { path: '/login', query: { next: to.fullPath } }
  if (to.path === '/login' && auth.session) return '/dashboard'
  if (to.meta.edit && !canEdit.value) return '/dashboard'
  if (to.meta.admin && !isAdmin.value) return '/dashboard'
})
router.afterEach((to) => { document.title = to.meta.title ? `${to.meta.title} · ${APP_NAME}` : APP_NAME })

export default router
