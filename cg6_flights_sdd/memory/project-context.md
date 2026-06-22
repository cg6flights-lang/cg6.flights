# /memory/project-context.md

# Project Context — CG6 Flights

## Proyecto

CG6 Flights.

## Visión

Centro de Gestión y Control de Vuelos Diarios.

## Contexto operacional

Plataforma web para Base Aérea Las Palmas, orientada a control diario de vuelos por unidad, estados operacionales, históricos, auditoría, reportes y comunicación interna.

## Roles

- Líder.
- Administrador General.
- Comando de Unidad.
- Administrador de Unidad.
- TTAA.

## Stack preliminar

- Flutter Web.
- Supabase.
- Vercel.

## Estado actual de implementación (2026-06-02)

### Completado
- **Auth** — Login, registro, sesión, RBAC, permisos derivados de rol vía rolePermissionMatrix
- **Units** — CRUD completo con Edge Function
- **Aircraft** — CRUD con Edge Function + dashboard por unidad con layout dos columnas (Operativas/Inoperativas/Mantenimiento + resumen + curva de operatividad con tracking histórico via `aircraft_status_history`)
- **Crew** — CRUD con Edge Function + dashboard split Pilotos/Mecánicos con filtros y `assignment_type` (Nato/Foráneo)
- **Users** — Listado, asignación de rol/estado/unidad
- **Core** — Result types, errores, permisos, i18n ES/EN, tema claro/oscuro, router con guards
- **Routes** — CRUD completo con Edge Function + mapa interactivo (flutter_map + OpenStreetMap) + planificador de rutas con calculador de distancia (NM/KM), rumbo, ETE configurable, rutas guardadas y análisis de rutas frecuentes
- **Dashboard** — Vista operacional con cards y badges
- **Profile** — Modal de edición con actualización en Supabase
- **Flight Orders** — CRUD completo de órdenes de vuelo con Edge Function `manage-flight-order`
  - Flujo de estados: draft → submitted → approved/observed → closed/reopened
  - Items de vuelo (`flight_order_items`) con aeronave, tripulación (PC/CP/MA + function_code PS/IP/PM/CP/CO/PI/PR), rutas (origen/destino con tipo airport/zone/waypoint), niveles de vuelo, ETE, combustible (lbs/gal), perfiles
  - Número de orden auto-generado: `ACRONYM-XXX` con fallback a `code` si `acronym` es null
  - Estados de vuelo por item: waiting → taxi → takeoff → landing → engine_off con tracking de tiempos (`flight_order_state_events`)
  - Cancelación de vuelos individuales con motivo
  - Panel de detalle con vista de items, tripulación, rutas, tiempos, perfiles
  - PDF de Orden de Vuelo (formato A4 landscape con tabla de 14 columnas, state/times, firmas)
  - Borrado de órdenes (solo draft, solo roles globales o flight_orders.close)
  - Checkbox "¿Mecánico a bordo?" para hacer opcional el campo MA
  - Validación de aeropuerto en rutas (validator required)
- **Flights** — Vista diaria de vuelos con tablero operacional y Pantalla LED full-screen.
  - Pantalla LED en sección Vuelos con estética aeroportuaria militar: fondo oscuro, texto monoespaciado amarillo/verde/ámbar/rojo con glow, marco físico, matriz LED, scanlines, ON/OFF y auto-refresh cada 60s.
  - Columnas operativas: HORA, UNIDAD·COLA, DESTINO, ETA, OBSERVACIÓN.
  - Transformación de datos encapsulada en presenter (`FlightLedBoardPresenter`) y lectura mediante `FlightOrdersRepository.listFlightsByDate`.
- **SDD de Flight Orders** — [`specs/flight-orders.spec.md`](specs/flight-orders.spec.md) creado post-implementación con module spec completo, UI/UX spec y tests requeridos. Product spec actualizado con RFs 050-059 detallados. Frontend spec ampliado con sección 11.4 (UI/UX Flight Orders).

### Bugs conocidos (2026-05-27)
- **Panel de detalle no muestra relaciones**: `listItems` hace `select('*')` sin joins en `flight_order_items`. Las relaciones anidadas (routes, crew, profiles, state_events) llegan vacías. Documentado en [`flight-orders.spec.md`](specs/flight-orders.spec.md) como caso de integración pendiente.
- **Transiciones de estado sin confirmación**: Submit, approve, observe, close, reopen se ejecutan sin diálogo de confirmación previa.

### Pendiente
Flight Status, Closures, History, Notifications, Reports, Calendar, Maps, Settings

### Completado recientemente (2026-06-02)
- **Audit** — Sección completa con 2 pestañas: Eventos (4 bloques temáticos en 2 columnas: Operaciones, Gestión de Vuelo, Personal, Sistema) y Rendimiento (4 gráficas fl_chart: tendencias, dona, barras apiladas, KPIs). RLS con scope por unidad + limpieza pg_cron cada 2 meses.
- **Messages** — Mensajería dual realtime v1.1. Chat privado 1:1 con confirmación de visto. Publicaciones operacionales con scope global/unidad y comentarios. 5 modelos, 3 nuevos permisos, 8 políticas RLS, Edge Function `manage-message-post`. UI 3-columnas desktop con Realtime.
- **METAR** — Widget corregido: selector muestra todos los aeropuertos de la tabla `routes`.
- **Branding** — Header con isotipo favicon + texto colorizado CG6 Flights v1.0. Sidebar hover scale 1.35x. Botón idioma con globo.
- **Deploy** — Primer despliegue Vercel en producción. Script `deploy_local.sh`.

### SDD (2026-06-02)
- **`specs/flight-orders.spec.md`** — module spec completo con 7 entidades, 14 casos de uso.
- **`specs/audit.spec.md`** — spec post-implementación de Auditoría.
- **`specs/messages.spec.md`** — spec con 5 entidades, 8 casos de uso, permisos, RLS, Realtime.
- **`specs/product.spec.md`** — actualizado con RFs 050-059.
- **`specs/frontend.spec.md`** — actualizado con sección 11.4 UI/UX Flight Orders.

### Decisiones técnicas recientes
- **fl_chart** v1.2.0 para gráficas (MIT license, 100% Dart puro, compatible con Web)
- Tracking histórico de cambios de estado de aeronaves via tabla `aircraft_status_history`
- RPC `get_operational_curve` para curva de operatividad con granularidad configurable
- Layout dos columnas con contenedores independientes y scroll autónomo por columna
- `VerticalDivider` para separación visual entre columnas izquierda y derecha
- `InputDecorator` + `DropdownButton` (no-FormField) para evitar bugs de sincronización de `DropdownButtonFormField.value` deprecado en Flutter 3.41.6
- `listItems` con queries separadas + `inFilter` en lugar de select anidado complejo (en diagnóstico)
- PDF generation con package `pdf` + `dart:html` para descarga en web (conditional exports)
- Pantalla LED de Vuelos implementada sin nuevas dependencias, usando Flutter puro (`CustomPainter`, sombras, gradientes y timers) y presenter para mantener la lógica fuera de widgets.
- Mensajería dual realtime con Supabase Realtime (5 tablas con streams) + Edge Function `manage-message-post`. Chat privado RLS restringido a participantes. Publicaciones con scope global/unidad.
- pg_cron para limpieza automática de audit_logs cada 2 meses.
- Script `deploy_local.sh` con detección de compilación DDC vía response time de `main.dart.js`.
- Vercel deploy con `outputDirectory: build/web` (sin buildCommand porque Flutter no está en las build machines).

### Sesión 2026-06-22 (Realtime, METAR, fechas en Vuelos, estandarización de horas)
- **Realtime ops** — Patrón "Realtime → invalidate": helper `lib/core/realtime/realtime_invalidator.dart` (canal Supabase por tabla, con debounce, que invalida providers Riverpod sin reescribir queries con joins). Aplicado a Crew (`crew_members`) y Dashboard (`flight_orders`, `flight_order_items`, `flight_order_state_events`, `aircraft`). Notifications ya era StreamProvider; se quitó el Timer de polling de 5s. Migración `20260621000000_realtime_ops_tables.sql` habilita esas tablas en la publicación `supabase_realtime` (replica identity full).
- **Flight item dialog** — Rediseño a 3 pasos (Vuelo · Combustible y Ruta · Tripulación) reutilizando el selector de tripulación completo (`_buildCrewSection`: function codes + checkbox mecánico + i18n); se eliminó un Step 3 duplicado e inferior.
- **METAR** — Visibilidad en km (statute miles × 1.609344) en `MetarData.visDisplay`; aplica a Vuelos y Dashboard (comparten `MetarWidget`).
- **Vuelos: fecha** — Calendario `showDatePicker` en el header de Vuelos; la Pantalla LED hereda la fecha seleccionada vía `FlightLedBoard(initialDate:)`.
- **Estandarización de horas a UTC** — Norma: almacenar SIEMPRE en UTC, mostrar SIEMPRE con `formatTimeWithOffset` usando el offset de `timezoneProvider` (default Perú UTC-5, configurable en Settings). Corregidos: guardado de `scheduled_departure` (local→UTC en `flight_item_form_dialog`), carga del modal (UTC→local), LED presenter (`toLocalTime` en vez de `dt.toLocal()`), Aircraft `_RelatedOrderCard` (→ `ConsumerWidget`) y PDF (offset inyectado por el provider). Migración `20260622000000_fix_scheduled_departure_utc.sql` corrige datos históricos (+5h).
- **Entorno local** — SDK Flutter correcto: `/Users/franciscobances1997/flutter/flutter/bin/flutter` (el del PATH `/flutter/bin` es incorrecto y provoca timeouts de I/O). El device `web-server` en :8080 resultó más estable que `-d chrome` (que se cuelga en "Waiting for connection from debug service on Chrome").

## Principios

- Seguridad alta.
- Auditoría transversal.
- Separación por unidad.
- Permisos granulares.
- Históricos 5 años.
- Responsive.
- Bilingüe Español/Inglés.
- Diseño aeronáutico militar.
- Credenciales en `.env.json` (gitignored), nunca en código fuente.
- Actualizar contexto de proyecto al final de cada sesión para continuidad.
