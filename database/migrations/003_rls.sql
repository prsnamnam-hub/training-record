-- ============================================================================
-- ASW Training Record — 003 Row Level Security & grants
--   ADMIN        : full access (incl. users/roles, settings, audit log)
--   HR_TRAINING  : create/edit training, participants, expenses, master data, import/export
--   VIEWER       : read dashboard / reports / search
-- No DELETE policy on business tables: records are soft-deleted (deleted_at) so
-- historical data can never be removed through the API (RULE 3).
-- ============================================================================

-- Policies wrap helper calls in (select ...) so Postgres evaluates them once per query (initPlan)
-- instead of once per row of every joined table — required for report/dashboard performance.

-- base privileges (Supabase grants these by default; explicit here so the file is self-contained)
grant usage on schema public to authenticated, service_role;
grant select, insert, update on all tables in schema public to authenticated;
grant all on all tables in schema public to service_role;
grant usage, select on all sequences in schema public to authenticated, service_role;

do $$
declare t text;
begin
  foreach t in array array[
    'companies','business_groups','departments','sections','level_groups','positions','employees',
    'training_types','training_categories','training_providers','trainers','expense_categories',
    'training_courses','training_sessions','training_participants','training_evaluations','training_expenses',
    'training_budgets','import_batches','import_issues','app_settings']
  loop
    execute format('alter table public.%I enable row level security', t);
    execute format('drop policy if exists p_select on public.%I', t);
    execute format('create policy p_select on public.%I for select to authenticated using ((select public.can_view()))', t);
    execute format('drop policy if exists p_insert on public.%I', t);
    execute format('create policy p_insert on public.%I for insert to authenticated with check ((select public.can_edit()))', t);
    execute format('drop policy if exists p_update on public.%I', t);
    execute format('create policy p_update on public.%I for update to authenticated using ((select public.can_edit())) with check ((select public.can_edit()))', t);
    execute format('revoke delete on public.%I from anon, authenticated', t);
    execute format('revoke all on public.%I from anon', t);
  end loop;
end $$;

-- settings: only admins may change
drop policy if exists p_insert on public.app_settings;
create policy p_insert on public.app_settings for insert to authenticated with check ((select public.is_admin()));
drop policy if exists p_update on public.app_settings;
create policy p_update on public.app_settings for update to authenticated using ((select public.is_admin())) with check ((select public.is_admin()));

-- evaluations and budgets may be removed (they are not historical training records)
grant delete on public.training_evaluations, public.training_budgets to authenticated;
drop policy if exists p_delete on public.training_evaluations;
create policy p_delete on public.training_evaluations for delete to authenticated using ((select public.can_edit()));
drop policy if exists p_delete on public.training_budgets;
create policy p_delete on public.training_budgets for delete to authenticated using ((select public.can_edit()));

-- profiles: everyone sees their own; admins see and manage all
alter table public.profiles enable row level security;
revoke all on public.profiles from anon;
revoke delete on public.profiles from authenticated;
drop policy if exists p_self on public.profiles;
create policy p_self on public.profiles for select to authenticated using (id = auth.uid() or public.is_admin());
drop policy if exists p_admin_update on public.profiles;
create policy p_admin_update on public.profiles for update to authenticated using (public.is_admin()) with check (public.is_admin());
drop policy if exists p_self_update on public.profiles;
create policy p_self_update on public.profiles for update to authenticated
  using (id = auth.uid())
  with check (id = auth.uid() and role = (select p.role from public.profiles p where p.id = auth.uid())
              and is_active = (select p.is_active from public.profiles p where p.id = auth.uid()));

-- audit log: admin only, read only (writes come from the security-definer trigger)
alter table public.audit_logs enable row level security;
revoke all on public.audit_logs from anon;
revoke insert, update, delete on public.audit_logs from authenticated;
drop policy if exists p_select on public.audit_logs;
create policy p_select on public.audit_logs for select to authenticated using ((select public.is_admin()));

-- views run with the caller's RLS (security_invoker)
revoke all on public.v_session_cost, public.v_session_summary, public.v_participant_fact from anon;
grant select on public.v_session_cost, public.v_session_summary, public.v_participant_fact to authenticated;

-- functions: never callable anonymously
revoke execute on all functions in schema public from anon, public;
grant execute on all functions in schema public to authenticated, service_role;
-- trigger-only / internal helpers
revoke execute on function public.handle_new_user() from authenticated;
