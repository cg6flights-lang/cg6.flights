# /memory/decisions.md

# Decisions Memory — CG6 Flights

## Decisiones aprobadas

- Arquitectura modular por dominios.
- Flutter Web preliminar.
- Supabase preliminar.
- PostgreSQL como fuente de verdad.
- RLS obligatorio.
- RBAC + permisos granulares.
- Separación por unidad.
- Auditoría transversal.
- Estados de vuelo basados en eventos (`flight_order_state_events`).
- Órdenes de vuelo con items, rutas, tripulación y perfiles vía `flight_order_items` + tablas relacionadas.
- PDF de Orden de Vuelo generado en frontend con package `pdf`.
- Número de orden auto-generado: `ACRONYM-XXX` desde Edge Function.
- Reportes centralizados.
- Realtime limitado.
- Edge Functions para operaciones sensibles.
- Storage con buckets separados.
- Foto perfil máximo 5 MB.
- Históricos 5 años.
- Español/Inglés.
- Diseño aeronáutico militar.
- Mapas encapsulados.
- Geolocalización remota pendiente.
- IA gobernada por specs.
- Cambios estructurales mediante ADR.
