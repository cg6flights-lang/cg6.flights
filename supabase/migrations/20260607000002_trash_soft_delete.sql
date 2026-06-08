-- Migration: Add deleted_at to tables missing soft-delete for Trash/Backup system
-- Tables already with deleted_at: units, aircraft, crew_members, routes, flights, calendar_events, messages

-- flight_orders
alter table public.flight_orders add column if not exists deleted_at timestamptz;

-- flight_order_profiles
alter table public.flight_order_profiles add column if not exists deleted_at timestamptz;

-- flight_order_items (cancelItem should set deleted_at instead of just status)
-- Already has cancelled status; ensure deleted_at is set on cancel

-- RLS: allow reading soft-deleted items for authorized roles (leader, general_admin)
-- The trash page queries all tables with deleted_at IS NOT NULL
-- Existing RLS policies on each table already allow read for authorized roles
-- No new RLS policies needed for reading; restore uses existing Edge Functions
