-- Extended profile fields for CG6 Flights v1.2
-- Add personal data columns to profiles

alter table public.profiles
  add column if not exists first_name text,
  add column if not exists last_name text,
  add column if not exists document_type text,
  add column if not exists document_id text,
  add column if not exists phone_country_code text default '+51',
  add column if not exists birth_date date,
  add column if not exists grade text,
  add column if not exists password_changed_at timestamptz;

-- Constraint: document_type must be 'dni' or 'passport' when set
alter table public.profiles
  add constraint profiles_document_type_check
  check (document_type is null or document_type in ('dni', 'passport'));

-- Constraint: grade must reference a valid active grade
-- (soft reference — not a FK to avoid circular deps on seed order)

-- Index for grade lookups
create index if not exists profiles_grade_idx on public.profiles(grade);

-- Index for document lookups
create index if not exists profiles_document_id_idx on public.profiles(document_id);
