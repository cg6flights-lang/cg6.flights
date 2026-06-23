# Modulo: Personal, Escuadrones y Cadetes

## Estado

Implementado (as-built 2026-06-23, v1.1–v1.2). Spec post-implementación.

## Responsabilidad

- Gestionar la **tripulación** (pilotos, copilotos, mecánicos / ingenieros de vuelo) por unidad.
- Gestionar **escuadrones de vuelo** dentro de una unidad (GRU51) y su asociación M:N con aeronaves.
- Soportar el rol **Jefe de Escuadrón** con scope acotado a su escuadrón.
- Gestionar **cadetes temporales**: cursos, grados, PRDI, turnos de instrucción.

## No responsabilidad

- No gestiona usuarios/cuentas (eso es Auth/Users); la tripulación es un maestro operativo.
- No define permisos por escuadrón: el Jefe de Escuadrón opera por **scope** (`squadronId`), no por permisos propios.

## Entidades

### crew_members

Base en `database.spec.md §5` (`id`, `unit_id`, `full_name`, `document_id`, `crew_type`, `active`, timestamps, `deleted_at`). Columnas as-built:

- `assignment_type` — Nato / Foráneo.
- `function_code` — PS/IP/PM/CP/CO/PI/PR.
- `squadron_id` UUID FK `flight_squadrons` (scope).
- `cadet_course_id` UUID FK `cadet_courses`.
- `training_start`, `training_end` date; `course_group` text.
- `photo_path` text (Storage privado).

### flight_squadrons

- `id` UUID PK, `unit_id` UUID FK units, nombre/código, `active`, timestamps.

### aircraft_squadrons (junction M:N)

- `aircraft_id` UUID FK aircraft (on delete cascade).
- `squadron_id` UUID FK flight_squadrons (on delete cascade).

### cadet_courses

- `id` UUID PK, `unit_id` UUID FK units, datos del curso (nombre, grupo, fechas).

### flight_order_items (columnas de instrucción)

- `flight_type` (default `normal`), `shift`, `instructor_id` FK crew_members, `rating`, `cadet_turn` int, `check_ride`.

## Casos de uso

1. CRUD de tripulación por unidad (Edge Function `manage-crew`).
2. Dashboard split Pilotos / Mecánicos con filtros (unidad, escuadrón, tipo).
3. Gestionar escuadrones de una unidad y asociar aeronaves (M:N).
4. Filtrar Tripulaciones y Aeronaves por escuadrón.
5. Aplicar scope `squadronId` para el Jefe de Escuadrón (`session_controller`).
6. Gestionar cadetes: curso, grado, foto; asignar turnos/PRDI a vuelos con instructor y check ride.

## Permisos

- `crew.read`, `crew.manage`.
- Aeronaves: `aircraft.read`, `aircraft.manage` (para asociación con escuadrones).
- Jefe de Escuadrón: sin permiso propio; **scope** por `squadronId`.

## RLS

- Tripulación, escuadrones y junctions aislados por unidad.
- Jefe de Escuadrón limitado a su escuadrón.

## UI

- Página Tripulaciones: split Pilotos/Mecánicos, filtros, foto, modal de detalle / hoja de vida.
- Aeronaves: filtros y chips por escuadrón.
- Gestión de cadetes con cursos, grados y turnos.

## Errores

- `crew.manage` ausente → 403.
- Operación sobre unidad/escuadrón ajeno → 403 (`AUTH_UNIT_MISMATCH`).

## Tests requeridos

- [x] Dominio `CrewMember` (`test/features/crew/domain/crew_member_test.dart`): categorías, `assignment_type`, `cadetCourseLabel`, serialización.
- [ ] Scope por escuadrón: Jefe de Escuadrón no ve otro escuadrón.
- [ ] Junction `aircraft_squadrons` M:N consistente.
