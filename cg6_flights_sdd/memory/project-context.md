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

## Estado actual de implementación (2026-05-30)

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
Flight Status, Closures, History, Audit, Notifications, Messages, Reports, Calendar, Maps, Settings

### SDD (2026-05-27)
- **`specs/flight-orders.spec.md`** creado — module spec completo con 7 entidades, 14 casos de uso, máquinas de estado, UI/UX spec, y tests requeridos.
- **`specs/product.spec.md`** actualizado — RFs 050-059 detallados reemplazando 5 RFs genéricos.
- **`specs/frontend.spec.md`** actualizado — Sección 11.4 UI/UX Flight Orders con especificación de 6 componentes, layouts responsivos, estados visuales, y flujos de interacción.

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
