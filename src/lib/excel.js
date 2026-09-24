// Read the first (or named) sheet of an .xlsx into plain objects keyed by header text.
export async function readWorkbook(file) {
  const { default: ExcelJS } = await import('exceljs')
  const wb = new ExcelJS.Workbook()
  await wb.xlsx.load(await file.arrayBuffer())
  return wb
}

export function cellToValue(v) {
  if (v === null || v === undefined) return null
  if (v instanceof Date) return v
  if (typeof v === 'object') {
    if ('result' in v) return cellToValue(v.result)          // formula
    if ('richText' in v) return v.richText.map((t) => t.text).join('')
    if ('text' in v) return v.text                           // hyperlink
    if ('error' in v) return null                            // #N/A etc.
  }
  return v
}

/** Detect the header row (first row with >= minCols non-empty cells) and return rows as objects. */
export function sheetToRows(ws, { minCols = 3 } = {}) {
  let headerRow = 1
  for (let r = 1; r <= Math.min(ws.rowCount, 15); r++) {
    const vals = ws.getRow(r).values.filter((v) => cellToValue(v) !== null && cellToValue(v) !== '')
    if (vals.length >= minCols) { headerRow = r; break }
  }
  const headers = []
  const seen = {}
  ws.getRow(headerRow).eachCell({ includeEmpty: true }, (cell, col) => {
    let h = String(cellToValue(cell.value) ?? '').replace(/\s+/g, ' ').trim()
    if (h) { seen[h] = (seen[h] || 0) + 1; if (seen[h] > 1) h = `${h}#${seen[h]}` }
    headers[col] = h
  })
  const rows = []
  for (let r = headerRow + 1; r <= ws.rowCount; r++) {
    const row = ws.getRow(r)
    const o = { __row: r }
    let any = false
    headers.forEach((h, col) => {
      if (!h) return
      const v = cellToValue(row.getCell(col).value)
      if (v !== null && v !== '') any = true
      o[h] = typeof v === 'string' ? v.replace(/\s+/g, ' ').trim() : v
    })
    if (any) rows.push(o)
  }
  return { headers: headers.filter(Boolean), rows, headerRow }
}

export async function readSheetRows(file, sheetName) {
  const wb = await readWorkbook(file)
  const ws = sheetName ? wb.getWorksheet(sheetName) : wb.worksheets[0]
  return sheetToRows(ws)
}

export const toISO = (v) => {
  if (!v) return null
  if (v instanceof Date) return v.toISOString().slice(0, 10)
  if (typeof v === 'number' && v > 20000 && v < 80000) return new Date(Date.UTC(1899, 11, 30) + v * 86400000).toISOString().slice(0, 10)
  const s = String(v).trim()
  let m = s.match(/^(\d{4})-(\d{1,2})-(\d{1,2})/)
  if (m) { let y = +m[1]; if (y > 2400) y -= 543; return `${y}-${m[2].padStart(2, '0')}-${m[3].padStart(2, '0')}` }
  m = s.match(/^(\d{1,2})[/.-](\d{1,2})[/.-](\d{2,4})$/)
  if (m) { let y = +m[3]; if (y < 100) y += 2000; if (y > 2400) y -= 543; return `${y}-${m[2].padStart(2, '0')}-${m[1].padStart(2, '0')}` }
  return s // let the server validate and report
}
