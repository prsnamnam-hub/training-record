# Changelog — ASW Training Record

_Append-only. Newest entries at the bottom._

## 2026-09-24
- Phase 1–3: Excel analysis, field mapping and database design (`docs/01_Excel_Analysis_Mapping_DB_Design.md`).
- Database: schema, triggers (audit log, stamping), analytic views, `rpc_dashboard`, `rpc_report`, `rpc_employee_target`, shared import engine (`import_training_rows`, `import_employees`, `import_expenses`) with dry-run preview, RLS for Admin / HR-Training / Viewer.
- Historical migration builder (`scripts/build_historical_seed.py`); verified on Postgres: session counts per year match the Excel dashboard (2566: 135, 2567: 122, 2568: 71, 2569: 60), 7,322 participants (3 true duplicates skipped, 1 row without year flagged invalid).
- Frontend (Vue 3 + Vite): Dashboard (Excel layout + hours/cost/expense/insights), Training Record, Training Session (create flow, participants, results, expenses), Participants, Calendar (month/week/day), Master Data (employee, course + analysis, category, type, trainer, provider, department, section, company, expense category, budget), Expense (all/food/other), Report Center (15 reports), Employee History, Monthly Management Report, Custom Report, Import Center, Export, Users, Roles, Audit Log, Settings.
- GitHub Pages deploy workflow.
- Historical import runner `scripts/run_historical_seed.mjs` (`npm run seed:run`, dev dependency `pg`): runs all seed chunks in one transaction, `--dry-run` rolls back, refuses to run on a non-empty database unless `--allow-existing`, verifies participants / sessions / employees / per-year counts against the Excel-derived seed rows. Tested on local Postgres (PGlite): 7,336 rows → 7,322 imported · 3 duplicate · 1 invalid (Teambuilding BU2) · 0 failed; re-run = all duplicates, no new rows. Import Center is not used for historical data (it does not read the "Training Courses" sheet and tags rows `Excel Import`).
