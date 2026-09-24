# ASW Training Record

**ASW Training Record — Training Record & Training Expense Management**

A web system for managing employee training: courses, sessions, participants, expenses, reports, and dashboards. Historical Excel data and new training entries live in one database.

## Status

- [x] Phase 1–3: Excel analysis, data mapping, database design → [docs/01_Excel_Analysis_Mapping_DB_Design.md](docs/01_Excel_Analysis_Mapping_DB_Design.md)
- [x] Phase 4–17: Database, historical migration builder, application → [docs/02_System_Guide.md](docs/02_System_Guide.md)
- [ ] Go-live: Supabase project + GitHub Pages deploy

## Docs

- [docs/02_System_Guide.md](docs/02_System_Guide.md) — architecture, decisions, runbook, deployment (start here)
- [docs/01_Excel_Analysis_Mapping_DB_Design.md](docs/01_Excel_Analysis_Mapping_DB_Design.md) — Excel analysis & mapping
- [docs/CHANGELOG.md](docs/CHANGELOG.md) — append-only change log

## Develop

```bash
npm install
cp .env.example .env.local   # public Supabase URL + anon key
npm run dev
```

## Data policy

The source Excel files contain employee personal data. They are excluded by `.gitignore` and must never be committed.
