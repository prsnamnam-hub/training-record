<template>
  <div class="toast-stack">
    <div v-for="t in toasts" :key="t.id" class="toast" :class="t.type">{{ t.message }}</div>
  </div>
</template>
<script setup>
import { toasts } from '../lib/toast'
</script>
