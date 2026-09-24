<template><div ref="el" class="chart" :class="{ tall }" :style="height ? { height } : null"></div></template>
<script setup>
import { onMounted, onBeforeUnmount, ref, watch, shallowRef } from 'vue'
const props = defineProps({ option: Object, tall: Boolean, height: String })
const el = ref(null)
const chart = shallowRef(null)
let ro
const PALETTE = ['#0f4c81', '#f5b400', '#2a9d8f', '#e76f51', '#8e6cc9', '#6c8ead', '#d4a373', '#52b788', '#bc4749', '#577590']
async function render() {
  if (!el.value || !props.option) return
  const echarts = await import('echarts')
  if (!chart.value) chart.value = echarts.init(el.value, null, { renderer: 'canvas' })
  chart.value.setOption({
    color: PALETTE,
    textStyle: { fontFamily: 'Sarabun, sans-serif' },
    grid: { left: 8, right: 16, top: 36, bottom: 8, containLabel: true },
    tooltip: { trigger: 'axis', confine: true },
    ...props.option,
  }, true)
}
onMounted(() => {
  render()
  ro = new ResizeObserver(() => chart.value?.resize())
  ro.observe(el.value)
})
watch(() => props.option, render, { deep: true })
onBeforeUnmount(() => { ro?.disconnect(); chart.value?.dispose() })
</script>
