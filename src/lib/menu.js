// Main menu: a few top-level categories in the sidebar; each category's pages are shown as
// tabs above the page content (AppLayout). `prefixes` decide which category a route belongs to
// (so detail pages such as /training/sessions/12 keep their category highlighted).
// role: 'edit' = Admin / HR-Training, 'admin' = Admin only.
export const MENU = [
  { key: 'dashboard', label: 'Dashboard', prefixes: ['/dashboard', '/search'], items: [
    { to: '/dashboard', label: 'Dashboard' },
  ] },
  { key: 'training', label: 'Training', prefixes: ['/training'], items: [
    { to: '/training/records', label: 'Training Record' },
    { to: '/training/sessions', label: 'Training Session' },
    { to: '/training/participants', label: 'Participants' },
    { to: '/training/calendar', label: 'Calendar' },
  ] },
  { key: 'expense', label: 'Expense', prefixes: ['/expense'], items: [
    { to: '/expense/all', label: 'Training Expense' },
    { to: '/expense/food', label: 'Food Expense' },
    { to: '/expense/other', label: 'Other Expense' },
  ] },
  { key: 'reports', label: 'Reports', prefixes: ['/reports', '/export'], items: [
    { to: '/reports/center', label: 'Report Center' },
    { to: '/reports/monthly', label: 'Monthly Management' },
    { to: '/reports/employee', label: 'Employee Report' },
    { to: '/reports/custom', label: 'Custom Report' },
    { to: '/export', label: 'Export' },
  ] },
  { key: 'master', label: 'Master Data', prefixes: ['/master', '/import'], items: [
    { to: '/master/employees', label: 'Employee' },
    { to: '/master/courses', label: 'Course' },
    { to: '/master/categories', label: 'Category' },
    { to: '/master/training-types', label: 'Training Type' },
    { to: '/master/trainers', label: 'Trainer' },
    { to: '/master/providers', label: 'Provider' },
    { to: '/master/departments', label: 'Department' },
    { to: '/master/sections', label: 'Section' },
    { to: '/master/companies', label: 'Company' },
    { to: '/master/expense-categories', label: 'Expense Category' },
    { to: '/master/budgets', label: 'Budget' },
    { to: '/import', label: 'Import Excel', role: 'edit' },
  ] },
  { key: 'system', label: 'Settings', prefixes: ['/system'], items: [
    { to: '/system/users', label: 'Users', role: 'admin' },
    { to: '/system/roles', label: 'Roles' },
    { to: '/system/audit', label: 'Audit Log', role: 'admin' },
    { to: '/system/settings', label: 'General', role: 'admin' },
  ] },
]

export const sectionOf = (path) =>
  MENU.find((s) => s.prefixes.some((p) => path === p || path.startsWith(p + '/'))) || null
