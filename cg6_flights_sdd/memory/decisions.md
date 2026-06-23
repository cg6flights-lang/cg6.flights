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

## Decisiones recientes (v1.1–v1.3)

- Rol **Jefe de Escuadrón** (`squadronChief`) + scope por escuadrón (`squadronId` en `session_controller`).
- Escuadrones de vuelo con junction **M:N** a aeronaves (`flight_squadrons`, `aircraft_squadrons`).
- **Cadetes temporales**: `cadet_courses`, grados, PRDI, turnos en vuelos.
- **Soft-delete general (Papelera)** en vez de borrado físico ordinario; restauración desde Auditoría.
- **i18n completo ES/EN** (custom, ~38 archivos, toggle en login y header).
- **Realtime → invalidate**: `RealtimeInvalidator` invalida providers Riverpod por canal/tabla con debounce (sin reescribir queries con joins); se elimina el polling con `Timer`.
- **Horas en UTC** en DB; display con offset de `timezoneProvider`.
- **Batch loading** de relaciones de OV (queries separadas + `inFilter`) en vez de selects anidados.
- Aeronaves: `aircraft_page` **modularizado** en `presentation/widgets/` + `aircraft_providers.dart`.
- **Testing**: suite unitaria (dominios + presenters + servicios); gates `flutter analyze` (0 issues) + `flutter test`.
- Dashboard: `ReorderableListView` con `onReorderItem` (no `onReorder`, deprecado en Flutter 3.44.1).
