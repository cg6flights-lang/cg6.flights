-- Tabla de grados militares FAP para tripulaciones
-- Oficiales (pilotos) y Tecnicos/Sub Oficiales (mecanicos)

create table if not exists public.grades (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name text not null,
  category public.crew_category not null,
  sort_order int not null default 0,
  active boolean not null default true
);

-- Seed: Oficiales (Pilotos)
insert into public.grades (code, name, category, sort_order) values
  ('TTG FAP', 'Teniente General FAP', 'pilot', 1),
  ('MAG FAP', 'Mayor General FAP', 'pilot', 2),
  ('COR FAP', 'Coronel FAP', 'pilot', 3),
  ('COM FAP', 'Comandante FAP', 'pilot', 4),
  ('MAY FAP', 'Mayor FAP', 'pilot', 5),
  ('CAP FAP', 'Capitan FAP', 'pilot', 6),
  ('TEN FAP', 'Teniente FAP', 'pilot', 7),
  ('ALF FAP', 'Alferez FAP', 'pilot', 8);

-- Seed: Tecnicos / Sub Oficiales (Mecanicos)
insert into public.grades (code, name, category, sort_order) values
  ('TSP FAP', 'Tecnico Supervisor FAP', 'mechanic', 1),
  ('TIP FAP', 'Tecnico Inspector FAP', 'mechanic', 2),
  ('TC1 FAP', 'Tecnico de 1era FAP', 'mechanic', 3),
  ('TC2 FAP', 'Tecnico de 2da FAP', 'mechanic', 4),
  ('TC3 FAP', 'Tecnico de 3era FAP', 'mechanic', 5),
  ('SO1 FAP', 'Sub Oficial de 1era FAP', 'mechanic', 6),
  ('SO2 FAP', 'Sub Oficial de 2da FAP', 'mechanic', 7),
  ('SO3 FAP', 'Sub Oficial de 3era FAP', 'mechanic', 8);

-- RLS: lectura para cualquier autenticado
alter table public.grades enable row level security;

drop policy if exists "grades_read_authenticated" on public.grades;
create policy "grades_read_authenticated"
on public.grades
for select
to authenticated
using (true);
