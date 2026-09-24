// Export helpers — Excel (ExcelJS), CSV and PDF (html2pdf → jsPDF + html2canvas, renders Thai correctly).
import { saveAs } from 'file-saver'
import { APP_NAME, APP_SUBTITLE } from './config'
import { dateTimeTH } from './format'

/** columns: [{ key, label, width?, type?: 'number'|'money'|'date'|'percent', value?: (row)=>any }] */
function cellValue(row, col) {
  const v = col.value ? col.value(row) : row[col.key]
  if (v === null || v === undefined) return ''
  if (col.type === 'date' && v) return new Date(String(v).length === 10 ? v + 'T00:00:00' : v)
  if (['number', 'money', 'percent'].includes(col.type) && v !== '') return Number(v)
  return v
}

/**
 * sheets: [{ name, title?, subtitle?, columns, rows, filters?: string }]
 */
export async function exportExcel(filename, sheets) {
  const { default: ExcelJS } = await import('exceljs')
  const wb = new ExcelJS.Workbook()
  wb.creator = APP_NAME
  wb.title = APP_NAME
  wb.created = new Date()
  for (const s of sheets) {
    const ws = wb.addWorksheet((s.name || 'Report').replace(/[\\/?*[\]:]/g, ' ').slice(0, 31))
    const ncol = Math.max(s.columns.length, 1)
    ws.mergeCells(1, 1, 1, ncol)
    ws.getCell(1, 1).value = APP_NAME + (s.title ? ` — ${s.title}` : '')
    ws.getCell(1, 1).font = { bold: true, size: 14, color: { argb: 'FF0F4C81' } }
    ws.mergeCells(2, 1, 2, ncol)
    ws.getCell(2, 1).value = [s.subtitle || APP_SUBTITLE, s.filters, `ออกรายงาน ${dateTimeTH(new Date())}`].filter(Boolean).join('  |  ')
    ws.getCell(2, 1).font = { size: 10, color: { argb: 'FF666666' } }
    const header = ws.getRow(4)
    s.columns.forEach((c, i) => {
      const cell = header.getCell(i + 1)
      cell.value = c.label
      cell.font = { bold: true, color: { argb: 'FFFFFFFF' } }
      cell.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FF0F4C81' } }
      cell.alignment = { vertical: 'middle', wrapText: true }
      ws.getColumn(i + 1).width = c.width || Math.min(Math.max(String(c.label).length + 4, 12), 50)
      if (c.type === 'money') ws.getColumn(i + 1).numFmt = '#,##0.00'
      if (c.type === 'number') ws.getColumn(i + 1).numFmt = '#,##0.##'
      if (c.type === 'percent') ws.getColumn(i + 1).numFmt = '0.0"%"'
      if (c.type === 'date') ws.getColumn(i + 1).numFmt = 'dd/mm/yyyy'
    })
    s.rows.forEach((r, ri) => {
      const row = ws.getRow(5 + ri)
      s.columns.forEach((c, ci) => { row.getCell(ci + 1).value = cellValue(r, c) })
    })
    ws.views = [{ state: 'frozen', ySplit: 4 }]
    ws.autoFilter = { from: { row: 4, column: 1 }, to: { row: 4, column: ncol } }
  }
  const buf = await wb.xlsx.writeBuffer()
  saveAs(new Blob([buf], { type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' }), filename)
}

export function exportCSV(filename, columns, rows) {
  const esc = (v) => {
    if (v === null || v === undefined) return ''
    const s = v instanceof Date ? v.toISOString().slice(0, 10) : String(v)
    return /[",\n]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s
  }
  const lines = [columns.map((c) => esc(c.label)).join(',')]
  for (const r of rows) lines.push(columns.map((c) => esc(c.value ? c.value(r) : r[c.key])).join(','))
  // BOM so Excel opens Thai text as UTF-8
  saveAs(new Blob(['﻿' + lines.join('\r\n')], { type: 'text/csv;charset=utf-8' }), filename)
}

export async function exportPDF(element, filename, { landscape = true } = {}) {
  const { default: html2pdf } = await import('html2pdf.js')
  document.body.classList.add('pdf-exporting')
  try {
    await html2pdf()
      .set({
        margin: [8, 8, 10, 8],
        filename,
        image: { type: 'jpeg', quality: 0.95 },
        html2canvas: { scale: 2, useCORS: true, backgroundColor: '#ffffff' },
        jsPDF: { unit: 'mm', format: 'a4', orientation: landscape ? 'landscape' : 'portrait' },
        pagebreak: { mode: ['css', 'legacy'], avoid: ['.card', 'tr', '.kpi'] },
      })
      .from(element)
      .save()
  } finally {
    document.body.classList.remove('pdf-exporting')
  }
}

/** ASW_Training_Record_Report_2026_09 style names */
export function fileStamp(prefix, parts = []) {
  const clean = parts.filter((p) => p !== null && p !== undefined && p !== '').map((p) => String(p).replace(/[^\w฀-๿-]+/g, '_'))
  return ['ASW', prefix, ...clean].join('_')
}
