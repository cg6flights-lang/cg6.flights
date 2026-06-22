-- Enable Supabase Realtime for operational tables.
-- Allows the frontend to subscribe to changes and refresh live
-- (notifications stream + "realtime -> invalidate" pattern for crew/dashboard).
-- RLS remains the source of truth for per-row visibility.

-- replica identity full so UPDATE/DELETE events carry the full old row.
alter table public.notifications replica identity full;
alter table public.crew_members replica identity full;
alter table public.aircraft replica identity full;
alter table public.flight_orders replica identity full;
alter table public.flight_order_items replica identity full;
alter table public.flight_order_state_events replica identity full;

-- Add each table to the supabase_realtime publication, idempotently.
do $$
declare
  t text;
  tables text[] := array[
    'notifications',
    'crew_members',
    'aircraft',
    'flight_orders',
    'flight_order_items',
    'flight_order_state_events'
  ];
begin
  foreach t in array tables loop
    if not exists (
      select 1
      from pg_publication p
      join pg_publication_rel pr on pr.prpubid = p.oid
      join pg_class c on c.oid = pr.prrelid
      join pg_namespace n on n.oid = c.relnamespace
      where p.pubname = 'supabase_realtime'
        and n.nspname = 'public'
        and c.relname = t
    ) then
      execute format('alter publication supabase_realtime add table public.%I', t);
    end if;
  end loop;
exception
  when undefined_object then
    create publication supabase_realtime;
    foreach t in array tables loop
      execute format('alter publication supabase_realtime add table public.%I', t);
    end loop;
end $$;
