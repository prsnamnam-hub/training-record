// Column mappings for the Import Center. Header candidates include the exact headers of the
// historical workbook (sheet "Training Record") so the original Excel can be re-imported as-is.
import { toISO } from './excel'

const pad5 = (v) => {
  if (v === null || v === undefined || v === '') return null
  const s = String(v).trim()
  return /^\d+$/.test(s) && s.length < 5 ? s.padStart(5, '0') : s
}
const txt = (v) => (v === null || v === undefined || v === '' ? null : String(v).trim())
const numv = (v) => (v === null || v === undefined || v === '' ? null : String(v).replace(/,/g, ''))
const beYear = (v) => {
  if (!v) return null
  const n = parseInt(String(v).slice(0, 4), 10)
  if (!n) return null
  return n > 2400 ? n - 543 : n
}

export const IMPORT_TYPES = {
  training_record: {
    label: 'Training Record / Participant',
    desc: 'ประวัติการอบรมรายบุคคล (1 แถว = พนักงาน × หลักสูตร) — รองรับไฟล์รูปแบบเดิม "รายการหลักสูตรอบรม" (ชีต Training Record) และ Template ของระบบ · แถวที่ไม่มีรหัสพนักงานจะสร้างเป็น Training Session',
    rpc: 'import_training_rows',
    chunk: 1000,
    sheetHint: 'Training Record',
    fields: [
      { key: 'employee_code', label: 'รหัสพนักงาน', headers: ['รหัสพนักงาน', 'employee_code', 'Employee ID', 'รหัส'], fmt: pad5 },
      { key: 'employee_code_alt', label: 'รหัสพนักงาน (สำรอง)', headers: ['รหัส*ใหม่'], fmt: pad5 },
      { key: 'title_th', label: 'คำนำหน้า', headers: ['คำนำหน้า', 'title_th'] },
      { key: 'first_name_th', label: 'ชื่อ', headers: ['ชื่อ', 'first_name_th', 'First Name'] },
      { key: 'last_name_th', label: 'นามสกุล', headers: ['นามสกุล', 'last_name_th', 'Last Name'] },
      { key: 'nickname', label: 'ชื่อเล่น', headers: ['ชื่อเล่น#2', 'ชื่อเล่น', 'nickname'] },
      { key: 'legacy_title', label: 'คำนำหน้า (เดิม)', headers: ['คำนำหน้าชื่อ'] },
      { key: 'legacy_first_name', label: 'ชื่อ (เดิม)', headers: ['ชื่อไทย'] },
      { key: 'legacy_last_name', label: 'นามสกุล (เดิม)', headers: ['นามสกุลไทย'] },
      { key: 'company_code', label: 'รหัสบริษัท', headers: ['รหัสบริษัท', 'company_code'] },
      { key: 'company_name', label: 'ชื่อบริษัท', headers: ['ชื่อบริษัท', 'company_name', 'Company'] },
      { key: 'area_code', label: 'AreaCode', headers: ['AreaCode'] },
      { key: 'area_name', label: 'AreaName', headers: ['AreaName'] },
      { key: 'work_location', label: 'Subarea (สำนักงาน/ไซท์)', headers: ['SubareaName'] },
      { key: 'business_group', label: 'กลุ่มธุรกิจ', headers: ['กลุ่มธุรกิจ', 'business_group'] },
      { key: 'department_code', label: 'รหัสหน่วยงาน', headers: ['รหัสหน่วยงาน', 'department_code'] },
      { key: 'department_name', label: 'ฝ่าย (Department)', headers: ['ฝ่าย', 'department_name', 'Department'] },
      { key: 'level_group_code', label: 'รหัสกลุ่มระดับ', headers: ['รหัสกลุ่มระดับพนักงาน'] },
      { key: 'level_group_name', label: 'กลุ่มระดับพนักงาน', headers: ['ชื่อกลุ่มระดับพนักงาน', 'level_group'] },
      { key: 'position_code', label: 'รหัสระดับพนักงาน', headers: ['รหัสระดับพนักงาน'] },
      { key: 'position_name', label: 'ระดับตำแหน่ง', headers: ['ชื่อระดับพนักงาน', 'position'] },
      { key: 'job_level', label: 'Level', headers: ['Level'], fmt: (v) => (/^\d+$/.test(String(v ?? '')) ? Number(v) : null) },
      { key: 'job_title', label: 'ตำแหน่ง', headers: ['ตำแหน่ง', 'job_title', 'Position'] },
      { key: 'job_group', label: 'Group', headers: ['Group'] },
      { key: 'employment_status', label: 'สถานะพนักงาน', headers: ['Status', 'employment_status'] },
      { key: 'hire_date', label: 'วันที่จ้างงาน', headers: ['วันที่จ้างงาน', 'hire_date'], fmt: toISO },
      { key: 'probation_date', label: 'วันที่ผ่านทดลองงาน', headers: ['วันที่ผ่านทดลองงาน'], fmt: toISO },
      { key: 'termination_date', label: 'วันที่พ้นสภาพ', headers: ['วันที่พ้นสภาพ'], fmt: toISO },
      { key: 'name_check_result', label: 'ผลตรวจสอบชื่อ', headers: ['ผลตรวจสอบ (เทียบ B-F กับ Employee Info Report)'] },
      { key: 'course_name', label: 'ชื่อหลักสูตร *', headers: ['ชื่อหลักสูตร', 'course_name', 'Course', 'Course Name'], required: true },
      { key: 'start_date', label: 'วันที่อบรม', headers: ['วันที่อบรม', 'start_date', 'Training Date'], fmt: toISO },
      { key: 'end_date', label: 'วันที่สิ้นสุด', headers: ['วันที่สิ้นสุด', 'end_date'], fmt: toISO },
      { key: 'fiscal_year', label: 'ปีที่อบรม (พ.ศ./ค.ศ.)', headers: ['ปีที่อบรม', 'fiscal_year', 'Year'], fmt: beYear },
      { key: 'legacy_month_text', label: 'เดือนที่อบรม (ข้อความ)', headers: ['เดือนที่อบรม'] },
      { key: 'training_type', label: 'ประเภท (Inhouse/Public/Online)', headers: ['ประเภท Inhouse / Public', 'training_type', 'Training Type', 'ประเภท'] },
      { key: 'legacy_course_id', label: 'Course ID (Excel)', headers: ['Course ID', 'legacy_course_id'], fmt: (v) => (/^\d+$/.test(String(v ?? '')) ? Number(v) : null) },
      { key: 'training_hours', label: 'ชั่วโมงอบรม', headers: ['ชั่วโมงอบรม', 'training_hours', 'Training Hours'], fmt: numv },
      { key: 'category', label: 'หมวดหมู่', headers: ['หมวดหมู่', 'category', 'Training Category'] },
      { key: 'provider', label: 'Provider', headers: ['Provider', 'ผู้จัด', 'provider', 'Training Provider'] },
      { key: 'trainer', label: 'Trainer', headers: ['Trainer', 'วิทยากร', 'trainer'] },
      { key: 'location', label: 'สถานที่', headers: ['สถานที่', 'location', 'Location'] },
      { key: 'attendance_status', label: 'การเข้าร่วม', headers: ['attendance_status', 'Attendance'] },
      { key: 'completion_status', label: 'ผลการอบรม', headers: ['completion_status', 'Completion', 'ผลการอบรม'] },
      { key: 'score', label: 'คะแนน', headers: ['score', 'Score', 'คะแนน'], fmt: numv },
      { key: 'evaluation_score', label: 'คะแนนประเมิน', headers: ['evaluation_score', 'คะแนนประเมิน'], fmt: numv },
      { key: 'certificate_no', label: 'Certificate', headers: ['certificate_no', 'Certificate'] },
      { key: 'legacy_value', label: 'ค่าที่บันทึก (ตามไฟล์เดิม)', headers: ['ค่าที่บันทึก (ตามไฟล์เดิม)'], fmt: numv },
      { key: 'remark', label: 'หมายเหตุ', headers: ['remark', 'หมายเหตุ'] },
    ],
    finalize(r) {
      if (!r.employee_code && r.employee_code_alt) { r.employee_code = r.employee_code_alt; r.in_hr_master = false }
      delete r.employee_code_alt
      if (r.start_date && !r.fiscal_year) r.fiscal_year = Number(String(r.start_date).slice(0, 4))
      return r
    },
  },
  employee: {
    label: 'Employee', desc: 'Employee Master — เพิ่ม/อัปเดตพนักงานตามรหัสพนักงาน', rpc: 'import_employees', chunk: 1000,
    fields: [
      { key: 'employee_code', label: 'รหัสพนักงาน *', headers: ['รหัสพนักงาน', 'employee_code', 'Employee ID', 'รหัส*ใหม่'], fmt: pad5, required: true },
      { key: 'title_th', label: 'คำนำหน้า', headers: ['คำนำหน้า', 'คำนำหน้าชื่อ', 'title_th'] },
      { key: 'first_name_th', label: 'ชื่อ', headers: ['ชื่อ', 'ชื่อไทย', 'first_name_th'] },
      { key: 'last_name_th', label: 'นามสกุล', headers: ['นามสกุล', 'นามสกุลไทย', 'last_name_th'] },
      { key: 'nickname', label: 'ชื่อเล่น', headers: ['ชื่อเล่น', 'nickname'] },
      { key: 'company_code', label: 'รหัสบริษัท', headers: ['รหัสบริษัท', 'company_code'] },
      { key: 'company_name', label: 'ชื่อบริษัท', headers: ['ชื่อบริษัท', 'company_name'] },
      { key: 'department_code', label: 'รหัสหน่วยงาน', headers: ['รหัสหน่วยงาน', 'department_code'] },
      { key: 'department_name', label: 'ฝ่าย', headers: ['ฝ่าย', 'department_name', 'Department'] },
      { key: 'job_title', label: 'ตำแหน่ง', headers: ['ตำแหน่ง', 'job_title', 'Position'] },
      { key: 'employment_type', label: 'ประเภทการจ้าง', headers: ['employment_type', 'ประเภทการจ้าง'] },
      { key: 'employment_status', label: 'สถานะ', headers: ['Status', 'employment_status', 'สถานะ'] },
      { key: 'hire_date', label: 'วันที่จ้างงาน', headers: ['วันที่จ้างงาน', 'hire_date'], fmt: toISO },
    ],
  },
  course: {
    label: 'Course', desc: 'Course Master — หลักสูตรที่ชื่อซ้ำ (รวมรุ่น) จะถูกนับเป็น Duplicate', rpc: null, chunk: 500,
    fields: [
      { key: 'course_name', label: 'ชื่อหลักสูตร *', headers: ['ชื่อหลักสูตร', 'course_name', 'Course Name'], required: true },
      { key: 'course_code', label: 'Course ID', headers: ['course_code', 'Course Code'] },
      { key: 'training_type', label: 'ประเภท', headers: ['training_type', 'ประเภท', 'Training Type'] },
      { key: 'category', label: 'หมวดหมู่', headers: ['category', 'หมวดหมู่'] },
      { key: 'provider', label: 'Provider', headers: ['provider', 'Provider'] },
      { key: 'standard_hours', label: 'ชั่วโมงมาตรฐาน', headers: ['standard_hours', 'ชั่วโมง'], fmt: numv },
      { key: 'standard_cost', label: 'ค่าใช้จ่ายมาตรฐาน', headers: ['standard_cost', 'ค่าใช้จ่าย'], fmt: numv },
      { key: 'objective', label: 'Objective', headers: ['objective', 'วัตถุประสงค์'] },
    ],
  },
  session: {
    label: 'Training Session', desc: 'รอบอบรม (ไม่มีรายชื่อผู้เข้าอบรม) — ใช้เครื่องมือเดียวกับ Training Record', rpc: 'import_training_rows', chunk: 1000,
    fields: [
      { key: 'course_name', label: 'ชื่อหลักสูตร / รุ่น *', headers: ['ชื่อหลักสูตร', 'course_name'], required: true },
      { key: 'start_date', label: 'วันที่เริ่ม', headers: ['วันที่อบรม', 'start_date'], fmt: toISO },
      { key: 'end_date', label: 'วันที่สิ้นสุด', headers: ['วันที่สิ้นสุด', 'end_date'], fmt: toISO },
      { key: 'fiscal_year', label: 'ปี', headers: ['ปีที่อบรม', 'fiscal_year'], fmt: beYear },
      { key: 'training_type', label: 'ประเภท', headers: ['ประเภท Inhouse / Public', 'training_type', 'ประเภท'] },
      { key: 'training_hours', label: 'ชั่วโมง', headers: ['training_hours', 'ชั่วโมงอบรม'], fmt: numv },
      { key: 'trainer', label: 'Trainer', headers: ['trainer', 'วิทยากร'] },
      { key: 'provider', label: 'Provider', headers: ['provider', 'ผู้จัด'] },
      { key: 'location', label: 'สถานที่', headers: ['location', 'สถานที่'] },
      { key: 'category', label: 'หมวดหมู่', headers: ['category', 'หมวดหมู่'] },
      { key: 'legacy_course_id', label: 'Course ID (Excel)', headers: ['Course ID'], fmt: (v) => (/^\d+$/.test(String(v ?? '')) ? Number(v) : null) },
      { key: 'session_status', label: 'สถานะ', headers: ['status', 'สถานะ'] },
    ],
    finalize(r) { if (r.start_date && !r.fiscal_year) r.fiscal_year = Number(String(r.start_date).slice(0, 4)); return r },
  },
  expense: {
    label: 'Expense', desc: 'ค่าใช้จ่าย — ต้องระบุ Training ID (session_code) หรือ Course ID เดิมจาก Excel', rpc: 'import_expenses', chunk: 1000,
    fields: [
      { key: 'session_code', label: 'Training ID (TS-...)', headers: ['session_code', 'Training ID'] },
      { key: 'legacy_course_id', label: 'Course ID (Excel)', headers: ['Course ID', 'legacy_course_id'] },
      { key: 'session_id', label: 'Session ID (ระบบ)', headers: ['session_id'] },
      { key: 'expense_category', label: 'ประเภทค่าใช้จ่าย *', headers: ['expense_category', 'ประเภทค่าใช้จ่าย', 'Expense Category'], required: true },
      { key: 'description', label: 'รายละเอียด', headers: ['description', 'รายละเอียด'] },
      { key: 'meal_type', label: 'มื้ออาหาร', headers: ['meal_type', 'มื้อ'] },
      { key: 'quantity', label: 'จำนวน', headers: ['quantity', 'จำนวน', 'Quantity'], fmt: numv },
      { key: 'unit_price', label: 'ราคา/หน่วย *', headers: ['unit_price', 'ราคาต่อหน่วย', 'Unit Price'], fmt: numv, required: true },
      { key: 'expense_date', label: 'วันที่', headers: ['expense_date', 'วันที่'], fmt: toISO },
      { key: 'vendor', label: 'Vendor', headers: ['vendor', 'ผู้ขาย'] },
      { key: 'invoice_no', label: 'เลขที่เอกสาร', headers: ['invoice_no', 'เลขที่ใบแจ้งหนี้'] },
      { key: 'remark', label: 'หมายเหตุ', headers: ['remark', 'หมายเหตุ'] },
    ],
  },
}

export function autoMap(type, headers) {
  const m = {}
  const lower = headers.map((h) => h.toLowerCase())
  for (const f of IMPORT_TYPES[type].fields) {
    const hit = f.headers.find((h) => headers.includes(h)) || f.headers.find((h) => lower.includes(h.toLowerCase()))
    if (hit) m[f.key] = headers[lower.indexOf(hit.toLowerCase())] ?? hit
  }
  return m
}

export function transform(type, rows, mapping) {
  const def = IMPORT_TYPES[type]
  return rows.map((src) => {
    let r = { row_no: src.__row }
    for (const f of def.fields) {
      const col = mapping[f.key]
      if (!col) continue
      const raw = src[col]
      const v = f.fmt ? f.fmt(raw) : txt(raw instanceof Date ? toISO(raw) : raw)
      if (v !== null && v !== undefined && v !== '') r[f.key] = v
    }
    if (def.finalize) r = def.finalize(r)
    return r
  })
}

export function templateColumns(type) {
  return IMPORT_TYPES[type].fields.filter((f) => !f.key.endsWith('_alt')).map((f) => ({ key: f.key, label: f.headers.find((h) => /^[a-z_]+$/.test(h)) || f.headers[0] }))
}
