-- Cadet Courses management

create table if not exists cadet_courses (
  id uuid primary key default gen_random_uuid(),
  unit_id uuid not null references units(id),
  name text not null,
  start_date date not null,
  end_date date not null,
  status text default 'active',    -- 'active', 'archived'
  created_at timestamptz default now()
);

-- Replace course_group text with cadet_course_id FK
alter table crew_members
  add column if not exists cadet_course_id uuid references cadet_courses(id);

alter table cadet_courses enable row level security;

create policy "cadet_courses_read" on cadet_courses for select to authenticated using (true);
create policy "cadet_courses_manage" on cadet_courses for all to authenticated using (public.has_permission('crew.manage')) with check (public.has_permission('crew.manage'));
