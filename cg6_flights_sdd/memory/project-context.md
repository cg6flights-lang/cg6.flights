# /memory/project-context.md

# Project Context — CG6 Flights

## Proyecto

CG6 Flights.

## Visión

Centro de Gestión y Control de Vuelos Diarios.

## Contexto operacional

Plataforma web para Base Aérea Las Palmas, orientada a control diario de vuelos por unidad, estados operacionales, históricos, auditoría, reportes y comunicación interna.

## Roles (6)

- Líder.
- Administrador General.
- Comando de Unidad.
- Administrador de Unidad.
- Jefe de Escuadrón.  ← añadido en v1.2 (GRU51).
- TTAA.

Definidos en `lib/core/security/app_role.dart` (`AppRole`). `isGlobal` = leader | generalAdmin.

## Stack as-built

- Flutter Web 3.44.1 + Riverpod + GoRouter.
- Supabase (PostgreSQL + RLS + Storage + Realtime + Edge Functions).
- fl_chart, flutter_map + latlong2, pdf, intl, shared_preferences.
- Deploy: Vercel (`outputDirectory: build/web`).

---

## Estado as-built (2026-06-23)

Branch de desarrollo: `cg6_flights_v1.3` (HEAD `62f0669`). 18 módulos en `lib/features`, 36 migraciones, 16 Edge Functions, suite de 100 tests.

### Módulos implementados

- **Auth** — Login, registro, sesión, RBAC, permisos derivados de rol vía `rolePermissionMatrix`. Edge Functions `bootstrap-profile`, `claim-first-leader`, `change-password`.
- **Users** — Listado, asignación de rol/estado/unidad/escuadrón. Edge Functions `assign-user-access`, `manage-user`. Permisos en `lib/features/users/domain/user_permissions.dart`.
- **Units** — CRUD con Edge Function `manage-unit`.
- **Aircraft (v2)** — CRUD (`manage-aircraft`, `list-aircraft`) + dashboard por unidad: model cards agrupadas con dots de estado, chips de unidad, modal de detalle (horas reales vs programadas), BarChart de horas por modelo, curva de operatividad (`get_operational_curve` + `aircraft_status_history`). Estados Operativo/Inoperativo (mantenimiento unificado). Junction M:N con escuadrones (`aircraft_squadrons`) + filtros por escuadrón. `aircraft_page.dart` modularizado en `presentation/widgets/` (6 widgets) + `aircraft_providers.dart` (v1.3).
- **Crew** — CRUD (`manage-crew`) + dashboard split Pilotos/Mecánicos con filtros, `assignment_type` (Nato/Foráneo), `function_code` (PS/IP/PM/CP/CO/PI/PR), foto (`crew_photo` + storage). Cadetes temporales: `cadet_courses`, grados, PRDI, turnos.
- **Squadrons (Escuadrones)** — Escuadrones de vuelo (GRU51), rol Jefe de Escuadrón, scope `squadronId` en `session_controller`, filtros en Tripulaciones/Aeronaves, junction M:N con aeronaves.
- **Routes** — CRUD (`manage-route`) + mapa interactivo (flutter_map + OpenStreetMap) + planificador (distancia NM/KM, rumbo, ETE) + rutas guardadas + análisis de rutas frecuentes.
- **Flight Orders** — CRUD con Edge Function `manage-flight-order`. Estados draft → submitted → approved/observed → closed/reopened. Items (`flight_order_items`) con aeronave, tripulación, rutas, niveles, ETE, combustible, perfiles (romanos). Número `ACRONYM-XXX-YYYY`. Estados por item waiting → taxi → takeoff → landing → engine_off (`flight_order_state_events`). Cancelación individual. Diálogo de item a 3 pasos (Vuelo · Combustible y Ruta · Tripulación). PDF A4 landscape (14 columnas, firmas, offset de zona inyectado). Borrado por Líder. Carga de relaciones por batch loading (queries separadas + `inFilter`).
- **Flights** — Vista diaria con tablero operacional + Pantalla LED full-screen (estética aeroportuaria militar, `CustomPainter`, presenter `FlightLedBoardPresenter`, lectura `listFlightsByDate`). Selector de fecha (calendario) que hereda la Pantalla LED. METAR widget (visibilidad en km).
- **Dashboard (modular v2)** — Layout 2 secciones, widgets reordenables (`ReorderableListView` + `onReorderItem`), KPIs reales, Timeline Gantt, Modo Edición, adaptativo por rol, relojes, fleet status por unidad/modelo. Realtime sin polling.
- **Audit** — 2 pestañas: Eventos (4 bloques: Operaciones, Gestión de Vuelo, Personal, Sistema) y Rendimiento (4 gráficas fl_chart). RLS con scope por unidad + limpieza pg_cron cada 2 meses. Integra la Papelera.
- **Trash (Papelera)** — Soft-delete general integrado en Auditoría. Edge Function `list-trash`, migración `trash_soft_delete`.
- **Closures (Cierres)** — Página con resumen y soft-delete para OV (nota: en v1.3 el ítem de menú "Cierres" fue retirado del menú principal; la lógica de cierre vive en el flujo de OV).
- **Messages** — Mensajería dual realtime. Chat privado 1:1 con confirmación de visto + publicaciones operacionales (scope global/unidad) con comentarios. Edge Function `manage-message-post`. 5 tablas con streams Realtime, UI 3-columnas.
- **Notifications** — Campana con badge, dropdown no leídas, página completa con filtro. StreamProvider Realtime (sin Timer de polling).
- **Calendar** — Eventos operacionales (`calendar_events`, Edge Function `manage-calendar-event`).
- **Profile** — Perfil completo, bienvenida, cambio de contraseña, edición con actualización en Supabase, avatar (storage).
- **Settings** — Configuración incl. `timezoneProvider` (offset configurable, default Perú UTC-5).
- **Flight Status** — Presentación de estados de vuelo.
- **Core** — Result types (`AppResult`), catálogo de errores, seguridad/permisos (`app_role.dart`), realtime (`realtime_invalidator.dart`), estado, config, i18n ES/EN custom, tema claro/oscuro, router con guards.

### Internacionalización

i18n completo ES/EN (custom, 220+ claves, ~38 archivos convertidos), toggle de idioma en login y header (botón globo).

### Timezone

Norma: almacenar SIEMPRE en UTC; mostrar SIEMPRE con `formatTimeWithOffset` usando el offset de `timezoneProvider`. `toLocalTime(utc, offset)` para conversión. Migración `fix_scheduled_departure_utc` corrigió datos históricos.

### Pendiente / no implementado como módulo propio

- **Reports** — generación PDF centralizada aún acotada a Flight Orders; módulo Reports transversal pendiente.
- **History** — consulta histórica transversal; hoy cubierta parcialmente por Audit + Trash.
- **Maps** — no es módulo autónomo; vive embebido en `routes` (flutter_map).

### Bugs / deuda conocida

- **(RESUELTO)** Panel de detalle de OV con relaciones vacías: se migró `listItems` a batch loading (queries separadas + `inFilter`); las relaciones (routes, crew, profiles, state_events) ya cargan.
- **Transiciones de estado sin confirmación**: submit/approve/observe/close/reopen aún se ejecutan sin diálogo de confirmación previa (pendiente).

---

## Registro de sesiones

### Sesión 2026-06-02 (base v1.0)
Auth, Units, Aircraft v1, Crew, Users, Routes, Flight Orders, Flights (LED board), Audit, Messages v1.1, METAR, Branding v1.0, primer deploy Vercel. Specs `flight-orders.spec.md` y `messages.spec.md` creadas.

### Sesión v1.1 (i18n, perfil, aeronaves v2 — jun 05–07)
- i18n completo ES/EN (220+ claves, ~38 archivos) + toggle idioma en login.
- Perfil de usuario completo + bienvenida + cambio de contraseña + relojes en dashboard + crear usuario admin.
- Aeronaves v2 (model cards, chips unidad, modal detalle, horas reales vs programadas, BarChart), dashboard fleet, METAR mejorado, dataset de aeropuertos ampliado, notificaciones (Codex).
- Página Cierres. Limpieza de warnings (0 issues).

### Sesión v1.2 (escuadrones, cadetes, papelera — jun 08–10)
- **Escuadrones GRU51** + rol Jefe de Escuadrón + `session_controller` con scope `squadronId` + filtros en Tripulaciones/Aeronaves. Junction M:N `aircraft_squadrons` (`flight_squadrons` + `aircraft_squadrons`).
- **Dashboard adaptativo por rol.**
- **Cadetes temporales**: infraestructura PRDI + turnos + alerta, `cadet_courses`, gestión de cadetes, grados, `photo_path`, turnos en vuelos (`training_prdi_shifts`, `cadet_courses`, `crew_photo`).
- **Papelera general** integrada en Auditoría + soft-delete para OV (`trash_soft_delete`).

### Sesión 2026-06-22 (realtime, METAR, fechas, UTC — v1.3)
- **Realtime ops** — patrón "Realtime → invalidate": helper `lib/core/realtime/realtime_invalidator.dart` (canal Supabase por tabla, con debounce, que invalida providers Riverpod sin reescribir queries con joins). Aplicado a Crew, Dashboard y Notifications (se eliminó el polling con Timer). Migración `20260621000000_realtime_ops_tables.sql` (replica identity full en la publicación `supabase_realtime`).
- **Flight item dialog** — rediseño a 3 pasos reutilizando el selector de tripulación completo (function codes + checkbox mecánico + i18n).
- **METAR** — visibilidad en km (statute miles × 1.609344) en `MetarData.visDisplay`.
- **Vuelos: fecha** — `showDatePicker` en el header; la Pantalla LED hereda la fecha (`FlightLedBoard(initialDate:)`).
- **Estandarización de horas a UTC** — guardado local→UTC, carga UTC→local, LED presenter (`toLocalTime`), Aircraft `_RelatedOrderCard` → `ConsumerWidget`, PDF con offset inyectado. Migración `20260622000000_fix_scheduled_departure_utc.sql` (+5h histórico).

### Sesión 2026-06-23 (refactor + tests — v1.3)
- **Refactor modular de Aeronaves** — extracción de 6 widgets desde `aircraft_page.dart` (−2.426 líneas) a `presentation/widgets/` + nuevo `aircraft_providers.dart`.
- **Suite de tests unitarios** — `test/core/{app_result,app_role,timezone_provider}` + `test/features/{aircraft,crew,flight_orders}/domain` + presenters/servicios. 100 tests pasando, `flutter analyze` limpio.
- **Fix** — `onReorder → onReorderItem` en `dashboard_page` (deprecación Flutter 3.44.1 + off-by-one al reordenar).
- **Documentación** — actualización integral del SDD a estructura as-built; eliminación de 6 prompts/handoffs de trabajos antiguos.

---

## Decisiones técnicas vigentes

- **Realtime → invalidate**: canal Supabase por tabla con debounce invalida providers Riverpod, en lugar de reescribir queries con joins (`RealtimeInvalidator`). Tablas en publicación `supabase_realtime` con replica identity full.
- **Horas en UTC**: almacenar en UTC, mostrar con offset de `timezoneProvider`.
- **Batch loading** de relaciones de OV (queries separadas + `inFilter`) en vez de selects anidados complejos.
- **fl_chart** v1.2.0 (MIT, Dart puro) para gráficas.
- Tracking histórico de estado de aeronaves vía `aircraft_status_history`; RPC `get_operational_curve`.
- `InputDecorator` + `DropdownButton` (no-FormField) para evitar bugs de sincronización de `DropdownButtonFormField.value`.
- Pantalla LED en Flutter puro (`CustomPainter`, presenter) sin nuevas dependencias.
- pg_cron para limpieza de `audit_logs` cada 2 meses.
- `deploy_local.sh` detecta compilación DDC vía response time de `main.dart.js`.
- Vercel deploy con `outputDirectory: build/web` (sin buildCommand: Flutter no está en las build machines).
- Soft-delete general (Papelera) en vez de borrado físico ordinario.

## Principios

- Seguridad alta.
- Auditoría transversal.
- Separación por unidad (y escuadrón).
- Permisos granulares.
- Históricos 5 años.
- Responsive.
- Bilingüe Español/Inglés.
- Diseño aeronáutico militar.
- Credenciales en `.env.json` (gitignored), nunca en código fuente.
- Actualizar contexto de proyecto al final de cada sesión para continuidad.
