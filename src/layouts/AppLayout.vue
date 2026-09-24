<template>
  <div class="shell">
    <aside class="sidebar" :class="{ open: menuOpen }" @click="menuOpen = false">
      <div class="brand">
        <img :src="logo" alt="" />
        <div><b>{{ APP_NAME }}</b><small>Training Management &amp; Analytics</small></div>
      </div>
      <nav class="nav">
        <template v-for="g in menu" :key="g.title">
          <div v-if="g.title" class="grp">{{ g.title }}</div>
          <template v-for="i in g.items" :key="i.to">
            <RouterLink v-if="!i.role || allowed(i.role)" :to="i.to"><span class="ico">{{ i.icon }}</span>{{ i.label }}</RouterLink>
          </template>
        </template>
      </nav>
    </aside>
    <div class="main">
      <header class="topbar no-print">
        <button class="btn ghost menu-btn" @click.stop="menuOpen = !menuOpen">☰</button>
        <form class="search" @submit.prevent="goSearch">
          <input v-model="q" placeholder="ค้นหา รหัสพนักงาน / ชื่อ / หลักสูตร / ฝ่าย / Training ID / Provider" />
        </form>
        <div class="spacer"></div>
        <div class="user-chip">
          <div class="avatar">{{ initials }}</div>
          <div class="name"><div>{{ auth.profile?.full_name || auth.profile?.email }}</div>
            <div class="small muted">{{ ROLE_LABEL[role] }}</div></div>
          <button class="btn sm" @click="logout">ออกจากระบบ</button>
        </div>
      </header>
      <main class="content">
        <div v-if="role === 'none'" class="alert warn mb">
          บัญชีของคุณยังไม่ได้รับสิทธิ์ใช้งาน หรือถูกปิดใช้งาน — กรุณาติดต่อผู้ดูแลระบบ (Admin) เพื่อกำหนด Role
        </div>
        <RouterView :key="$route.fullPath" />
      </main>
      <footer class="footer no-print">© {{ new Date().getFullYear() }} {{ APP_NAME }} — {{ APP_TAGLINE }}</footer>
    </div>
  </div>
</template>
<script setup>
import { computed, ref } from 'vue'
import { useRouter } from 'vue-router'
import { APP_NAME, APP_TAGLINE } from '../lib/config'
import { auth, role, ROLE_LABEL, signOut, canEdit, isAdmin } from '../lib/auth'

const logo = import.meta.env.BASE_URL + 'favicon.svg'
const router = useRouter()
const q = ref('')
const menuOpen = ref(false)
const initials = computed(() => (auth.profile?.full_name || auth.profile?.email || '?').slice(0, 1).toUpperCase())
const allowed = (r) => (r === 'edit' ? canEdit.value : r === 'admin' ? isAdmin.value : true)
const menu = [
  { title: '', items: [{ to: '/dashboard', label: 'Dashboard', icon: '▦' }] },
  { title: 'Training', items: [
    { to: '/training/records', label: 'Training Record', icon: '☰' },
    { to: '/training/sessions', label: 'Training Session', icon: '◷' },
    { to: '/training/participants', label: 'Participants', icon: '👥' },
    { to: '/training/calendar', label: 'Training Calendar', icon: '📅' },
  ] },
  { title: 'Master Data', items: [
    { to: '/master/employees', label: 'Employee', icon: '👤' },
    { to: '/master/courses', label: 'Course', icon: '📘' },
    { to: '/master/categories', label: 'Category', icon: '🏷' },
    { to: '/master/training-types', label: 'Training Type', icon: '◈' },
    { to: '/master/trainers', label: 'Trainer', icon: '🎤' },
    { to: '/master/providers', label: 'Provider', icon: '🏢' },
    { to: '/master/departments', label: 'Department', icon: '🗂' },
    { to: '/master/sections', label: 'Section', icon: '▤' },
    { to: '/master/companies', label: 'Company', icon: '🏛' },
    { to: '/master/expense-categories', label: 'Expense Category', icon: '💳' },
    { to: '/master/budgets', label: 'Training Budget', icon: '💰' },
  ] },
  { title: 'Expense', items: [
    { to: '/expense/all', label: 'Training Expense', icon: '฿' },
    { to: '/expense/food', label: 'Food Expense', icon: '🍱' },
    { to: '/expense/other', label: 'Other Expense', icon: '🧾' },
  ] },
  { title: 'Reports', items: [
    { to: '/reports/center', label: 'Report Center', icon: '📊' },
    { to: '/reports/employee', label: 'Employee Report', icon: '🧑‍💼' },
    { to: '/reports/monthly', label: 'Monthly Management', icon: '🗓' },
    { to: '/reports/custom', label: 'Custom Report', icon: '⚙' },
  ] },
  { title: 'Import / Export', items: [
    { to: '/import', label: 'Import Excel', icon: '⬆', role: 'edit' },
    { to: '/export', label: 'Export Report', icon: '⬇' },
  ] },
  { title: 'System', items: [
    { to: '/system/users', label: 'Users', icon: '🔑', role: 'admin' },
    { to: '/system/roles', label: 'Roles', icon: '🛡' },
    { to: '/system/audit', label: 'Audit Log', icon: '📜', role: 'admin' },
    { to: '/system/settings', label: 'Settings', icon: '⚙', role: 'admin' },
  ] },
]
function goSearch() { if (q.value.trim()) router.push({ path: '/search', query: { q: q.value.trim() } }) }
async function logout() { await signOut(); router.replace('/login') }
</script>
