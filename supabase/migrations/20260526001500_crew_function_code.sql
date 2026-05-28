-- Add function_code to flight_order_crew
ALTER TABLE public.flight_order_crew
  ADD COLUMN IF NOT EXISTS function_code varchar(10);
