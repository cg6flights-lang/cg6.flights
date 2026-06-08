-- M:N junction table: aircraft ↔ squadrons
create table if not exists public.aircraft_squadrons (
  aircraft_id uuid not null references public.aircraft(id) on delete cascade,
  squadron_id uuid not null references public.flight_squadrons(id) on delete cascade,
  primary key (aircraft_id, squadron_id)
);

alter table public.aircraft_squadrons enable row level security;

create policy "aircraft_squadrons_read"
on public.aircraft_squadrons for select
to authenticated
using (true);

create policy "aircraft_squadrons_manage"
on public.aircraft_squadrons for all
to authenticated
using (public.has_permission('aircraft.manage'))
with check (public.has_permission('aircraft.manage'));
