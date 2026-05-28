-- Crew SDD alignment: adapta schema a requisitos operativos reales
-- Reemplaza crew_type (pilot/copilot/mechanic/flight_engineer) por crew_category (pilot/mechanic)
-- Desglosa full_name en grade + first_name + last_name
-- Agrega nsa como identificador militar unico
-- Agrega qualifications text[] para pilotos
-- Agrega appointment_date
-- Migra flight_crew.crew_type a role_code (PC/CP/MA)

do $$
begin
  create type public.crew_category as enum ('pilot', 'mechanic');
exception
  when duplicate_object then null;
end $$;

-- 1. Agregar columnas nuevas a crew_members
alter table public.crew_members
  add column if not exists grade text,
  add column if not exists first_name text,
  add column if not exists last_name text,
  add column if not exists nsa text,
  add column if not exists appointment_date date,
  add column if not exists qualifications text[] default '{}',
  add column if not exists crew_category public.crew_category;

-- 2. Migrar datos existentes desde columnas viejas
update public.crew_members
set
  grade = coalesce(nullif(trim(grade), ''), ''),
  first_name = coalesce(nullif(trim(first_name), ''), split_part(trim(full_name), ' ', 1)),
  last_name = coalesce(nullif(trim(last_name), ''), trim(substring(full_name from position(' ' in full_name) + 1))),
  nsa = coalesce(nullif(trim(nsa), ''), coalesce(nullif(trim(document_id), ''), '')),
  crew_category = case
    when crew_type = 'mechanic' then 'mechanic'::public.crew_category
    else 'pilot'::public.crew_category
  end,
  appointment_date = coalesce(appointment_date, current_date)
where grade is null
   or grade = ''
   or first_name is null
   or first_name = ''
   or last_name is null
   or last_name = ''
   or nsa is null
   or nsa = ''
   or crew_category is null;

-- 3. Asignar valores por defecto donde no se pudo migrar
update public.crew_members set grade = '' where grade is null;
update public.crew_members set first_name = '' where first_name is null;
update public.crew_members set last_name = '' where last_name is null;
update public.crew_members set nsa = gen_random_uuid()::text where nsa is null or nsa = '';
update public.crew_members set appointment_date = current_date where appointment_date is null;
update public.crew_members set crew_category = 'pilot'::public.crew_category where crew_category is null;

-- 4. NOT NULL en nuevas columnas
alter table public.crew_members
  alter column grade set not null,
  alter column first_name set not null,
  alter column last_name set not null,
  alter column nsa set not null,
  alter column appointment_date set not null,
  alter column crew_category set not null;

-- 5. Unique constraint en nsa
delete from public.crew_members a
using public.crew_members b
where a.id < b.id and a.nsa = b.nsa;

alter table public.crew_members
  add constraint crew_members_nsa_key unique (nsa);

-- 6. Eliminar columnas viejas
alter table public.crew_members
  drop column if exists full_name,
  drop column if exists document_id,
  drop column if exists crew_type;

-- 7. Recrear indices
drop index if exists public.crew_members_unit_type_idx;
create index if not exists crew_members_unit_category_idx
  on public.crew_members(unit_id, crew_category);
create index if not exists crew_members_nsa_idx
  on public.crew_members(nsa);

-- 8. Migrar flight_crew: crew_type -> role_code
alter table public.flight_crew
  add column if not exists role_code text;

update public.flight_crew
set role_code = case crew_type::text
  when 'pilot' then 'PC'
  when 'copilot' then 'CP'
  when 'mechanic' then 'MA'
  when 'flight_engineer' then 'MA'
  else 'PC'
end;

alter table public.flight_crew
  alter column role_code set not null;

alter table public.flight_crew
  drop column if exists crew_type;

-- 9. Recrear trigger updated_at (por si acaso)
drop trigger if exists set_crew_members_updated_at on public.crew_members;
create trigger set_crew_members_updated_at
before update on public.crew_members
for each row execute function public.set_updated_at();
