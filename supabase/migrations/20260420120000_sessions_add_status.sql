-- Sessions: status column + CHECK + trigger (auto sync on every insert/update).
-- Run in Supabase SQL Editor as the default role (postgres / service role).
-- Do NOT use "Run with RLS" / role-switch for this script: DDL + triggers are not meant
-- to be parsed or executed as a fragmented RLS preview; that can break $$ bodies.

-- 1) Column
alter table public.sessions
  add column if not exists status text not null default 'waiting';

comment on column public.sessions.status is
  'waiting | ready | active | ended — kept in sync by trigger + app (active on voice start).';

-- 2) Trigger function (no PL/pgSQL variables named like columns — avoids odd editor/RLS parsers)
create or replace function public.sessions_sync_status_and_updated_at()
returns trigger
language plpgsql
as $fn$
begin
  if (
    select count(distinct trim(both from t.p))
    from unnest(coalesce(new.participants, '{}'::text[])) as t(p)
    where trim(both from t.p) is not null and trim(both from t.p) <> ''
  ) > 2 then
    raise exception 'sessions allow at most 2 distinct participants (got %)',
      (select count(distinct trim(both from t2.p))
       from unnest(coalesce(new.participants, '{}'::text[])) as t2(p)
       where trim(both from t2.p) is not null and trim(both from t2.p) <> '')
      using errcode = '23514';
  end if;

  if new."endTime" is not null then
    new.status := 'ended';
  elsif (
    select count(distinct trim(both from t3.p))
    from unnest(coalesce(new.participants, '{}'::text[])) as t3(p)
    where trim(both from t3.p) is not null and trim(both from t3.p) <> ''
  ) < 2 then
    new.status := 'waiting';
  elsif new.status = 'active' then
    null;
  else
    new.status := 'ready';
  end if;

  new."updatedAt" := now();
  return new;
end;
$fn$;

drop trigger if exists sessions_sync_status_and_updated_at on public.sessions;
create trigger sessions_sync_status_and_updated_at
  before insert or update on public.sessions
  for each row
  execute function public.sessions_sync_status_and_updated_at();

-- 3) Recompute all existing rows through the trigger
update public.sessions s
set id = s.id;

-- 4) Allowed values only (run after backfill so no invalid rows)
alter table public.sessions
  drop constraint if exists sessions_status_check;
alter table public.sessions
  add constraint sessions_status_check
  check (status in ('waiting', 'ready', 'active', 'ended'));
