-- ETE adjustments table for post-engine-shutdown planned ETE corrections
create table if not exists public.ete_adjustments (
  id uuid primary key default gen_random_uuid(),
  flight_id uuid not null references public.flights(id),
  flight_order_id uuid not null references public.flight_orders(id),
  old_ete_minutes int not null,
  new_ete_minutes int not null,
  adjusted_by uuid not null references public.profiles(id),
  status text not null default 'pending', -- pending, approved, rejected
  reviewed_by uuid references public.profiles(id),
  reason text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Index for lookup by flight order
create index if not exists ete_adjustments_order_idx on public.ete_adjustments(flight_order_id);
create index if not exists ete_adjustments_status_idx on public.ete_adjustments(status);

-- RLS
alter table public.ete_adjustments enable row level security;

drop policy if exists "ete_adjustments_read_by_unit" on public.ete_adjustments;
create policy "ete_adjustments_read_by_unit"
on public.ete_adjustments for select
to authenticated
using (
  exists (
    select 1 from public.flight_orders fo
    where fo.id = ete_adjustments.flight_order_id
    and fo.unit_id = (select unit_id from public.profiles where id = auth.uid())
  )
  or
  exists (
    select 1 from public.profiles
    where id = auth.uid()
    and role in ('leader', 'general_admin')
  )
);

drop policy if exists "ete_adjustments_insert_by_unit" on public.ete_adjustments;
create policy "ete_adjustments_insert_by_unit"
on public.ete_adjustments for insert
to authenticated
with check (
  auth.uid() = adjusted_by
);

drop policy if exists "ete_adjustments_update_by_reviewer" on public.ete_adjustments;
create policy "ete_adjustments_update_by_reviewer"
on public.ete_adjustments for update
to authenticated
using (
  exists (
    select 1 from public.profiles
    where id = auth.uid()
    and role in ('leader', 'general_admin', 'unit_command')
  )
);
