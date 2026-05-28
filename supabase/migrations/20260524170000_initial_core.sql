create extension if not exists pgcrypto;

do $$
begin
  create type public.app_role as enum (
    'leader',
    'general_admin',
    'unit_command',
    'unit_admin',
    'ttaa'
  );
exception
  when duplicate_object then null;
end $$;

do $$
begin
  create type public.profile_status as enum (
    'pending',
    'active',
    'inactive',
    'rejected'
  );
exception
  when duplicate_object then null;
end $$;

do $$
begin
  create type public.crew_type as enum (
    'pilot',
    'copilot',
    'mechanic',
    'flight_engineer'
  );
exception
  when duplicate_object then null;
end $$;

do $$
begin
  create type public.aircraft_status as enum (
    'operational',
    'inoperative',
    'maintenance'
  );
exception
  when duplicate_object then null;
end $$;

do $$
begin
  create type public.flight_order_status as enum (
    'draft',
    'submitted',
    'observed',
    'approved',
    'closed',
    'reopened'
  );
exception
  when duplicate_object then null;
end $$;

do $$
begin
  create type public.flight_status_code as enum (
    'motor_start',
    'taxi_start',
    'takeoff',
    'landing',
    'engine_shutdown'
  );
exception
  when duplicate_object then null;
end $$;

do $$
begin
  create type public.closure_status as enum (
    'requested',
    'observed',
    'approved',
    'rejected',
    'reopened'
  );
exception
  when duplicate_object then null;
end $$;

do $$
begin
  create type public.audit_result as enum ('success', 'denied', 'failed');
exception
  when duplicate_object then null;
end $$;

do $$
begin
  create type public.report_format as enum ('pdf', 'excel');
exception
  when duplicate_object then null;
end $$;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create table if not exists public.units (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name text not null,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text not null unique,
  display_name text not null,
  status public.profile_status not null default 'pending',
  role public.app_role,
  unit_id uuid references public.units(id),
  phone text,
  avatar_path text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint profiles_unit_required_for_unit_roles check (
    role is null
    or role in ('leader', 'general_admin')
    or unit_id is not null
  )
);

create unique index if not exists one_active_leader
on public.profiles (role)
where role = 'leader' and status = 'active';

create table if not exists public.permissions (
  id uuid primary key default gen_random_uuid(),
  key text not null unique,
  description text not null,
  module text not null,
  active boolean not null default true
);

create table if not exists public.role_permissions (
  id uuid primary key default gen_random_uuid(),
  role public.app_role not null,
  permission_id uuid not null references public.permissions(id) on delete cascade,
  enabled boolean not null default true,
  created_at timestamptz not null default now(),
  unique (role, permission_id)
);

create table if not exists public.audit_logs (
  id uuid primary key default gen_random_uuid(),
  actor_id uuid references public.profiles(id),
  actor_role public.app_role,
  actor_unit_id uuid references public.units(id),
  action text not null,
  resource_type text not null,
  resource_id uuid,
  result public.audit_result not null,
  ip_address text,
  user_agent text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.aircraft (
  id uuid primary key default gen_random_uuid(),
  unit_id uuid not null references public.units(id),
  tail_number text not null unique,
  model text not null,
  status public.aircraft_status not null default 'operational',
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create table if not exists public.crew_members (
  id uuid primary key default gen_random_uuid(),
  unit_id uuid not null references public.units(id),
  full_name text not null,
  document_id text,
  crew_type public.crew_type not null,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create table if not exists public.routes (
  id uuid primary key default gen_random_uuid(),
  unit_id uuid references public.units(id),
  name text not null,
  origin text not null,
  destination text not null,
  stops jsonb not null default '[]'::jsonb,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create table if not exists public.flight_orders (
  id uuid primary key default gen_random_uuid(),
  unit_id uuid not null references public.units(id),
  operation_date date not null,
  status public.flight_order_status not null default 'draft',
  submitted_at timestamptz,
  approved_at timestamptz,
  closed_at timestamptz,
  created_by uuid references public.profiles(id),
  approved_by uuid references public.profiles(id),
  closed_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (unit_id, operation_date)
);

create table if not exists public.flights (
  id uuid primary key default gen_random_uuid(),
  flight_order_id uuid not null references public.flight_orders(id),
  unit_id uuid not null references public.units(id),
  aircraft_id uuid not null references public.aircraft(id),
  route_id uuid not null references public.routes(id),
  planned_departure timestamptz,
  planned_arrival timestamptz,
  actual_total_minutes integer,
  actual_air_minutes integer,
  closed boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create table if not exists public.flight_crew (
  id uuid primary key default gen_random_uuid(),
  flight_id uuid not null references public.flights(id) on delete cascade,
  crew_member_id uuid not null references public.crew_members(id),
  crew_type public.crew_type not null,
  unique (flight_id, crew_member_id)
);

create table if not exists public.flight_status_events (
  id uuid primary key default gen_random_uuid(),
  flight_id uuid not null references public.flights(id) on delete cascade,
  status public.flight_status_code not null,
  occurred_at timestamptz not null,
  locality text,
  recorded_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  unique (flight_id, status)
);

create table if not exists public.closure_requests (
  id uuid primary key default gen_random_uuid(),
  flight_order_id uuid not null references public.flight_orders(id),
  status public.closure_status not null default 'requested',
  requested_by uuid references public.profiles(id),
  reviewed_by uuid references public.profiles(id),
  notes text,
  requested_at timestamptz,
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  recipient_id uuid references public.profiles(id),
  unit_id uuid references public.units(id),
  title text not null,
  body text not null,
  read_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  sender_id uuid not null references public.profiles(id),
  recipient_id uuid references public.profiles(id),
  unit_id uuid references public.units(id),
  subject text not null,
  body text not null,
  created_at timestamptz not null default now()
);

create table if not exists public.report_exports (
  id uuid primary key default gen_random_uuid(),
  requested_by uuid not null references public.profiles(id),
  report_type text not null,
  format public.report_format not null,
  filters jsonb not null default '{}'::jsonb,
  storage_path text,
  created_at timestamptz not null default now()
);

create index if not exists profiles_role_idx on public.profiles(role);
create index if not exists profiles_unit_id_idx on public.profiles(unit_id);
create index if not exists profiles_status_idx on public.profiles(status);
create index if not exists role_permissions_role_idx on public.role_permissions(role);
create index if not exists audit_logs_actor_created_idx on public.audit_logs(actor_id, created_at desc);
create index if not exists audit_logs_resource_idx on public.audit_logs(resource_type, resource_id);
create index if not exists aircraft_unit_id_idx on public.aircraft(unit_id);
create index if not exists crew_members_unit_type_idx on public.crew_members(unit_id, crew_type);
create index if not exists flight_orders_unit_date_idx on public.flight_orders(unit_id, operation_date desc);
create index if not exists flights_unit_id_idx on public.flights(unit_id);
create index if not exists flights_order_id_idx on public.flights(flight_order_id);
create index if not exists flight_status_events_flight_time_idx on public.flight_status_events(flight_id, occurred_at);
create index if not exists notifications_recipient_read_idx on public.notifications(recipient_id, read_at);

drop trigger if exists set_units_updated_at on public.units;
create trigger set_units_updated_at
before update on public.units
for each row execute function public.set_updated_at();

drop trigger if exists set_profiles_updated_at on public.profiles;
create trigger set_profiles_updated_at
before update on public.profiles
for each row execute function public.set_updated_at();

drop trigger if exists set_aircraft_updated_at on public.aircraft;
create trigger set_aircraft_updated_at
before update on public.aircraft
for each row execute function public.set_updated_at();

drop trigger if exists set_crew_members_updated_at on public.crew_members;
create trigger set_crew_members_updated_at
before update on public.crew_members
for each row execute function public.set_updated_at();

drop trigger if exists set_routes_updated_at on public.routes;
create trigger set_routes_updated_at
before update on public.routes
for each row execute function public.set_updated_at();

drop trigger if exists set_flight_orders_updated_at on public.flight_orders;
create trigger set_flight_orders_updated_at
before update on public.flight_orders
for each row execute function public.set_updated_at();

drop trigger if exists set_flights_updated_at on public.flights;
create trigger set_flights_updated_at
before update on public.flights
for each row execute function public.set_updated_at();

drop trigger if exists set_closure_requests_updated_at on public.closure_requests;
create trigger set_closure_requests_updated_at
before update on public.closure_requests
for each row execute function public.set_updated_at();

create or replace function public.enforce_general_admin_limit()
returns trigger
language plpgsql
as $$
begin
  if new.status = 'active' and new.role = 'general_admin' then
    if (
      select count(*)
      from public.profiles
      where status = 'active'
        and role = 'general_admin'
        and id <> new.id
    ) >= 5 then
      raise exception 'BUSINESS_GENERAL_ADMIN_LIMIT_REACHED';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists enforce_general_admin_limit_trigger on public.profiles;
create trigger enforce_general_admin_limit_trigger
before insert or update on public.profiles
for each row execute function public.enforce_general_admin_limit();

create or replace function public.current_profile_role()
returns public.app_role
language sql
stable
security definer
set search_path = public
as $$
  select role from public.profiles where id = auth.uid();
$$;

create or replace function public.current_profile_unit_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select unit_id from public.profiles where id = auth.uid();
$$;

create or replace function public.current_profile_status()
returns public.profile_status
language sql
stable
security definer
set search_path = public
as $$
  select status from public.profiles where id = auth.uid();
$$;

create or replace function public.is_active_profile()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(public.current_profile_status() = 'active', false);
$$;

create or replace function public.is_global_role()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.current_profile_role() in ('leader', 'general_admin');
$$;

create or replace function public.same_unit(target_unit_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select target_unit_id is not null
    and public.current_profile_unit_id() = target_unit_id;
$$;

create or replace function public.has_permission(permission_key text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(exists (
    select 1
    from public.profiles p
    join public.role_permissions rp on rp.role = p.role
    join public.permissions perm on perm.id = rp.permission_id
    where p.id = auth.uid()
      and p.status = 'active'
      and rp.enabled
      and perm.active
      and perm.key = permission_key
  ), false);
$$;

create or replace function public.handle_new_auth_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, email, display_name, status)
  values (
    new.id,
    coalesce(new.email, ''),
    coalesce(new.raw_user_meta_data ->> 'display_name', new.email, 'Usuario'),
    'pending'
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_auth_user();

alter table public.units enable row level security;
alter table public.profiles enable row level security;
alter table public.permissions enable row level security;
alter table public.role_permissions enable row level security;
alter table public.audit_logs enable row level security;
alter table public.aircraft enable row level security;
alter table public.crew_members enable row level security;
alter table public.routes enable row level security;
alter table public.flight_orders enable row level security;
alter table public.flights enable row level security;
alter table public.flight_crew enable row level security;
alter table public.flight_status_events enable row level security;
alter table public.closure_requests enable row level security;
alter table public.notifications enable row level security;
alter table public.messages enable row level security;
alter table public.report_exports enable row level security;

drop policy if exists "profiles_read_own_or_authorized" on public.profiles;
create policy "profiles_read_own_or_authorized"
on public.profiles
for select
to authenticated
using (
  id = auth.uid()
  or (
    public.has_permission('users.read')
    and (
      public.is_global_role()
      or public.same_unit(unit_id)
    )
  )
);

drop policy if exists "profiles_update_own_profile_fields" on public.profiles;
create policy "profiles_update_own_profile_fields"
on public.profiles
for update
to authenticated
using (id = auth.uid() and public.has_permission('profile.update'))
with check (id = auth.uid());

drop policy if exists "units_read_authorized" on public.units;
create policy "units_read_authorized"
on public.units
for select
to authenticated
using (
  public.has_permission('units.read')
  and (public.is_global_role() or public.same_unit(id))
);

drop policy if exists "permissions_read_authorized" on public.permissions;
create policy "permissions_read_authorized"
on public.permissions
for select
to authenticated
using (public.has_permission('permissions.read'));

drop policy if exists "role_permissions_read_authorized" on public.role_permissions;
create policy "role_permissions_read_authorized"
on public.role_permissions
for select
to authenticated
using (public.has_permission('permissions.read'));

drop policy if exists "audit_read_authorized" on public.audit_logs;
create policy "audit_read_authorized"
on public.audit_logs
for select
to authenticated
using (public.has_permission('audit.read'));

drop policy if exists "aircraft_read_by_scope" on public.aircraft;
create policy "aircraft_read_by_scope"
on public.aircraft
for select
to authenticated
using (
  public.has_permission('aircraft.read')
  and (public.is_global_role() or public.same_unit(unit_id))
);

drop policy if exists "crew_read_by_scope" on public.crew_members;
create policy "crew_read_by_scope"
on public.crew_members
for select
to authenticated
using (
  public.has_permission('crew.read')
  and (public.is_global_role() or public.same_unit(unit_id))
);

drop policy if exists "routes_read_by_scope" on public.routes;
create policy "routes_read_by_scope"
on public.routes
for select
to authenticated
using (
  public.has_permission('flight_orders.read')
  and (public.is_global_role() or unit_id is null or public.same_unit(unit_id))
);

drop policy if exists "flight_orders_read_by_scope" on public.flight_orders;
create policy "flight_orders_read_by_scope"
on public.flight_orders
for select
to authenticated
using (
  public.has_permission('flight_orders.read')
  and (public.is_global_role() or public.same_unit(unit_id))
);

drop policy if exists "flights_read_by_scope" on public.flights;
create policy "flights_read_by_scope"
on public.flights
for select
to authenticated
using (
  public.has_permission('flights.read')
  and (public.is_global_role() or public.same_unit(unit_id))
);

drop policy if exists "flight_crew_read_by_flight_scope" on public.flight_crew;
create policy "flight_crew_read_by_flight_scope"
on public.flight_crew
for select
to authenticated
using (
  exists (
    select 1
    from public.flights f
    where f.id = flight_crew.flight_id
      and public.has_permission('flights.read')
      and (public.is_global_role() or public.same_unit(f.unit_id))
  )
);

drop policy if exists "flight_status_read_by_flight_scope" on public.flight_status_events;
create policy "flight_status_read_by_flight_scope"
on public.flight_status_events
for select
to authenticated
using (
  exists (
    select 1
    from public.flights f
    where f.id = flight_status_events.flight_id
      and public.has_permission('flights.read')
      and (public.is_global_role() or public.same_unit(f.unit_id))
  )
);

drop policy if exists "closures_read_by_order_scope" on public.closure_requests;
create policy "closures_read_by_order_scope"
on public.closure_requests
for select
to authenticated
using (
  exists (
    select 1
    from public.flight_orders fo
    where fo.id = closure_requests.flight_order_id
      and public.has_permission('flight_orders.read')
      and (public.is_global_role() or public.same_unit(fo.unit_id))
  )
);

drop policy if exists "notifications_read_own_or_unit" on public.notifications;
create policy "notifications_read_own_or_unit"
on public.notifications
for select
to authenticated
using (
  public.has_permission('notifications.read')
  and (
    recipient_id = auth.uid()
    or (unit_id is not null and public.same_unit(unit_id))
    or public.is_global_role()
  )
);

drop policy if exists "messages_read_own_or_unit" on public.messages;
create policy "messages_read_own_or_unit"
on public.messages
for select
to authenticated
using (
  public.has_permission('messages.read')
  and (
    sender_id = auth.uid()
    or recipient_id = auth.uid()
    or (unit_id is not null and public.same_unit(unit_id))
    or public.is_global_role()
  )
);

drop policy if exists "report_exports_read_authorized" on public.report_exports;
create policy "report_exports_read_authorized"
on public.report_exports
for select
to authenticated
using (
  public.has_permission('reports.read')
  and (requested_by = auth.uid() or public.is_global_role())
);

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'profile-avatars',
  'profile-avatars',
  false,
  5242880,
  array['image/png', 'image/jpeg', 'image/webp']
)
on conflict (id) do update
set public = excluded.public,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

insert into storage.buckets (id, name, public, file_size_limit)
values ('reports', 'reports', false, 52428800)
on conflict (id) do update
set public = excluded.public,
    file_size_limit = excluded.file_size_limit;

drop policy if exists "profile_avatars_owner_read" on storage.objects;
create policy "profile_avatars_owner_read"
on storage.objects
for select
to authenticated
using (
  bucket_id = 'profile-avatars'
  and owner = auth.uid()
);

drop policy if exists "profile_avatars_owner_write" on storage.objects;
create policy "profile_avatars_owner_write"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'profile-avatars'
  and owner = auth.uid()
  and public.has_permission('profile.update')
);

drop policy if exists "reports_private_authorized_read" on storage.objects;
create policy "reports_private_authorized_read"
on storage.objects
for select
to authenticated
using (
  bucket_id = 'reports'
  and public.has_permission('reports.read')
);
