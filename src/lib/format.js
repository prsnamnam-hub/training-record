export const TH_MONTHS = ['ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.', 'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.']
export const TH_MONTHS_FULL = ['มกราคม', 'กุมภาพันธ์', 'มีนาคม', 'เมษายน', 'พฤษภาคม', 'มิถุนายน', 'กรกฎาคม', 'สิงหาคม', 'กันยายน', 'ตุลาคม', 'พฤศจิกายน', 'ธันวาคม']

export const be = (y) => (y == null ? '' : Number(y) + 543)

export function num(v, digits = 0) {
  if (v === null || v === undefined || v === '' || Number.isNaN(Number(v))) return '-'
  return Number(v).toLocaleString('th-TH', { minimumFractionDigits: digits, maximumFractionDigits: digits })
}
export const money = (v) => (v === null || v === undefined ? '-' : num(v, 2))
export const baht = (v) => (v === null || v === undefined ? '-' : `${num(v, 0)} บาท`)
export const pct = (v, digits = 0) => (v === null || v === undefined || !isFinite(v) ? '-' : `${num(v, digits)}%`)

export function dateTH(d) {
  if (!d) return '-'
  const dt = typeof d === 'string' ? new Date(d.length === 10 ? d + 'T00:00:00' : d) : d
  if (Number.isNaN(dt.getTime())) return '-'
  return `${dt.getDate()} ${TH_MONTHS[dt.getMonth()]} ${dt.getFullYear() + 543}`
}
export function dateTimeTH(d) {
  if (!d) return '-'
  const dt = new Date(d)
  return `${dateTH(dt)} ${String(dt.getHours()).padStart(2, '0')}:${String(dt.getMinutes()).padStart(2, '0')}`
}
export const isoDate = (d) => {
  const dt = d instanceof Date ? d : new Date(d)
  return `${dt.getFullYear()}-${String(dt.getMonth() + 1).padStart(2, '0')}-${String(dt.getDate()).padStart(2, '0')}`
}
export const safeDiv = (a, b) => (b ? a / b : null)
export const changePct = (cur, prev) => (prev ? ((cur - prev) / prev) * 100 : null)

/** Same rule as public.normalize_course_name(): strip a trailing "รุ่นที่ N" / "รุ่น N" / "ครั้งที่ N". */
export function normalizeCourseName(s) {
  return String(s || '').replace(/\s+/g, ' ')
    .replace(/\s*(\((รุ่นที่|รุ่น|ครั้งที่)\s*\d+\)|(รุ่นที่|รุ่น|ครั้งที่)\s*\.?\s*\d+)\s*$/, '')
    .replace(/\s+/g, ' ').trim()
}
export const courseKey = (s) => normalizeCourseName(s).toLowerCase()
