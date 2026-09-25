-- ============================================================================
-- ASW Training Record — 004 Pre-Test / Post-Test scores + certificate files
-- Idempotent. Adds nullable columns only (no existing data changes).
-- ============================================================================

alter table public.training_participants add column if not exists pre_test_score  numeric(6,2);
alter table public.training_participants add column if not exists post_test_score numeric(6,2);
do $$ begin
  alter table public.training_participants add constraint training_participants_test_scores_chk
    check ((pre_test_score is null or pre_test_score >= 0) and (post_test_score is null or post_test_score >= 0));
exception when duplicate_object then null; end $$;
comment on column public.training_participants.certificate_url is 'Storage path in bucket "certificates" (private) — open via a signed URL';

-- Certificate files: private bucket, same rights as the training data
-- (view = any active role, upload/replace/remove = Admin or HR/Training)
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('certificates', 'certificates', false, 10485760, array['application/pdf', 'image/png', 'image/jpeg', 'image/webp'])
on conflict (id) do update set public = false, file_size_limit = excluded.file_size_limit, allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists certificates_select on storage.objects;
create policy certificates_select on storage.objects for select to authenticated
  using (bucket_id = 'certificates' and (select public.can_view()));
drop policy if exists certificates_insert on storage.objects;
create policy certificates_insert on storage.objects for insert to authenticated
  with check (bucket_id = 'certificates' and (select public.can_edit()));
drop policy if exists certificates_update on storage.objects;
create policy certificates_update on storage.objects for update to authenticated
  using (bucket_id = 'certificates' and (select public.can_edit()))
  with check (bucket_id = 'certificates' and (select public.can_edit()));
drop policy if exists certificates_delete on storage.objects;
create policy certificates_delete on storage.objects for delete to authenticated
  using (bucket_id = 'certificates' and (select public.can_edit()));
