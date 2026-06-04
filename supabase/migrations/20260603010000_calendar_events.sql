-- Calendario operacional: actividades globales visibles para usuarios activos.

insert into public.permissions (key, description, module)
values
  ('calendar.read', 'Leer calendario operacional', 'calendar'),
  ('calendar.manage', 'Gestionar actividades del calendario', 'calendar')
on conflict (key) do update
set description = excluded.description,
    module = excluded.module,
    active = true;

insert into public.role_permissions (role, permission_id, enabled)
select role_name::public.app_role, p.id, true
from public.permissions p
cross join (
  values
    ('leader'),
    ('general_admin'),
    ('unit_command'),
    ('unit_admin'),
    ('ttaa')
) as roles(role_name)
where p.key = 'calendar.read'
on conflict (role, permission_id) do update set enabled = excluded.enabled;

insert into public.role_permissions (role, permission_id, enabled)
select role_name::public.app_role, p.id, true
from public.permissions p
cross join (
  values
    ('leader'),
    ('general_admin')
) as roles(role_name)
where p.key = 'calendar.manage'
on conflict (role, permission_id) do update set enabled = excluded.enabled;

create table if not exists public.calendar_events (
  id uuid primary key default gen_random_uuid(),
  title text not null check (length(trim(title)) > 0),
  description text,
  location text,
  event_type text not null default 'operations' check (
    event_type in ('operations', 'training', 'maintenance', 'briefing', 'administrative', 'other')
  ),
  status text not null default 'scheduled' check (
    status in ('scheduled', 'in_progress', 'completed', 'cancelled')
  ),
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint calendar_events_time_check check (ends_at >= starts_at)
);

create index if not exists calendar_events_starts_at_idx
on public.calendar_events(starts_at)
where deleted_at is null;

create index if not exists calendar_events_status_idx
on public.calendar_events(status, starts_at)
where deleted_at is null;

drop trigger if exists set_calendar_events_updated_at on public.calendar_events;
create trigger set_calendar_events_updated_at
before update on public.calendar_events
for each row execute function public.set_updated_at();

alter table public.calendar_events enable row level security;

drop policy if exists "calendar_events_read_all_active" on public.calendar_events;
create policy "calendar_events_read_all_active"
on public.calendar_events
for select
to authenticated
using (
  deleted_at is null
  and public.has_permission('calendar.read')
);
