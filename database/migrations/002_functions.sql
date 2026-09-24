-- ============================================================================
-- ASW Training Record — 002 Functions, triggers, views, analytics RPCs
-- ============================================================================

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

-- Course master key: collapse whitespace and strip a trailing "รุ่นที่ N" / "รุ่น N" /
-- "ครั้งที่ N" / "(ครั้งที่ N)" so every round of the same course maps to one course.
-- Titles like "DCP รุ่นที่ 341/2023" keep their suffix (different programmes per year).
create or replace function public.normalize_course_name(p text)
returns text language sql immutable as $$
  select btrim(regexp_replace(
           regexp_replace(regexp_replace(coalesce(p,''), '\s+', ' ', 'g'),
             '\s*(\((รุ่นที่|รุ่น|ครั้งที่)\s*\d+\)|(รุ่นที่|รุ่น|ครั้งที่)\s*\.?\s*\d+)\s*$', ''),
           '\s+', ' ', 'g'))
$$;

create or replace function public.course_key(p text)
returns text language sql immutable as $$
  select lower(public.normalize_course_name(p))
$$;

create or replace function public.clean_text(p text)
returns text language sql immutable as $$
  select nullif(btrim(regexp_replace(coalesce(p,''), '\s+', ' ', 'g')), '')
$$;

create or replace function public.try_date(p text)
returns date language plpgsql immutable as $$
begin
  if p is null or btrim(p) = '' then return null; end if;
  return p::date;
exception when others then return null;
end $$;

create or replace function public.try_num(p text)
returns numeric language plpgsql immutable as $$
begin
  if p is null or btrim(p) = '' then return null; end if;
  return p::numeric;
exception when others then return null;
end $$;

-- Role helpers (security definer so policies can call them without recursion)
create or replace function public.current_app_role()
returns text language sql stable security definer set search_path = public as $$
  select coalesce((select role from public.profiles where id = auth.uid() and is_active), 'none')
$$;

create or replace function public.is_admin()
returns boolean language sql stable security definer set search_path = public as $$
  select public.current_app_role() = 'admin'
$$;

create or replace function public.can_edit()
returns boolean language sql stable security definer set search_path = public as $$
  select public.current_app_role() in ('admin','hr_training')
$$;

-- Caller check usable inside SECURITY DEFINER functions (current_user is the owner there).
-- SQL editor / service role (no JWT or role=service_role) is trusted; API callers need admin/hr_training.
create or replace function public.caller_can_edit()
returns boolean language sql stable security definer set search_path = public as $$
  select case coalesce(nullif(current_setting('request.jwt.claims', true),'')::jsonb->>'role', 'service_role')
           when 'service_role' then true
           when 'authenticated' then public.can_edit()
           else false end
$$;

create or replace function public.can_view()
returns boolean language sql stable security definer set search_path = public as $$
  select public.current_app_role() in ('admin','hr_training','viewer')
$$;

-- ---------------------------------------------------------------------------
-- New user → profile. The very first user becomes admin (bootstrap); others viewer.
-- ---------------------------------------------------------------------------
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, email, full_name, role)
  values (new.id, new.email,
          coalesce(new.raw_user_meta_data->>'full_name', split_part(new.email,'@',1)),
          case when exists (select 1 from public.profiles) then 'viewer' else 'admin' end)
  on conflict (id) do nothing;
  return new;
end $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.handle_new_user();

-- ---------------------------------------------------------------------------
-- updated_at / created_by / updated_by stamping
-- ---------------------------------------------------------------------------
create or replace function public.stamp_row()
returns trigger language plpgsql as $$
declare j jsonb := to_jsonb(new);
begin
  -- nested IFs: a table without the column must never evaluate new.<column>
  if tg_op = 'INSERT' and j ? 'created_by' then
    if j->>'created_by' is null then new.created_by := auth.uid(); end if;
  end if;
  if j ? 'updated_at' then new.updated_at := now(); end if;
  if j ? 'updated_by' then new.updated_by := auth.uid(); end if;
  if tg_op = 'UPDATE' and j ? 'deleted_at' then
    if j->>'deleted_at' is not null and to_jsonb(old)->>'deleted_at' is null then new.deleted_by := auth.uid(); end if;
  end if;
  return new;
end $$;

-- ---------------------------------------------------------------------------
-- Audit trigger: original value / updated value / who / when
-- Bulk imports set app.bulk_import=on and are traced through import_batches instead.
-- ---------------------------------------------------------------------------
create or replace function public.audit_row()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_old jsonb; v_new jsonb; v_action text; v_changed text[]; v_email text;
  v_ignore text[] := array['updated_at','updated_by','created_at','created_by'];
begin
  if coalesce(current_setting('app.bulk_import', true), 'off') = 'on' then
    return coalesce(new, old);
  end if;
  v_old := case when tg_op in ('UPDATE','DELETE') then to_jsonb(old) end;
  v_new := case when tg_op in ('INSERT','UPDATE') then to_jsonb(new) end;
  v_action := tg_op;
  if tg_op = 'UPDATE' then
    select array_agg(k) into v_changed
      from jsonb_object_keys(v_new) k
     where not (k = any(v_ignore)) and (v_old->k) is distinct from (v_new->k);
    if v_changed is null then return new; end if;
    if (v_old->>'deleted_at') is null and (v_new->>'deleted_at') is not null then v_action := 'SOFT_DELETE';
    elsif (v_old->>'deleted_at') is not null and (v_new->>'deleted_at') is null then v_action := 'RESTORE';
    end if;
  end if;
  select email into v_email from public.profiles where id = auth.uid();
  insert into public.audit_logs (table_name, record_id, action, old_data, new_data, changed_fields, changed_by, changed_by_email)
  values (tg_table_name, coalesce(v_new->>'id', v_old->>'id', v_new->>'key'), v_action,
          case when tg_op = 'UPDATE' then (select jsonb_object_agg(k, v_old->k) from unnest(v_changed) k) else v_old end,
          case when tg_op = 'UPDATE' then (select jsonb_object_agg(k, v_new->k) from unnest(v_changed) k) else v_new end,
          v_changed, auth.uid(), v_email);
  return coalesce(new, old);
end $$;

do $$
declare t text;
begin
  foreach t in array array[
    'companies','business_groups','departments','sections','level_groups','positions','employees',
    'training_types','training_categories','training_providers','trainers','expense_categories',
    'training_courses','training_sessions','training_participants','training_expenses',
    'training_budgets','profiles','app_settings']
  loop
    execute format('drop trigger if exists trg_stamp on public.%I', t);
    execute format('create trigger trg_stamp before insert or update on public.%I for each row execute function public.stamp_row()', t);
    execute format('drop trigger if exists trg_audit on public.%I', t);
    execute format('create trigger trg_audit after insert or update or delete on public.%I for each row execute function public.audit_row()', t);
  end loop;
end $$;

-- ---------------------------------------------------------------------------
-- Analytic views (security_invoker → RLS of the caller applies)
-- ---------------------------------------------------------------------------
create or replace view public.v_session_cost with (security_invoker = true) as
select s.id as session_id,
       coalesce(sum(e.amount), 0)::numeric(16,2) as total_cost,
       coalesce(sum(e.amount) filter (where c.cost_group = 'Course Fee'), 0)     as cost_course_fee,
       coalesce(sum(e.amount) filter (where c.cost_group = 'Trainer Fee'), 0)    as cost_trainer_fee,
       coalesce(sum(e.amount) filter (where c.cost_group = 'Food'), 0)           as cost_food,
       coalesce(sum(e.amount) filter (where c.cost_group = 'Accommodation'), 0)  as cost_accommodation,
       coalesce(sum(e.amount) filter (where c.cost_group = 'Transportation'), 0) as cost_transportation,
       coalesce(sum(e.amount) filter (where c.cost_group = 'Venue'), 0)          as cost_venue,
       coalesce(sum(e.amount) filter (where c.cost_group = 'Material'), 0)       as cost_material,
       coalesce(sum(e.amount) filter (where c.cost_group = 'Other'), 0)          as cost_other,
       count(e.id) as expense_items
  from public.training_sessions s
  left join public.training_expenses e on e.session_id = s.id and e.deleted_at is null
  left join public.expense_categories c on c.id = e.expense_category_id
 group by s.id;

create or replace view public.v_session_summary with (security_invoker = true) as
select s.*,
       c.course_name, c.course_key, c.category_id,
       tt.name  as training_type,
       cat.name as category_name,
       tr.name  as trainer_name,
       pr.name  as provider_name,
       coalesce(p.participant_count, 0) as participant_count,
       coalesce(sc.total_cost, 0)       as total_cost,
       sc.cost_food, sc.cost_course_fee, sc.cost_trainer_fee,
       case when coalesce(p.participant_count,0) > 0 then round(coalesce(sc.total_cost,0) / p.participant_count, 2) end as cost_per_participant,
       case when coalesce(s.training_hours,0) > 0 then round(coalesce(sc.total_cost,0) / s.training_hours, 2) end as cost_per_hour,
       extract(month from s.start_date)::int as month
  from public.training_sessions s
  join public.training_courses c on c.id = s.course_id
  left join public.training_types tt on tt.id = coalesce(s.training_type_id, c.training_type_id)
  left join public.training_categories cat on cat.id = c.category_id
  left join public.trainers tr on tr.id = coalesce(s.trainer_id, c.trainer_id)
  left join public.training_providers pr on pr.id = coalesce(s.provider_id, c.provider_id)
  left join (select session_id, count(*) participant_count
               from public.training_participants where deleted_at is null group by session_id) p on p.session_id = s.id
  left join public.v_session_cost sc on sc.session_id = s.id
 where s.deleted_at is null;

-- One row per participant (= training record) with every reporting dimension
create or replace view public.v_participant_fact with (security_invoker = true) as
select tp.id                                   as participant_id,
       tp.session_id,
       s.course_id,
       tp.employee_id,
       e.employee_code,
       e.full_name                             as employee_name,
       e.nickname,
       e.employment_status,
       s.session_name,
       c.course_name,
       s.start_date,
       s.end_date,
       s.fiscal_year                           as year,
       extract(month from s.start_date)::int   as month,
       coalesce(s.training_type_id, c.training_type_id) as training_type_id,
       tt.name                                 as training_type,
       tt.is_internal,
       c.category_id,
       cat.name                                as category_name,
       coalesce(s.provider_id, c.provider_id)  as provider_id,
       pr.name                                 as provider_name,
       coalesce(s.trainer_id, c.trainer_id)    as trainer_id,
       tr.name                                 as trainer_name,
       s.location,
       s.status                                as session_status,
       tp.company_id,
       co.name                                 as company_name,
       tp.department_id,
       d.name                                  as department_name,
       d.business_group_id,
       bg.code                                 as business_group,
       e.section_id,
       sec.name                                as section_name,
       tp.level_group_id,
       lg.name                                 as level_group_name,
       lg.sort_order                           as level_group_sort,
       tp.position_id,
       po.name                                 as position_name,
       coalesce(tp.training_hours, s.training_hours) as training_hours,
       tp.attendance_status,
       tp.completion_status,
       tp.score,
       tp.evaluation_score,
       tp.certificate_no,
       tp.legacy_value,
       tp.data_source,
       coalesce(sc.total_cost, 0)              as session_total_cost,
       coalesce(pc.cnt, 0)                     as session_participants,
       case when coalesce(pc.cnt,0) > 0 then coalesce(sc.total_cost,0) / pc.cnt else 0 end as allocated_cost,
       e.in_hr_master
  from public.training_participants tp
  join public.training_sessions s on s.id = tp.session_id and s.deleted_at is null
  join public.training_courses  c on c.id = s.course_id
  join public.employees         e on e.id = tp.employee_id
  left join public.training_types tt on tt.id = coalesce(s.training_type_id, c.training_type_id)
  left join public.training_categories cat on cat.id = c.category_id
  left join public.training_providers pr on pr.id = coalesce(s.provider_id, c.provider_id)
  left join public.trainers tr on tr.id = coalesce(s.trainer_id, c.trainer_id)
  left join public.companies co on co.id = tp.company_id
  left join public.departments d on d.id = tp.department_id
  left join public.business_groups bg on bg.id = d.business_group_id
  left join public.sections sec on sec.id = e.section_id
  left join public.level_groups lg on lg.id = tp.level_group_id
  left join public.positions po on po.id = tp.position_id
  left join public.v_session_cost sc on sc.session_id = s.id
  left join (select session_id, count(*) cnt from public.training_participants
              where deleted_at is null group by session_id) pc on pc.session_id = s.id
 where tp.deleted_at is null;

-- ---------------------------------------------------------------------------
-- Filtering: one function every report/dashboard shares
-- p = { years:[2025], months:[1..12], date_from, date_to, company_ids:[], department_ids:[],
--       business_group_ids:[], section_ids:[], level_group_ids:[], training_type_ids:[],
--       category_ids:[], course_ids:[], provider_ids:[], trainer_ids:[], employee_ids:[],
--       session_ids:[] }
-- ---------------------------------------------------------------------------
create or replace function public._ids(p jsonb, k text)
returns bigint[] language sql immutable as $$
  select case when p ? k and jsonb_typeof(p->k) = 'array' and jsonb_array_length(p->k) > 0
              then array(select (jsonb_array_elements_text(p->k))::bigint) end
$$;

create or replace function public.fact_filtered(p jsonb)
returns setof public.v_participant_fact
language sql stable security invoker set search_path = public as $$
  select f.* from public.v_participant_fact f
   where (public._ids(p,'years') is null or f.year = any(public._ids(p,'years')))
     and (public._ids(p,'months') is null or f.month = any(public._ids(p,'months')::int[]))
     and (p->>'date_from' is null or f.start_date >= (p->>'date_from')::date)
     and (p->>'date_to'   is null or f.start_date <= (p->>'date_to')::date)
     and (public._ids(p,'company_ids') is null or f.company_id = any(public._ids(p,'company_ids')))
     and (public._ids(p,'department_ids') is null or f.department_id = any(public._ids(p,'department_ids')))
     and (public._ids(p,'business_group_ids') is null or f.business_group_id = any(public._ids(p,'business_group_ids')))
     and (public._ids(p,'section_ids') is null or f.section_id = any(public._ids(p,'section_ids')))
     and (public._ids(p,'level_group_ids') is null or f.level_group_id = any(public._ids(p,'level_group_ids')))
     and (public._ids(p,'training_type_ids') is null or f.training_type_id = any(public._ids(p,'training_type_ids')))
     and (public._ids(p,'category_ids') is null or f.category_id = any(public._ids(p,'category_ids')))
     and (public._ids(p,'course_ids') is null or f.course_id = any(public._ids(p,'course_ids')))
     and (public._ids(p,'provider_ids') is null or f.provider_id = any(public._ids(p,'provider_ids')))
     and (public._ids(p,'trainer_ids') is null or f.trainer_id = any(public._ids(p,'trainer_ids')))
     and (public._ids(p,'employee_ids') is null or f.employee_id = any(public._ids(p,'employee_ids')))
     and (public._ids(p,'session_ids') is null or f.session_id = any(public._ids(p,'session_ids')))
$$;

-- Aggregate a filtered fact set by one dimension. Used by the Report Center.
-- p_group: year | month | year_month | department | company | business_group | section | level_group
--          | position | course | session | training_type | category | provider | trainer | employee
create or replace function public.rpc_report(p jsonb, p_group text)
returns table (
  group_key text, group_label text, sort_key text,
  sessions bigint, courses bigint, participants bigint, employees bigint,
  training_hours numeric, total_cost numeric, cost_per_participant numeric,
  cost_per_hour numeric, avg_hours_per_person numeric, inhouse bigint, public_cnt bigint, online bigint,
  last_date date
)
language sql stable security invoker set search_path = public as $$
  with f as (select * from public.fact_filtered(p)),
  g as (
    select
      case p_group
        when 'year' then f.year::text
        when 'month' then f.month::text
        when 'year_month' then f.year::text || '-' || lpad(coalesce(f.month,0)::text,2,'0')
        when 'department' then f.department_id::text
        when 'company' then f.company_id::text
        when 'business_group' then f.business_group_id::text
        when 'section' then f.section_id::text
        when 'level_group' then f.level_group_id::text
        when 'position' then f.position_id::text
        when 'course' then f.course_id::text
        when 'session' then f.session_id::text
        when 'training_type' then f.training_type_id::text
        when 'category' then f.category_id::text
        when 'provider' then f.provider_id::text
        when 'trainer' then f.trainer_id::text
        when 'employee' then f.employee_id::text
      end as gk,
      case p_group
        when 'year' then (f.year + 543)::text
        when 'month' then f.month::text
        when 'year_month' then f.year::text || '-' || lpad(coalesce(f.month,0)::text,2,'0')
        when 'department' then f.department_name
        when 'company' then f.company_name
        when 'business_group' then f.business_group
        when 'section' then f.section_name
        when 'level_group' then f.level_group_name
        when 'position' then f.position_name
        when 'course' then f.course_name
        when 'session' then f.session_name || coalesce(' (' || to_char(f.start_date,'DD/MM/YYYY') || ')','')
        when 'training_type' then f.training_type
        when 'category' then f.category_name
        when 'provider' then f.provider_name
        when 'trainer' then f.trainer_name
        when 'employee' then f.employee_code || ' ' || f.employee_name
      end as gl,
      case p_group when 'level_group' then lpad(coalesce(f.level_group_sort,99)::text,3,'0') else null end as sk,
      f.*
    from f
  ),
  sess as (  -- session-level hours/cost, counted once per session inside each group
    select gk, session_id, max(coalesce(g.training_hours,0)) as s_hours
      from g group by gk, session_id
  )
  select g.gk, coalesce(max(g.gl), 'ไม่ระบุ'), coalesce(max(g.sk), max(g.gl)),
         count(distinct g.session_id), count(distinct g.course_id), count(*), count(distinct g.employee_id),
         round(coalesce(sum(g.training_hours),0),2),
         round(sum(g.allocated_cost),2),
         case when count(*) > 0 then round(sum(g.allocated_cost)/count(*),2) end,
         case when (select sum(s_hours) from sess where sess.gk is not distinct from g.gk) > 0
              then round(sum(g.allocated_cost) / (select sum(s_hours) from sess where sess.gk is not distinct from g.gk), 2) end,
         case when count(distinct g.employee_id) > 0 then round(coalesce(sum(g.training_hours),0)/count(distinct g.employee_id),2) end,
         count(*) filter (where g.training_type = 'Inhouse'),
         count(*) filter (where g.training_type = 'Public'),
         count(*) filter (where g.training_type = 'Online'),
         max(g.start_date)
    from g
   group by g.gk
$$;

-- Employee summary for "ผ่านเป้า ≥ N หลักสูตร/ปี"
create or replace function public.rpc_employee_target(p jsonb)
returns table (employee_id bigint, employee_code text, employee_name text, department_name text,
               level_group_name text, year int, courses bigint, training_hours numeric, total_cost numeric, met_target boolean)
language sql stable security invoker set search_path = public as $$
  with t as (select coalesce((select (value)::text::int from public.app_settings where key='training_target_per_year'),2) n)
  select f.employee_id, max(f.employee_code), max(f.employee_name), max(f.department_name), max(f.level_group_name),
         f.year, count(*), round(coalesce(sum(f.training_hours),0),2), round(sum(f.allocated_cost),2),
         count(*) >= (select n from t)
    from public.fact_filtered(p) f
   group by f.employee_id, f.year
$$;

-- ---------------------------------------------------------------------------
-- Dashboard: mirrors the Excel "Dashboard" sheet (year + month selector) and adds
-- hours / cost / expense sections. p may contain any fact_filtered keys except years/months.
-- ---------------------------------------------------------------------------
-- ---------------------------------------------------------------------------
-- Dashboard: mirrors the Excel "Dashboard" sheet (year + month selector) and adds
-- hours / cost / expense sections. p may contain any fact_filtered keys except years/months.
-- The filtered fact set is materialized once and every section reads from it.
-- ---------------------------------------------------------------------------
create or replace function public.rpc_dashboard(p jsonb, p_year int, p_month int)
returns jsonb
language sql stable security invoker set search_path = public as $$
with prm as (
  select coalesce(p, '{}'::jsonb) - 'years' - 'months' as base,
         coalesce((select (value)::text::int from public.app_settings where key='training_target_per_year'), 2) as tgt
),
pf as (
  select base, tgt,
         base ?| array['company_ids','department_ids','business_group_ids','section_ids','level_group_ids','employee_ids'] as part_filter
    from prm
),
f as materialized (select x.* from pf, public.fact_filtered(pf.base) x),
fy as materialized (select * from f where year = p_year),
ss as materialized (
  select s.* from public.v_session_summary s, pf
   where s.fiscal_year = p_year
     and (public._ids(pf.base,'training_type_ids') is null or s.training_type_id = any(public._ids(pf.base,'training_type_ids')))
     and (public._ids(pf.base,'category_ids') is null or s.category_id = any(public._ids(pf.base,'category_ids')))
     and (public._ids(pf.base,'course_ids') is null or s.course_id = any(public._ids(pf.base,'course_ids')))
     and (public._ids(pf.base,'provider_ids') is null or s.provider_id = any(public._ids(pf.base,'provider_ids')))
     and (public._ids(pf.base,'trainer_ids') is null or s.trainer_id = any(public._ids(pf.base,'trainer_ids')))
     and (not pf.part_filter or s.id in (select session_id from fy))
)
select jsonb_build_object(
  'kpi', jsonb_build_object(
    'month', (select jsonb_build_object(
        'sessions', count(distinct session_id), 'participants', count(*), 'employees', count(distinct employee_id),
        'hours', coalesce(sum(training_hours),0), 'cost', coalesce(sum(allocated_cost),0),
        'inhouse', count(*) filter (where training_type='Inhouse'),
        'public', count(*) filter (where training_type='Public'),
        'online', count(*) filter (where training_type='Online'))
      from fy where month = p_month),
    'prev_month', (select jsonb_build_object('sessions', count(distinct session_id), 'participants', count(*),
        'employees', count(distinct employee_id), 'cost', coalesce(sum(allocated_cost),0))
      from f where (p_month > 1 and year = p_year and month = p_month - 1) or (p_month = 1 and year = p_year - 1 and month = 12)),
    'ytd', (select jsonb_build_object(
        'sessions', count(distinct session_id), 'participants', count(*), 'employees', count(distinct employee_id),
        'hours', coalesce(sum(training_hours),0), 'cost', coalesce(sum(allocated_cost),0),
        'courses', count(distinct course_id),
        'inhouse', count(*) filter (where training_type='Inhouse'),
        'public', count(*) filter (where training_type='Public'),
        'online', count(*) filter (where training_type='Online'))
      from fy where month <= p_month),
    'ytd_last_year', (select jsonb_build_object('sessions', count(distinct session_id), 'participants', count(*),
        'employees', count(distinct employee_id), 'cost', coalesce(sum(allocated_cost),0))
      from f where year = p_year - 1 and month <= p_month),
    'year', (select jsonb_build_object(
        'sessions', count(distinct session_id), 'participants', count(*), 'employees', count(distinct employee_id),
        'hours', coalesce(sum(training_hours),0), 'cost', coalesce(sum(allocated_cost),0),
        'courses', count(distinct course_id),
        'internal', count(*) filter (where is_internal), 'external', count(*) filter (where not is_internal),
        'internal_sessions', count(distinct session_id) filter (where is_internal),
        'external_sessions', count(distinct session_id) filter (where not is_internal),
        'no_date_sessions', count(distinct session_id) filter (where month is null),
        'no_date_participants', count(*) filter (where month is null),
        'not_in_hr', count(*) filter (where not in_hr_master))
      from fy),
    'target', (select jsonb_build_object('target', (select tgt from pf),
        'met', count(*) filter (where n >= (select tgt from pf)), 'trained', count(*))
      from (select employee_id, count(*) n from fy group by employee_id) x),
    'future_sessions', (select count(*) from ss where start_date > current_date),
    'planned_sessions_year', (select count(*) from ss)
  ),
  'participant_filter', (select part_filter from pf),
  'session_cost', (select jsonb_build_object(
        'year', coalesce(sum(total_cost),0),
        'ytd', coalesce(sum(total_cost) filter (where month <= p_month),0),
        'month', coalesce(sum(total_cost) filter (where month = p_month),0),
        'session_hours', coalesce(sum(training_hours),0),
        'session_hours_ytd', coalesce(sum(training_hours) filter (where month <= p_month),0))
      from ss),
  'monthly', (select jsonb_agg(jsonb_build_object('month', m,
        'sessions', coalesce(x.sessions,0), 'participants', coalesce(x.participants,0),
        'inhouse', coalesce(x.inhouse,0), 'public', coalesce(x.pub,0), 'online', coalesce(x.online,0),
        'employees', coalesce(x.employees,0), 'hours', coalesce(x.hours,0), 'cost', coalesce(x.cost,0)) order by m)
      from generate_series(1,12) m
      left join (select month, count(distinct session_id) sessions, count(*) participants,
                        count(*) filter (where training_type='Inhouse') inhouse,
                        count(*) filter (where training_type='Public') pub,
                        count(*) filter (where training_type='Online') online,
                        count(distinct employee_id) employees, sum(training_hours) hours, sum(allocated_cost) cost
                   from fy group by month) x on x.month = m),
  'yearly', (select jsonb_agg(row_to_json(y) order by y.year) from (
      select f.year, count(distinct session_id) sessions, count(*) participants, count(distinct f.employee_id) employees,
             round(count(*)::numeric / nullif(count(distinct f.employee_id),0), 2) avg_per_person,
             (select count(*) from (select employee_id from f f2 where f2.year = f.year group by employee_id
                                     having count(*) >= (select tgt from pf)) t) met_target,
             round(100.0 * count(*) filter (where training_type='Inhouse') / nullif(count(*),0), 1) pct_inhouse,
             coalesce(sum(training_hours),0) hours, coalesce(sum(allocated_cost),0) cost
        from f where f.year is not null group by f.year) y),
  'by_type', (select jsonb_agg(row_to_json(t) order by t.participants desc) from (
      select coalesce(training_type,'ไม่ระบุ') label, count(distinct session_id) sessions, count(*) participants
        from fy group by training_type) t),
  'by_company', (select jsonb_agg(row_to_json(t) order by t.participants desc) from (
      select coalesce(company_name,'ไม่พบข้อมูลใน Employee Info Report') label, count(*) participants,
             count(distinct employee_id) employees, coalesce(sum(allocated_cost),0) cost
        from fy group by company_name) t),
  'by_level', (select jsonb_agg(row_to_json(t) order by t.sort) from (
      select coalesce(level_group_name,'ไม่ระบุ') label, coalesce(max(level_group_sort),99) sort, count(*) participants,
             count(distinct employee_id) employees,
             round(count(*)::numeric / nullif(count(distinct employee_id),0),2) avg_per_person
        from fy group by level_group_name) t),
  'top_departments', (select jsonb_agg(row_to_json(t)) from (
      select department_id id, coalesce(department_name,'ไม่ระบุ') label, count(*) participants,
             count(distinct employee_id) employees, count(distinct course_id) courses,
             coalesce(sum(training_hours),0) hours, coalesce(sum(allocated_cost),0) cost,
             round(count(*)::numeric / nullif(count(distinct employee_id),0),2) avg_per_person,
             round(coalesce(sum(allocated_cost),0) / nullif(count(distinct employee_id),0),2) cost_per_employee
        from fy group by department_id, department_name
       order by count(*) desc limit 10) t),
  'top_courses', (select jsonb_agg(row_to_json(t)) from (
      select session_id id, max(session_name) label, min(start_date) start_date, max(training_type) training_type,
             count(*) participants, coalesce(sum(training_hours),0) hours, max(session_total_cost) cost,
             round(max(session_total_cost) / nullif(count(*),0),2) cost_per_person
        from fy group by session_id
       order by count(*) desc, min(start_date) limit 10) t),
  'top_course_masters', (select jsonb_agg(row_to_json(t)) from (
      select course_id id, max(course_name) label, count(distinct session_id) sessions, count(*) participants,
             coalesce(sum(training_hours),0) hours, coalesce(sum(allocated_cost),0) cost,
             round(coalesce(sum(allocated_cost),0) / nullif(count(*),0),2) cost_per_person
        from fy group by course_id
       order by count(*) desc limit 10) t),
  'cost_by_department', (select jsonb_agg(row_to_json(t)) from (
      select coalesce(department_name,'ไม่ระบุ') label, coalesce(sum(allocated_cost),0) cost, count(*) participants,
             round(coalesce(sum(allocated_cost),0) / nullif(count(distinct employee_id),0),2) cost_per_employee
        from fy group by department_name having coalesce(sum(allocated_cost),0) > 0
       order by 2 desc limit 15) t),
  'expense_by_group', (select jsonb_agg(row_to_json(t) order by t.amount desc) from (
      select ec.cost_group label, sum(e.amount) amount, count(*) items
        from public.training_expenses e
        join public.expense_categories ec on ec.id = e.expense_category_id
       where e.deleted_at is null and e.session_id in (select id from ss)
       group by ec.cost_group) t),
  'budget', (select jsonb_build_object('budget', coalesce(sum(b.budget_amount),0),
                                       'session_budget', coalesce((select sum(budget_amount) from ss),0))
      from public.training_budgets b, pf
     where b.fiscal_year = p_year
       and (public._ids(pf.base,'department_ids') is null or b.department_id = any(public._ids(pf.base,'department_ids')))
       and (public._ids(pf.base,'company_ids') is null or b.company_id = any(public._ids(pf.base,'company_ids'))))
)
$$;

-- Distinct values for filter dropdowns
create or replace function public.rpc_filter_options()
returns jsonb language sql stable security invoker set search_path = public as $$
  select jsonb_build_object(
    'years', (select coalesce(jsonb_agg(distinct fiscal_year order by fiscal_year), '[]') from public.training_sessions where deleted_at is null),
    'companies', (select coalesce(jsonb_agg(jsonb_build_object('id',id,'name',name) order by name),'[]') from public.companies),
    'departments', (select coalesce(jsonb_agg(jsonb_build_object('id',id,'name',name,'code',code) order by name),'[]') from public.departments where is_active),
    'business_groups', (select coalesce(jsonb_agg(jsonb_build_object('id',id,'name',code) order by code),'[]') from public.business_groups),
    'sections', (select coalesce(jsonb_agg(jsonb_build_object('id',id,'name',name) order by name),'[]') from public.sections where is_active),
    'level_groups', (select coalesce(jsonb_agg(jsonb_build_object('id',id,'name',name) order by sort_order),'[]') from public.level_groups),
    'training_types', (select coalesce(jsonb_agg(jsonb_build_object('id',id,'name',name) order by sort_order),'[]') from public.training_types where is_active),
    'categories', (select coalesce(jsonb_agg(jsonb_build_object('id',id,'name',name) order by name),'[]') from public.training_categories where is_active),
    'courses', (select coalesce(jsonb_agg(jsonb_build_object('id',id,'name',course_name) order by course_name),'[]') from public.training_courses where deleted_at is null),
    'providers', (select coalesce(jsonb_agg(jsonb_build_object('id',id,'name',name) order by name),'[]') from public.training_providers where is_active),
    'trainers', (select coalesce(jsonb_agg(jsonb_build_object('id',id,'name',name) order by name),'[]') from public.trainers where is_active),
    'expense_categories', (select coalesce(jsonb_agg(jsonb_build_object('id',id,'name',name,'name_th',name_th,'cost_group',cost_group,'is_food',is_food) order by sort_order nulls last, name),'[]') from public.expense_categories where is_active)
  )
$$;

-- ---------------------------------------------------------------------------
-- Import engine — shared by the historical migration and the Import Center.
--   p_rows    : jsonb array of flat rows (see docs/03_Import_Format.md)
--   p_options : { dry_run: bool, data_source: 'Historical Excel'|'Excel Import', source_file, import_type }
-- Returns a summary; with dry_run nothing is written (runs inside a savepoint that is rolled back).
-- Duplicate protection: employee_code; course_key; session = legacy_course_id or
-- (course, session_name, start_date|year, type); participant = (session, employee).
-- ---------------------------------------------------------------------------
create or replace function public.import_training_rows(p_rows jsonb, p_options jsonb default '{}'::jsonb)
returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_dry     boolean := coalesce((p_options->>'dry_run')::boolean, false);
  v_source  text    := coalesce(p_options->>'data_source', 'Excel Import');
  v_batch   uuid;
  v_result  jsonb;
  r         jsonb;
  i int := 0;
  n_total int := 0; n_invalid int := 0; n_dup int := 0; n_new int := 0; n_upd int := 0; n_sessions_new int := 0;
  n_emp_new int := 0; n_course_new int := 0;
  issues jsonb := '[]'::jsonb;
  status_list jsonb := '[]'::jsonb;
  v_emp bigint; v_course bigint; v_session bigint; v_type bigint; v_company bigint; v_dept bigint; v_bg bigint;
  v_lg bigint; v_pos bigint; v_cat bigint; v_prov bigint; v_trainer bigint; v_part bigint;
  v_code text; v_course_name text; v_session_name text; v_start date; v_end date; v_year int; v_legacy int;
  v_row_status text; v_existing record; v_msg text;
  seen_keys text[] := '{}'; v_key text;
begin
  if not public.caller_can_edit() then
    raise exception 'permission denied: import requires admin or hr_training role';
  end if;
  if jsonb_typeof(p_rows) <> 'array' then raise exception 'p_rows must be a JSON array'; end if;

  begin  -- savepoint; rolled back for dry runs
    perform set_config('app.bulk_import', 'on', true);

    insert into public.import_batches (source_file, import_type, data_source, status, imported_by)
    values (p_options->>'source_file', coalesce(p_options->>'import_type','training_record'), v_source,
            case when v_dry then 'preview' else 'completed' end, auth.uid())
    returning id into v_batch;

    for r in select * from jsonb_array_elements(p_rows) loop
      i := i + 1;
      n_total := n_total + 1;
      v_row_status := null; v_msg := null;
      v_emp := null; v_session := null;

      v_code        := public.clean_text(r->>'employee_code');
      v_session_name:= public.clean_text(r->>'course_name');
      v_course_name := public.normalize_course_name(r->>'course_name');
      v_start       := public.try_date(r->>'start_date');
      v_end         := public.try_date(r->>'end_date');
      v_year        := coalesce(extract(year from v_start)::int, (r->>'fiscal_year')::int);
      v_legacy      := (r->>'legacy_course_id')::int;

      -- validation ---------------------------------------------------------------
      if v_session_name is null then v_msg := 'ไม่มีชื่อหลักสูตร (course_name)';
      elsif v_year is null then v_msg := 'ไม่มีวันที่อบรมหรือปีที่อบรม';
      elsif r->>'start_date' is not null and btrim(r->>'start_date') <> '' and v_start is null then v_msg := 'วันที่อบรมไม่ถูกต้อง: ' || (r->>'start_date');
      elsif v_end is not null and v_start is not null and v_end < v_start then v_msg := 'วันที่สิ้นสุดก่อนวันที่เริ่ม';
      elsif r->>'training_hours' is not null and btrim(r->>'training_hours') <> '' and coalesce(public.try_num(r->>'training_hours'), -1) < 0 then v_msg := 'ชั่วโมงอบรมไม่ถูกต้อง';
      elsif v_code is not null and v_code !~ '^[0-9A-Za-z-]+$' then v_msg := 'รหัสพนักงานไม่ถูกต้อง: ' || v_code;
      end if;
      if v_msg is not null then
        n_invalid := n_invalid + 1;
        issues := issues || jsonb_build_object('row', coalesce((r->>'row_no')::int, i), 'severity','error','type','invalid','message', v_msg);
        status_list := status_list || jsonb_build_object('row', coalesce((r->>'row_no')::int, i), 'status','invalid','message',v_msg);
        continue;
      end if;

      -- within-file duplicate ----------------------------------------------------------
      v_key := coalesce(v_legacy::text, v_session_name || '|' || coalesce(v_start::text, v_year::text) || '|' || coalesce(r->>'training_type','')) || '#' || coalesce(v_code,'');
      if v_code is not null and v_key = any(seen_keys) then
        n_dup := n_dup + 1;
        issues := issues || jsonb_build_object('row', coalesce((r->>'row_no')::int, i), 'severity','warning','type','duplicate_in_file',
                   'message', 'แถวซ้ำในไฟล์: พนักงาน ' || v_code || ' / ' || v_session_name);
        status_list := status_list || jsonb_build_object('row', coalesce((r->>'row_no')::int, i), 'status','duplicate','message','ซ้ำในไฟล์');
        continue;
      end if;
      seen_keys := seen_keys || v_key;

      -- master data upserts ------------------------------------------------------------
      v_type := null;
      if public.clean_text(r->>'training_type') is not null then
        insert into public.training_types (name, is_internal)
        values (initcap(lower(public.clean_text(r->>'training_type'))), lower(r->>'training_type') = 'inhouse')
        on conflict (name) do nothing;
        select id into v_type from public.training_types where lower(name) = lower(public.clean_text(r->>'training_type'));
      end if;

      v_cat := null;
      if public.clean_text(r->>'category') is not null then
        insert into public.training_categories (name) values (public.clean_text(r->>'category')) on conflict (name) do nothing;
        select id into v_cat from public.training_categories where name = public.clean_text(r->>'category');
      end if;
      v_prov := null;
      if public.clean_text(r->>'provider') is not null then
        insert into public.training_providers (name) values (public.clean_text(r->>'provider')) on conflict (name) do nothing;
        select id into v_prov from public.training_providers where name = public.clean_text(r->>'provider');
      end if;
      v_trainer := null;
      if public.clean_text(r->>'trainer') is not null then
        insert into public.trainers (name, provider_id) values (public.clean_text(r->>'trainer'), v_prov) on conflict (name) do nothing;
        select id into v_trainer from public.trainers where name = public.clean_text(r->>'trainer');
      end if;

      -- course ---------------------------------------------------------------------------
      select id into v_course from public.training_courses where course_key = public.course_key(v_session_name);
      if v_course is null then
        insert into public.training_courses (course_name, course_key, training_type_id, category_id, provider_id, trainer_id,
                                             standard_hours, data_source, import_batch_id, import_date)
        values (v_course_name, public.course_key(v_session_name), v_type, v_cat, v_prov, v_trainer,
                public.try_num(r->>'training_hours'), v_source, v_batch, now())
        returning id into v_course;
        n_course_new := n_course_new + 1;
      end if;

      -- session --------------------------------------------------------------------------
      if v_legacy is not null then
        select id into v_session from public.training_sessions where legacy_course_id = v_legacy;
      end if;
      -- natural-key match only for rows without an Excel Course ID: the source file has a few
      -- Course IDs that repeat the same title/date and the Excel dashboard counts them separately
      if v_session is null and v_legacy is null then
        select id into v_session from public.training_sessions
         where course_id = v_course and session_name = v_session_name and deleted_at is null
           and coalesce(start_date, make_date(fiscal_year,1,1)) = coalesce(v_start, make_date(v_year,1,1))
           and coalesce(training_type_id,0) = coalesce(v_type,0)
         limit 1;
      end if;
      if v_session is null then
        insert into public.training_sessions (legacy_course_id, course_id, session_name, training_type_id, start_date, end_date,
             training_hours, fiscal_year, legacy_month_text, trainer_id, provider_id, location, status,
             data_source, import_batch_id, import_date)
        values (v_legacy, v_course, v_session_name, v_type, v_start, coalesce(v_end, v_start),
             public.try_num(r->>'training_hours'), v_year, public.clean_text(r->>'legacy_month_text'), v_trainer, v_prov,
             public.clean_text(r->>'location'),
             coalesce(public.clean_text(r->>'session_status'),
               case when v_start > current_date then 'Scheduled'
                    when v_start is null and v_code is null then 'Planned'
                    else 'Completed' end),
             v_source, v_batch, now())
        returning id into v_session;
        n_sessions_new := n_sessions_new + 1;
      else
        -- fill gaps only; never overwrite values entered in the system
        update public.training_sessions set
          training_hours = coalesce(training_hours, public.try_num(r->>'training_hours')),
          trainer_id     = coalesce(trainer_id, v_trainer),
          provider_id    = coalesce(provider_id, v_prov),
          location       = coalesce(location, public.clean_text(r->>'location'))
        where id = v_session
          and (training_hours is null or trainer_id is null or provider_id is null or location is null);
      end if;

      if v_code is null then   -- session-only row (planned session without participants)
        status_list := status_list || jsonb_build_object('row', coalesce((r->>'row_no')::int, i), 'status','session_only');
        continue;
      end if;

      -- org master -------------------------------------------------------------------
      v_company := null;
      if public.clean_text(r->>'company_code') is not null then
        insert into public.companies (code, name, area_code, area_name)
        values (public.clean_text(r->>'company_code'), coalesce(public.clean_text(r->>'company_name'), r->>'company_code'),
                public.clean_text(r->>'area_code'), public.clean_text(r->>'area_name'))
        on conflict (code) do nothing;
        select id into v_company from public.companies where code = public.clean_text(r->>'company_code');
      end if;
      v_bg := null;
      if public.clean_text(r->>'business_group') is not null then
        insert into public.business_groups (code, name) values (public.clean_text(r->>'business_group'), public.clean_text(r->>'business_group'))
        on conflict (code) do nothing;
        select id into v_bg from public.business_groups where code = public.clean_text(r->>'business_group');
      end if;
      v_dept := null;
      if public.clean_text(r->>'department_code') is not null then
        select id into v_dept from public.departments where code = public.clean_text(r->>'department_code');
        if v_dept is null then
          insert into public.departments (code, name, business_group_id)
          values (public.clean_text(r->>'department_code'), coalesce(public.clean_text(r->>'department_name'), r->>'department_code'), v_bg)
          returning id into v_dept;
        end if;
      elsif public.clean_text(r->>'department_name') is not null then
        select id into v_dept from public.departments
         where lower(name) = lower(public.clean_text(r->>'department_name'))
            or lower(public.clean_text(r->>'department_name')) = any(select lower(a) from unnest(aliases) a)
         order by code nulls last limit 1;
        if v_dept is null then
          insert into public.departments (name, business_group_id) values (public.clean_text(r->>'department_name'), v_bg)
          returning id into v_dept;
        end if;
      end if;
      v_lg := null;
      if public.clean_text(r->>'level_group_code') is not null then
        insert into public.level_groups (code, name, sort_order)
        values (public.clean_text(r->>'level_group_code'), coalesce(public.clean_text(r->>'level_group_name'), r->>'level_group_code'),
                (r->>'level_group_code')::int)
        on conflict (code) do nothing;
        select id into v_lg from public.level_groups where code = public.clean_text(r->>'level_group_code');
      end if;
      v_pos := null;
      if public.clean_text(r->>'position_code') is not null then
        insert into public.positions (code, name, level_group_id)
        values (public.clean_text(r->>'position_code'), coalesce(public.clean_text(r->>'position_name'), r->>'position_code'), v_lg)
        on conflict (code) do nothing;
        select id into v_pos from public.positions where code = public.clean_text(r->>'position_code');
      end if;

      -- employee ---------------------------------------------------------------------
      select id into v_emp from public.employees where employee_code = v_code;
      if v_emp is null then
        insert into public.employees (employee_code, title_th, first_name_th, last_name_th, nickname,
             legacy_title, legacy_first_name, legacy_last_name, legacy_nickname,
             company_id, business_group_id, department_id, position_id, level_group_id,
             job_level, job_title, job_group, work_location, employment_type, employment_status,
             hire_date, probation_date, termination_date, name_check_result, in_hr_master,
             data_source, import_batch_id, import_date)
        values (v_code, public.clean_text(r->>'title_th'), public.clean_text(r->>'first_name_th'), public.clean_text(r->>'last_name_th'),
             public.clean_text(r->>'nickname'), public.clean_text(r->>'legacy_title'), public.clean_text(r->>'legacy_first_name'),
             public.clean_text(r->>'legacy_last_name'), public.clean_text(r->>'legacy_nickname'),
             v_company, v_bg, v_dept, v_pos, v_lg,
             (r->>'job_level')::int, public.clean_text(r->>'job_title'), public.clean_text(r->>'job_group'),
             public.clean_text(r->>'work_location'), public.clean_text(r->>'employment_type'), public.clean_text(r->>'employment_status'),
             public.try_date(r->>'hire_date'), public.try_date(r->>'probation_date'), public.try_date(r->>'termination_date'),
             public.clean_text(r->>'name_check_result'), coalesce((r->>'in_hr_master')::boolean, true),
             v_source, v_batch, now())
        returning id into v_emp;
        n_emp_new := n_emp_new + 1;
      else
        -- newer HR data wins for current attributes; history keeps its own snapshot
        update public.employees e set
          title_th        = coalesce(public.clean_text(r->>'title_th'), e.title_th),
          first_name_th   = coalesce(public.clean_text(r->>'first_name_th'), e.first_name_th),
          last_name_th    = coalesce(public.clean_text(r->>'last_name_th'), e.last_name_th),
          nickname        = coalesce(public.clean_text(r->>'nickname'), e.nickname),
          company_id      = coalesce(v_company, e.company_id),
          business_group_id = coalesce(v_bg, e.business_group_id),
          department_id   = case when v_start is null or v_start >= coalesce((select max(s.start_date) from public.training_participants tp
                                   join public.training_sessions s on s.id = tp.session_id where tp.employee_id = e.id), v_start)
                                 then coalesce(v_dept, e.department_id) else e.department_id end,
          position_id     = coalesce(v_pos, e.position_id),
          level_group_id  = coalesce(v_lg, e.level_group_id),
          job_level       = coalesce((r->>'job_level')::int, e.job_level),
          job_title       = coalesce(public.clean_text(r->>'job_title'), e.job_title),
          job_group       = coalesce(public.clean_text(r->>'job_group'), e.job_group),
          work_location   = coalesce(public.clean_text(r->>'work_location'), e.work_location),
          employment_status = coalesce(public.clean_text(r->>'employment_status'), e.employment_status),
          hire_date       = coalesce(public.try_date(r->>'hire_date'), e.hire_date),
          probation_date  = coalesce(public.try_date(r->>'probation_date'), e.probation_date),
          termination_date= coalesce(public.try_date(r->>'termination_date'), e.termination_date)
        where e.id = v_emp;
      end if;

      -- participant --------------------------------------------------------------------
      select * into v_existing from public.training_participants
       where session_id = v_session and employee_id = v_emp and deleted_at is null;
      if not found then
        insert into public.training_participants (session_id, employee_id, company_id, department_id, level_group_id, position_id,
             attendance_status, completion_status, training_hours, score, certificate_no, evaluation_score, legacy_value, remark,
             data_source, import_batch_id, import_date)
        values (v_session, v_emp, v_company, v_dept, v_lg, v_pos,
             coalesce(public.clean_text(r->>'attendance_status'), case when v_start > current_date then 'Registered' else 'Attended' end),
             coalesce(public.clean_text(r->>'completion_status'), case when v_start > current_date then 'Pending' else 'Completed' end),
             public.try_num(r->>'participant_hours'), public.try_num(r->>'score'), public.clean_text(r->>'certificate_no'),
             public.try_num(r->>'evaluation_score'), public.try_num(r->>'legacy_value'), public.clean_text(r->>'remark'),
             v_source, v_batch, now());
        n_new := n_new + 1;
        status_list := status_list || jsonb_build_object('row', coalesce((r->>'row_no')::int, i), 'status','new');
      elsif (public.try_num(r->>'score') is not null and public.try_num(r->>'score') is distinct from v_existing.score)
         or (public.clean_text(r->>'certificate_no') is not null and public.clean_text(r->>'certificate_no') is distinct from v_existing.certificate_no)
         or (public.clean_text(r->>'completion_status') is not null and public.clean_text(r->>'completion_status') is distinct from v_existing.completion_status)
         or (public.try_num(r->>'evaluation_score') is not null and public.try_num(r->>'evaluation_score') is distinct from v_existing.evaluation_score) then
        update public.training_participants set
          score = coalesce(public.try_num(r->>'score'), score),
          certificate_no = coalesce(public.clean_text(r->>'certificate_no'), certificate_no),
          completion_status = coalesce(public.clean_text(r->>'completion_status'), completion_status),
          evaluation_score = coalesce(public.try_num(r->>'evaluation_score'), evaluation_score)
        where id = v_existing.id;
        n_upd := n_upd + 1;
        status_list := status_list || jsonb_build_object('row', coalesce((r->>'row_no')::int, i), 'status','updated');
      else
        n_dup := n_dup + 1;
        status_list := status_list || jsonb_build_object('row', coalesce((r->>'row_no')::int, i), 'status','duplicate','message','มีในระบบแล้ว');
      end if;
    end loop;

    v_result := jsonb_build_object(
      'batch_id', v_batch, 'dry_run', v_dry,
      'total_records', n_total, 'valid_records', n_total - n_invalid, 'invalid_records', n_invalid,
      'duplicate_records', n_dup, 'new_records', n_new, 'updated_records', n_upd,
      'records_to_import', n_new + n_upd,
      'new_sessions', n_sessions_new, 'new_employees', n_emp_new, 'new_courses', n_course_new,
      'issues', issues, 'rows', status_list);

    update public.import_batches set
      total_records = n_total, valid_records = n_total - n_invalid, invalid_records = n_invalid,
      duplicate_records = n_dup, new_records = n_new, updated_records = n_upd, imported_records = n_new + n_upd,
      summary = v_result - 'rows' - 'issues'
    where id = v_batch;

    insert into public.import_issues (batch_id, row_no, severity, issue_type, message)
    select v_batch, (x->>'row')::int, x->>'severity', x->>'type', x->>'message' from jsonb_array_elements(issues) x;

    perform set_config('app.bulk_import', 'off', true);
    if v_dry then raise exception using errcode = 'P0001', message = 'ASW_DRY_RUN'; end if;
  exception when sqlstate 'P0001' then
    if sqlerrm <> 'ASW_DRY_RUN' then raise; end if;
    -- dry run: everything above is rolled back, summary is kept
  end;
  return v_result;
end $$;

-- Record a batch's issues coming from client-side parsing (e.g. unreadable rows)
create or replace function public.log_import_issue(p_batch uuid, p_row int, p_severity text, p_type text, p_message text)
returns void language sql security definer set search_path = public as $$
  insert into public.import_issues (batch_id, row_no, severity, issue_type, message)
  select p_batch, p_row, p_severity, p_type, p_message where public.can_edit();
$$;

-- Import employee master only (Import Center → Employee)
create or replace function public.import_employees(p_rows jsonb, p_options jsonb default '{}'::jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare r jsonb; v_dry boolean := coalesce((p_options->>'dry_run')::boolean,false);
  n_new int := 0; n_upd int := 0; n_inv int := 0; n int := 0; v_id bigint; v_dept bigint; v_company bigint; res jsonb;
  issues jsonb := '[]';
begin
  if not public.caller_can_edit() then
    raise exception 'permission denied';
  end if;
  begin
    perform set_config('app.bulk_import', 'on', true);
    for r in select * from jsonb_array_elements(p_rows) loop
      n := n + 1;
      if public.clean_text(r->>'employee_code') is null then
        n_inv := n_inv + 1; issues := issues || jsonb_build_object('row', coalesce((r->>'row_no')::int,n), 'message','ไม่มีรหัสพนักงาน'); continue;
      end if;
      v_company := null; v_dept := null;
      if public.clean_text(r->>'company_code') is not null then
        insert into public.companies (code, name) values (public.clean_text(r->>'company_code'), coalesce(public.clean_text(r->>'company_name'), r->>'company_code'))
        on conflict (code) do nothing;
        select id into v_company from public.companies where code = public.clean_text(r->>'company_code');
      end if;
      if public.clean_text(r->>'department_code') is not null then
        select id into v_dept from public.departments where code = public.clean_text(r->>'department_code');
        if v_dept is null then
          insert into public.departments (code, name) values (public.clean_text(r->>'department_code'), coalesce(public.clean_text(r->>'department_name'), r->>'department_code')) returning id into v_dept;
        end if;
      elsif public.clean_text(r->>'department_name') is not null then
        select id into v_dept from public.departments where lower(name) = lower(public.clean_text(r->>'department_name')) limit 1;
        if v_dept is null then
          insert into public.departments (name) values (public.clean_text(r->>'department_name')) returning id into v_dept;
        end if;
      end if;
      select id into v_id from public.employees where employee_code = public.clean_text(r->>'employee_code');
      if v_id is null then
        insert into public.employees (employee_code, title_th, first_name_th, last_name_th, nickname, company_id, department_id,
          job_title, employment_type, employment_status, hire_date, data_source)
        values (public.clean_text(r->>'employee_code'), public.clean_text(r->>'title_th'), public.clean_text(r->>'first_name_th'),
          public.clean_text(r->>'last_name_th'), public.clean_text(r->>'nickname'), v_company, v_dept,
          public.clean_text(r->>'job_title'), public.clean_text(r->>'employment_type'), coalesce(public.clean_text(r->>'employment_status'),'Active'),
          public.try_date(r->>'hire_date'), 'Excel Import');
        n_new := n_new + 1;
      else
        update public.employees set
          title_th = coalesce(public.clean_text(r->>'title_th'), title_th),
          first_name_th = coalesce(public.clean_text(r->>'first_name_th'), first_name_th),
          last_name_th = coalesce(public.clean_text(r->>'last_name_th'), last_name_th),
          nickname = coalesce(public.clean_text(r->>'nickname'), nickname),
          company_id = coalesce(v_company, company_id), department_id = coalesce(v_dept, department_id),
          job_title = coalesce(public.clean_text(r->>'job_title'), job_title),
          employment_type = coalesce(public.clean_text(r->>'employment_type'), employment_type),
          employment_status = coalesce(public.clean_text(r->>'employment_status'), employment_status),
          hire_date = coalesce(public.try_date(r->>'hire_date'), hire_date)
        where id = v_id;
        n_upd := n_upd + 1;
      end if;
    end loop;
    res := jsonb_build_object('dry_run', v_dry, 'total_records', n, 'valid_records', n - n_inv, 'invalid_records', n_inv,
                              'new_records', n_new, 'updated_records', n_upd, 'duplicate_records', 0,
                              'records_to_import', n_new + n_upd, 'issues', issues);
    insert into public.import_batches (import_type, data_source, source_file, status, total_records, valid_records, invalid_records,
                                       new_records, updated_records, imported_records, summary, imported_by)
    values ('employee', 'Excel Import', p_options->>'source_file', case when v_dry then 'preview' else 'completed' end,
            n, n - n_inv, n_inv, n_new, n_upd, n_new + n_upd, res - 'issues', auth.uid());
    perform set_config('app.bulk_import', 'off', true);
    if v_dry then raise exception using errcode = 'P0001', message = 'ASW_DRY_RUN'; end if;
  exception when sqlstate 'P0001' then
    if sqlerrm <> 'ASW_DRY_RUN' then raise; end if;
  end;
  return res;
end $$;

-- Import expenses: rows { legacy_course_id | session_id, expense_category, description, meal_type, quantity, unit_price, expense_date, vendor, invoice_no }
create or replace function public.import_expenses(p_rows jsonb, p_options jsonb default '{}'::jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare r jsonb; v_dry boolean := coalesce((p_options->>'dry_run')::boolean,false);
  n int := 0; n_new int := 0; n_inv int := 0; n_dup int := 0; v_sess bigint; v_cat bigint; res jsonb; issues jsonb := '[]'; v_msg text;
begin
  if not public.caller_can_edit() then
    raise exception 'permission denied';
  end if;
  begin
    for r in select * from jsonb_array_elements(p_rows) loop
      n := n + 1; v_msg := null; v_sess := null; v_cat := null;
      if (r->>'session_id') is not null then select id into v_sess from public.training_sessions where id = (r->>'session_id')::bigint and deleted_at is null;
      elsif (r->>'session_code') is not null then select id into v_sess from public.training_sessions where session_code = r->>'session_code' and deleted_at is null;
      elsif (r->>'legacy_course_id') is not null then select id into v_sess from public.training_sessions where legacy_course_id = (r->>'legacy_course_id')::int;
      end if;
      select id into v_cat from public.expense_categories where lower(name) = lower(public.clean_text(r->>'expense_category')) or lower(name_th) = lower(public.clean_text(r->>'expense_category')) limit 1;
      if v_sess is null then v_msg := 'ไม่พบ Training Session';
      elsif v_cat is null then v_msg := 'ไม่พบ Expense Category: ' || coalesce(r->>'expense_category','');
      elsif coalesce(public.try_num(r->>'unit_price'), -1) < 0 or coalesce(public.try_num(coalesce(r->>'quantity','1')), -1) < 0 then v_msg := 'จำนวนเงินไม่ถูกต้อง';
      end if;
      if v_msg is not null then
        n_inv := n_inv + 1; issues := issues || jsonb_build_object('row', coalesce((r->>'row_no')::int,n), 'message', v_msg); continue;
      end if;
      if exists (select 1 from public.training_expenses e where e.session_id = v_sess and e.expense_category_id = v_cat and e.deleted_at is null
                  and coalesce(e.description,'') = coalesce(public.clean_text(r->>'description'),'')
                  and e.quantity = coalesce(public.try_num(r->>'quantity'),1) and e.unit_price = public.try_num(r->>'unit_price')
                  and coalesce(e.invoice_no,'') = coalesce(public.clean_text(r->>'invoice_no'),'')) then
        n_dup := n_dup + 1; continue;
      end if;
      insert into public.training_expenses (session_id, expense_category_id, description, meal_type, quantity, unit_price,
        expense_date, vendor, invoice_no, remark, data_source)
      values (v_sess, v_cat, public.clean_text(r->>'description'), public.clean_text(r->>'meal_type'), coalesce(public.try_num(r->>'quantity'),1),
        public.try_num(r->>'unit_price'), public.try_date(r->>'expense_date'), public.clean_text(r->>'vendor'),
        public.clean_text(r->>'invoice_no'), public.clean_text(r->>'remark'), 'Excel Import');
      n_new := n_new + 1;
    end loop;
    res := jsonb_build_object('dry_run', v_dry, 'total_records', n, 'valid_records', n - n_inv, 'invalid_records', n_inv,
      'duplicate_records', n_dup, 'new_records', n_new, 'updated_records', 0, 'records_to_import', n_new, 'issues', issues);
    insert into public.import_batches (import_type, data_source, source_file, status, total_records, valid_records, invalid_records,
       duplicate_records, new_records, imported_records, summary, imported_by)
    values ('expense','Excel Import', p_options->>'source_file', case when v_dry then 'preview' else 'completed' end,
       n, n - n_inv, n_inv, n_dup, n_new, n_new, res - 'issues', auth.uid());
    if v_dry then raise exception using errcode = 'P0001', message = 'ASW_DRY_RUN'; end if;
  exception when sqlstate 'P0001' then
    if sqlerrm <> 'ASW_DRY_RUN' then raise; end if;
  end;
  return res;
end $$;

-- Session codes like TS-2026-0001 for sessions created in the system
create or replace function public.assign_session_code()
returns trigger language plpgsql as $$
begin
  if new.session_code is null then
    new.session_code := 'TS-' || new.fiscal_year || '-' || lpad(new.id::text, 5, '0');
  end if;
  return new;
end $$;
drop trigger if exists trg_session_code on public.training_sessions;
create trigger trg_session_code before insert on public.training_sessions
  for each row execute function public.assign_session_code();

create or replace function public.assign_course_code()
returns trigger language plpgsql as $$
begin
  if new.course_code is null then new.course_code := 'C' || lpad(new.id::text, 5, '0'); end if;
  new.course_key := public.course_key(new.course_name);
  return new;
end $$;
drop trigger if exists trg_course_code on public.training_courses;
create trigger trg_course_code before insert or update on public.training_courses
  for each row execute function public.assign_course_code();
