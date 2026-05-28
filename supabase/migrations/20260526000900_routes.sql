-- Drop FK from flights so we can recreate routes
ALTER TABLE public.flights DROP CONSTRAINT IF EXISTS flights_route_id_fkey;

-- Drop trigger and policies from old routes table
DROP TRIGGER IF EXISTS set_routes_updated_at ON public.routes;
DROP POLICY IF EXISTS routes_read_by_scope ON public.routes;

-- Drop old table
DROP TABLE IF EXISTS public.routes;

-- Create route_category enum
DO $$
BEGIN
  CREATE TYPE public.route_category AS ENUM ('internacional', 'nacional', 'aerodromo', 'helipuerto');
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

-- Create new routes table
CREATE TABLE public.routes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  airport_name text NOT NULL,
  category route_category NOT NULL DEFAULT 'internacional',
  icao_code text,
  iata_code text,
  country text NOT NULL,
  city text NOT NULL,
  latitude double precision,
  longitude double precision,
  active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz
);

-- Re-add trigger
CREATE TRIGGER set_routes_updated_at
  BEFORE UPDATE ON public.routes
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- Re-add FK on flights
ALTER TABLE public.flights
  ADD CONSTRAINT flights_route_id_fkey
  FOREIGN KEY (route_id) REFERENCES public.routes(id);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_routes_active ON routes (active) WHERE active = true;
CREATE INDEX IF NOT EXISTS idx_routes_category ON routes (category);
CREATE INDEX IF NOT EXISTS idx_routes_country ON routes (country);

-- RLS
ALTER TABLE public.routes ENABLE ROW LEVEL SECURITY;

-- Read policy: any authenticated user with routes.read can read active routes
CREATE POLICY routes_read_all ON public.routes
  FOR SELECT
  USING (active = true);

-- Manage policy: only leader and general_admin with active profile can insert/update/delete
CREATE POLICY routes_manage_by_global ON public.routes
  FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
        AND profiles.status = 'active'
        AND profiles.role IN ('leader', 'general_admin')
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
        AND profiles.status = 'active'
        AND profiles.role IN ('leader', 'general_admin')
    )
  );
