<template>
  <div>
    <div class="tbl-wrap" :style="maxHeight ? { maxHeight, overflowY: 'auto' } : null">
      <table class="tbl">
        <thead>
          <tr>
            <th v-for="c in columns" :key="c.key" :class="[c.class, { sortable: c.sortable !== false && sortable, num: isNum(c) }]"
                @click="c.sortable !== false && sortable && sortBy(c)">
              {{ c.label }}<span v-if="sortKey === c.key">{{ sortAsc ? ' ▲' : ' ▼' }}</span>
            </th>
            <th v-if="$slots.actions" class="no-print"></th>
          </tr>
        </thead>
        <tbody>
          <tr v-if="loading"><td :colspan="columns.length + 1"><div class="loading-block"><span class="spinner"></span> กำลังโหลด...</div></td></tr>
          <tr v-else-if="!pageRows.length"><td :colspan="columns.length + 1"><div class="empty">{{ emptyText }}</div></td></tr>
          <template v-else>
            <tr v-for="(r, i) in pageRows" :key="r[rowKey] ?? i" :class="{ clickable: !!$attrs.onRowClick }" @click="$emit('row-click', r)">
              <td v-for="c in columns" :key="c.key" :class="[c.class, { num: isNum(c) }]">
                <slot :name="'cell-' + c.key" :row="r" :value="r[c.key]">{{ display(r, c) }}</slot>
              </td>
              <td v-if="$slots.actions" class="no-print nowrap" @click.stop><slot name="actions" :row="r" /></td>
            </tr>
          </template>
        </tbody>
        <tfoot v-if="$slots.foot"><slot name="foot" /></tfoot>
      </table>
    </div>
    <div v-if="showPager" class="pager no-print">
      <span>ทั้งหมด {{ num(totalCount) }} รายการ</span>
      <select class="input" style="width:auto" :value="size" @change="$emit('update:size', +$event.target.value); goto(1)">
        <option v-for="s in [25, 50, 100, 200]" :key="s" :value="s">{{ s }} / หน้า</option>
      </select>
      <button class="btn sm" :disabled="curPage <= 1" @click="goto(curPage - 1)">‹</button>
      <span>หน้า {{ curPage }} / {{ pages }}</span>
      <button class="btn sm" :disabled="curPage >= pages" @click="goto(curPage + 1)">›</button>
    </div>
  </div>
</template>
<script setup>
import { computed, ref, watch } from 'vue'
import { num, money, dateTH, pct } from '../lib/format'

const props = defineProps({
  columns: { type: Array, required: true },
  rows: { type: Array, default: () => [] },
  loading: Boolean,
  rowKey: { type: String, default: 'id' },
  // server mode: pass total + page and listen to update:page / sort
  total: { type: Number, default: null },
  page: { type: Number, default: 1 },
  size: { type: Number, default: 50 },
  sortable: { type: Boolean, default: true },
  paginate: { type: Boolean, default: true },
  maxHeight: String,
  emptyText: { type: String, default: 'ไม่พบข้อมูล' },
})
const emit = defineEmits(['update:page', 'update:size', 'sort', 'row-click'])
const server = computed(() => props.total !== null)
const sortKey = ref(null)
const sortAsc = ref(true)
const localPage = ref(1)
watch(() => props.rows, () => { if (!server.value) localPage.value = 1 })

const isNum = (c) => ['number', 'money', 'percent'].includes(c.type)
function display(r, c) {
  const v = c.format ? c.format(r) : r[c.key]
  if (c.format) return v
  if (c.type === 'money') return money(v)
  if (c.type === 'number') return num(v, c.digits || 0)
  if (c.type === 'percent') return pct(v, c.digits ?? 1)
  if (c.type === 'date') return dateTH(v)
  return v ?? '-'
}
function sortBy(c) {
  if (sortKey.value === c.key) sortAsc.value = !sortAsc.value
  else { sortKey.value = c.key; sortAsc.value = !isNum(c) }
  if (server.value) emit('sort', { key: c.sortKey || c.key, asc: sortAsc.value })
}
const sorted = computed(() => {
  if (server.value || !sortKey.value) return props.rows
  const c = props.columns.find((x) => x.key === sortKey.value)
  const val = (r) => (c?.sortValue ? c.sortValue(r) : r[sortKey.value])
  return [...props.rows].sort((a, b) => {
    const x = val(a), y = val(b)
    if (x === y) return 0
    if (x === null || x === undefined) return 1
    if (y === null || y === undefined) return -1
    const cmp = typeof x === 'number' && typeof y === 'number' ? x - y : String(x).localeCompare(String(y), 'th', { numeric: true })
    return sortAsc.value ? cmp : -cmp
  })
})
const totalCount = computed(() => (server.value ? props.total : props.rows.length))
const curPage = computed(() => (server.value ? props.page : localPage.value))
const pages = computed(() => Math.max(1, Math.ceil(totalCount.value / props.size)))
const showPager = computed(() => props.paginate && totalCount.value > Math.min(props.size, 25))
const pageRows = computed(() => {
  if (server.value || !props.paginate) return sorted.value
  const from = (localPage.value - 1) * props.size
  return sorted.value.slice(from, from + props.size)
})
function goto(p) {
  p = Math.min(Math.max(1, p), pages.value)
  if (server.value) emit('update:page', p)
  else localPage.value = p
}
</script>
