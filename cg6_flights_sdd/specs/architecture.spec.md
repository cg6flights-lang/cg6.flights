# /specs/architecture.spec.md

# Architecture Specification — CG6 Flights

## 1. Arquitectura objetivo

CG6 Flights usará una arquitectura web modular, segura, auditable y escalable.

Stack preliminar:

- Flutter Web.
- Supabase.
- PostgreSQL.
- Row Level Security.
- Supabase Storage.
- Supabase Realtime.
- Supabase Edge Functions.
- Vercel.

## 2. Capas

```txt
Presentation Layer
Application Layer
Domain Layer
Data Access Layer
Security & Governance Layer
Audit Layer
Integration Layer
```

## 3. Módulos

- Auth
- Users
- Roles
- Permissions
- Units
- Aircraft
- Crew
- Flight Orders
- Flights
- Flight Status
- Routes
- Closures
- History
- Audit
- Notifications
- Messages
- Reports
- Calendar
- Maps
- Profile
- I18n
- Shared
- Governance

## 4. Boundaries principales

- Auth autentica, no autoriza operación.
- Permissions valida acciones.
- Units aísla información por unidad.
- Flight Orders gestiona ficha diaria.
- Flights gestiona vuelos individuales.
- Flight Status registra eventos de estado.
- Closures protege fichas cerradas.
- History es de consulta, no modifica operación.
- Audit registra eventos, no ejecuta negocio.
- Reports genera PDF/Excel.
- Maps encapsula proveedor.
- Shared no contiene lógica crítica.

## 5. Comunicación técnica

```txt
Flutter Web
  -> Presentation Layer
  -> Application Services
  -> Domain Services
  -> Repositories
  -> Supabase Client
  -> Supabase Auth / PostgreSQL / RLS / Storage / Realtime / Edge Functions
```

Reglas:

- No widgets con lógica crítica.
- No consultas sensibles directas desde pantallas.
- No service role key en Flutter.
- No reportes fuera de Reports Module.
- No permisos solo visuales.
- No realtime global sin filtro.

## 6. Seguridad arquitectónica

Principios:

- mínimo privilegio;
- separación por unidad;
- defensa en profundidad;
- RLS obligatorio;
- auditoría obligatoria;
- cero confianza en cliente;
- secretos fuera del frontend;
- errores seguros.

## 7. Escalabilidad y confiabilidad

- Paginación obligatoria.
- Filtros en históricos y auditoría.
- Índices en columnas críticas.
- Realtime selectivo.
- Edge Functions para operaciones pesadas.
- Auditoría escalable.
- Reportes bajo demanda.
- Prevención de duplicados.
- Idempotencia en acciones críticas.

## 8. Manejo de errores

Formato estándar:

```txt
{
  ok: false,
  error: {
    code: string,
    message: string,
    category: string,
    severity: string
  }
}
```

Categorías:

- AUTH
- AUTHORIZATION
- VALIDATION
- BUSINESS_RULE
- DATA
- NETWORK
- STORAGE
- REALTIME
- EXPORT
- SYSTEM

## 9. Dependencias permitidas

Stack preliminar permitido:

- Flutter Web.
- Supabase.
- Vercel.

Dependencias candidatas:

- supabase_flutter
- go_router
- flutter_riverpod o bloc
- intl
- flutter_localizations
- pdf o alternativa
- excel o alternativa
- file_picker si aplica
- flutter_svg si aplica
- lottie si aplica

No se instala nada sin justificación y revisión.

## 10. Decisiones arquitectónicas iniciales

- DA-001: Arquitectura modular por dominios.
- DA-002: Flutter Web frontend preliminar.
- DA-003: Supabase backend preliminar.
- DA-004: PostgreSQL fuente de verdad.
- DA-005: RLS obligatorio.
- DA-006: RBAC + permisos granulares.
- DA-007: separación estricta por unidad.
- DA-008: Líder único.
- DA-009: Administrador General máximo 5.
- DA-010: TTAA limitado.
- DA-011: auditoría transversal.
- DA-012: no eliminación física ordinaria.
- DA-013: estados de vuelo basados en eventos.
- DA-014: tiempos derivados.
- DA-015: cierre protegido.
- DA-016: Reports Module único generador PDF/Excel.
- DA-017: exportaciones confidenciales y auditadas.
- DA-018: Realtime limitado.
- DA-019: Edge Functions para operaciones sensibles.
- DA-020: Storage con buckets separados.
- DA-021: foto de perfil máximo 5 MB.
- DA-022: históricos 5 años.
- DA-023: históricos filtrados.
- DA-024: bilingüe Español/Inglés.
- DA-025: diseño aeronáutico militar.
- DA-026: mapas encapsulados.
- DA-027: geolocalización remota pendiente.
- DA-028: mensajería interna trazable.
- DA-029: notificaciones no reemplazan auditoría.
- DA-030: Vercel hosting preliminar.
- DA-031: ambientes separados.
- DA-032: no datos reales confidenciales en desarrollo.
- DA-033: respuestas normalizadas.
- DA-034: catálogo central de errores.
- DA-035: IA gobernada por specs.
- DA-036: cambios estructurales mediante ADR.
- DA-037: testing antes de deploy.
- DA-038: no implementación antes de specs completas.
- DA-039: herramientas gratuitas como prioridad inicial.
- DA-040: arquitectura preparada para evolución.
