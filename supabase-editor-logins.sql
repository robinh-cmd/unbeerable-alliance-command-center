-- Editor logins for the UnBEERable Alliance Command Center
-- Run once in Supabase: SQL Editor > New query > paste everything > Run.
-- Safe to run again.
--
-- Result:
--   * Everyone with the link (anonymous sessions) can READ the website tables.
--   * Only accounts listed in public.site_editors can ADD / CHANGE / DELETE.
--   * The game sync (lw_sync) connects as the database owner and is not affected.

begin;

-- 1. Who may edit -----------------------------------------------------------
create table if not exists public.site_editors (
  user_id    uuid primary key references auth.users(id) on delete cascade,
  label      text,
  created_at timestamptz not null default now()
);
alter table public.site_editors enable row level security;
revoke all on public.site_editors from anon, authenticated;

-- true only for a real (non-anonymous) login that is listed in site_editors
create or replace function public.is_editor()
returns boolean
language sql stable security definer
set search_path = ''
as $$
  select coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false) = false
     and exists (select 1 from public.site_editors e where e.user_id = auth.uid());
$$;

-- 2. Website tables: read for every session, write for editors only --------
do $$
declare
  t text;
  p record;
begin
  foreach t in array array[
    'alliance_members',
    'versus_active_tournament', 'versus_tournament_history',
    'train_rotation_state', 'train_rotation_history',
    'desert_storm_roster', 'desert_storm_thp_observations', 'desert_storm_skip_history',
    'canyon_storm_roster', 'canyon_storm_thp_observations',
    'roster_growth_history', 'roster_sync_status'
  ] loop
    if to_regclass('public.' || t) is null then
      raise notice 'Table public.% not found - skipped', t;
      continue;
    end if;
    execute format('alter table public.%I enable row level security', t);
    for p in select policyname from pg_policies where schemaname = 'public' and tablename = t loop
      execute format('drop policy %I on public.%I', p.policyname, t);
    end loop;
    execute format('create policy site_read   on public.%I for select to authenticated using (true)', t);
    execute format('create policy site_insert on public.%I for insert to authenticated with check (public.is_editor())', t);
    execute format('create policy site_update on public.%I for update to authenticated using (public.is_editor()) with check (public.is_editor())', t);
    execute format('create policy site_delete on public.%I for delete to authenticated using (public.is_editor())', t);
    execute format('revoke all on public.%I from anon', t);
    execute format('grant select, insert, update, delete on public.%I to authenticated', t);
  end loop;
end $$;

-- 3. Database functions: nobody can call them from the website any more,
--    except is_editor(). (Backup restore etc. still work from the SQL editor,
--    the daily backup job and the game sync, which run as the owner.)
do $$
declare
  f record;
begin
  for f in
    select p.oid::regprocedure as sig
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.prokind = 'f'
      and p.proname <> 'is_editor'
      and not exists (select 1 from pg_depend d where d.objid = p.oid and d.deptype = 'e')  -- skip extension functions
  loop
    execute format('revoke execute on function %s from public, anon, authenticated', f.sig);
  end loop;
end $$;
-- triggers (e.g. roster growth history) run as the editor and need the id sequences
grant usage, select on all sequences in schema public to authenticated;

revoke all on function public.is_editor() from public;
grant execute on function public.is_editor() to anon, authenticated;

commit;

-- 4. Check: what the website roles can do now (read the output below) ------
select tablename, policyname, cmd
from pg_policies
where schemaname = 'public'
order by tablename, cmd;
