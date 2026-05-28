alter table public.aircraft
  add column if not exists manufacturer text,
  add column if not exists serial_number text,
  add column if not exists year integer;

update public.aircraft set manufacturer = '' where manufacturer is null;
alter table public.aircraft alter column manufacturer set not null;

drop policy if exists "aircraft_insert_authorized" on public.aircraft;
create policy "aircraft_insert_authorized"
on public.aircraft
for insert
to authenticated
with check (
  public.has_permission('aircraft.manage')
  and (public.is_global_role() or public.same_unit(unit_id))
);

drop policy if exists "aircraft_update_authorized" on public.aircraft;
create policy "aircraft_update_authorized"
on public.aircraft
for update
to authenticated
using (
  public.has_permission('aircraft.manage')
  and (public.is_global_role() or public.same_unit(unit_id))
)
with check (
  public.has_permission('aircraft.manage')
  and (public.is_global_role() or public.same_unit(unit_id))
);

drop policy if exists "aircraft_delete_authorized" on public.aircraft;
create policy "aircraft_delete_authorized"
on public.aircraft
for delete
to authenticated
using (
  public.has_permission('aircraft.manage')
  and (public.is_global_role() or public.same_unit(unit_id))
);
