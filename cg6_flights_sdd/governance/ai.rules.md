# /governance/ai.rules.md

# AI Governance Rules — CG6 Flights

## 1. Regla principal

La especificación es la fuente de verdad.

Ningún agente IA puede generar código que contradiga:

- Product Spec.
- Architecture Spec.
- Frontend Spec.
- Backend Spec.
- Database Spec.
- Security Spec.
- API Contracts.
- Testing Spec.
- Quality Gates.
- ADRs.

## 2. Prohibiciones absolutas

La IA no puede:

1. Crear lógica de negocio en controllers o widgets.
2. Crear APIs sin contrato.
3. Acceder directamente a DB fuera de repositories.
4. Omitir validaciones.
5. Poner secretos en código.
6. Cambiar arquitectura sin ADR.
7. Duplicar lógica crítica.
8. Crear features sin criterios de aceptación.
9. Proponer deploy sin testing.
10. Instalar dependencias sin justificación.
11. Saltarse RLS.
12. Saltarse auditoría.
13. Crear permisos improvisados.
14. Crear rutas críticas sin guard.
15. Generar PDF/Excel fuera de Reports Module.
16. Crear canales Realtime globales sin filtro.
17. Implementar geolocalización remota sin política.
18. Cambiar stack sin aprobación.

## 3. Convenciones obligatorias

- Modularidad por dominio.
- Servicios por caso de uso.
- Repositories para acceso a datos.
- Resultados normalizados.
- Errores normalizados.
- Auditoría en acciones críticas.
- Permisos por acción.
- Separación por unidad.
- No eliminación física ordinaria.
- **Credenciales en `.env.json`** (gitignored), nunca hardcodeadas. Usar `--dart-define-from-file=.env.json`.
- **Actualizar contexto al final de cada sesión**: memoria del proyecto (`cg6_flights_sdd/memory/project-context.md`) y auto-memory de Claude (`memory/project_overview.md`) deben reflejar el estado actual de implementación, features completadas, y decisiones técnicas relevantes.

## 4. Obligaciones de cada agente IA

Antes de generar código debe verificar:

- spec aplicable;
- módulo afectado;
- permisos requeridos;
- auditoría requerida;
- contratos;
- tests necesarios;
- impacto arquitectónico;
- dependencias permitidas.

## 5. Salida esperada de agentes IA

Todo agente debe indicar:

- archivo modificado;
- motivo;
- spec usada;
- riesgos;
- pruebas requeridas;
- si requiere ADR.
