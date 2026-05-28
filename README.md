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
flutter run -d chrome
```

With Supabase:

```sh
flutter run -d chrome \
  --dart-define=SUPABASE_URL=https://your-project-ref.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-public-anon-key
```

## Supabase local

```sh
supabase start
supabase db reset
```

Remote linking will be done after the new Supabase project is created.
