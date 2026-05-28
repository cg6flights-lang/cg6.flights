# /specs/backend.spec.md

# Backend Specification — CG6 Flights

## Estado

Aprobado operativo para implementación v1.0.

## 1. Propósito

El backend de CG6 Flights se implementa sobre Supabase y debe proveer autenticación, persistencia, autorización reforzada, auditoría, almacenamiento, realtime selectivo y operaciones sensibles mediante Edge Functions.

## 2. Stack backend

- Supabase Auth para identidad.
- PostgreSQL como fuente de verdad.
- Row Level Security obligatorio.
- Supabase Storage para archivos.
- Supabase Realtime solo en canales filtrados.
- Supabase Edge Functions en Deno para acciones sensibles y contratos estables.

No se agrega un servidor backend adicional en v1.0 salvo ADR aprobado.

## 3. Capas backend

- Auth Provider: identidad de usuario y sesión.
- Application Services: casos de uso por módulo.
- Domain Services: reglas de negocio puras.
- Repositories: único acceso a tablas, vistas y RPC.
- Policy Layer: RLS, permisos, unidad y alcance.
- Audit Layer: registro transversal de acciones críticas.
- Integration Layer: Storage, Realtime, PDF/Excel, mapas y notificaciones.

## 4. Reglas generales

- Ningún secreto se expone al frontend.
- La service role key solo se permite en Edge Functions controladas.
- Todo input debe validarse antes de persistir.
- Toda acción crítica valida sesión, usuario activo, rol, permiso, unidad y alcance.
- Todo resultado usa respuesta normalizada.
- Toda falla usa catálogo central de errores.
- No hay eliminación física ordinaria de registros operativos.
- Reportes PDF/Excel pasan exclusivamente por Reports Module.
- Geolocalización remota queda deshabilitada hasta política aprobada.

## 5. Servicios por dominio

### Auth

- Registrar usuario con correo.
- Iniciar sesión.
- Cerrar sesión.
- Recuperar contraseña.
- Crear perfil pendiente después del registro.
- Bloquear operación si el perfil está inactivo, pendiente, sin rol o sin unidad cuando aplique.

### Users

- Consultar usuarios según permiso y alcance.
- Activar/desactivar usuarios.
- Asignar rol.
- Asignar unidad.
- Actualizar datos permitidos del perfil.
- Validar máximo 1 Líder y máximo 5 Administradores Generales.
- Permitir bootstrap controlado del primer Líder solo cuando no exista Líder activo.

### Roles y Permissions

- Mantener roles oficiales.
- Mantener catálogo de permisos por acción.
- Activar/desactivar permisos por rol.
- Evaluar permisos por usuario, rol, unidad y recurso.
- Auditar cambios de permisos.

### Units

- Crear, editar y desactivar unidades.
- Aislar datos por unidad.
- Impedir operación de roles de unidad sin unidad asignada.

### Aircraft

- Registrar aeronaves.
- Asociar aeronaves a unidad.
- Marcar operativo/inoperativo.
- Consultar histórico por aeronave.

### Crew

- Registrar tripulantes.
- Asociar tripulantes a unidad.
- Clasificar piloto, copiloto, mecanico o ingeniero de vuelo.
- Consultar histórico por tripulante.

### Flight Orders

- Crear ficha diaria por unidad y fecha.
- Asociar vuelos.
- Validar completitud.
- Aprobar, rechazar u observar.
- Solicitar PDF a Reports Module.

### Flights y Flight Status

- Crear vuelos de una ficha diaria.
- Asociar aeronave, tripulación, ruta y horarios planificados.
- Registrar eventos de estado en secuencia.
- Calcular tiempos derivados:
  - total: inicio de taxeo hasta apagado de motor;
  - parcial: despegue hasta aterrizaje.
- Impedir cambios ordinarios en vuelos cerrados.

### Closures

- Solicitar cierre de ficha diaria.
- Aprobar, rechazar u observar cierre.
- Reabrir solo con permiso especial.
- Proteger ficha y vuelos cerrados.

### History

- Consultar históricos diarios, semanales, mensuales y anuales.
- Filtrar por unidad, aeronave, piloto, mecanico, ruta y estado.
- No modificar datos operativos.

### Audit

- Registrar acciones críticas.
- Registrar actor, rol, unidad, recurso, acción, resultado, IP si disponible, user agent si disponible y metadata segura.
- Permitir lectura solo a roles autorizados.

### Notifications y Messages

- Crear notificaciones por eventos relevantes.
- Marcar notificaciones vistas sin borrar auditoría.
- Mensajería interna trazable por alcance global o unidad.

### Reports

- Generar PDF y Excel bajo demanda.
- Auditar cada exportación.
- Validar permiso y alcance antes de generar.
- No guardar exportaciones confidenciales públicamente.

### Calendar, Maps, Profile e I18n

- Calendar expone eventos operativos autorizados.
- Maps encapsula proveedor y no activa geolocalización remota sin política.
- Profile administra foto hasta 5 MB en bucket privado.
- I18n entrega llaves estables para Español e Inglés.

## 6. DTOs mínimos

Todo DTO debe incluir validaciones de tipo, longitud y obligatoriedad.

- AuthRegisterInput: email, password, display_name.
- ProfileUpdateInput: display_name, phone, avatar_path opcional.
- UserRoleAssignmentInput: user_id, role, unit_id opcional.
- PermissionToggleInput: role, permission_key, enabled.
- UnitInput: code, name, active.
- AircraftInput: tail_number, model, manufacturer, unit_id, status, serial_number opcional, year opcional.
- CrewMemberInput: full_name, document_id opcional, crew_type, unit_id, active.
- FlightOrderInput: unit_id, operation_date, items[] (opcional).
- FlightOrderItemInput: aircraft_id, mission, flight_level_min, flight_level_max, ete_minutes, fuel_type, fuel_amount, scheduled_departure, routes[], crew[], profile_ids[].
- FlightOrderRouteInput: segment_order, segment_type, origin_type, origin_route_id, origin_label, origin_lat, origin_lng, destination_type, destination_route_id, destination_label, destination_lat, destination_lng.
- FlightOrderCrewInput: crew_member_id, role_code (PC/CP/MA), function_code (PS/IP/PM/CP/CO/PI/PR) opcional.
- FlightOrderAction: action (create/update/add_item/submit/approve/observe/close/reopen/cancel_item/advance_state/delete).
- CancellationInput: item_id, cancel_reason.
- AdvanceStateInput: item_id, next_status.
- FlightOrderProfileInput: flight_order_id, description.
- ClosureRequestInput: flight_order_id, notes opcional.
- ReportRequestInput: report_type, date_range, filters, format.

## 7. Validaciones obligatorias

- Email válido y normalizado.
- Fechas en UTC para persistencia y localizadas solo en UI.
- `unit_id` obligatorio para roles de unidad.
- `role` solo puede ser uno de los roles oficiales.
- Secuencia de estado de vuelo (flight_order_items.status):
  - waiting;
  - taxi;
  - takeoff;
  - landing;
  - engine_off.
- Secuencia de estado de orden (flight_orders.status):
  - draft → submitted → approved/observed → closed → reopened.
- La cancelación de un vuelo individual requiere motivo (`cancel_reason`).
- No se puede cerrar una ficha con vuelos incompletos salvo observación autorizada.
- No se puede exportar sin permiso `reports.export`.
- No se puede leer auditoría sin permiso `audit.read`.

## 8. Respuesta normalizada

```json
{
  "ok": true,
  "data": {},
  "meta": {}
}
```

```json
{
  "ok": false,
  "error": {
    "code": "AUTHORIZATION_PERMISSION_DENIED",
    "message": "Operacion no autorizada.",
    "category": "AUTHORIZATION",
    "severity": "high"
  }
}
```

## 9. Catálogo de errores

- AUTH_SESSION_MISSING.
- AUTH_USER_INACTIVE.
- AUTH_PROFILE_PENDING.
- AUTHORIZATION_ROLE_REQUIRED.
- AUTHORIZATION_UNIT_REQUIRED.
- AUTHORIZATION_PERMISSION_DENIED.
- VALIDATION_INVALID_INPUT.
- BUSINESS_LEADER_LIMIT_REACHED.
- BUSINESS_GENERAL_ADMIN_LIMIT_REACHED.
- BUSINESS_FLIGHT_STATUS_SEQUENCE_INVALID.
- BUSINESS_FLIGHT_ORDER_CLOSED.
- DATA_NOT_FOUND.
- DATA_CONFLICT.
- STORAGE_FILE_TOO_LARGE.
- EXPORT_NOT_ALLOWED.
- SYSTEM_UNEXPECTED.

## 10. Logging y auditoría

- Logs técnicos no deben incluir secretos ni datos personales innecesarios.
- Auditoría es obligatoria en cambios de usuarios, roles, permisos, unidades, aeronaves, tripulación, órdenes de vuelo, vuelos, estados, cierres, reportes y mensajes.
- Los errores de autorización fallidos también se auditan cuando identifican usuario autenticado.

## 11. Realtime

- Solo se permiten canales por unidad o recurso.
- Queda prohibido canal global de vuelos.
- Cada suscripción debe validar sesión y alcance.
- Realtime no reemplaza auditoría ni persistencia.

## 12. Criterios de aceptación

- Los servicios no acceden a DB fuera de repositories.
- Las Edge Functions validan JWT.
- Las acciones sensibles tienen contrato documentado.
- Las respuestas cumplen formato normalizado.
- Los errores usan catálogo central.
- Los permisos y RLS bloquean accesos indebidos.
