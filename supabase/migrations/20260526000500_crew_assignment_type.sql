-- Agregar tipo de asignacion (Nato / Foraneo) a tripulantes
-- Nato: pertenece a la unidad
-- Foraneo: vuela en la unidad pero pertenece a otra

alter table public.crew_members
  add column if not exists assignment_type text not null default 'nato';

alter table public.crew_members
  add constraint crew_members_assignment_type_check
  check (assignment_type in ('nato', 'foraneo'));
