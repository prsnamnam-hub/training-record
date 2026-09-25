<template>
  <div>
    <PageHeader title="Roles & Permissions" subtitle="สิทธิ์การใช้งานตาม Role — บังคับใช้ที่ฐานข้อมูลด้วย Row Level Security" crumb="Settings" />
    <div class="card">
      <div class="tbl-wrap"><table class="tbl">
        <thead><tr><th>สิทธิ์</th><th>ADMIN</th><th>HR / TRAINING</th><th>VIEWER</th></tr></thead>
        <tbody><tr v-for="p in perms" :key="p[0]"><td>{{ p[0] }}</td><td v-for="i in 3" :key="i">{{ p[i] ? '✅' : '—' }}</td></tr></tbody>
      </table></div>
      <p class="small muted mt">Role ของคุณ: <b>{{ ROLE_LABEL[role] }}</b> · ไม่มีผู้ใช้ใดลบข้อมูลการอบรมได้ (Soft delete + Audit Log) เพื่อป้องกันการสูญหายของ Historical Data</p>
    </div>
  </div>
</template>
<script setup>
import PageHeader from '../../components/PageHeader.vue'
import { role, ROLE_LABEL } from '../../lib/auth'
const perms = [
  ['View Dashboard / Report / Search', 1, 1, 1], ['Export Excel / CSV / PDF', 1, 1, 1], ['Create / Edit Training', 1, 1, 0], ['Manage Participant', 1, 1, 0],
  ['Manage Expense', 1, 1, 0], ['Manage Master Data', 1, 1, 0], ['Import Excel', 1, 1, 0], ['Manage Users / Roles', 1, 0, 0], ['View Audit Log', 1, 0, 0], ['System Settings', 1, 0, 0],
]
</script>
