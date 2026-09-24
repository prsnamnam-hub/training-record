<template>
  <div class="row no-print">
    <button class="btn sm" :disabled="busy" @click="run('excel')">⬇ Excel</button>
    <button class="btn sm" :disabled="busy" @click="run('csv')">⬇ CSV</button>
    <button v-if="pdf" class="btn sm" :disabled="busy" @click="run('pdf')">⬇ PDF</button>
    <span v-if="busy" class="spinner" style="width:16px;height:16px;border-width:2px"></span>
  </div>
</template>
<script setup>
import { ref } from 'vue'
import { toastError } from '../lib/toast'
const props = defineProps({ handler: Function, pdf: { type: Boolean, default: true } })
const busy = ref(false)
async function run(kind) {
  busy.value = true
  try { await props.handler(kind) } catch (e) { toastError(e) } finally { busy.value = false }
}
</script>
