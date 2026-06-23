# /specs/database.spec.md

# Database Specification — CG6 Flights

## Estado

Aprobado operativo para implementación v1.0.

## 1. Propósito

La base de datos debe preservar la verdad operacional de CG6 Flights con trazabilidad, separación por unidad, RLS obligatorio, retención histórica de 5 años y soporte para reportes auditados.

## 2. Motor

- PostgreSQL administrado por Supabase.
- Migraciones versionadas en `/supabase/migrations`.
- RLS habilitado en todas las tablas sensibles.
- No se permiten cambios manuales no reproducibles en producción.

## 3. Convenciones

- Claves primarias UUID con `gen_random_uuid()`.
- Timestamps `created_at`, `updated_at`, `deleted_at` cuando aplique.
- Soft delete mediante `deleted_at` o `active = false`.
- Fechas operativas en UTC.
- Campos de auditoría: `created_by`, `updated_by` cuando aplique.
- Tablas en `public` salvo necesidad de schema separado aprobada por ADR.

## 4. Enumeraciones

- `app_role`: leader, general_admin, unit_command, unit_admin, squadron_chief, ttaa.
- `profile_status`: pending, active, inactive, rejected.
- `crew_type`: pilot, copilot, mechanic, flight_engineer.
- `aircraft_status`: operational, inoperative, maintenance.
- `flight_order_status`: draft, submitted, observed, approved, closed, reopened.
- `flight_status_code`: motor_start, taxi_start, takeoff, landing, engine_shutdown.
- `closure_status`: requested, observed, approved, rejected, reopened.
- `audit_result`: success, denied, failed.
- `report_format`: pdf, excel.

## 5. Tablas core

### units

- `id` UUID PK.
- `code` text único.
- `name` text.
- `active` boolean.
- `created_at`, `updated_at`, `deleted_at`.

### profiles

- `id` UUID PK vinculado a `auth.users.id`.
- `email` text único.
- `display_name` text.
- `status` profile_status.
- `role` app_role nullable.
- `unit_id` UUID nullable FK units.
- `phone` text nullable.
- `avatar_path` text nullable.
- `created_at`, `updated_at`.

Reglas:

- Un usuario pendiente no opera.
- Roles de unidad requieren `unit_id`.
- Solo puede existir un perfil con role leader activo.
- Solo pueden existir cinco perfiles general_admin activos.

### permissions

- `id` UUID PK.
- `key` text único.
- `description` text.
- `module` text.
- `active` boolean.

### role_permissions

- `id` UUID PK.
- `role` app_role.
- `permission_id` UUID FK permissions.
- `enabled` boolean.
- Unique `(role, permission_id)`.

### audit_logs

- `id` UUID PK.
- `actor_id` UUID nullable.
- `actor_role` app_role nullable.
- `actor_unit_id` UUID nullable.
- `action` text.
- `resource_type` text.
- `resource_id` UUID nullable.
- `result` audit_result.
- `ip_address` text nullable.
- `user_agent` text nullable.
- `metadata` jsonb.
- `created_at`.

### aircraft

- `id` UUID PK.
- `unit_id` UUID FK units.
- `tail_number` text único.
- `model` text.
- `manufacturer` text.
- `serial_number` text nullable.
- `year` integer nullable.
- `status` aircraft_status.
- `active` boolean.
- `created_at`, `updated_at`, `deleted_at`.

### crew_members

- `id` UUID PK.
- `unit_id` UUID FK units.
- `full_name` text.
- `document_id` text nullable.
- `crew_type` crew_type.
- `active` boolean.
- `created_at`, `updated_at`, `deleted_at`.

### routes

- `id` UUID PK.
- `unit_id` UUID nullable FK units.
- `name` text.
- `origin` text.
- `destination` text.
- `stops` jsonb.
- `active` boolean.
- `created_at`, `updated_at`, `deleted_at`.

### flight_orders

- `id` UUID PK.
- `unit_id` UUID FK units.
- `operation_date` date.
- `order_number` varchar (generado: ACRONYM-XXX).
- `status` flight_order_status.
- `submitted_at`, `approved_at`, `closed_at` nullable.
- `created_by`, `approved_by`, `closed_by` nullable.
- `created_at`, `updated_at`.
- Unique `(unit_id, operation_date)`.

### flight_order_items

- `id` UUID PK.
- `flight_order_id` UUID FK flight_orders.
- `aircraft_id` UUID FK aircraft.
- `mission` text nullable.
- `flight_level_min` integer nullable.
- `flight_level_max` integer nullable.
- `ete_minutes` integer nullable.
- `fuel_type` varchar nullable (lbs/gal).
- `fuel_amount` numeric nullable.
- `scheduled_departure` timestamptz nullable.
- `status` varchar (waiting, taxi, takeoff, landing, engine_off, cancelled).
- `cancelled` boolean.
- `cancelled_at` timestamptz nullable.
- `cancelled_by` UUID nullable.
- `cancel_reason` text nullable.
- `created_at`, `updated_at`.

### flight_order_routes

- `id` UUID PK.
- `flight_order_item_id` UUID FK flight_order_items.
- `segment_order` integer.
- `segment_type` varchar (outbound/return).
- `origin_type` varchar (airport/zone/waypoint).
- `origin_route_id` UUID FK routes nullable.
- `origin_label` varchar nullable.
- `origin_lat` double precision nullable.
- `origin_lng` double precision nullable.
- `destination_type` varchar (airport/zone/waypoint).
- `destination_route_id` UUID FK routes nullable.
- `destination_label` varchar nullable.
- `destination_lat` double precision nullable.
- `destination_lng` double precision nullable.
- `created_at`.

### flight_order_crew

- `id` UUID PK.
- `flight_order_item_id` UUID FK flight_order_items.
- `crew_member_id` UUID FK crew_members.
- `role_code` varchar (PC/CP/MA).
- `function_code` varchar nullable (PS/IP/PM/CP/CO/PI/PR).

### flight_order_state_events

- `id` UUID PK.
- `flight_order_item_id` UUID FK flight_order_items.
- `status` varchar.
- `occurred_at` timestamptz.
- `recorded_by` UUID FK profiles.
- `created_at`.

### flight_order_profiles

- `id` UUID PK.
- `flight_order_id` UUID FK flight_orders.
- `profile_number` integer (auto-numerado por orden).
- `description` text.
- `created_at`.

### flight_order_item_profiles

- `id` UUID PK.
- `flight_order_item_id` UUID FK flight_order_items.
- `profile_id` UUID FK flight_order_profiles.
- Junction table: perfiles asignados a vuelos específicos.

### closure_requests

- `id` UUID PK.
- `flight_order_id` UUID FK flight_orders.
- `status` closure_status.
- `requested_by`, `reviewed_by` UUID nullable.
- `notes` text nullable.
- `requested_at`, `reviewed_at` nullable.
- `created_at`, `updated_at`.

### notifications

- `id` UUID PK.
- `recipient_id` UUID FK profiles nullable.
- `unit_id` UUID FK units nullable.
- `title` text.
- `body` text.
- `read_at` timestamptz nullable.
- `created_at`.

### calendar_events

- `id` UUID PK.
- `title` text.
- `description` text nullable.
- `location` text nullable.
- `event_type` text (`operations`, `training`, `maintenance`, `briefing`, `administrative`, `other`).
- `status` text (`scheduled`, `in_progress`, `completed`, `cancelled`).
- `starts_at` timestamptz.
- `ends_at` timestamptz.
- `created_by` UUID FK profiles.
- `created_at`, `updated_at`, `deleted_at`.

Reglas:

- `ends_at >= starts_at`.
- Lectura para usuarios activos con `calendar.read`.
- Gestión solo vía Edge Function para usuarios con `calendar.manage`.
- Eliminación ordinaria es lógica mediante `deleted_at`.

### messages

- `id` UUID PK.
- `sender_id` UUID FK profiles.
- `recipient_id` UUID FK profiles.
- `unit_id` UUID FK units nullable; debe ser null para chat privado v1.1.
- `subject` text; por defecto `Chat`.
- `body` text.
- `created_at`.

Reglas:

- Chats privados solo son visibles para remitente y destinatario.
- Los roles globales no leen conversaciones privadas ajenas.

### message_reads

- `id` UUID PK.
- `message_id` UUID FK messages.
- `profile_id` UUID FK profiles.
- `read_at` timestamptz.
- `created_at`.
- Unique `(message_id, profile_id)`.

### message_posts

- `id` UUID PK.
- `author_id` UUID FK profiles.
- `scope` text (`global` o `unit`).
- `unit_id` UUID FK units nullable.
- `body` text.
- `created_at`, `updated_at`, `deleted_at`.
- Constraint: scope global requiere `unit_id is null`; scope unidad requiere `unit_id is not null`.

### message_post_comments

- `id` UUID PK.
- `post_id` UUID FK message_posts.
- `author_id` UUID FK profiles.
- `body` text.
- `created_at`, `deleted_at`.

### message_post_reads

- `id` UUID PK.
- `post_id` UUID FK message_posts.
- `profile_id` UUID FK profiles.
- `read_at` timestamptz.
- `created_at`.
- Unique `(post_id, profile_id)`.

### report_exports

- `id` UUID PK.
- `requested_by` UUID FK profiles.
- `report_type` text.
- `format` report_format.
- `filters` jsonb.
- `storage_path` text nullable.
- `created_at`.

### Tablas y columnas añadidas (v1.1–v1.3, as-built)

**flight_squadrons** (escuadrones de vuelo)

- `id` UUID PK.
- `unit_id` UUID FK units.
- nombre/código + `active` + timestamps.

**aircraft_squadrons** (junction M:N aeronave↔escuadrón)

- `aircraft_id` UUID FK aircraft (on delete cascade).
- `squadron_id` UUID FK flight_squadrons (on delete cascade).

> `profiles`, `crew_members` y `flight_order_items` reciben `squadron_id` UUID FK `flight_squadrons` (scope por escuadrón para el rol Jefe de Escuadrón).

**cadet_courses** (cursos de cadetes)

- `id` UUID PK.
- `unit_id` UUID FK units.
- datos del curso (nombre, grupo, fechas).
- referenciada por `crew_members.cadet_course_id`.

Columnas de cadetes/instrucción en **crew_members**: `assignment_type` (Nato/Foráneo), `function_code` (PS/IP/PM/CP/CO/PI/PR), `training_start` date, `training_end` date, `course_group` text, `cadet_course_id` UUID FK, `photo_path` text (Storage privado).

Columnas de turnos/instrucción en **flight_order_items**: `flight_type` text (default `normal`), `shift` text, `instructor_id` UUID FK crew_members, `rating` text, `cadet_turn` int, `check_ride` text.

**aircraft_status_history** (tracking de operatividad)

- `id` UUID PK.
- `aircraft_id` UUID FK aircraft (on delete cascade).
- `unit_id` UUID FK units.
- `status` aircraft_status + timestamp del cambio.
- Base de la curva de operatividad (RPC `get_operational_curve`).

**Soft-delete (Papelera)**: columna `deleted_at timestamptz` en `flight_orders`, `flight_order_profiles` y demás tablas operativas; restauración desde Auditoría (Edge Function `list-trash`).

**Realtime**: `flight_orders`, `flight_order_items`, `flight_order_state_events`, `aircraft`, `crew_members` en la publicación `supabase_realtime` con replica identity full (migración `20260621000000_realtime_ops_tables.sql`).

## 6. Storage

Buckets:

- `profile-avatars`: privado, máximo 5 MB por archivo.
- `reports`: privado, exportaciones temporales o controladas.

Reglas:

- No buckets públicos para datos confidenciales.
- La URL firmada debe expirar.
- Toda exportación se registra en `report_exports` y `audit_logs`.

## 7. Índices mínimos

- `profiles(role)`, `profiles(unit_id)`, `profiles(status)`.
- `role_permissions(role)`.
- `audit_logs(actor_id, created_at desc)`.
- `audit_logs(resource_type, resource_id)`.
- `aircraft(unit_id)`.
- `crew_members(unit_id, crew_type)`.
- `flight_orders(unit_id, operation_date desc)`.
- `flight_order_items(flight_order_id, created_at)`.
- `flight_order_routes(flight_order_item_id, segment_order)`.
- `flight_order_crew(flight_order_item_id)`.
- `flight_order_state_events(flight_order_item_id, occurred_at)`.
- `flight_order_profiles(flight_order_id, profile_number)`.
- `flight_order_item_profiles(flight_order_item_id, profile_id)`.
- `notifications(recipient_id, read_at)`.
- `calendar_events(starts_at)`.
- `calendar_events(status, starts_at)`.
- `messages(sender_id, created_at desc)`.
- `messages(recipient_id, created_at desc)`.
- `message_reads(message_id, profile_id)`.
- `message_posts(scope, unit_id, created_at desc)`.
- `message_post_comments(post_id, created_at)`.
- `message_post_reads(post_id, profile_id)`.

## 8. RLS obligatorio

Funciones auxiliares:

- `current_profile_id()`.
- `current_profile_role()`.
- `current_profile_unit_id()`.
- `current_profile_status()`.
- `has_permission(permission_key text)`.
- `is_global_role()`.
- `same_unit(unit_id uuid)`.

Políticas base:

- Líder ve y administra alcance global según permisos.
- Administrador General ve alcance global operativo según permisos.
- Comando de Unidad ve y autoriza su unidad.
- Administrador de Unidad opera su unidad.
- TTAA solo lee vuelos asignados o autorizados.
- Usuario pending, inactive o sin rol no accede a datos operativos.
- Excepción de privacidad: `messages` de chat privado solo permite lectura a remitente o destinatario aunque el usuario sea líder o administrador global.
- Publicaciones (`message_posts`) admiten alcance global o unidad; comentarios y confirmaciones siguen la visibilidad del post.
- Calendario (`calendar_events`) es global de lectura para todo usuario activo con `calendar.read`; `calendar.manage` queda limitado a líder y administrador general.

## 9. Integridad y reglas DB

- Constraints para límites de Líder y Administrador General.
- Trigger `updated_at`.
- Trigger de validación de secuencia de estados.
- Trigger o función para recalcular tiempos derivados.
- Restricción para impedir modificación ordinaria de fichas cerradas.
- Soft delete para registros operativos.

## 10. Backups y retención

- Retención histórica funcional: 5 años.
- Backups según capacidades del plan Supabase contratado.
- Exportaciones no sustituyen backup.
- Datos reales no se usan en desarrollo.

## 11. Criterios de aceptación

- Todas las tablas sensibles tienen RLS habilitado.
- Las migraciones son reproducibles.
- Los índices cubren consultas principales.
- Las políticas impiden lectura cruzada entre unidades.
- Los límites de roles superiores se validan en DB y backend.
- Las exportaciones quedan auditadas.
