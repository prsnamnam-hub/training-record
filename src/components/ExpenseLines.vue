<template>
  <div class="tbl-wrap">
    <table class="tbl">
      <thead><tr><th style="min-width:200px">ประเภทค่าใช้จ่าย</th><th>รายละเอียด</th><th>มื้ออาหาร</th>
        <th class="num">จำนวน (Quantity)</th><th class="num">ราคา/หน่วย (Unit Price)</th><th class="num">รวม</th><th></th></tr></thead>
      <tbody>
        <tr v-if="!modelValue.length"><td colspan="7" class="empty">ยังไม่มีรายการ</td></tr>
        <tr v-for="(e, i) in modelValue" :key="i">
          <td><select v-model="e.expense_category_id" class="input">
            <option :value="null">- เลือก -</option>
            <option v-for="c in categories" :key="c.id" :value="c.id">{{ c.name }}{{ c.name_th ? ' — ' + c.name_th : '' }}</option></select></td>
          <td><input v-model="e.description" class="input" /></td>
          <td><select v-model="e.meal_type" class="input" :disabled="!isFood(e)"><option :value="null">-</option>
            <option v-for="m in MEAL_TYPES" :key="m" :value="m">{{ MEAL_TH[m] }}</option></select></td>
          <td><input v-model.number="e.quantity" type="number" min="0" step="1" class="input num" style="width:110px" /></td>
          <td><input v-model.number="e.unit_price" type="number" min="0" step="0.01" class="input num" style="width:140px" /></td>
          <td class="num">{{ money((+e.quantity || 0) * (+e.unit_price || 0)) }}</td>
          <td><button class="btn sm danger" @click="modelValue.splice(i, 1)">✕</button></td>
        </tr>
      </tbody>
      <tfoot><tr><td colspan="5" class="right">Total Cost</td><td class="num">{{ money(total) }}</td><td></td></tr></tfoot>
    </table>
  </div>
</template>
<script setup>
import { computed } from 'vue'
import { money } from '../lib/format'
import { MEAL_TYPES, MEAL_TH } from '../lib/constants'
const props = defineProps({ modelValue: { type: Array, required: true }, categories: { type: Array, default: () => [] } })
const isFood = (e) => props.categories.find((c) => c.id === e.expense_category_id)?.is_food
const total = computed(() => props.modelValue.reduce((a, e) => a + (+e.quantity || 0) * (+e.unit_price || 0), 0))
</script>
