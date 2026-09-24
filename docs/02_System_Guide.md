# ASW Training Record — System Guide (Architecture · Deployment · Runbook)

> ASW Training Record — Training Record & Training Expense Management
> เอกสารหลัก (Single Source of Truth) ของสถานะระบบ · อัปเดต 24-Sep-2026

## 1. สถานะปัจจุบัน

| ส่วน | สถานะ |
|---|---|
| Phase 1–3 Excel Analysis / Mapping / DB Design | ✅ [01_Excel_Analysis_Mapping_DB_Design.md](01_Excel_Analysis_Mapping_DB_Design.md) |
| Database schema + RLS + Import engine + Analytics RPC | ✅ `database/migrations/001–003` — ทดสอบกับ Postgres (PGlite) แล้ว |
| Historical migration (7,325 แถว Excel) | ✅ **Import เข้า Supabase แล้ว 24-Sep-2026** — 7,336 rows · 7,322 imported · 3 duplicate · 1 invalid · 0 failed · 398 sessions · 967 employees · 308 courses |
| Frontend (Vue 3 + Vite) ครบทุกเมนู | ✅ build ผ่าน |
| Supabase project | ✅ `asw-training-record` (ref `lcouhsgvzsqhppqedpzk`, Singapore) — migration 001–003 |
| Deploy | ✅ https://prsnamnam-hub.github.io/training-record/ (GitHub Actions, push `main`) |
| Auth URL Configuration | ✅ Site URL = URL ข้างบน · Redirect URLs: `https://prsnamnam-hub.github.io/training-record/**`, `http://localhost:5173/**` |

## 2. Architecture

```
Excel (Training/) ──► scripts/build_historical_seed.py ──► database/seed/historical_*.sql
                                                              │  select import_training_rows(...)
Import Center (web) ── .xlsx → mapping → dry-run preview ─────┤
                                                              ▼
                          Supabase Postgres (Single Source of Truth)
          employees · training_courses · training_sessions · training_participants
          training_expenses · masters · import_batches · audit_logs · profiles
                                                              │ RLS + security_invoker views
            v_participant_fact / v_session_summary / rpc_dashboard / rpc_report
                                                              ▼
       Vue 3 SPA (GitHub Pages) — Dashboard · Reports · Training · Expense · Import/Export
```

* **Historical + ใหม่ อยู่ในตารางเดียวกัน** แยกด้วย `data_source` = `Historical Excel` / `System Entry` / `Excel Import` + `import_batch_id` + `import_date`
* **Import engine เดียว** (`public.import_training_rows`) ใช้ทั้ง migration และ Import Center → กฎ validation / duplicate เหมือนกัน
* Dashboard/Report คำนวณด้วย SQL (`rpc_dashboard`, `rpc_report`) รองรับ 100k+ records (index บน session/employee/department/date)
* ไม่มีการลบจริง: ตารางธุรกิจไม่มีสิทธิ์ DELETE → soft delete (`deleted_at`) + `audit_logs` (old/new value, ผู้แก้ไข, เวลา)

## 3. การตัดสินใจที่ใช้ (ยืนยัน/เปลี่ยนได้)

| เรื่อง | ค่าที่ใช้ | เหตุผล |
|---|---|---|
| Excel "Course ID" | = **Training Session** | 1 ID = 1 ชื่อ+วันที่+ประเภท เสมอ |
| Course Master | ตัด "รุ่นที่ N / รุ่น N / ครั้งที่ N" ท้ายชื่อ → 1 หลักสูตรหลายรุ่น | ตามที่แนะนำใน Phase 1 (`normalize_course_name`) |
| คอลัมน์ T "ค่าที่บันทึก" | เก็บใน `training_participants.legacy_value` ไม่ใช้เป็นชั่วโมง | ยังไม่ทราบความหมาย — ไม่เดา |
| ปีรายงาน | ปีปฏิทิน ม.ค.–ธ.ค. แสดงเป็น พ.ศ. | ตาม Excel Dashboard |
| ชั่วโมง / ค่าใช้จ่ายย้อนหลัง | ว่าง (ไม่สร้าง Mock) | Excel ไม่มีข้อมูล |
| Course ID ซ้ำชื่อ/วันเดียวกัน | เก็บแยก session | Excel Dashboard นับแยก (135/122/71/60 รอบ ตรงกับ Excel) |
| Participant ซ้ำ 3 คู่ | นำเข้า 1 แถว + log ใน `import_issues` | duplicate จริง |
| "Teambuilding BU2" (ไม่มีปี/วันที่) | invalid ใน migration | ไม่มีข้อมูลปี — สร้างใหม่ในระบบได้ |
| Cost per participant | ค่าใช้จ่ายของรอบ ÷ ผู้เข้าอบรมของรอบ (allocated) | ทำให้ Cost by Department รวมได้ถูกต้อง |

## 4. โครงสร้าง Repository

| Path | หน้าที่ |
|---|---|
| `database/migrations/001_schema.sql` | ตาราง, index, ข้อมูลอ้างอิง (Training Type, Expense Category) |
| `database/migrations/002_functions.sql` | triggers (audit/stamp), views, `fact_filtered`, `rpc_dashboard`, `rpc_report`, import functions |
| `database/migrations/003_rls.sql` | Row Level Security + grants (Admin / HR-Training / Viewer) |
| `scripts/build_historical_seed.py` | อ่าน Excel → `database/seed/historical_*.sql` (gitignored — มีข้อมูลส่วนบุคคล) |
| `scripts/run_historical_seed.mjs` | รัน seed เข้า Supabase ใน transaction เดียว + Verify กับ Excel (`npm run seed:run`) |
| `src/lib/*` | config, auth, api (filter model เดียว), export (Excel/CSV/PDF), import mapping |
| `src/views/*` | หน้าจอตามเมนู |
| `supabase/functions/admin-users/` | Edge Function: Admin สร้างผู้ใช้ + ตั้งรหัสผ่าน (service_role อยู่ฝั่ง server เท่านั้น) |
| `.github/workflows/deploy.yml` | Build + Deploy GitHub Pages เมื่อ push `main` |

## 5. Runbook — ติดตั้ง Database (ครั้งแรก)

1. Supabase Dashboard → **SQL Editor** → รันตามลำดับ: `001_schema.sql` → `002_functions.sql` → `003_rls.sql` (รันซ้ำได้ — idempotent)
2. สร้างไฟล์ seed ในเครื่อง: `npm run seed:build` (= `python3 scripts/build_historical_seed.py`)
3. Import ข้อมูลเก่า ด้วย `scripts/run_historical_seed.mjs` — รันทุก chunk ใน **transaction เดียว** (สำเร็จทั้งหมดหรือไม่เปลี่ยนอะไรเลย) แล้ว Verify กับตัวเลขจาก Excel อัตโนมัติ
   * Connection string: Supabase › **Connect** › **Session pooler** (มีรหัสผ่าน DB — ส่งผ่าน env เท่านั้น ห้าม commit/บันทึกลงไฟล์)
   * `DATABASE_URL='postgresql://...' npm run seed:run -- --dry-run` → รัน + ตรวจ + ROLLBACK (ไม่เปลี่ยนข้อมูล)
   * `DATABASE_URL='postgresql://...' npm run seed:run` → รัน + ตรวจ + COMMIT (ถ้า Verify ไม่ผ่านจะ ROLLBACK เอง)
   * ถ้ามีข้อมูลอยู่แล้ว script จะหยุดโดยไม่แก้อะไร; `--allow-existing` = รันซ้ำ (ทุกแถวเป็น Duplicate)
   ผลที่ถูกต้อง: total 7,336 · imported 7,322 · duplicate 3 · invalid 1 (Teambuilding BU2) · sessions 398 · employees 967 · courses 308
   Session ที่มีผู้เข้าอบรม ต่อปี 2566–2569 = 135 / 122 / 71 / 60 (ตรง Excel Dashboard) · ทุก session รวม session-only = 136 / 124 / 71 / 67
4. **หลัง Import จำนวนมากทุกครั้ง ให้รัน `analyze;`** (SQL Editor) — ถ้าไม่รัน สถิติตารางจะเก่า ทำให้ Dashboard/Report ช้าจน timeout (ทดสอบแล้ว: 1.8s → 0.5s ในเครื่อง)
   ตรวจเพิ่ม (SQL Editor): `select fiscal_year+543, count(*) from training_sessions group by 1 order by 1;` และ `select count(*) from training_participants;`
   (ทางเลือก: รัน `historical_01–05.sql` ใน SQL Editor ทีละไฟล์ — ผลเหมือนกัน แต่ไฟล์ใหญ่ ~1.2 MB/ไฟล์)
   * วิธีที่ใช้จริงครั้งแรก (ไม่ต้องใช้รหัสผ่าน DB): `npx supabase login` แล้ว `supabase db query --linked --project-ref <ref> -f …`
     Management API รับได้ ~1 MB/request → อัปโหลด seed เป็นชิ้น ~250 แถวเข้า schema ชั่วคราว `import_staging` (revoke จาก anon/authenticated)
     → รัน `import_training_rows` ต่อไฟล์ใน transaction เดียว + ตรวจตัวเลข (ไม่ตรง = rollback) → `drop schema import_staging cascade`
5. Authentication → Users: ผู้ใช้ **คนแรก** ที่ลงทะเบียนจะเป็น Admin อัตโนมัติ (Admin = สิทธิ์สูงสุด / superadmin); คนถัดไปเป็น Viewer → Admin เปลี่ยน Role ที่ System › Users
   * วิธีที่แนะนำสำหรับคนแรก: Supabase › Authentication › Users › **Add user › Create new user** (ติ๊ก Auto Confirm) — ไม่ต้องรออีเมลยืนยัน
   * หลังจากนั้น Admin เพิ่มผู้ใช้พร้อมรหัสผ่าน / ตั้งรหัสผ่านใหม่ ได้ที่ System › Users (Edge Function `admin-users`)
5.1 Deploy Edge Function (ครั้งแรก/เมื่อแก้): `npx supabase login` แล้ว
   `npx supabase functions deploy admin-users --project-ref lcouhsgvzsqhppqedpzk --use-api`
   (Gateway ตรวจ JWT + function ตรวจ role Admin อีกชั้น; ใช้ `SUPABASE_SERVICE_ROLE_KEY` ที่ Supabase ใส่ให้ฝั่ง server — ไม่มี secret ใน repo/browser)
6. Authentication → URL Configuration: ใส่ Site URL = URL ของเว็บ (GitHub Pages) เพื่อให้ลิงก์ยืนยันอีเมล/รีเซ็ตรหัสผ่านทำงาน

Import ไฟล์ Excel เดิมซ้ำ (ผ่าน Import Center หรือ seed) → ทุกแถวเป็น Duplicate ไม่มีข้อมูลซ้ำ

## 6. Deployment

* Frontend: GitHub Pages ผ่าน GitHub Actions (`deploy.yml`) — Settings › Pages › Source = **GitHub Actions**
* ค่า public (ไม่ใช่ความลับ): `VITE_SUPABASE_URL`, `VITE_SUPABASE_ANON_KEY` (= Publishable key `sb_publishable_…`)
  * Production: GitHub › Settings › Secrets and variables › Actions › **Variables** (ตั้งแล้ว)
  * Local dev: `.env.local` (gitignored) — `src/lib/config.js` DEFAULTS เว้นว่างไว้
* **ห้าม** ใส่ `service_role` key ในโค้ด/Repository
* Router เป็น hash mode (`/#/dashboard`) → ไม่ต้องตั้ง SPA fallback
* หลังเปลี่ยนค่า env ต้อง build/deploy ใหม่ (ค่าถูกฝังตอน build)

## 7. Roles

| สิทธิ์ | Admin | HR/Training | Viewer |
|---|:-:|:-:|:-:|
| Dashboard / Report / Search / Export | ✅ | ✅ | ✅ |
| Create/Edit Training, Participant, Expense, Master Data, Import | ✅ | ✅ | — |
| Users/Roles, Audit Log, Settings | ✅ | — | — |

## 8. Import Format

ดาวน์โหลด Template ได้ที่ Import Center ทุกประเภท · ไฟล์ Excel เดิม (`ชีต Training Record`) Import ได้โดยตรง — ระบบจับคู่หัวคอลัมน์อัตโนมัติ
Unique keys: employee = `employee_code` · course = ชื่อหลักสูตร (normalize) · session = Excel Course ID หรือ (course, ชื่อรอบ, วันที่, ประเภท) · participant = (session, employee)
