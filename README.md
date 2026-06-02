# CG6 Flights

Centro de Gestion y Control de Vuelos Diarios.

## Source of truth

The SDD folder is the governing source:

```txt
cg6_flights_sdd/
```

Implementation must follow the approved specs, contracts, governance rules, quality gates and ADRs in that folder.

## Local web run

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
