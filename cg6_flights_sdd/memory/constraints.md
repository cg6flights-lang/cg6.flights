# /memory/constraints.md

# Constraints — CG6 Flights

## Restricciones funcionales

- Líder máximo 1.
- Administrador General máximo 5.
- TTAA limitado.
- Usuario sin rol no opera.
- Usuario sin unidad no opera en roles de unidad.
- Separación por escuadrón (scope `squadronId`) para Jefe de Escuadrón.
- Cierre protege ficha diaria.
- No eliminación física ordinaria; borrado lógico (Papelera) con posibilidad de restauración.
- Históricos 5 años.

## Restricciones técnicas

- Flutter no contiene secretos.
- No service role key en frontend.
- RLS obligatorio.
- Realtime filtrado.
- Edge Functions para operaciones sensibles.
- PDF/Excel solo desde Reports Module.
- Horas almacenadas en UTC; nunca persistir hora local.
- SDK Flutter del proyecto (`flutter/flutter/bin/flutter`) y puerto 8080 para dev local.
- Dependencias solo con justificación.
- Cambios estructurales con ADR.

## Restricciones de seguridad

- Datos confidenciales.
- Separación por unidad.
- Auditoría obligatoria.
- Exportaciones auditadas.
- Geolocalización remota pendiente de política.
