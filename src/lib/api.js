// Data-access layer. Every screen goes through here so Dashboard, Reports and lists
// share one filter model (same keys as public.fact_filtered in the database).
import { supabase, must } from './supabase'

export const FILTER_KEYS = [
  'years', 'months', 'company_ids', 'department_ids', 'business_group_ids', 'section_ids', 'level_group_ids',
  'training_type_ids', 'category_ids', 'course_ids', 'provider_ids', 'trainer_ids', 'employee_ids', 'session_ids',
]

export function cleanFilters(f = {}) {
  const out = {}
  for (const k of FILTER_KEYS) if (Array.isArray(f[k]) && f[k].length) out[k] = f[k].map(Number)
  if (f.date_from) out.date_from = f.date_from
  if (f.date_to) out.date_to = f.date_to
  return out
}

const FACT_COLS = {
  years: 'year', months: 'month', company_ids: 'company_id', department_ids: 'department_id',
  business_group_ids: 'business_group_id', section_ids: 'section_id', level_group_ids: 'level_group_id',
  training_type_ids: 'training_type_id', category_ids: 'category_id', course_ids: 'course_id',
  provider_ids: 'provider_id', trainer_ids: 'trainer_id', employee_ids: 'employee_id', session_ids: 'session_id',
}

export function applyFactFilters(q, f) {
  const c = cleanFilters(f)
  for (const [k, col] of Object.entries(FACT_COLS)) if (c[k]) q = q.in(col, c[k])
  if (c.date_from) q = q.gte('start_date', c.date_from)
  if (c.date_to) q = q.lte('start_date', c.date_to)
  return q
}

let _options = null
export async function filterOptions(force = false) {
  if (_options && !force) return _options
  _options = await must(supabase.rpc('rpc_filter_options'))
  // two departments can share a name (different codes, e.g. Accounting 12AC / WHB) → show the code so pickers can tell them apart
  const seen = {}
  for (const d of _options.departments || []) seen[d.name] = (seen[d.name] || 0) + 1
  for (const d of _options.departments || []) if (seen[d.name] > 1 && d.code) d.name = `${d.name} (${d.code})`
  return _options
}
export const invalidateOptions = () => { _options = null }

export const dashboard = (filters, year, month) =>
  must(supabase.rpc('rpc_dashboard', { p: cleanFilters(filters), p_year: year, p_month: month }))

export const report = (filters, group) =>
  must(supabase.rpc('rpc_report', { p: cleanFilters(filters), p_group: group }))

export const employeeTarget = (filters) =>
  must(supabase.rpc('rpc_employee_target', { p: cleanFilters(filters) }))

/** Paged training records (participant fact). */
export async function facts(filters, { page = 1, size = 50, search = '', order = 'start_date', asc = false, all = false } = {}) {
  let q = supabase.from('v_participant_fact').select('*', { count: all ? undefined : 'exact' })
  q = applyFactFilters(q, filters)
  if (search) {
    const s = search.replace(/[%,()]/g, ' ').trim()
    q = q.or(`employee_code.ilike.%${s}%,employee_name.ilike.%${s}%,course_name.ilike.%${s}%,session_name.ilike.%${s}%,department_name.ilike.%${s}%,provider_name.ilike.%${s}%`)
  }
  q = q.order(order, { ascending: asc, nullsFirst: false }).order('participant_id', { ascending: true })
  if (all) return fetchAll(q)
  const from = (page - 1) * size
  const { data, count } = await must(q.range(from, from + size - 1))
  return { rows: data, count }
}

/** Page through a query 1000 rows at a time (PostgREST max rows) — used for exports. */
export async function fetchAll(q, limit = 200000) {
  const out = []
  for (let from = 0; from < limit; from += 1000) {
    const { data, error } = await q.range(from, from + 999)
    if (error) throw new Error(error.message)
    out.push(...data)
    if (data.length < 1000) break
  }
  return out
}

// ---- generic CRUD --------------------------------------------------------------
export async function list(table, { select = '*', order = 'id', asc = true, filters = {}, search, searchCols = [], page, size, softDelete = false, inFilters = {} } = {}) {
  let q = supabase.from(table).select(select, { count: page ? 'exact' : undefined })
  for (const [k, v] of Object.entries(filters)) if (v !== undefined && v !== null && v !== '') q = q.eq(k, v)
  for (const [k, v] of Object.entries(inFilters)) if (Array.isArray(v) && v.length) q = q.in(k, v)
  if (softDelete) q = q.is('deleted_at', null)
  if (search && searchCols.length) {
    const s = search.replace(/[%,()]/g, ' ').trim()
    q = q.or(searchCols.map((c) => `${c}.ilike.%${s}%`).join(','))
  }
  q = q.order(order, { ascending: asc, nullsFirst: false })
  if (page) {
    const from = (page - 1) * size
    const { data, count } = await must(q.range(from, from + size - 1))
    return { rows: data, count }
  }
  return fetchAll(q)
}

export const getOne = (table, id, select = '*') => must(supabase.from(table).select(select).eq('id', id).single())
export const insertRow = (table, row) => must(supabase.from(table).insert(row).select().single())
export const insertRows = (table, rows) => must(supabase.from(table).insert(rows).select())
export const updateRow = (table, id, patch) => must(supabase.from(table).update(patch).eq('id', id).select().single())
export const softDelete = (table, id) => must(supabase.from(table).update({ deleted_at: new Date().toISOString() }).eq('id', id).select().single())
export const restoreRow = (table, id) => must(supabase.from(table).update({ deleted_at: null }).eq('id', id).select().single())
export const deleteRow = (table, id) => must(supabase.from(table).delete().eq('id', id))

export const rpc = (fn, args) => must(supabase.rpc(fn, args))

export async function searchEmployees(term, limit = 20) {
  const s = (term || '').replace(/[%,()]/g, ' ').trim()
  let q = supabase.from('employees').select('id, employee_code, full_name, nickname, department_id, employment_status, departments(name)').is('deleted_at', null)
  if (s) q = q.or(`employee_code.ilike.%${s}%,full_name.ilike.%${s}%,nickname.ilike.%${s}%`)
  return must(q.order('employee_code').limit(limit))
}
