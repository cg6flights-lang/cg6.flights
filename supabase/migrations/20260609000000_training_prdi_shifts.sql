-- Migration: Cadet training, PRDI flights, shifts, and alert flights

-- 1. Crew members: cadet training fields
alter table crew_members
  add column if not exists training_start date,
  add column if not exists training_end date,
  add column if not exists course_group text;

-- 2. Flights: PRDI, shifts, alert, ratings
alter table flights
  add column if not exists flight_type text default 'normal',
  add column if not exists shift text,
  add column if not exists instructor_id uuid references crew_members(id),
  add column if not exists rating text,
  add column if not exists cadet_turn int,
  add column if not exists check_ride text;
