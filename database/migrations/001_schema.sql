-- ============================================================================
-- ASW Training Record — 001 Schema
-- ASW Training Record — Training Record & Training Expense Management
-- Target: Supabase (PostgreSQL 15+). Idempotent: safe to re-run.
-- ============================================================================

create schema if not exists extensions;
create extension if not exists pg_trgm with schema extensions;

-- ---------------------------------------------------------------------------
-- Users / roles
-- ---------------------------------------------------------------------------
create table if not exists public.profiles (
  id          uuid primary key references auth.users(id) on delete cascade,
  email       text,
  full_name   text,
  role        text not null default 'viewer' check (role in ('admin','hr_training','viewer')),
  is_active   boolean not null default true,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- Import batches (data lineage) — created early because other tables reference it
-- ---------------------------------------------------------------------------
create table if not exists public.import_batches (
  id            uuid primary key default gen_random_uuid(),
  source_file   text,
  import_type   text not null default 'training_record',
  data_source   text not null default 'Excel Import'
                check (data_source in ('Historical Excel','System Entry','Excel Import')),
  total_records     int default 0,
  valid_records     int default 0,
  invalid_records   int default 0,
  duplicate_records int default 0,
  new_records       int default 0,
  updated_records   int default 0,
  imported_records  int default 0,
  status        text not null default 'completed' check (status in ('preview','completed','failed')),
  summary       jsonb,
  imported_by   uuid references auth.users(id),
  imported_at   timestamptz not null default now()
);

create table if not exists public.import_issues (
  id          bigint generated always as identity primary key,
  batch_id    uuid references public.import_batches(id) on delete cascade,
  sheet       text,
  row_no      int,
  severity    text not null default 'warning' check (severity in ('error','warning','info')),
  issue_type  text,
  message     text,
  raw         jsonb,
  created_at  timestamptz not null default now()
);

-- Common audit / lineage columns are repeated per table (explicit > clever).

-- ---------------------------------------------------------------------------
-- Organisation master data
-- ---------------------------------------------------------------------------
create table if not exists public.companies (
  id          bigint generated always as identity primary key,
  code        text unique not null,
  name        text not null,
  area_code   text,
  area_name   text,
  is_active   boolean not null default true,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create table if not exists public.business_groups (
  id          bigint generated always as identity primary key,
  code        text unique not null,
  name        text,
  is_active   boolean not null default true,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create table if not exists public.departments (
  id                bigint generated always as identity primary key,
  code              text unique,
  name              text not null,
  business_group_id bigint references public.business_groups(id),
  aliases           text[] not null default '{}',
  is_active         boolean not null default true,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now()
);
create unique index if not exists departments_name_uq on public.departments (lower(name)) where code is null;

create table if not exists public.sections (
  id            bigint generated always as identity primary key,
  department_id bigint references public.departments(id),
  name          text not null,
  is_active     boolean not null default true,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  unique (department_id, name)
);

create table if not exists public.level_groups (
  id          bigint generated always as identity primary key,
  code        text unique not null,
  name        text not null,
  sort_order  int,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create table if not exists public.positions (
  id             bigint generated always as identity primary key,
  code           text unique not null,
  name           text not null,
  level_group_id bigint references public.level_groups(id),
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- Employees
-- ---------------------------------------------------------------------------
create table if not exists public.employees (
  id                  bigint generated always as identity primary key,
  employee_code       text unique not null,
  title_th            text,
  first_name_th       text,
  last_name_th        text,
  nickname            text,
  legacy_title        text,
  legacy_first_name   text,
  legacy_last_name    text,
  legacy_nickname     text,
  company_id          bigint references public.companies(id),
  business_group_id   bigint references public.business_groups(id),
  department_id       bigint references public.departments(id),
  section_id          bigint references public.sections(id),
  position_id         bigint references public.positions(id),
  level_group_id      bigint references public.level_groups(id),
  job_level           int,
  job_title           text,
  job_group           text,
  work_location       text,
  employment_type     text,
  employment_status   text,
  hire_date           date,
  probation_date      date,
  termination_date    date,
  name_check_result   text,
  in_hr_master        boolean not null default true,
  full_name           text generated always as (
                        trim(coalesce(first_name_th, legacy_first_name, '') || ' ' || coalesce(last_name_th, legacy_last_name, ''))
                      ) stored,
  data_source         text not null default 'System Entry'
                      check (data_source in ('Historical Excel','System Entry','Excel Import')),
  import_batch_id     uuid references public.import_batches(id),
  import_date         timestamptz,
  created_by          uuid references auth.users(id),
  created_at          timestamptz not null default now(),
  updated_by          uuid references auth.users(id),
  updated_at          timestamptz not null default now(),
  deleted_by          uuid references auth.users(id),
  deleted_at          timestamptz
);
create index if not exists employees_dept_idx on public.employees (department_id);
create index if not exists employees_name_trgm on public.employees using gin (full_name extensions.gin_trgm_ops);

-- ---------------------------------------------------------------------------
-- Training master data
-- ---------------------------------------------------------------------------
create table if not exists public.training_types (
  id          bigint generated always as identity primary key,
  name        text unique not null,
  is_internal boolean not null default true,
  sort_order  int,
  is_active   boolean not null default true,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create table if not exists public.training_categories (
  id          bigint generated always as identity primary key,
  name        text unique not null,
  description text,
  is_active   boolean not null default true,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create table if not exists public.training_providers (
  id          bigint generated always as identity primary key,
  name        text unique not null,
  contact     text,
  phone       text,
  email       text,
  remark      text,
  is_active   boolean not null default true,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create table if not exists public.trainers (
  id          bigint generated always as identity primary key,
  name        text unique not null,
  is_internal boolean not null default false,
  employee_id bigint references public.employees(id),
  provider_id bigint references public.training_providers(id),
  expertise   text,
  remark      text,
  is_active   boolean not null default true,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create table if not exists public.expense_categories (
  id          bigint generated always as identity primary key,
  name        text unique not null,
  name_th     text,
  cost_group  text not null default 'Other'
              check (cost_group in ('Course Fee','Trainer Fee','Food','Accommodation','Transportation','Venue','Material','Other')),
  is_food     boolean not null default false,
  is_system   boolean not null default false,
  sort_order  int,
  is_active   boolean not null default true,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create table if not exists public.training_courses (
  id                bigint generated always as identity primary key,
  course_code       text unique,
  course_name       text not null,
  course_key        text unique not null,          -- normalized name, the duplicate-protection key
  category_id       bigint references public.training_categories(id),
  training_type_id  bigint references public.training_types(id),
  objective         text,
  provider_id       bigint references public.training_providers(id),
  trainer_id        bigint references public.trainers(id),
  standard_hours    numeric(8,2),
  standard_cost     numeric(14,2),
  status            text not null default 'Active' check (status in ('Active','Inactive')),
  remark            text,
  data_source       text not null default 'System Entry'
                    check (data_source in ('Historical Excel','System Entry','Excel Import')),
  import_batch_id   uuid references public.import_batches(id),
  import_date       timestamptz,
  created_by        uuid references auth.users(id),
  created_at        timestamptz not null default now(),
  updated_by        uuid references auth.users(id),
  updated_at        timestamptz not null default now(),
  deleted_by        uuid references auth.users(id),
  deleted_at        timestamptz
);
create index if not exists training_courses_name_trgm on public.training_courses using gin (course_name extensions.gin_trgm_ops);

create table if not exists public.training_sessions (
  id                bigint generated always as identity primary key,
  session_code      text unique,
  legacy_course_id  int unique,                    -- Excel "Course ID" (1 row = 1 session)
  course_id         bigint not null references public.training_courses(id),
  session_name      text not null,                 -- full original title incl. รุ่นที่ N
  training_type_id  bigint references public.training_types(id),
  start_date        date,
  end_date          date,
  start_time        time,
  end_time          time,
  training_hours    numeric(8,2),
  fiscal_year       int not null,                  -- calendar year (C.E.) used for reporting
  legacy_month_text text,
  trainer_id        bigint references public.trainers(id),
  provider_id       bigint references public.training_providers(id),
  location          text,
  budget_amount     numeric(14,2),
  status            text not null default 'Completed'
                    check (status in ('Draft','Planned','Scheduled','In Progress','Completed','Cancelled')),
  remark            text,
  data_source       text not null default 'System Entry'
                    check (data_source in ('Historical Excel','System Entry','Excel Import')),
  import_batch_id   uuid references public.import_batches(id),
  import_date       timestamptz,
  created_by        uuid references auth.users(id),
  created_at        timestamptz not null default now(),
  updated_by        uuid references auth.users(id),
  updated_at        timestamptz not null default now(),
  deleted_by        uuid references auth.users(id),
  deleted_at        timestamptz,
  check (end_date is null or start_date is null or end_date >= start_date)
);
create index if not exists training_sessions_course_idx on public.training_sessions (course_id);
create index if not exists training_sessions_date_idx on public.training_sessions (start_date);
create index if not exists training_sessions_year_idx on public.training_sessions (fiscal_year);
-- natural key for sessions created without a legacy id
create unique index if not exists training_sessions_natural_uq
  on public.training_sessions (course_id, session_name, coalesce(start_date, make_date(fiscal_year,1,1)), coalesce(training_type_id, 0))
  where deleted_at is null and legacy_course_id is null;

-- Training record = one employee in one session (+ result)
create table if not exists public.training_participants (
  id                 bigint generated always as identity primary key,
  session_id         bigint not null references public.training_sessions(id),
  employee_id        bigint not null references public.employees(id),
  -- snapshot of the employee's org at training time (history must not move when HR data changes)
  company_id         bigint references public.companies(id),
  department_id      bigint references public.departments(id),
  level_group_id     bigint references public.level_groups(id),
  position_id        bigint references public.positions(id),
  attendance_status  text not null default 'Attended'
                     check (attendance_status in ('Registered','Attended','Absent','Cancelled')),
  completion_status  text not null default 'Completed'
                     check (completion_status in ('Completed','Not Completed','In Progress','Pending')),
  training_hours     numeric(8,2),                 -- override; null = session hours
  score              numeric(6,2),
  certificate_no     text,
  certificate_url    text,
  evaluation_score   numeric(6,2),
  legacy_value       numeric(8,2),                 -- Excel col T "ค่าที่บันทึก (ตามไฟล์เดิม)" kept verbatim
  remark             text,
  data_source        text not null default 'System Entry'
                     check (data_source in ('Historical Excel','System Entry','Excel Import')),
  import_batch_id    uuid references public.import_batches(id),
  import_date        timestamptz,
  created_by         uuid references auth.users(id),
  created_at         timestamptz not null default now(),
  updated_by         uuid references auth.users(id),
  updated_at         timestamptz not null default now(),
  deleted_by         uuid references auth.users(id),
  deleted_at         timestamptz
);
create unique index if not exists training_participants_uq
  on public.training_participants (session_id, employee_id) where deleted_at is null;
create index if not exists training_participants_emp_idx on public.training_participants (employee_id);
create index if not exists training_participants_dept_idx on public.training_participants (department_id);

create table if not exists public.training_evaluations (
  id              bigint generated always as identity primary key,
  participant_id  bigint not null references public.training_participants(id) on delete cascade,
  evaluation_type text not null default 'Reaction',
  score           numeric(6,2),
  comment         text,
  created_by      uuid references auth.users(id),
  created_at      timestamptz not null default now()
);

-- Expenses always belong to a session (RULE 10)
create table if not exists public.training_expenses (
  id                  bigint generated always as identity primary key,
  session_id          bigint not null references public.training_sessions(id),
  expense_category_id bigint not null references public.expense_categories(id),
  description         text,
  meal_type           text check (meal_type in ('Breakfast','Lunch','Dinner','Coffee Break','Snack')),
  quantity            numeric(12,2) not null default 1 check (quantity >= 0),
  unit_price          numeric(14,2) not null default 0 check (unit_price >= 0),
  amount              numeric(16,2) generated always as (round(quantity * unit_price, 2)) stored,
  expense_date        date,
  vendor              text,
  invoice_no          text,
  remark              text,
  data_source         text not null default 'System Entry'
                      check (data_source in ('Historical Excel','System Entry','Excel Import')),
  import_batch_id     uuid references public.import_batches(id),
  created_by          uuid references auth.users(id),
  created_at          timestamptz not null default now(),
  updated_by          uuid references auth.users(id),
  updated_at          timestamptz not null default now(),
  deleted_by          uuid references auth.users(id),
  deleted_at          timestamptz
);
create index if not exists training_expenses_session_idx on public.training_expenses (session_id);

create table if not exists public.training_budgets (
  id                  bigint generated always as identity primary key,
  fiscal_year         int not null,
  company_id          bigint references public.companies(id),
  department_id       bigint references public.departments(id),
  expense_category_id bigint references public.expense_categories(id),
  budget_amount       numeric(16,2) not null default 0,
  remark              text,
  created_by          uuid references auth.users(id),
  created_at          timestamptz not null default now(),
  updated_by          uuid references auth.users(id),
  updated_at          timestamptz not null default now()
);
create unique index if not exists training_budgets_uq
  on public.training_budgets (fiscal_year, coalesce(company_id,0), coalesce(department_id,0), coalesce(expense_category_id,0));

create table if not exists public.app_settings (
  key         text primary key,
  value       jsonb not null,
  updated_at  timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- Audit log
-- ---------------------------------------------------------------------------
create table if not exists public.audit_logs (
  id          bigint generated always as identity primary key,
  table_name  text not null,
  record_id   text,
  action      text not null check (action in ('INSERT','UPDATE','DELETE','SOFT_DELETE','RESTORE')),
  old_data    jsonb,
  new_data    jsonb,
  changed_fields text[],
  changed_by  uuid,
  changed_by_email text,
  changed_at  timestamptz not null default now()
);
create index if not exists audit_logs_table_idx on public.audit_logs (table_name, record_id);
create index if not exists audit_logs_time_idx on public.audit_logs (changed_at desc);

-- ---------------------------------------------------------------------------
-- Seed reference data (values found in Excel + requirement defaults)
-- ---------------------------------------------------------------------------
insert into public.training_types (name, is_internal, sort_order) values
  ('Inhouse', true, 1), ('Public', false, 2), ('Online', false, 3)
on conflict (name) do nothing;

insert into public.expense_categories (name, name_th, cost_group, is_food, is_system, sort_order) values
  ('Course Fee','ค่าลงทะเบียน/ค่าหลักสูตร','Course Fee',false,true,1),
  ('Trainer Fee','ค่าวิทยากร','Trainer Fee',false,true,2),
  ('Food','ค่าอาหาร','Food',true,true,3),
  ('Beverage','ค่าเครื่องดื่ม','Food',true,true,4),
  ('Accommodation','ค่าที่พัก','Accommodation',false,true,5),
  ('Transportation','ค่าเดินทาง','Transportation',false,true,6),
  ('Venue','ค่าสถานที่','Venue',false,true,7),
  ('Training Material','ค่าเอกสาร/อุปกรณ์การอบรม','Material',false,true,8),
  ('Certificate','ค่าใบประกาศ','Material',false,true,9),
  ('Equipment','ค่าอุปกรณ์','Material',false,true,10),
  ('Printing','ค่าพิมพ์เอกสาร','Material',false,true,11),
  ('Parking','ค่าจอดรถ','Transportation',false,true,12),
  ('Miscellaneous','ค่าเบ็ดเตล็ด','Other',false,true,13),
  ('Other Expense','ค่าใช้จ่ายอื่น ๆ','Other',false,true,14)
on conflict (name) do nothing;

insert into public.app_settings (key, value) values
  ('training_target_per_year', '2'::jsonb)   -- Excel Dashboard: "ผ่านเป้า ≥ 2 หลักสูตร/ปี"
on conflict (key) do nothing;
