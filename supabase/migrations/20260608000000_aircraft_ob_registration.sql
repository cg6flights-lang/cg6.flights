-- Migration: Add OB registration support for EDACI aircraft
alter table public.aircraft
  add column if not exists ob_tail_number text,
  add column if not exists display_registration text not null default 'FAP';
