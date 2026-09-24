<template>
  <div class="page-head">
    <div class="titles">
      <div v-if="crumb" class="small muted">{{ crumb }}</div>
      <h1>{{ title }}</h1>
      <p v-if="subtitle">{{ subtitle }}</p>
    </div>
    <div class="actions no-print"><slot /></div>
  </div>
</template>
<script setup>
defineProps({ title: String, subtitle: String, crumb: String })
</script>
