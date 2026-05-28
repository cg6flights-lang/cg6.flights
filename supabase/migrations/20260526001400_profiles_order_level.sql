-- Profiles at Flight Order level + fuel_type column
-- Drops old per-item profiles, creates order-level profiles with item junction table.

-- 0. Add fuel_type to flight_order_items
ALTER TABLE public.flight_order_items ADD COLUMN IF NOT EXISTS fuel_type varchar(20);

-- 1. Drop old per-item profiles table
DROP TABLE IF EXISTS public.flight_order_profiles CASCADE;

-- 2. Create new profiles table with FK to flight_orders
CREATE TABLE public.flight_order_profiles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  flight_order_id uuid NOT NULL REFERENCES public.flight_orders(id) ON DELETE CASCADE,
  profile_number integer NOT NULL,
  description text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (flight_order_id, profile_number)
);

ALTER TABLE public.flight_order_profiles ENABLE ROW LEVEL SECURITY;

-- 3. Junction table: which profiles are assigned to which items
CREATE TABLE public.flight_order_item_profiles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  flight_order_item_id uuid NOT NULL REFERENCES public.flight_order_items(id) ON DELETE CASCADE,
  profile_id uuid NOT NULL REFERENCES public.flight_order_profiles(id) ON DELETE CASCADE,
  UNIQUE (flight_order_item_id, profile_id)
);

ALTER TABLE public.flight_order_item_profiles ENABLE ROW LEVEL SECURITY;

-- 4. Indexes
CREATE INDEX flight_order_profiles_order_id_idx ON public.flight_order_profiles(flight_order_id);
CREATE INDEX flight_order_item_profiles_item_id_idx ON public.flight_order_item_profiles(flight_order_item_id);
CREATE INDEX flight_order_item_profiles_profile_id_idx ON public.flight_order_item_profiles(profile_id);

-- 5. RLS policies

-- flight_order_profiles
DROP POLICY IF EXISTS "flight_order_profiles_read_by_scope" ON public.flight_order_profiles;
CREATE POLICY "flight_order_profiles_read_by_scope"
ON public.flight_order_profiles FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.flight_orders fo
    WHERE fo.id = flight_order_profiles.flight_order_id
      AND public.has_permission('flight_orders.read')
      AND (public.is_global_role() OR public.same_unit(fo.unit_id))
  )
);

DROP POLICY IF EXISTS "flight_order_profiles_insert_by_create" ON public.flight_order_profiles;
CREATE POLICY "flight_order_profiles_insert_by_create"
ON public.flight_order_profiles FOR INSERT TO authenticated
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.flight_orders fo
    WHERE fo.id = flight_order_profiles.flight_order_id
      AND public.has_permission('flight_orders.create')
      AND (public.is_global_role() OR public.same_unit(fo.unit_id))
  )
);

DROP POLICY IF EXISTS "flight_order_profiles_delete_by_create" ON public.flight_order_profiles;
CREATE POLICY "flight_order_profiles_delete_by_create"
ON public.flight_order_profiles FOR DELETE TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.flight_orders fo
    WHERE fo.id = flight_order_profiles.flight_order_id
      AND public.has_permission('flight_orders.create')
      AND (public.is_global_role() OR public.same_unit(fo.unit_id))
  )
);

-- flight_order_item_profiles
DROP POLICY IF EXISTS "flight_order_item_profiles_read_by_scope" ON public.flight_order_item_profiles;
CREATE POLICY "flight_order_item_profiles_read_by_scope"
ON public.flight_order_item_profiles FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.flight_order_items foi
    JOIN public.flight_orders fo ON fo.id = foi.flight_order_id
    WHERE foi.id = flight_order_item_profiles.flight_order_item_id
      AND public.has_permission('flight_orders.read')
      AND (public.is_global_role() OR public.same_unit(fo.unit_id))
  )
);

DROP POLICY IF EXISTS "flight_order_item_profiles_insert_by_create" ON public.flight_order_item_profiles;
CREATE POLICY "flight_order_item_profiles_insert_by_create"
ON public.flight_order_item_profiles FOR INSERT TO authenticated
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.flight_order_items foi
    JOIN public.flight_orders fo ON fo.id = foi.flight_order_id
    WHERE foi.id = flight_order_item_profiles.flight_order_item_id
      AND public.has_permission('flight_orders.create')
      AND (public.is_global_role() OR public.same_unit(fo.unit_id))
  )
);

DROP POLICY IF EXISTS "flight_order_item_profiles_delete_by_create" ON public.flight_order_item_profiles;
CREATE POLICY "flight_order_item_profiles_delete_by_create"
ON public.flight_order_item_profiles FOR DELETE TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.flight_order_items foi
    JOIN public.flight_orders fo ON fo.id = foi.flight_order_id
    WHERE foi.id = flight_order_item_profiles.flight_order_item_id
      AND public.has_permission('flight_orders.create')
      AND (public.is_global_role() OR public.same_unit(fo.unit_id))
  )
);
