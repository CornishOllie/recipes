-- Recipes app shared state. Reuses the Georgia Supabase project.
-- Run this once in the Supabase SQL Editor. Idempotent.

----------------------------------------------------------------------
-- Tables
----------------------------------------------------------------------

create table if not exists recipe_favourites (
  family_code text not null,
  slug text not null,
  added_at timestamptz not null default now(),
  added_by text,
  primary key (family_code, slug)
);

-- Single row per family for the meal plan + shopping ticks (treated as a
-- coherent document, last-write-wins).
create table if not exists recipe_state (
  family_code text primary key,
  meal_plan jsonb,
  shopping_checks jsonb,
  updated_at timestamptz not null default now(),
  updated_by text
);

----------------------------------------------------------------------
-- RLS
----------------------------------------------------------------------

alter table recipe_favourites enable row level security;
alter table recipe_state enable row level security;

do $reset$
declare r record;
begin
  for r in
    select schemaname, tablename, policyname from pg_policies
    where schemaname = 'public'
      and tablename in ('recipe_favourites','recipe_state')
  loop
    execute format('drop policy if exists %I on %I.%I', r.policyname, r.schemaname, r.tablename);
  end loop;
end
$reset$;

create policy recipe_favs_anon_read   on recipe_favourites for select to anon using (length(family_code) >= 4);
create policy recipe_favs_anon_insert on recipe_favourites for insert to anon with check (length(family_code) >= 4);
create policy recipe_favs_anon_delete on recipe_favourites for delete to anon using (length(family_code) >= 4);

create policy recipe_state_anon_read   on recipe_state for select to anon using (length(family_code) >= 4);
create policy recipe_state_anon_insert on recipe_state for insert to anon with check (length(family_code) >= 4);
create policy recipe_state_anon_update on recipe_state for update to anon using (length(family_code) >= 4) with check (length(family_code) >= 4);
create policy recipe_state_anon_delete on recipe_state for delete to anon using (length(family_code) >= 4);

----------------------------------------------------------------------
-- Realtime
----------------------------------------------------------------------

do $rt$
begin
  begin alter publication supabase_realtime add table recipe_favourites; exception when duplicate_object then null; end;
  begin alter publication supabase_realtime add table recipe_state;       exception when duplicate_object then null; end;
end
$rt$;
