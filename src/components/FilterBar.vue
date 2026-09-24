<template>
  <div class="filterbar">
    <div v-for="f in fields" :key="f" class="field">
      <label>{{ DEF[f].label }}</label>
      <template v-if="f === 'date_from' || f === 'date_to'">
        <input type="date" class="input" :value="modelValue[f] || ''" @input="set(f, $event.target.value || null)" />
      </template>
      <MultiSelect v-else :model-value="modelValue[DEF[f].key] || []" :options="opts(f)"
                   @update:model-value="set(DEF[f].key, $event)" />
    </div>
    <div class="field" style="flex:0 0 auto; min-width:0">
      <label>&nbsp;</label>
      <button class="btn sm" @click="reset">ล้างตัวกรอง</button>
    </div>
  </div>
</template>
<script setup>
import { onMounted, ref } from 'vue'
import MultiSelect from './MultiSelect.vue'
import { filterOptions } from '../lib/api'
import { TH_MONTHS } from '../lib/format'

const props = defineProps({
  modelValue: { type: Object, required: true },
  fields: { type: Array, default: () => ['years', 'months', 'departments', 'training_types', 'categories', 'courses'] },
})
const emit = defineEmits(['update:modelValue'])
const o = ref(null)
const DEF = {
  years: { label: 'ปี (พ.ศ.)', key: 'years' },
  months: { label: 'เดือน', key: 'months' },
  date_from: { label: 'ตั้งแต่วันที่', key: 'date_from' },
  date_to: { label: 'ถึงวันที่', key: 'date_to' },
  companies: { label: 'บริษัท', key: 'company_ids' },
  business_groups: { label: 'กลุ่มธุรกิจ', key: 'business_group_ids' },
  departments: { label: 'ฝ่าย (Department)', key: 'department_ids' },
  sections: { label: 'Section', key: 'section_ids' },
  level_groups: { label: 'กลุ่มระดับพนักงาน', key: 'level_group_ids' },
  training_types: { label: 'ประเภท (Training Type)', key: 'training_type_ids' },
  categories: { label: 'หมวดหมู่ (Category)', key: 'category_ids' },
  courses: { label: 'หลักสูตร (Course)', key: 'course_ids' },
  providers: { label: 'ผู้จัด (Provider)', key: 'provider_ids' },
  trainers: { label: 'วิทยากร (Trainer)', key: 'trainer_ids' },
  expense_categories: { label: 'ประเภทค่าใช้จ่าย', key: 'expense_category_ids' },
}
function opts(f) {
  if (!o.value) return []
  if (f === 'years') return (o.value.years || []).map((y) => ({ id: y, name: String(y + 543) }))
  if (f === 'months') return TH_MONTHS.map((m, i) => ({ id: i + 1, name: m }))
  const src = { companies: 'companies', business_groups: 'business_groups', departments: 'departments', sections: 'sections',
    level_groups: 'level_groups', training_types: 'training_types', categories: 'categories', courses: 'courses',
    providers: 'providers', trainers: 'trainers', expense_categories: 'expense_categories' }[f]
  return (o.value[src] || []).map((x) => ({ id: x.id, name: x.name_th ? `${x.name} — ${x.name_th}` : x.name }))
}
function set(k, v) { emit('update:modelValue', { ...props.modelValue, [k]: v }) }
function reset() {
  const keep = {}
  emit('update:modelValue', keep)
}
onMounted(async () => { o.value = await filterOptions() })
</script>
