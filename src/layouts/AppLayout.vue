<template>
  <div class="shell">
    <aside class="sidebar" :class="{ open: menuOpen }" @click="menuOpen = false">
      <div class="brand">
        <img class="logo" :src="logo" alt="ASSET WISE" />
        <small>Training Record</small>
      </div>
      <nav class="nav">
        <RouterLink v-for="s in sections" :key="s.key" :to="s.items[0].to" :class="{ on: current?.key === s.key }">{{ s.label }}</RouterLink>
      </nav>
      <div class="sidebar-foot">{{ APP_NAME }}</div>
    </aside>
    <div class="sidebar-back" :class="{ open: menuOpen }" @click="menuOpen = false"></div>
    <div class="main">
      <header class="topbar no-print">
        <button class="btn ghost menu-btn" aria-label="เมนู" @click.stop="menuOpen = !menuOpen">☰</button>
        <form class="search" @submit.prevent="goSearch">
          <input v-model="q" placeholder="ค้นหา รหัสพนักงาน / ชื่อ / หลักสูตร / ฝ่าย / Training ID / Provider" />
        </form>
        <div class="spacer"></div>
        <div class="user-chip">
          <div class="avatar">{{ initials }}</div>
          <div class="name"><div>{{ auth.profile?.full_name || auth.profile?.email }}</div>
            <div class="small muted">{{ ROLE_LABEL[role] }}</div></div>
          <button class="btn sm ghost" @click="logout">ออกจากระบบ</button>
        </div>
      </header>
      <main class="content">
        <div v-if="role === 'none'" class="alert warn mb">
          บัญชีของคุณยังไม่ได้รับสิทธิ์ใช้งาน หรือถูกปิดใช้งาน — กรุณาติดต่อผู้ดูแลระบบ (Admin) เพื่อกำหนด Role
        </div>
        <nav v-if="subItems.length > 1" class="subnav no-print">
          <RouterLink v-for="i in subItems" :key="i.to" :to="i.to" :class="{ on: $route.path === i.to || $route.path.startsWith(i.to + '/') }">{{ i.label }}</RouterLink>
        </nav>
        <RouterView :key="$route.fullPath" />
      </main>
      <footer class="footer no-print">© {{ new Date().getFullYear() }} {{ APP_NAME }} — {{ APP_TAGLINE }}</footer>
    </div>
  </div>
</template>
<script setup>
import { computed, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { APP_NAME, APP_TAGLINE } from '../lib/config'
import { auth, role, ROLE_LABEL, signOut, canEdit, isAdmin } from '../lib/auth'
import { MENU, sectionOf } from '../lib/menu'

const logo = import.meta.env.BASE_URL + 'logo-assetwise.png'
const route = useRoute()
const router = useRouter()
const q = ref('')
const menuOpen = ref(false)
const initials = computed(() => (auth.profile?.full_name || auth.profile?.email || '?').slice(0, 1).toUpperCase())
const allowed = (r) => (r === 'edit' ? canEdit.value : r === 'admin' ? isAdmin.value : true)
// sidebar = categories the user can open; tabs = that category's pages
const sections = computed(() => MENU.map((s) => ({ ...s, items: s.items.filter((i) => !i.role || allowed(i.role)) })).filter((s) => s.items.length))
const current = computed(() => { const s = sectionOf(route.path); return s && sections.value.find((x) => x.key === s.key) })
const subItems = computed(() => current.value?.items || [])
function goSearch() { if (q.value.trim()) router.push({ path: '/search', query: { q: q.value.trim() } }) }
async function logout() { await signOut(); router.replace('/login') }
</script>
