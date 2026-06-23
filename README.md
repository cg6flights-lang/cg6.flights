# CG6 Flights

Centro de Gestion y Control de Vuelos Diarios.

**Estado**: en producción (Vercel). Flutter Web 3.44.1 + Riverpod + GoRouter + Supabase. Desarrollo activo en `cg6_flights_v1.3`. Módulos: Auth, Usuarios, Unidades, Aeronaves, Tripulación/Escuadrones/Cadetes, Órdenes de Vuelo, Vuelos (Pantalla LED + METAR), Dashboard modular, Auditoría, Papelera, Mensajería, Notificaciones, Calendario, Rutas, Perfil, Configuración. Bilingüe ES/EN, realtime, horas en UTC.

## Source of truth

The SDD folder is the governing source:

```txt
cg6_flights_sdd/
```

Implementation must follow the approved specs, contracts, governance rules, quality gates and ADRs in that folder.

## Local web run

Recommended: `scripts/deploy_local.sh` — handles cleanup, hot-restart vs full launch, waits for the DDC compile to finish, and opens Chrome only when the app is ready. Use the project Flutter SDK configured in `.vscode/settings.json` and port `8080`.

Without Supabase credentials the app runs in safe local mode for UI/guard validation.

```sh
scripts/cleanup_flutter_local.sh
flutter run -d chrome --web-port=8080
```

With Supabase:

```sh
scripts/cleanup_flutter_local.sh
flutter run -d chrome --web-port=8080 --dart-define-from-file=.env.json
```

Use the workspace Flutter SDK configured in `.vscode/settings.json`.
Do not leave parallel `flutter run` or temporary Chrome sessions alive before
running tests or starting a new local deploy.

## Supabase local

```sh
supabase start
supabase db reset
```

Remote linking will be done after the new Supabase project is created.
