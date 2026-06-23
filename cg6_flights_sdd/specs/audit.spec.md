# Modulo: Auditoría

## Estado

Implementado (as-built 2026-06-23). Spec post-implementación.

## Responsabilidad

- Registrar y exponer la traza de acciones críticas del sistema (`audit_logs`).
- Presentar la auditoría en dos vistas: **Eventos** (registro cronológico) y **Rendimiento** (analítica con gráficas).
- Integrar la **Papelera** (soft-delete) para listar y restaurar registros borrados lógicamente.
- Aplicar scope por unidad mediante RLS.

## No responsabilidad

- No ejecuta lógica de negocio; solo registra y consulta.
- No reemplaza backups ni persistencia operativa.
- No expone auditoría a roles sin `audit.read`.

## Entidades

### audit_logs

Definida en `database.spec.md §5`: `id`, `actor_id`, `actor_role`, `actor_unit_id`, `action`, `resource_type`, `resource_id`, `result` (`success`/`denied`/`failed`), `ip_address`, `user_agent`, `metadata` jsonb, `created_at`.

Soft-delete: las tablas operativas marcan `deleted_at`; la Papelera consulta esos registros (Edge Function `list-trash`).

## Casos de uso

1. Registrar acción crítica (alta/edición/baja, transiciones de OV, eventos de estado, exportaciones, denegaciones autenticadas).
2. Consultar **Eventos** agrupados en 4 bloques temáticos (2 columnas): Operaciones, Gestión de Vuelo, Personal, Sistema.
3. Consultar **Rendimiento** con 4 gráficas fl_chart: tendencias, dona, barras apiladas y KPIs.
4. Listar y **restaurar** registros desde la Papelera.

## Permisos

- `audit.read` — leer auditoría (roles autorizados).
- `trash.read` — acceder a la Papelera.

## RLS

- Scope por unidad: roles de unidad solo ven auditoría de su unidad; roles globales con permiso ven auditoría global.
- `audit_logs` no visible sin `audit.read`.

## UI

- Página de Auditoría con 2 pestañas: **Eventos** y **Rendimiento**.
- Eventos: 4 bloques temáticos en 2 columnas.
- Rendimiento: 4 gráficas fl_chart (tendencias, dona, barras apiladas, KPIs).
- Papelera integrada para restauración.

## Retención

- Limpieza automática de `audit_logs` vía **pg_cron cada 2 meses**.
- Históricos operativos: 5 años.

## Errores

- Lectura sin `audit.read` → 403 (`AUTHORIZATION`).
- Acceso a unidad ajena → 403 (`AUTH_UNIT_MISMATCH`).

## Tests requeridos

- [ ] `audit_logs` no visible sin `audit.read`.
- [ ] Scope por unidad: unit_admin no ve auditoría de otra unidad.
- [ ] Acción crítica genera registro con actor/rol/unidad/resultado.
- [ ] Restauración desde Papelera revierte `deleted_at`.
