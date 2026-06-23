# /governance/quality-gates.md

# Quality Gates — CG6 Flights

## Gate 01 — Product Spec

- [x] Visión definida.
- [x] Roles definidos.
- [x] Workflows definidos.
- [x] Reglas de negocio definidas.
- [x] Riesgos definidos.

Estado: aprobado operativo.

## Gate 02 — Architecture Spec

- [x] Arquitectura definida.
- [x] Capas definidas.
- [x] Módulos definidos.
- [x] Boundaries definidos.
- [x] Seguridad arquitectónica definida.
- [x] Escalabilidad definida.
- [x] Dependencias definidas.
- [x] Decisiones iniciales definidas.

Estado: aprobado con observaciones.

## Gate 03 — Frontend Spec

- [x] Arquitectura frontend iniciada.
- [x] Pantallas y navegación iniciadas.
- [x] Componentes detallados.
- [x] Flujos UI detallados.
- [x] Estados de error detallados.

Estado: aprobado operativo.

## Gate 04 — Backend Spec

- [x] Framework backend definido.
- [x] Servicios definidos.
- [x] DTOs y validaciones definidos.
- [x] Repositories, autorización, logging y errores definidos.

Estado: aprobado operativo.

## Gate 05 — Database Spec

- [x] PostgreSQL definido.
- [x] Tablas, relaciones, constraints e índices definidos.
- [x] Migraciones, RLS, storage, backups y retención definidos.

Estado: aprobado operativo.

## Gate 06 — API Contracts

- [x] Contratos Edge Functions definidos.
- [x] Payloads, responses, errores, autenticación y versionado definidos.
- [x] Realtime y repositories directos delimitados.

Estado: aprobado operativo.

## Gate 07 — Security Spec

- [x] Autenticación, autorización y permisos definidos.
- [x] Secretos, OWASP, sesiones, auditoría, headers y storage definidos.
- [x] Política de geolocalización pendiente bloqueada explícitamente.

Estado: aprobado operativo.

## Gate 08 — Testing Spec

- [x] Unit, widget, integration, E2E, RLS, seguridad y CI validation definidos.

Estado: aprobado operativo.

## Gate 09 — Deployment Spec

- [x] Infraestructura, ambientes, CI/CD, monitoring, rollback y disaster recovery definidos.

Estado: aprobado operativo.

## Regla de bloqueo

No se debe implementar código productivo si fallan gates de:

- arquitectura;
- seguridad;
- base de datos;
- API contracts;
- testing.

Estado actual: gates críticos aprobados. **Implementación en producción (v1.0+ en Vercel; desarrollo en `cg6_flights_v1.3`).** Gates de ejecución continua antes de cada merge/deploy: `flutter analyze` (0 issues) + `flutter test` (suite verde, 100 tests) con el SDK del proyecto.
