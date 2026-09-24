// Executive insights computed from rpc_dashboard output — never hard-coded.
import { TH_MONTHS, be, num, money, pct, safeDiv, changePct } from './format'

export function dashboardCosts(d) {
  const pf = d.participant_filter
  return { year: pf ? d.kpi.year.cost : d.session_cost.year, month: pf ? d.kpi.month.cost : d.session_cost.month, ytd: pf ? d.kpi.ytd.cost : d.session_cost.ytd }
}

export function buildInsights(d, year, month) {
  const k = d.kpi
  const cost = dashboardCosts(d)
  const out = []
  const m = TH_MONTHS[month - 1]
  const ch = changePct(k.month.participants, k.prev_month.participants)
  if (ch !== null) out.push(`Training (คน-ครั้ง) เดือน ${m} <b>${ch >= 0 ? 'เพิ่มขึ้น' : 'ลดลง'} ${Math.abs(ch).toFixed(1)}%</b> จากเดือนก่อน (${num(k.prev_month.participants)} → ${num(k.month.participants)})`)
  else out.push(`เดือน ${m} มีผู้เข้าอบรม <b>${num(k.month.participants)}</b> คน-ครั้ง จาก ${num(k.month.sessions)} รอบอบรม`)
  const ytdCh = changePct(k.ytd.participants, k.ytd_last_year.participants)
  if (ytdCh !== null) out.push(`สะสม ม.ค.–${m} ${be(year)}: <b>${num(k.ytd.participants)}</b> คน-ครั้ง ${ytdCh >= 0 ? 'สูงกว่า' : 'ต่ำกว่า'}ปีก่อนช่วงเดียวกัน ${Math.abs(ytdCh).toFixed(1)}%`)
  const depts = d.top_departments || []
  const byHours = [...depts].sort((a, b) => b.hours - a.hours)[0]
  if (byHours && byHours.hours > 0) out.push(`Department ที่มี Training Hours สูงสุดคือ <b>${byHours.label}</b> (${num(byHours.hours, 1)} ชม.)`)
  else if (depts[0]) out.push(`Department ที่เข้าอบรมมากที่สุดคือ <b>${depts[0].label}</b> (${num(depts[0].participants)} คน-ครั้ง, ${num(depts[0].employees)} คน)`)
  const tc = (d.top_courses || [])[0]
  if (tc) out.push(`Course ที่มี Participant สูงสุดคือ <b>${tc.label}</b> (${num(tc.participants)} คน)`)
  out.push(`Training Cost เดือนนี้ <b>${money(cost.month)}</b> บาท · สะสมทั้งปี ${money(cost.year)} บาท`)
  const cpp = safeDiv(cost.year, k.year.participants)
  out.push(`Cost / Participant เฉลี่ย <b>${cpp ? money(cpp) : '-'}</b> บาท`)
  out.push(`พนักงานผ่านเป้า ≥ ${k.target.target} หลักสูตร/ปี <b>${num(k.target.met)}</b> คน (${pct(safeDiv(k.target.met, k.target.trained) * 100)} ของผู้เข้าอบรม)`)
  const inh = safeDiv(k.ytd.inhouse, k.ytd.participants)
  if (inh !== null) out.push(`สัดส่วน Inhouse สะสม ${pct(inh * 100)} · Public ${pct(safeDiv(k.ytd.public, k.ytd.participants) * 100)} · Online ${pct(safeDiv(k.ytd.online, k.ytd.participants) * 100)}`)
  return out
}
