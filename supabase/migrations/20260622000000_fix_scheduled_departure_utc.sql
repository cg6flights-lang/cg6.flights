-- Historical fix for flight_order_items.scheduled_departure.
--
-- These values were written as local Peru time (UTC-5) but persisted as if they
-- were UTC (the app built a local DateTime and serialized it without converting).
-- The app now stores scheduled_departure in real UTC and renders it with the
-- configured timezone offset. To make existing rows consistent with the new
-- convention, shift them +5 hours so the stored instant becomes real UTC.
--
-- One-time correction: Supabase migrations run exactly once, so this will not
-- be re-applied. Assumes historical data was created in Peru (UTC-5), which
-- matches the operational context (Base Aérea Las Palmas).

update public.flight_order_items
set scheduled_departure = scheduled_departure + interval '5 hours'
where scheduled_departure is not null;
