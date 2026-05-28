-- Tabla de historial de estados de aeronaves para tracking de curva de operatividad
create table if not exists public.aircraft_status_history (
  id uuid primary key default gen_random_uuid(),
  aircraft_id uuid not null references public.aircraft(id) on delete cascade,
  unit_id uuid not null references public.units(id),
  status public.aircraft_status not null,
  created_at timestamptz not null default now()
);

create index if not exists aircraft_status_history_aircraft_created_idx
  on public.aircraft_status_history(aircraft_id, created_at desc);

create index if not exists aircraft_status_history_unit_created_idx
  on public.aircraft_status_history(unit_id, created_at desc);

alter table public.aircraft_status_history enable row level security;

drop policy if exists "aircraft_status_history_read_by_scope"
  on public.aircraft_status_history;

create policy "aircraft_status_history_read_by_scope"
on public.aircraft_status_history
for select
to authenticated
using (
  public.has_permission('aircraft.read')
  and (public.is_global_role() or public.same_unit(unit_id))
);

-- RPC: curva de operatividad agregada por periodo
create or replace function public.get_operational_curve(
  p_unit_id uuid,
  p_granularity text default 'month',
  p_months_lookback integer default 12
)
returns table (
  period_label text,
  operational bigint,
  inoperative bigint,
  maintenance bigint,
  total bigint,
  operational_pct numeric
)
language plpgsql
stable
set search_path = public
as $$
declare
  interval_type text;
begin
  interval_type := case
    when p_granularity = 'week' then '1 week'
    when p_granularity = 'month' then '1 month'
    when p_granularity = 'year' then '1 year'
    else '1 month'
  end;

  return query
  with periods as (
    select date_trunc(p_granularity, generate_series(
      date_trunc(p_granularity, now() - (p_months_lookback || ' months')::interval),
      date_trunc(p_granularity, now()),
      interval_type::interval
    )) as period_start
  ),
  period_ranges as (
    select
      period_start,
      period_start + interval_type::interval - interval '1 second' as period_end
    from periods
  ),
  unit_aircraft as (
    select id, status from public.aircraft
    where unit_id = p_unit_id and active = true
  ),
  status_at_period as (
    select distinct on (pr.period_start, ua.id)
      pr.period_start,
      ua.id,
      coalesce(
        (select ash.status
         from public.aircraft_status_history ash
         where ash.aircraft_id = ua.id
           and ash.created_at <= pr.period_end
         order by ash.created_at desc
         limit 1),
        ua.status
      ) as status
    from period_ranges pr
    cross join unit_aircraft ua
  )
  select
    to_char(s.period_start, 'YYYY-MM-DD') as period_label,
    count(*) filter (where s.status = 'operational') as operational,
    count(*) filter (where s.status = 'inoperative') as inoperative,
    count(*) filter (where s.status = 'maintenance') as maintenance,
    count(*) as total,
    round(
      100.0 * count(*) filter (where s.status = 'operational')
      / nullif(count(*), 0),
      1
    ) as operational_pct
  from status_at_period s
  group by s.period_start
  order by s.period_start;
end;
$$;

-- Backfill: registrar estado actual de todas las aeronaves activas
do $$
begin
  if not exists (select 1 from public.aircraft_status_history limit 1) then
    insert into public.aircraft_status_history (aircraft_id, unit_id, status)
    select id, unit_id, status
    from public.aircraft
    where active = true;
  end if;
end $$;
