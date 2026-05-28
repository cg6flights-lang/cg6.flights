-- Agregar motivo de inoperatividad a aeronaves
alter table public.aircraft
  add column if not exists inoperative_reason text;
