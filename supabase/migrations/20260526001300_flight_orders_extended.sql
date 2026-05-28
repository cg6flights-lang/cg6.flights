-- Flight Orders extended schema
-- Adds acronym to units, callsign to crew_members, order_number to flight_orders,
-- and creates flight_order_items, crew, routes, state_events, and profiles tables.

-- 1. Extend existing tables
ALTER TABLE public.units ADD COLUMN IF NOT EXISTS acronym varchar(10);
ALTER TABLE public.crew_members ADD COLUMN IF NOT EXISTS callsign varchar(50);

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'flight_orders' AND column_name = 'order_number'
  ) THEN
    ALTER TABLE public.flight_orders ADD COLUMN order_number varchar(20);
  END IF;
END $$;

-- 2. flight_order_items
CREATE TABLE IF NOT EXISTS public.flight_order_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  flight_order_id uuid NOT NULL REFERENCES public.flight_orders(id) ON DELETE CASCADE,
  aircraft_id uuid NOT NULL REFERENCES public.aircraft(id),
  mission text,
  flight_level_min integer,
  flight_level_max integer,
  ete_minutes integer,
  fuel_amount numeric(8,1),
  scheduled_departure timestamptz,
  status varchar(20) NOT NULL DEFAULT 'waiting',
  cancelled boolean NOT NULL DEFAULT false,
  cancelled_at timestamptz,
  cancelled_by uuid REFERENCES public.profiles(id),
  cancel_reason text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.flight_order_items ENABLE ROW LEVEL SECURITY;

-- 3. flight_order_crew
CREATE TABLE IF NOT EXISTS public.flight_order_crew (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  flight_order_item_id uuid NOT NULL REFERENCES public.flight_order_items(id) ON DELETE CASCADE,
  crew_member_id uuid NOT NULL REFERENCES public.crew_members(id),
  role_code varchar(10) NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (flight_order_item_id, crew_member_id)
);

ALTER TABLE public.flight_order_crew ENABLE ROW LEVEL SECURITY;

-- 4. flight_order_routes (multi-segment)
CREATE TABLE IF NOT EXISTS public.flight_order_routes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  flight_order_item_id uuid NOT NULL REFERENCES public.flight_order_items(id) ON DELETE CASCADE,
  segment_order integer NOT NULL DEFAULT 1,
  segment_type varchar(20) NOT NULL DEFAULT 'outbound',
  origin_type varchar(20) NOT NULL DEFAULT 'airport',
  origin_route_id uuid REFERENCES public.routes(id),
  origin_label varchar(100),
  origin_lat double precision,
  origin_lng double precision,
  destination_type varchar(20) NOT NULL DEFAULT 'airport',
  destination_route_id uuid REFERENCES public.routes(id),
  destination_label varchar(100),
  destination_lat double precision,
  destination_lng double precision,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.flight_order_routes ENABLE ROW LEVEL SECURITY;

-- 5. flight_order_state_events
CREATE TABLE IF NOT EXISTS public.flight_order_state_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  flight_order_item_id uuid NOT NULL REFERENCES public.flight_order_items(id) ON DELETE CASCADE,
  status varchar(20) NOT NULL,
  occurred_at timestamptz NOT NULL DEFAULT now(),
  recorded_by uuid NOT NULL REFERENCES public.profiles(id),
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (flight_order_item_id, status)
);

ALTER TABLE public.flight_order_state_events ENABLE ROW LEVEL SECURITY;

-- 6. flight_order_profiles
CREATE TABLE IF NOT EXISTS public.flight_order_profiles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  flight_order_item_id uuid NOT NULL REFERENCES public.flight_order_items(id) ON DELETE CASCADE,
  profile_number integer NOT NULL,
  description text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (flight_order_item_id, profile_number)
);

ALTER TABLE public.flight_order_profiles ENABLE ROW LEVEL SECURITY;

-- 7. Indexes
CREATE INDEX IF NOT EXISTS flight_order_items_order_id_idx ON public.flight_order_items(flight_order_id);
CREATE INDEX IF NOT EXISTS flight_order_items_aircraft_id_idx ON public.flight_order_items(aircraft_id);
CREATE INDEX IF NOT EXISTS flight_order_routes_item_id_idx ON public.flight_order_routes(flight_order_item_id);
CREATE INDEX IF NOT EXISTS flight_order_state_events_item_id_idx ON public.flight_order_state_events(flight_order_item_id);
CREATE INDEX IF NOT EXISTS flight_order_profiles_item_id_idx ON public.flight_order_profiles(flight_order_item_id);
CREATE INDEX IF NOT EXISTS flight_order_crew_item_id_idx ON public.flight_order_crew(flight_order_item_id);

-- 8. Updated_at triggers
CREATE OR REPLACE FUNCTION public.set_flight_order_items_updated_at()
RETURNS trigger AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS set_flight_order_items_updated_at ON public.flight_order_items;
CREATE TRIGGER set_flight_order_items_updated_at
BEFORE UPDATE ON public.flight_order_items
FOR EACH ROW EXECUTE FUNCTION public.set_flight_order_items_updated_at();

-- 9. RLS Policies — read by scope (same pattern as flight_orders_read_by_scope)

-- flight_order_items
DROP POLICY IF EXISTS "flight_order_items_read_by_scope" ON public.flight_order_items;
CREATE POLICY "flight_order_items_read_by_scope"
ON public.flight_order_items
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.flight_orders fo
    WHERE fo.id = flight_order_items.flight_order_id
      AND public.has_permission('flight_orders.read')
      AND (public.is_global_role() OR public.same_unit(fo.unit_id))
  )
);

-- flight_order_crew
DROP POLICY IF EXISTS "flight_order_crew_read_by_scope" ON public.flight_order_crew;
CREATE POLICY "flight_order_crew_read_by_scope"
ON public.flight_order_crew
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.flight_order_items foi
    JOIN public.flight_orders fo ON fo.id = foi.flight_order_id
    WHERE foi.id = flight_order_crew.flight_order_item_id
      AND public.has_permission('flight_orders.read')
      AND (public.is_global_role() OR public.same_unit(fo.unit_id))
  )
);

-- flight_order_routes
DROP POLICY IF EXISTS "flight_order_routes_read_by_scope" ON public.flight_order_routes;
CREATE POLICY "flight_order_routes_read_by_scope"
ON public.flight_order_routes
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.flight_order_items foi
    JOIN public.flight_orders fo ON fo.id = foi.flight_order_id
    WHERE foi.id = flight_order_routes.flight_order_item_id
      AND public.has_permission('flight_orders.read')
      AND (public.is_global_role() OR public.same_unit(fo.unit_id))
  )
);

-- flight_order_state_events
DROP POLICY IF EXISTS "flight_order_state_events_read_by_scope" ON public.flight_order_state_events;
CREATE POLICY "flight_order_state_events_read_by_scope"
ON public.flight_order_state_events
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.flight_order_items foi
    JOIN public.flight_orders fo ON fo.id = foi.flight_order_id
    WHERE foi.id = flight_order_state_events.flight_order_item_id
      AND public.has_permission('flight_orders.read')
      AND (public.is_global_role() OR public.same_unit(fo.unit_id))
  )
);

-- flight_order_profiles
DROP POLICY IF EXISTS "flight_order_profiles_read_by_scope" ON public.flight_order_profiles;
CREATE POLICY "flight_order_profiles_read_by_scope"
ON public.flight_order_profiles
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.flight_order_items foi
    JOIN public.flight_orders fo ON fo.id = foi.flight_order_id
    WHERE foi.id = flight_order_profiles.flight_order_item_id
      AND public.has_permission('flight_orders.read')
      AND (public.is_global_role() OR public.same_unit(fo.unit_id))
  )
);
