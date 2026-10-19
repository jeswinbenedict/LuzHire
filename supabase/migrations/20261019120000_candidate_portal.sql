-- LuzHire · Phase 5 · Candidate portal support.

-- ---------------------------------------------------------------- resumes
-- Makes one of the caller's resumes the primary one. Two statements in one
-- function: the partial unique index allows only one primary per user, and
-- it is checked row by row.
create or replace function public.set_primary_resume(resume uuid)
returns void
language plpgsql
security invoker
set search_path = public, pg_temp
as $$
begin
  if not exists (select 1 from public.resumes where id = resume and user_id = app.uid()) then
    raise exception 'Resume not found' using errcode = '42501';
  end if;
  update public.resumes set is_primary = false
  where user_id = app.uid() and is_primary and id <> resume;
  update public.resumes set is_primary = true
  where id = resume and not is_primary;
end
$$;
revoke all on function public.set_primary_resume(uuid) from public, anon;
grant execute on function public.set_primary_resume(uuid) to authenticated;
