<template>
  <div>
    <div class="grid g4 mb">
      <KpiCard label="Total Cost" :value="money(total)" unit="บาท" color="var(--c4)" />
      <KpiCard label="Cost / Participant" :value="participants ? money(total / participants) : '-'" unit="บาท" :sub="`${participants} คน`" />
      <KpiCard label="Cost / Training Hour" :value="hours ? money(total / hours) : '-'" unit="บาท" :sub="hours ? `${hours} ชม.` : 'ยังไม่ระบุชั่วโมง'" />
      <KpiCard label="Budget vs Actual" :value="budget ? money(budget - total) : '-'" unit="บาท"
        :sub="budget ? `Budget ${money(budget)} · ใช้ไป ${((total / budget) * 100).toFixed(1)}%` : 'ยังไม่ตั้งงบประมาณ'"
        :color="budget && total > budget ? 'var(--danger)' : 'var(--ok)'" />
    </div>
    <div class="row mb no-print" v-if="canEdit">
      <button class="btn sm primary" @click="draft.push({ expense_category_id: null, description: '', meal_type: null, quantity: 1, unit_price: 0 })">+ เพิ่มรายการค่าใช้จ่าย</button>
      <button class="btn sm" @click="addFood">+ ค่าอาหาร (ตามจำนวนผู้เข้าอบรม)</button>
      <button v-if="draft.length" class="btn sm primary" :disabled="saving" @click="saveDraft">บันทึก {{ draft.length }} รายการ</button>
    </div>
    <ExpenseLines v-if="draft.length" v-model="draft" :categories="cats" class="mb" />
    <DataTable :columns="cols" :rows="rows" :loading="loading" :paginate="false">
      <template #cell-meal_type="{ row }">{{ row.meal_type ? MEAL_TH[row.meal_type] : '-' }}</template>
      <template v-if="canEdit" #actions="{ row }">
        <button class="btn sm" @click="edit(row)">แก้ไข</button>
        <button class="btn sm danger" @click="remove(row)">ลบ</button>
      </template>
      <template #foot><tr><td colspan="6" class="right">รวม</td><td class="num">{{ money(total) }}</td><td></td><td v-if="canEdit"></td></tr></template>
    </DataTable>
    <div v-if="groups.length" class="mt small">
      <b>สรุปตามประเภท:</b> <span v-for="g in groups" :key="g.k" class="badge" style="margin:2px">{{ g.k }} {{ money(g.v) }}</span>
    </div>

    <Modal :open="!!editing" title="แก้ไขค่าใช้จ่าย" @close="editing = null">
      <div v-if="editing" class="form-grid">
        <div class="field"><label>ประเภท</label><select v-model="editing.expense_category_id" class="input"><option v-for="c in cats" :key="c.id" :value="c.id">{{ c.name }}</option></select></div>
        <div class="field"><label>รายละเอียด</label><input v-model="editing.description" class="input" /></div>
        <div class="field"><label>มื้ออาหาร</label><select v-model="editing.meal_type" class="input"><option :value="null">-</option><option v-for="m in MEAL_TYPES" :key="m" :value="m">{{ MEAL_TH[m] }}</option></select></div>
        <div class="field"><label>จำนวน</label><input v-model.number="editing.quantity" type="number" min="0" class="input" /></div>
        <div class="field"><label>ราคา/หน่วย</label><input v-model.number="editing.unit_price" type="number" min="0" step="0.01" class="input" /></div>
        <div class="field"><label>วันที่จ่าย</label><input v-model="editing.expense_date" type="date" class="input" /></div>
        <div class="field"><label>ผู้ขาย / Vendor</label><input v-model="editing.vendor" class="input" /></div>
        <div class="field"><label>เลขที่ใบแจ้งหนี้</label><input v-model="editing.invoice_no" class="input" /></div>
        <div class="field wide"><label>หมายเหตุ</label><input v-model="editing.remark" class="input" /></div>
        <div class="wide"><b>รวม {{ money((editing.quantity || 0) * (editing.unit_price || 0)) }} บาท</b></div>
      </div>
      <template #footer><button class="btn" @click="editing = null">ยกเลิก</button><button class="btn primary" @click="saveEdit">บันทึก</button></template>
    </Modal>
  </div>
</template>
<script setup>
import { computed, onMounted, ref } from 'vue'
import DataTable from './DataTable.vue'
import KpiCard from './KpiCard.vue'
import Modal from './Modal.vue'
import ExpenseLines from './ExpenseLines.vue'
import { supabase, must } from '../lib/supabase'
import { canEdit } from '../lib/auth'
import { filterOptions } from '../lib/api'
import { money } from '../lib/format'
import { MEAL_TYPES, MEAL_TH } from '../lib/constants'
import { toastOk, toastError } from '../lib/toast'

const props = defineProps({ sessionId: { type: [Number, String], required: true }, session: Object })
const emit = defineEmits(['changed'])
const rows = ref([]); const loading = ref(false); const cats = ref([]); const draft = ref([]); const saving = ref(false); const editing = ref(null)
const cols = [
  { key: 'category', label: 'ประเภท' }, { key: 'description', label: 'รายละเอียด' }, { key: 'meal_type', label: 'มื้อ' },
  { key: 'quantity', label: 'จำนวน', type: 'number', digits: 0 }, { key: 'unit_price', label: 'ราคา/หน่วย', type: 'money' },
  { key: 'expense_date', label: 'วันที่', type: 'date' }, { key: 'amount', label: 'รวม', type: 'money' }, { key: 'vendor', label: 'Vendor' },
]
const participants = computed(() => props.session?.participant_count || 0)
const hours = computed(() => Number(props.session?.training_hours || 0))
const budget = computed(() => Number(props.session?.budget_amount || 0))
const total = computed(() => rows.value.reduce((a, r) => a + Number(r.amount || 0), 0))
const groups = computed(() => {
  const m = {}
  rows.value.forEach((r) => { m[r.cost_group] = (m[r.cost_group] || 0) + Number(r.amount) })
  return Object.entries(m).map(([k, v]) => ({ k, v }))
})
async function load() {
  loading.value = true
  try {
    const data = await must(supabase.from('training_expenses').select('*, expense_categories(name, name_th, cost_group)')
      .eq('session_id', props.sessionId).is('deleted_at', null).order('id'))
    rows.value = data.map((r) => ({ ...r, category: r.expense_categories?.name + (r.expense_categories?.name_th ? ` (${r.expense_categories.name_th})` : ''), cost_group: r.expense_categories?.cost_group }))
  } finally { loading.value = false }
}
function addFood() {
  const food = cats.value.find((c) => c.name === 'Food')
  draft.value.push({ expense_category_id: food?.id || null, description: 'ค่าอาหาร', meal_type: 'Lunch', quantity: participants.value || 1, unit_price: 0 })
}
async function saveDraft() {
  if (draft.value.some((d) => !d.expense_category_id)) return toastError(new Error('กรุณาเลือกประเภทค่าใช้จ่ายให้ครบ'))
  if (draft.value.some((d) => d.quantity < 0 || d.unit_price < 0)) return toastError(new Error('จำนวนเงินต้องไม่ติดลบ'))
  saving.value = true
  try {
    await must(supabase.from('training_expenses').insert(draft.value.map((d) => ({ ...d, session_id: Number(props.sessionId), data_source: 'System Entry' }))))
    toastOk('บันทึกค่าใช้จ่ายเรียบร้อย'); draft.value = []; await load(); emit('changed')
  } catch (e) { toastError(e) } finally { saving.value = false }
}
const edit = (r) => { editing.value = { ...r } }
async function saveEdit() {
  const e = editing.value
  try {
    await must(supabase.from('training_expenses').update({ expense_category_id: e.expense_category_id, description: e.description, meal_type: e.meal_type,
      quantity: e.quantity, unit_price: e.unit_price, expense_date: e.expense_date || null, vendor: e.vendor, invoice_no: e.invoice_no, remark: e.remark }).eq('id', e.id))
    editing.value = null; toastOk('บันทึกแล้ว'); await load(); emit('changed')
  } catch (err) { toastError(err) }
}
async function remove(r) {
  if (!confirm('ลบรายการค่าใช้จ่ายนี้? (Soft delete — ตรวจสอบย้อนหลังได้ใน Audit Log)')) return
  try { await must(supabase.from('training_expenses').update({ deleted_at: new Date().toISOString() }).eq('id', r.id)); await load(); emit('changed') }
  catch (e) { toastError(e) }
}
onMounted(async () => { cats.value = (await filterOptions()).expense_categories; load() })
</script>
