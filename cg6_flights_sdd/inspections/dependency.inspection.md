# /inspections/dependency.inspection.md

# Dependency Inspection — CG6 Flights

## Checklist

- [x] Dependencia justificada contra RF/RNF.
- [x] Licencia clara.
- [x] Mantenida.
- [x] Compatible con Flutter Web/Supabase/Vercel.
- [x] No expone datos confidenciales.
- [x] No introduce costo no aprobado.
- [x] No requiere secretos en frontend.
- [x] No rompe modularidad.
- [x] ADR generado si es crítica o ya cubierta por ADR existente.

## Estado

Ejecutada para foundation v1.0.

## Dependencias aprobadas en foundation

- `flutter_riverpod`: estado de sesion, idioma y guards.
- `go_router`: rutas publicas/protegidas y redirects por permisos.
- `supabase_flutter`: Auth, PostgREST, Storage y Realtime mediante repositories.
- `intl` y `flutter_localizations`: interfaz bilingue Espanol/Ingles.

No se agregan dependencias PDF/Excel hasta implementar Reports Module.
