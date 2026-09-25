// Main menu: 5 top-level categories in the sidebar; each category's pages are shown as
// tabs above the page content (AppLayout). `prefixes` decide which category a route belongs to
// (so detail pages such as /training/sessions/12 keep their category highlighted).
// role: 'edit' = Admin / HR-Training, 'admin' = Admin only.
export const MENU = [
  { key: 'dashboard', label: 'Dashboard', prefixes: ['/dashboard', '/search'], items: [
    { to: '/dashboard', label: 'Dashboard' },
  ] },
  { key: 'training', label: 'Training Record', prefixes: ['/training', '/expense'], items: [
    { to: '/training/sessions/new', label: 'บันทึกฝึกอบรม', role: 'edit' },
    // history = by-person records + by-course list (/training/sessions) and each course page
    { to: '/training/records', label: 'ประวัติการฝึกอบรม', match: ['/training/sessions', '/training/participants'] },
    { to: '/training/calendar', label: 'ปฏิทินอบรม' },
    { to: '/expense/all', label: 'ค่าใช้จ่าย', match: '/expense/' },
  ] },
  { key: 'database', label: 'Database', prefixes: ['/database', '/master', '/import'], items: [
    { to: '/database/employee-import', label: 'นำเข้าพนักงาน (Excel)', role: 'edit' },
    { to: '/master/employees', label: 'รายชื่อพนักงาน' },
    { to: '/master/courses', label: 'หลักสูตร' },
    { to: '/master/departments', label: 'ข้อมูลหลัก', match: '/master/' },
    { to: '/import', label: 'นำเข้าข้อมูลอื่น (Excel)', role: 'edit' },
  ] },
  { key: 'report', label: 'Report', prefixes: ['/reports', '/export'], items: [
    { to: '/reports/course', label: 'รายงานหลักสูตร' },
    { to: '/reports/employee', label: 'รายงานรายบุคคล' },
    { to: '/reports/department', label: 'รายงานฝ่าย' },
    { to: '/reports/center', label: 'รายงานอื่น ๆ', match: ['/reports/center', '/reports/monthly', '/reports/custom'] },
    { to: '/export', label: 'Export' },
  ] },
  { key: 'settings', label: 'Settings', prefixes: ['/system'], items: [
    { to: '/system/users', label: 'ผู้ใช้งาน (Users)', role: 'admin' },
    { to: '/system/roles', label: 'สิทธิ์ (Roles)' },
    { to: '/system/audit', label: 'Audit Log', role: 'admin' },
    { to: '/system/settings', label: 'ทั่วไป', role: 'admin' },
  ] },
]

export const sectionOf = (path) =>
  MENU.find((s) => s.prefixes.some((p) => path === p || path.startsWith(p + '/'))) || null

// which tab is active: exact page, its detail pages, or an explicit `match` prefix
export function tabActive(item, path, items) {
  const hit = (p) => path === p || path.startsWith(p + '/')
  if (hit(item.to)) return true
  const extra = [].concat(item.match || [])
  if (!extra.some((m) => (m.endsWith('/') ? path.startsWith(m) : hit(m)))) return false
  // a more specific tab wins (e.g. /master/employees over the generic /master/ match)
  return !items.some((i) => i !== item && hit(i.to))
}
