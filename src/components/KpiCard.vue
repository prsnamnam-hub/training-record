<template>
  <div class="kpi" :style="color ? { '--kpi-color': color } : null">
    <div class="label">{{ label }}</div>
    <div class="value">{{ value }}<small v-if="unit">{{ unit }}</small></div>
    <div v-if="sub || delta !== undefined" class="sub">
      <span v-if="delta !== undefined && delta !== null" :class="delta >= 0 ? 'delta-up' : 'delta-down'">
        {{ delta >= 0 ? '▲' : '▼' }} {{ Math.abs(delta).toFixed(1) }}%
      </span>
      {{ sub }}
    </div>
  </div>
</template>
<script setup>
defineProps({ label: String, value: [String, Number], unit: String, sub: String, delta: Number, color: String })
</script>
