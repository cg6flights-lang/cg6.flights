# /specs/deployment.spec.md

# Deployment Governance — CG6 Flights

## Estado

Aprobado operativo para implementación v1.0.

## 1. Propósito

El despliegue debe publicar Flutter Web en Vercel y usar Supabase como backend administrado, con ambientes separados, validaciones previas, rollback y manejo seguro de secretos.

## 2. Ambientes

- local: desarrollo en máquina del proyecto.
- preview: despliegues de revisión.
- production: operación real.

Reglas:

- No datos reales confidenciales en local ni preview.
- Cada ambiente usa proyecto Supabase o configuración separada.
- Variables de entorno por ambiente.

## 3. Vercel

- Hosting para Flutter Web compilado.
- Build command: `flutter build web --release`.
- Output directory: `build/web`.
- Headers de seguridad definidos antes de producción.
- Deploy de producción solo después de gates aprobados.

## 4. Supabase

- Migraciones versionadas.
- RLS habilitado antes de cargar datos.
- Edge Functions desplegadas con secretos gestionados.
- Storage buckets privados creados por migración o checklist reproducible.
- Backups según plan Supabase contratado.

## 5. Variables de entorno

Frontend:

- `SUPABASE_URL`.
- `SUPABASE_ANON_KEY`.

Edge Functions:

- `SUPABASE_URL`.
- `SUPABASE_ANON_KEY`.
- `SUPABASE_SERVICE_ROLE_KEY`.

Prohibido:

- versionar `.env`;
- usar service role key en Flutter;
- copiar secretos en documentación.

## 6. CI/CD

Pipeline mínimo:

- instalar Flutter estable;
- restaurar dependencias;
- `flutter analyze`;
- `flutter test`;
- `flutter build web --release`;
- validar migraciones Supabase;
- ejecutar revisión de seguridad/dependencias.

## 7. Rollback

- Vercel permite promover deployment previo.
- Migraciones irreversibles requieren plan de reversa documentado.
- Cambios de RLS deben validarse en preview antes de producción.

## 8. Monitoring y observabilidad

Inicial:

- logs de Vercel;
- logs de Supabase;
- audit_logs de aplicación.

Futuro:

- alertas;
- métricas de performance;
- trazas de Edge Functions.

## 9. Disaster recovery

- Backups Supabase según plan.
- Exportación de auditoría no sustituye backup.
- Documentar restauración antes de operación real.

## 10. Criterios de aceptación

- Build web reproducible.
- Variables por ambiente definidas.
- RLS activo en producción.
- No secretos en build frontend.
- Rollback documentado.
- Deploy bloqueado si fallan tests, seguridad, DB o contratos.
