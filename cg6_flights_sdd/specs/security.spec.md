# /specs/security.spec.md

# Security Governance — CG6 Flights

## Estado

Aprobado operativo para implementación v1.0.

## 1. Nivel de seguridad

CG6 Flights maneja información confidencial operacional y personal. El modelo de seguridad usa defensa en profundidad: Supabase Auth, RBAC, permisos por acción, RLS, Edge Functions, auditoría y manejo seguro de secretos.

## 2. Identidad y sesión

- Autenticación por correo y contraseña mediante Supabase Auth.
- Registro permitido, pero el usuario queda `pending` sin rol ni unidad.
- Usuario pending, inactive, rejected, sin rol o sin unidad requerida no opera.
- Sesión se valida en guards frontend, repositories, RLS y Edge Functions.
- Logout debe limpiar estado local sensible.

## 3. Roles

- leader: máximo 1 activo.
- general_admin: máximo 5 activos.
- unit_command: autoridad de unidad.
- unit_admin: operación de unidad.
- ttaa: acceso limitado.

Los roles no sustituyen permisos. Toda acción crítica requiere permiso explícito.

## 4. Permisos

Convención:

```txt
module.action
```

Permisos mínimos:

- `users.read`, `users.manage`, `users.assign_access`.
- `roles.read`.
- `permissions.read`, `permissions.manage`.
- `units.read`, `units.manage`.
- `aircraft.read`, `aircraft.manage`.
- `crew.read`, `crew.manage`.
- `flight_orders.read`, `flight_orders.create`, `flight_orders.review`, `flight_orders.close`.
- `flights.read`, `flights.create`, `flights.update`.
- `flight_status.create`.
- `closures.request`, `closures.review`, `closures.reopen`.
- `history.read`.
- `audit.read`.
- `notifications.read`, `notifications.manage`.
- `messages.read`, `messages.send`.
- `reports.read`, `reports.export`.
- `calendar.read`, `maps.read`, `profile.update`, `settings.manage`.

## 5. Alcance

- Roles globales pueden operar globalmente solo si tienen permiso.
- Roles de unidad solo operan su unidad.
- TTAA solo ve información asignada o autorizada.
- El alcance se valida en UI, services, RLS y Edge Functions.

## 6. RLS

- RLS habilitado en tablas sensibles.
- Políticas por rol, permiso y unidad.
- Ninguna tabla operacional queda abierta a `anon`.
- `authenticated` solo accede mediante políticas explícitas.
- Las políticas deben negar por defecto.

## 7. Secretos

- No se permite service role key en Flutter.
- `.env`, `.env.local`, `.env.production` no se versionan.
- Variables públicas Flutter usan solo anon key y URL.
- Secretos de Edge Functions viven en Supabase Secrets.

## 8. Validación y sanitización

- Validar tipo, longitud, obligatoriedad y formato.
- Normalizar email.
- Rechazar HTML no permitido.
- Escapar contenido mostrado cuando aplique.
- No confiar en datos del cliente.

## 9. OWASP

Controles mínimos:

- Broken Access Control: RLS + permissions + guards.
- Cryptographic Failures: HTTPS, secretos fuera de cliente.
- Injection: queries parametrizadas y Supabase client.
- Insecure Design: specs, ADRs y quality gates.
- Security Misconfiguration: buckets privados, headers y ambientes separados.
- Vulnerable Components: dependencias justificadas y revisadas.
- Identification Failures: Auth centralizado.
- Logging Failures: auditoría transversal.

## 10. Storage

- Buckets privados.
- Foto de perfil máximo 5 MB.
- Validar tipo MIME permitido para imágenes.
- Reportes confidenciales con URL firmada y expiración.

## 11. Auditoría

Obligatoria para:

- cambios de usuario, rol, permiso y unidad;
- cambios de aeronave y tripulación;
- creación, revisión y cierre de orden de vuelo;
- eventos de estado de vuelo;
- generación de PDF/Excel;
- mensajería interna crítica;
- denegaciones de autorización autenticadas.

## 12. Realtime

- Canales filtrados por unidad o usuario.
- Prohibido realtime global de operaciones.
- No enviar secretos ni datos fuera de alcance.

## 13. Headers y despliegue web

- Forzar HTTPS en producción.
- Configurar headers de seguridad en Vercel cuando aplique:
  - `X-Content-Type-Options: nosniff`;
  - `Referrer-Policy: strict-origin-when-cross-origin`;
  - `Permissions-Policy` restrictiva;
  - CSP compatible con Flutter Web y Supabase.

## 14. Geolocalización

- No se implementa confirmación remota con geolocalización hasta aprobar política específica.
- Mapas se limitan a visualización de rutas y localidades autorizadas.

## 15. Criterios de aceptación

- No hay secretos en frontend.
- RLS niega acceso cruzado por unidad.
- Usuarios pending no operan.
- Permisos visuales coinciden con permisos reales.
- Exportaciones y acciones críticas quedan auditadas.
