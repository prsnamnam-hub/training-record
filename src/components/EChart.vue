<template><div ref="el" class="chart" :class="{ tall }" :style="height ? { height } : null"></div></template>
<script setup>
import { onMounted, onBeforeUnmount, ref, watch, shallowRef } from 'vue'
const props = defineProps({ option: Object, tall: Boolean, height: String })
const el = ref(null)
const chart = shallowRef(null)
let ro
// validated categorical order (dataviz reference palette, light mode) — fixed order, never cycled
const PALETTE = ['#2a78d6', '#eb6834', '#1baf7a', '#eda100', '#e87ba4', '#008300', '#4a3aa7', '#e34948']
async function render() {
  if (!el.value || !props.option) return
  const echarts = await import('echarts')
  if (!chart.value) chart.value = echarts.init(el.value, null, { renderer: 'canvas' })
  chart.value.setOption({
    color: PALETTE,
    textStyle: { fontFamily: "'IBM Plex Sans Thai', Inter, sans-serif", color: '#4b5768' },
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
