<template>
  <Teleport to="body">
    <div v-if="open" class="modal-back" @mousedown.self="$emit('close')">
      <div class="modal" :class="{ wide }">
        <header><h3>{{ title }}</h3><button class="btn ghost" @click="$emit('close')">✕</button></header>
        <div class="body"><slot /></div>
        <footer v-if="$slots.footer"><slot name="footer" /></footer>
      </div>
    </div>
  </Teleport>
</template>
<script setup>
defineProps({ open: Boolean, title: String, wide: Boolean })
defineEmits(['close'])
</script>
