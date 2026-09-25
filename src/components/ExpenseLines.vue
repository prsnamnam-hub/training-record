<template>
  <div class="tbl-wrap">
    <table class="tbl">
      <thead><tr><th style="min-width:220px">ประเภทค่าใช้จ่าย</th><th class="num">จำนวน</th><th class="num">ราคา/หน่วย</th><th class="num">รวม</th><th></th></tr></thead>
      <tbody>
        <tr v-if="!modelValue.length"><td colspan="5" class="empty">ยังไม่มีรายการ</td></tr>
        <tr v-for="(e, i) in modelValue" :key="i">
          <td><select v-model="e.expense_category_id" class="input">
            <option :value="null">- เลือก -</option>
            <option v-for="c in categories" :key="c.id" :value="c.id">{{ c.name_th || c.name }}</option></select></td>
          <td class="num"><input v-model.number="e.quantity" type="number" min="0" step="1" class="input num" style="width:100px" /></td>
          <td class="num"><input v-model.number="e.unit_price" type="number" min="0" step="0.01" class="input num" style="width:140px" /></td>
          <td class="num" style="vertical-align:middle;font-weight:600">{{ money((+e.quantity || 0) * (+e.unit_price || 0)) }}</td>
          <td style="width:1%"><button class="btn sm ghost danger" title="ลบรายการ" @click="modelValue.splice(i, 1)">✕</button></td>
        </tr>
      </tbody>
      <tfoot><tr><td colspan="3" class="right">รวมทั้งหมด</td><td class="num">{{ money(total) }}</td><td></td></tr></tfoot>
    </table>
  </div>
</template>
<script setup>
import { computed } from 'vue'
import { money } from '../lib/format'
const props = defineProps({ modelValue: { type: Array, required: true }, categories: { type: Array, default: () => [] } })
const total = computed(() => props.modelValue.reduce((a, e) => a + (+e.quantity || 0) * (+e.unit_price || 0), 0))
</script>
