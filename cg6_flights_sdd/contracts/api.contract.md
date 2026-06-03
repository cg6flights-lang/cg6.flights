# /contracts/api.contract.md

# API Contracts — CG6 Flights

## Estado

Aprobado operativo para implementación v1.0.

## 1. Propósito

Este contrato define la comunicación entre Flutter Web y Supabase. Las consultas simples se realizan mediante repositories con Supabase Client y RLS. Las acciones sensibles usan Edge Functions versionadas.

## 2. Versionado

- Versión inicial: `v1`.
- Edge Functions usan prefijo lógico `v1`.
- Cambios incompatibles requieren nuevo contrato y análisis de impacto.

## 3. Autenticación

- Flutter usa Supabase Auth con anon key pública.
- Cada llamada sensible envía JWT del usuario autenticado.
- Edge Functions rechazan requests sin JWT válido.
- Service role key solo puede existir en variables de entorno de Edge Functions.

## 4. Headers

- `Authorization: Bearer <jwt>`.
- `Content-Type: application/json`.
- `X-CG6-Request-Id` opcional para trazabilidad.

## 5. Respuesta estándar

Éxito:

```json
{
  "ok": true,
  "data": {},
  "meta": {
    "request_id": "string"
  }
}
```

Error:

```json
{
  "ok": false,
  "error": {
    "code": "string",
    "message": "string",
    "category": "AUTHORIZATION",
    "severity": "high"
  }
}
```

## 6. Edge Functions v1

### POST `/functions/v1/bootstrap-profile`

Crea o devuelve el perfil del usuario autenticado después del registro/login.

Request:

```json
{
  "display_name": "string"
}
```

Response data:

```json
{
  "profile": {
    "id": "uuid",
    "email": "string",
    "display_name": "string",
    "status": "pending",
    "role": null,
    "unit_id": null
  }
}
```

Reglas:

- No asigna rol automáticamente.
- No asigna unidad automáticamente.
- Perfil queda pending por defecto.

### POST `/functions/v1/assign-user-access`

Asigna rol, unidad y estado operativo a un usuario.

Request:

```json
{
  "user_id": "uuid",
  "role": "leader",
  "unit_id": "uuid|null",
  "status": "active"
}
```

Permisos:

- `users.assign_access`.

Reglas:

- Valida máximo 1 Líder activo.
- Valida máximo 5 Administradores Generales activos.
- Roles de unidad requieren unidad.
- Audita éxito y denegación.

### POST `/functions/v1/claim-first-leader`

Permite que el primer usuario autenticado reclame el rol Líder cuando todavía no existe un Líder activo.

Request:

```json
{}
```

Response data:

```json
{
  "profile": {
    "id": "uuid",
    "email": "string",
    "display_name": "string",
    "status": "active",
    "role": "leader",
    "unit_id": null
  }
}
```

Reglas:

- Solo funciona si no existe un Líder activo.
- Requiere JWT válido.
- Activa el perfil del usuario autenticado.
- Audita éxito y denegación.

### POST `/functions/v1/toggle-role-permission`

Activa o desactiva un permiso para un rol.

Request:

```json
{
  "role": "unit_admin",
  "permission_key": "flights.create",
  "enabled": true
}
```

Permisos:

- `permissions.manage`.

### POST `/functions/v1/manage-unit`

Crea, edita o desactiva una unidad.

Request:

```json
{
  "action": "create",
  "unit_id": "uuid|null",
  "code": "GRU6",
  "name": "Grupo Aereo N. 6",
  "active": true
}
```

Permisos:

- `units.manage`.

Reglas:

- `create` requiere `code` y `name`.
- `update` requiere `unit_id`.
- `deactivate` requiere `unit_id` y marca `active = false`.
- Audita éxito y denegación.

### POST `/functions/v1/manage-aircraft`

Crea, edita o desactiva una aeronave.

Request:

```json
{
  "action": "create",
  "aircraft_id": "uuid|null",
  "unit_id": "uuid",
  "tail_number": "FAP-000",
  "model": "C-27J",
  "manufacturer": "Leonardo",
  "serial_number": "string|null",
  "year": 2026,
  "status": "operational"
}
```

Permisos:

- `aircraft.manage`.

Reglas:

- `create` requiere `unit_id`, `tail_number`, `model`, `manufacturer` y `status`.
- `update` requiere `aircraft_id`; los campos enviados deben validar tipo, estado y alcance.
- `deactivate` requiere `aircraft_id` y marca `active = false`, `deleted_at = now()`.
- Roles globales pueden operar aeronaves de cualquier unidad activa.
- Roles de unidad solo pueden operar aeronaves de su propia unidad y no pueden mover aeronaves a otra unidad.
- Audita éxito y denegación de autorización.

### POST `/functions/v1/manage-flight-order`

Edge Function unificada para todas las operaciones de Flight Orders.

Request:

```json
{
  "action": "create|update|add_item|submit|approve|observe|close|reopen|cancel_item|advance_state|delete|add_profile|remove_profile",
  "flight_order_id": "uuid|null",
  "unit_id": "uuid|null",
  "operation_date": "string|null",
  "item": { ... },
  "item_id": "uuid|null",
  "cancel_reason": "string|null",
  "next_status": "string|null",
  "profile_id": "uuid|null",
  "description": "string|null"
}
```

Acciones:
- `create` — Crea orden con número auto-generado (ACRONYM-XXX).
- `add_item` — Agrega vuelo a orden draft con rutas, tripulación, perfiles.
- `submit` — Envía orden a revisión (draft → submitted).
- `approve` — Aprueba orden (submitted/observed → approved).
- `observe` — Observa orden (submitted → observed).
- `close` — Cierra orden (approved → closed).
- `reopen` — Reabre orden (closed → reopened).
- `cancel_item` — Cancela un vuelo individual con motivo.
- `advance_state` — Avanza estado de vuelo (waiting → taxi → takeoff → landing → engine_off).
- `delete` — Borra orden (solo draft).
- `add_profile` — Agrega perfil de vuelo a la orden.
- `remove_profile` — Elimina perfil de la orden.

Permisos:
- `flight_orders.create` para create, update, add_item, add_profile, remove_profile.
- `flight_orders.review` para approve, observe, close, reopen.
- Roles globales o `flight_orders.close` para cancel_item y delete.
- `flight_orders.read` para advance_state.

Reglas:
- Solo se pueden agregar/modificar items en órdenes draft.
- Secuencia de estados de orden validada.
- Secuencia de estados de vuelo validada (no se puede saltar estados).
- Scope por unidad para roles no-globales.
- Número de orden: `acronym` de la unidad con fallback a `code`, formato `ACRONYM-XXX`.
- Cancelación de vuelo requiere motivo (`cancel_reason`).
- Avance de estado registra timestamp en `flight_order_state_events`.
- Perfiles auto-numerados por orden (`profile_number`).

### POST `/functions/v1/manage-message-post`

Crea publicaciones internas y comentarios sobre publicaciones visibles.

Request:

```json
{
  "action": "create_post|add_comment",
  "scope": "global|unit",
  "unit_id": "uuid|null",
  "post_id": "uuid|null",
  "body": "string"
}
```

Permisos:
- `message_posts.create` para `create_post`.
- `message_posts.comment` para `add_comment`.

Reglas:
- Requiere JWT válido y perfil activo.
- `create_post` global solo para `leader` y `general_admin`.
- `create_post` de unidad permitido para roles globales o roles de la misma unidad.
- `unit_command` y `unit_admin` publican dentro de su unidad asignada.
- `add_comment` solo aplica sobre publicaciones visibles por RLS/alcance.
- Audita éxito, denegación y fallas relevantes.
- Responde con `{ "ok": true, "data": { "post_id"|"comment_id": "uuid" } }` o error normalizado.

## 7. Repositories directos con Supabase Client

Permitidos solo con RLS y filtros explícitos:

- Lectura de perfil actual.
- Listado paginado de unidades autorizadas.
- Listado paginado de usuarios autorizados.
- Catálogo de permisos.
- Lectura de dashboards por vistas autorizadas.
- Lectura de notificaciones del usuario.
- Lectura realtime de mensajes privados, vistos, publicaciones, comentarios y confirmaciones filtradas por RLS.
- Inserción de chat privado y confirmaciones de lectura cuando RLS valida remitente/destinatario.

Prohibido:

- Saltar repositories.
- Consultas sensibles desde widgets.
- Usar service role key.
- Canales realtime globales.
- Leer chats privados ajenos aunque el usuario tenga rol global.

## 8. Paginación y filtros

Todo listado operacional debe soportar:

- `limit` máximo 100.
- `offset` o cursor.
- filtros por unidad cuando aplique.
- orden explícito.

## 9. Contratos realtime

Canales permitidos:

- `unit:{unit_id}:flight_orders`.
- `unit:{unit_id}:flight_order_items`.
- `unit:{unit_id}:notifications`.
- `profile:{profile_id}:notifications`.
- `profile:{profile_id}:messages`.
- `profile:{profile_id}:message_reads`.
- `message_posts` filtrado por RLS.
- `message_post_comments` filtrado por RLS.
- `message_post_reads` filtrado por RLS.

Cada canal debe filtrar por unidad o usuario.

## 10. Errores HTTP

- 200: respuesta normalizada exitosa.
- 400: validación.
- 401: sesión ausente o inválida.
- 403: permiso, rol, unidad o alcance inválido.
- 404: recurso no encontrado.
- 409: conflicto de negocio.
- 500: error inesperado.

## 11. Criterios de aceptación

- Toda Edge Function documentada valida JWT.
- Todo payload tiene validación.
- Todo error usa catálogo definido.
- Todo acceso sensible se audita.
- Las rutas contratadas no exponen secretos.
