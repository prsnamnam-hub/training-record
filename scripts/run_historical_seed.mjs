#!/usr/bin/env node
// ASW Training Record — run the historical migration (database/seed/historical_*.sql) against Supabase.
//
// Runs every chunk in ONE transaction (all-or-nothing), then verifies the database against the
// numbers derived from database/seed/historical_rows.json (built from the Excel by
// scripts/build_historical_seed.py). Uses the same engine as the Import Center
// (public.import_training_rows), so re-running only produces duplicates, never duplicate data.
//
// Usage (credentials via env only — never commit them):
//   read -rs "SUPABASE_DB_PASSWORD?DB password: " && export SUPABASE_DB_PASSWORD && npm run seed:run -- --dry-run
// or with a full connection string (Supabase › Connect):
//   DATABASE_URL='postgresql://...' node scripts/run_historical_seed.mjs --dry-run   # run + verify + ROLLBACK
//   DATABASE_URL='postgresql://...' node scripts/run_historical_seed.mjs             # run + verify + COMMIT
// Flags: --allow-existing  continue even if training data already exists (re-run; rows become duplicates)
import { readFileSync, readdirSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'
import pg from 'pg'

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..')
const SEED = join(ROOT, 'database', 'seed')
const DRY = process.argv.includes('--dry-run')
const ALLOW_EXISTING = process.argv.includes('--allow-existing')

// Either a full DATABASE_URL, or just the database password (SUPABASE_DB_PASSWORD) → direct connection.
const PROJECT_REF = 'lcouhsgvzsqhppqedpzk'
const DB_URL = process.env.DATABASE_URL || (process.env.SUPABASE_DB_PASSWORD
  ? `postgresql://postgres:${encodeURIComponent(process.env.SUPABASE_DB_PASSWORD)}@db.${PROJECT_REF}.supabase.co:5432/postgres`
  : '')
if (!DB_URL) {
  console.error('Set DATABASE_URL (Supabase › Connect) or SUPABASE_DB_PASSWORD (Project Settings › Database).')
  process.exit(1)
}
if (DB_URL.includes('[YOUR-PASSWORD]')) {
  console.error('The connection string still contains [YOUR-PASSWORD] — replace it with the database password.')
  process.exit(1)
}

// ---- expected numbers, derived from the seed rows (not hard-coded) --------------------------------
const rows = JSON.parse(readFileSync(join(SEED, 'historical_rows.json'), 'utf8'))
const withYear = rows.filter((r) => r.fiscal_year)
const partRows = withYear.filter((r) => r.employee_code)
const partKeys = new Set(partRows.map((r) => `${r.legacy_course_id}|${r.employee_code}`))
const sessionYear = new Map(withYear.map((r) => [r.legacy_course_id, r.fiscal_year]))
const attendedYear = new Map(partRows.map((r) => [r.legacy_course_id, r.fiscal_year]))
const countBy = (m) => [...m.values()].reduce((a, y) => ({ ...a, [y + 543]: (a[y + 543] || 0) + 1 }), {})
const expected = {
  total_records: rows.length,
  invalid_records: rows.length - withYear.length,
  duplicate_records: partRows.length - partKeys.size,
  participants: partKeys.size,
  sessions: sessionYear.size,
  employees: new Set(partRows.map((r) => r.employee_code)).size,
  sessions_by_year: countBy(sessionYear),
  attended_sessions_by_year: countBy(attendedYear),
  participants_by_year: countBy(new Map(partRows.map((r) => [`${r.legacy_course_id}|${r.employee_code}`, r.fiscal_year]))),
}

const files = readdirSync(SEED).filter((f) => /^historical_\d+\.sql$/.test(f)).sort()
if (!files.length) { console.error('No database/seed/historical_*.sql — run: npm run seed:build'); process.exit(1) }

const client = new pg.Client({ connectionString: DB_URL, ssl: { rejectUnauthorized: false } })
const q = async (sql) => (await client.query(sql)).rows
const HIST = `data_source = 'Historical Excel' and deleted_at is null`

async function counts() {
  const [c] = await q(`select
      (select count(*) from public.employees)::int              as employees,
      (select count(*) from public.training_courses)::int       as courses,
      (select count(*) from public.training_sessions)::int      as sessions,
      (select count(*) from public.training_participants)::int  as participants,
      (select count(*) from public.training_expenses)::int      as expenses,
      (select count(*) from public.import_batches where data_source = 'Historical Excel' and status = 'completed')::int as historical_batches`)
  return c
}

async function verify() {
  const [c] = await q(`select
      (select count(*) from public.training_participants where ${HIST})::int as participants,
      (select count(*) from public.training_sessions where ${HIST})::int     as sessions,
      (select count(distinct p.employee_id) from public.training_participants p where p.data_source = 'Historical Excel' and p.deleted_at is null)::int as employees`)
  const byYear = (sql) => q(sql).then((r) => Object.fromEntries(r.map((x) => [x.y, x.n])))
  const sessionsByYear = await byYear(`select fiscal_year + 543 as y, count(*)::int as n from public.training_sessions where ${HIST} group by 1 order by 1`)
  const attendedByYear = await byYear(`select s.fiscal_year + 543 as y, count(distinct s.id)::int as n
      from public.training_sessions s join public.training_participants p on p.session_id = s.id and p.deleted_at is null
      where s.data_source = 'Historical Excel' and s.deleted_at is null group by 1 order by 1`)
  const partByYear = await byYear(`select s.fiscal_year + 543 as y, count(*)::int as n
      from public.training_participants p join public.training_sessions s on s.id = p.session_id
      where p.data_source = 'Historical Excel' and p.deleted_at is null group by 1 order by 1`)
  const checks = [
    ['Participants', c.participants, expected.participants],
    ['Training Sessions', c.sessions, expected.sessions],
    ['Employees (ผู้เข้าอบรม)', c.employees, expected.employees],
    ['Sessions by year (พ.ศ.)', sessionsByYear, expected.sessions_by_year],
    ['Sessions with participants by year (Excel Dashboard)', attendedByYear, expected.attended_sessions_by_year],
    ['Participants by year', partByYear, expected.participants_by_year],
  ]
  let ok = true
  for (const [name, got, want] of checks) {
    const pass = JSON.stringify(got) === JSON.stringify(want)
    ok &&= pass
    console.log(`${pass ? '✔' : '✘'} ${name}: ${JSON.stringify(got)}${pass ? '' : `  (expected ${JSON.stringify(want)})`}`)
  }
  return ok
}

try { await client.connect() } catch (e) {
  console.error(`\nCannot connect to the database: ${e.message}\nNothing was changed. Check the database password (Project Settings › Database) and try again.`)
  process.exit(1)
}
try {
  const before = await counts()
  console.log('Database before:', before)
  const hasData = before.sessions || before.participants || before.historical_batches
  if (hasData && !ALLOW_EXISTING) {
    console.error('Database already contains training data / a historical batch. Nothing was changed.\n' +
      'Re-running is safe (existing rows count as duplicates) — pass --allow-existing to continue.')
    process.exit(2)
  }

  console.log(`\n${DRY ? 'DRY RUN (will ROLLBACK)' : 'IMPORT (will COMMIT)'} — ${files.length} chunk(s), one transaction\n`)
  await client.query('begin')
  await client.query('set local statement_timeout = 0')
  const total = {}
  for (const f of files) {
    const t0 = Date.now()
    const [res] = await q(readFileSync(join(SEED, f), 'utf8'))
    const r = Object.values(res)[0]
    for (const [k, v] of Object.entries(r)) if (typeof v === 'number') total[k] = (total[k] || 0) + v
    console.log(`  ${f}: total ${r.total_records} · new ${r.new_records} · duplicate ${r.duplicate_records} · invalid ${r.invalid_records}` +
      ` · sessions+ ${r.new_sessions} · employees+ ${r.new_employees} · courses+ ${r.new_courses}  (${((Date.now() - t0) / 1000).toFixed(1)}s)`)
  }
  console.log('\nSummary:', { total: total.total_records, imported: total.records_to_import, duplicate: total.duplicate_records,
    invalid: total.invalid_records, failed: 0, new_sessions: total.new_sessions, new_employees: total.new_employees, new_courses: total.new_courses })
  if (!hasData) {
    for (const k of ['total_records', 'invalid_records', 'duplicate_records']) {
      if (total[k] !== expected[k]) console.log(`✘ ${k}: ${total[k]} (expected ${expected[k]})`)
    }
  }

  console.log('\nVerify against Excel:')
  const ok = await verify()
  const issues = await q(`select i.issue_type, count(*)::int n from public.import_issues i join public.import_batches b on b.id = i.batch_id
      where b.data_source = 'Historical Excel' group by 1 order by 1`)
  console.log('Import issues logged:', Object.fromEntries(issues.map((x) => [x.issue_type, x.n])))

  if (DRY || !ok) {
    await client.query('rollback')
    console.log(DRY ? '\nDRY RUN — rolled back, database unchanged.' : '\nVerification FAILED — rolled back, database unchanged.')
    process.exit(ok ? 0 : 3)
  }
  await client.query('commit')
  console.log('\nCOMMITTED. Database after:', await counts())
} catch (e) {
  await client.query('rollback').catch(() => {})
  console.error('\nFAILED — rolled back, database unchanged:', e.message)
  process.exit(1)
} finally {
  await client.end()
}
