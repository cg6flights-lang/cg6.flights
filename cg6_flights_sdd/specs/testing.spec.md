# /specs/testing.spec.md

# Testing Governance — CG6 Flights

## Estado

Aprobado operativo para implementación v1.0.

## 1. Propósito

La calidad de CG6 Flights se valida con pruebas de frontend, dominio, contratos, base de datos, seguridad y flujos E2E antes de despliegue.

## 2. Gates obligatorios

Antes de merge/deploy:

- `flutter analyze`.
- `flutter test`.
- build web exitoso.
- migraciones Supabase reproducibles.
- pruebas de RLS críticas.
- inspección de dependencias.
- revisión contra AI Rules.

## 3. Pruebas frontend

- Unit tests para servicios, guards y mappers.
- Widget tests para pantallas críticas:
  - login;
  - registro pending;
  - dashboard;
  - permiso denegado;
  - estados loading/empty/error.
- Tests responsive en escritorio, tablet y móvil.
- Tests i18n para Español/Inglés en rutas principales.

## 4. Pruebas dominio

Casos obligatorios:

- Usuario pending no opera.
- Usuario inactive no opera.
- Usuario sin rol no opera.
- Usuario de unidad sin unidad no opera.
- Límite de 1 Líder.
- Límite de 5 Administradores Generales.
- Permiso faltante deniega acción.
- Secuencia inválida de estados de vuelo se rechaza.
- Ficha cerrada no se modifica.
- Exportación sin permiso se rechaza.

## 5. Pruebas database/RLS

- Authenticated sin perfil no lee operación.
- Pending no lee operación.
- Unit admin no lee otra unidad.
- Unit command no cierra otra unidad.
- General admin lee operación global autorizada.
- TTAA solo lee alcance asignado.
- Audit logs no son visibles sin `audit.read`.
- Storage privado no expone reportes.

## 6. Pruebas API/Edge Functions

Por cada Edge Function:

- JWT ausente devuelve 401.
- JWT válido sin permiso devuelve 403.
- Payload inválido devuelve 400.
- Conflicto de negocio devuelve 409.
- Éxito devuelve `ok: true`.
- Denegación o acción crítica genera auditoría.

## 7. Pruebas E2E

Flujos mínimos:

- Registro con correo crea perfil pending.
- Admin autorizado activa usuario, asigna rol y unidad.
- Usuario activo entra a dashboard permitido.
- Usuario intenta ruta sin permiso y recibe permission denied.
- Administrador consulta auditoría.
- Reporte solicitado sin permiso se bloquea.

## 8. Seguridad y regresión

- No secretos en repositorio.
- No service role key en Flutter.
- Dependencias revisadas.
- Buckets privados.
- Headers de seguridad revisados antes de producción.

## 9. Cobertura

- No se fija porcentaje global inicial.
- Todo módulo crítico debe tener pruebas sobre reglas de negocio y seguridad.
- Cambios en permisos, RLS, cierres, reportes o auditoría requieren tests específicos.

## 10. Criterios de aceptación

- Las pruebas obligatorias pasan localmente.
- Los escenarios de denegación están cubiertos.
- El build web no contiene secretos.
- Ningún deploy ocurre con gates críticos fallidos.
