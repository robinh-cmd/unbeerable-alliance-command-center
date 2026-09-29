-- Schema reference. The live Supabase project is already configured.
create extension if not exists pgcrypto;
create table if not exists public.alliance_members (
  id uuid primary key default gen_random_uuid(),
  name text not null check (length(trim(name)) between 1 and 100),
  created_at timestamptz not null default now()
);
create unique index if not exists alliance_members_name_ci_unique on public.alliance_members (lower(trim(name)));
alter table public.alliance_members enable row level security;
revoke all on table public.alliance_members from anon;
grant select, insert, update, delete on table public.alliance_members to authenticated;
