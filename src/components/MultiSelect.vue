<template>
  <div class="ms" ref="root">
    <button type="button" class="ms-trigger" @click="open = !open" :title="summary">{{ summary }}</button>
    <div v-if="open" class="ms-pop">
      <input v-if="options.length > 8" v-model="q" class="input" placeholder="ค้นหา..." />
      <div class="ms-list">
        <label v-if="!multiple">
          <input type="radio" :checked="!modelValue || modelValue === ''" @change="pick(null)" /> ทั้งหมด
        </label>
        <label v-for="o in shown" :key="o.id">
          <input :type="multiple ? 'checkbox' : 'radio'" :checked="isOn(o.id)" @change="toggle(o.id)" />
          <span>{{ o.name }}</span>
        </label>
        <div v-if="!shown.length" class="muted small" style="padding:6px 8px">ไม่พบข้อมูล</div>
      </div>
      <div v-if="multiple" class="ms-actions">
        <a href="#" @click.prevent="$emit('update:modelValue', [])">ล้าง</a>
        <a href="#" @click.prevent="$emit('update:modelValue', shown.map((o) => o.id))">เลือกทั้งหมด</a>
        <a href="#" @click.prevent="open = false">ปิด</a>
      </div>
    </div>
  </div>
</template>
<script setup>
import { computed, onBeforeUnmount, onMounted, ref } from 'vue'
const props = defineProps({
  modelValue: [Array, Number, String],
  options: { type: Array, default: () => [] },
  multiple: { type: Boolean, default: true },
  placeholder: { type: String, default: 'ทั้งหมด' },
})
const emit = defineEmits(['update:modelValue'])
const open = ref(false)
const q = ref('')
const root = ref(null)
const shown = computed(() => {
  const s = q.value.trim().toLowerCase()
  return s ? props.options.filter((o) => String(o.name).toLowerCase().includes(s)) : props.options
})
const isOn = (id) => (props.multiple ? (props.modelValue || []).includes(id) : props.modelValue === id)
function toggle(id) {
  if (!props.multiple) return pick(id)
  const cur = [...(props.modelValue || [])]
  const i = cur.indexOf(id)
  i >= 0 ? cur.splice(i, 1) : cur.push(id)
  emit('update:modelValue', cur)
}
function pick(id) { emit('update:modelValue', id); open.value = false }
const summary = computed(() => {
  if (!props.multiple) {
    const o = props.options.find((x) => x.id === props.modelValue)
    return o ? o.name : props.placeholder
  }
  const v = props.modelValue || []
  if (!v.length) return props.placeholder
  if (v.length === 1) return props.options.find((x) => x.id === v[0])?.name || '1 รายการ'
  return `เลือก ${v.length} รายการ`
})
const onDoc = (e) => { if (root.value && !root.value.contains(e.target)) open.value = false }
onMounted(() => document.addEventListener('mousedown', onDoc))
onBeforeUnmount(() => document.removeEventListener('mousedown', onDoc))
</script>
