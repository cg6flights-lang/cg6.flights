-- Migration: Flight Squadrons (Escuadrones de Vuelo) for GRU51
-- Adds squadron organizational structure to crew, aircraft, and profiles

-- 1. Create flight_squadrons table
create table if not exists public.flight_squadrons (
  id uuid primary key default gen_random_uuid(),
  unit_id uuid not null references public.units(id),
  name text not null,
  display_order int not null default 0,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- 2. Add squadron_id to crew_members, aircraft, and profiles
alter table public.crew_members
  add column if not exists squadron_id uuid references public.flight_squadrons(id);
alter table public.aircraft
  add column if not exists squadron_id uuid references public.flight_squadrons(id);
alter table public.profiles
  add column if not exists squadron_id uuid references public.flight_squadrons(id);

-- 3. Add squadron_chief to app_role enum
do $$
begin
  alter type public.app_role add value if not exists 'squadron_chief';
exception
  when duplicate_object then null;
end $$;

-- 4. Seed GRU51 squadrons
do $$
declare
  gru51_id uuid;
begin
  select id into gru51_id from public.units where code = 'GRU51';
  if gru51_id is not null then
    insert into public.flight_squadrons (id, unit_id, name, display_order)
    values
      (gen_random_uuid(), gru51_id, 'Escuadrón 510 — Ala Rotatoria', 1),
      (gen_random_uuid(), gru51_id, 'Escuadrón 511 — Instrucción Básica', 2),
      (gen_random_uuid(), gru51_id, 'Escuadrón 512 — Instrucción Avanzada', 3),
      (gen_random_uuid(), gru51_id, 'Escuadrón 513 — Pilotos de Caza', 4)
    on conflict do nothing;
  end if;
end $$;

-- 5. RLS for flight_squadrons
alter table public.flight_squadrons enable row level security;

create policy "squadrons_read_authorized"
on public.flight_squadrons
for select
to authenticated
using (active = true);

create policy "squadrons_manage_authorized"
on public.flight_squadrons
for all
to authenticated
using (public.has_permission('aircraft.manage'))
with check (public.has_permission('aircraft.manage'));
