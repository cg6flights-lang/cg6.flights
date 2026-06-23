# /specs/frontend.spec.md

# Frontend Specification — CG6 Flights

## 1. Propósito

El frontend debe entregar una interfaz web moderna, responsive, segura, bilingüe y orientada a operación aérea militar.

## 2. Framework

Tecnología preliminar:

```txt
Flutter Web
```

## 3. Principios frontend

- UI por rol.
- UI por unidad.
- Seguridad visual no es seguridad real.
- No lógica crítica en widgets.
- No secretos en frontend.
- No service role key.
- No generación PDF/Excel fuera de Reports.
- No rutas críticas sin guards.

## 4. Capas frontend

- Presentation Layer.
- Application Layer.
- Domain Layer frontend.
- Data Access Layer frontend.

## 5. Estructura modular

As-built (2026-06-23) — 18 módulos en `/features`:

```txt
/lib
  /app
  /core
    /config /errors /realtime /results /security /state
  /shared
    /widgets
  /features
    /auth
    /dashboard
    /users          (roles y permisos: core/security + users/domain)
    /units
    /aircraft       (presentation/widgets/ tras refactor v1.3)
    /crew           (incluye cadetes temporales)
    /flight_orders
    /flights        (Pantalla LED + METAR)
    /flight_status
    /routes         (mapa embebido — flutter_map)
    /closures
    /audit
    /trash          (papelera / soft-delete)
    /notifications
    /messages
    /calendar
    /profile
    /settings
```

Escuadrones se integran como scope/filtros en Crew y Aircraft (sin carpeta propia). `roles`, `permissions`, `history`, `reports` y `maps` **no** son módulos autónomos (ver architecture.spec §3).

## 6. Routing

Rutas públicas:

- /login
- /register
- /forgot-password

Rutas especiales (post-login sin acceso completo):

- /pending-access
- /permission-denied

Rutas protegidas (as-built):

- /dashboard
- /users
- /units
- /aircraft
- /crew
- /flight-orders
- /flights
- /routes
- /closures
- /audit
- /notifications
- /messages
- /calendar
- /profile
- /settings

> Papelera se accede desde Auditoría; escuadrones se filtran dentro de Crew/Aircraft; `/flight-status` no es ruta autónoma (estado embebido en Vuelos). `roles`, `permissions`, `history`, `reports`, `maps` no tienen ruta propia.

## 7. Guards

Deben validar:

- sesión;
- usuario activo;
- rol;
- unidad;
- permiso;
- alcance;
- recurso accesible.

## 8. Gestión de estado

Opción preferente preliminar:

- Riverpod.

Opciones aceptables:

- Bloc/Cubit.
- Provider.

## 9. Layouts

### Líder

Dashboard global, auditoría, permisos, usuarios, unidades, reportes, históricos, notificaciones.

### Administrador General

Control operacional global, reportes, históricos, cierres, auditoría operacional.

### Comando de Unidad

Control de unidad, autorización de cambios, cierre, históricos de unidad.

### Administrador de Unidad

Carga diaria, vuelos, estados, solicitud de cierre, unidad propia.

### TTAA

Vista limitada de vuelo asignado y confirmación autorizada.

## 10. Pantallas principales

- Login.
- Registro.
- Recuperación de contraseña.
- Dashboard.
- Usuarios.
- Roles.
- Permisos.
- Unidades.
- Aeronaves.
- Tripulación.
- Orden de Vuelo.
- Vuelos.
- Estados.
- Rutas.
- Cierres.
- Históricos.
- Auditoría.
- Notificaciones.
- Mensajes.
- Reportes.
- Calendario.
- Mapas.
- Perfil.
- Configuración.

## 11. Estados visuales obligatorios

- loading;
- success;
- empty;
- validation_error;
- permission_denied;
- business_error;
- network_error;
- system_error;
- sync_pending;
- retry_available.

## 11.1 Componentes base obligatorios

- AppShell con navegación lateral en escritorio y navegación compacta en móvil.
- TopBar con unidad activa, idioma, perfil y cierre de sesión.
- GuardedRoute para sesión, estado, rol, unidad, permiso y alcance.
- PermissionGate para ocultar o deshabilitar acciones no permitidas sin sustituir seguridad real.
- DataStateView para loading, empty, error, permission denied y retry.
- AppTable con paginación, filtros y estados vacíos.
- AppForm con validación visible y accesible.
- AuditTrailPanel para vistas autorizadas.
- LanguageSwitcher Español/Inglés.
- RoleBadge, UnitBadge y StatusBadge.

## 11.2 Flujos UI detallados

- Registro: usuario crea cuenta, se muestra estado pending y se bloquea operación hasta asignación.
- Login: sesión válida carga perfil; si falta rol, unidad o estado activo, se muestra bloqueo operativo.
- Administración de acceso: usuario autorizado asigna rol, unidad y estado; el cambio se audita.
- Navegación protegida: rutas críticas validan guards antes de renderizar contenido.
- Operación por unidad: roles de unidad solo ven la unidad asignada.
- Reportes: toda acción de exportar redirige al Reports Module.
- Errores: cada error normalizado se traduce a mensaje UI claro en Español/Inglés.

## 11.3 Estados de error por categoría

- AUTH: pedir login o informar sesión expirada.
- AUTHORIZATION: mostrar permission_denied sin revelar datos del recurso.
- VALIDATION: marcar campos y explicar corrección.
- BUSINESS_RULE: explicar regla operacional incumplida.
- DATA: mostrar no encontrado o conflicto.
- NETWORK: ofrecer retry.
- STORAGE: informar archivo inválido o excedido.
- REALTIME: mantener vista usable y marcar sync_pending.
- EXPORT: mostrar falla de generación desde Reports.
- SYSTEM: mensaje seguro sin detalles internos.

## 11.4 UI/UX — Mensajes

### 11.4.1 Estructura de componentes

| Componente | Responsabilidad |
|---|---|
| `MessagesPage` | Ruta única `/messages` con modo Chat/Publicaciones |
| `MessageComposeDialog` | Inicio de chat privado con destinatario y cuerpo |
| `MessagesRepository` | Streams realtime, envío de chat, vistos, publicaciones, comentarios y confirmaciones |

### 11.4.2 Modo Chat

- Primera columna: selector `Chat` / `Publicaciones`, indicador realtime, refresh y estado de permisos.
- Segunda columna: lista de conversaciones por usuario con nombre, rol/unidad/email, último mensaje, hora, badge de no leídos y estado activo visual.
- Tercera columna: chat privado con header del contacto, burbujas derecha/izquierda, composer inferior y ticks de enviado/visto.
- El botón `Nuevo chat` se muestra solo con `messages.send`.
- Los errores realtime no deben convertirse en estado vacío.

### 11.4.3 Modo Publicaciones

- Al seleccionar `Publicaciones`, la segunda columna se oculta y el timeline ocupa el espacio central.
- Composer superior visible solo con `message_posts.create`.
- Selector de alcance:
  - global solo para roles globales;
  - unidad para roles globales o roles de unidad dentro de su unidad.
- Cards con autor, rol, fecha, scope, cuerpo, contador de comentarios, contador de vistos y botón de confirmación de lectura.
- Todos los roles con `message_posts.comment` pueden comentar publicaciones visibles.

### 11.4.4 Responsive

- Desktop: multipanel.
- Tablet: lista + detalle o timeline expandido.
- Móvil: Chat alterna lista/detalle; Publicaciones usa timeline compacto.

## 11.5 UI/UX — Calendario Operacional

- `/calendar` reemplaza el stub por una vista operacional de actividades próximas.
- Layout de referencia:
  - tabs superiores `Resumen`, `Calendario`, `Actividades`;
  - tarjeta principal con calendario mensual compacto a la izquierda;
  - lista de actividades próximas a la derecha;
  - cards con fecha, estado, tipo, hora, ubicación y descripción corta.
- `Nueva actividad` solo visible con `calendar.manage`.
- Estados visuales: `Programada`, `En curso`, `Completada`, `Cancelada`.
- El ícono de calendario del header conserva badge del día, abre un preview tipo menú con mini calendario, alertas próximas y botón `Ampliar` hacia `/calendar`.
- Al abrir `/calendar`, el día seleccionado por defecto es hoy y la lista base muestra las actividades del mes visible, excluyendo meses auxiliares.
- Si el día seleccionado tiene actividades, se muestra un panel operacional con acciones para usuarios con `calendar.manage`: iniciar, modificar fecha y confirmar realizada.
- La parte inferior muestra un Gantt mensual con barras por duración, color por tipo, estado visual, línea de hoy y marcador del día seleccionado.
- Responsive:
  - desktop: calendario y lista en dos columnas;
  - tablet/móvil: calendario arriba, lista debajo, Gantt scrolleable sin cortes.

## 11.6 UI/UX — Flight Orders (Orden de Vuelo)

### 11.6.1 Estructura de componentes

| Componente | Archivo | Responsabilidad |
|---|---|---|
| `FlightOrdersPage` | `flight_orders_page.dart` | Página principal: tabla de órdenes + panel de detalle |
| `FlightOrderDetailPanel` | `flight_order_detail_panel.dart` | Detalle de orden: items, tripulación, rutas, timeline |
| `FlightOrderFormDialog` | `flight_order_form_dialog.dart` | Diálogo modal: crear nueva orden |
| `FlightItemFormDialog` | `flight_item_form_dialog.dart` | Diálogo modal: agregar vuelo a orden (8 secciones) |
| `FlightOrderPdfService` | `flight_order_pdf_service.dart` | Generación PDF A4 landscape |

### 11.6.2 FlightOrdersPage

**Layout responsivo**:
- ≥ 1100px: `Row` — DataTable (flex 3, altura 550px, scroll vertical) + `VerticalDivider` + Panel detalle (flex 2).
- < 1100px: `Column` — DataTable (altura 300px) + `Divider` + Panel detalle.

**Estados visuales**:
- `loading`: `DataStateView(kind: DataStateKind.loading)`.
- `empty`: Icono `assignment_outlined` + mensaje "No hay órdenes" + botón crear (si `canCreate`).
- `error`: `DataStateView(kind: DataStateKind.systemError)` con mensaje y botón retry.
- `success`: DataTable con filas seleccionables y panel de detalle.

**DataTable**: Columnas: N° Orden, Unidad, Fecha Operación, Estado, Acciones. Fila seleccionable (selected=true resaltada). Orden: `operation_date DESC`, limit 100.

**Chips de estado**: draft (gris), submitted (azul), observed (naranja), approved (verde), closed (rojo), reopened (púrpura).

**Acciones por estado de orden** (iconos con tooltip):
- draft: Submit (send), Delete (delete, solo si canDelete), PDF (picture_as_pdf, si canExport)
- submitted / observed: Approve (check_circle), Observe (visibility), PDF
- approved: Close (lock), PDF
- closed: Reopen (lock_open), PDF

**Providers**: `_ordersListProvider` (FutureProvider local invalidado al crear/cambiar/borrar órdenes).

### 11.6.3 FlightOrderDetailPanel

**Encabezado**: N° Orden, Unidad, Fecha, chip de estado, botón "+" (agregar item, solo draft y canCreate).

**Sección de items**: `ListView` de Cards. Cada card:
- Matrícula de aeronave + badge de estado de vuelo (chip coloreado)
- Misión
- Nivel de vuelo (min - max) + ETE
- Combustible: tipo + cantidad (lbs)
- Salida programada (HH:mm)
- Rutas: segmentos con formato "Origen → Destino" + tipo (outbound/return, airport/zone/waypoint)
- Tripulación: PC, CP, MA con nombre, callsign y function code en chip
- Perfiles asignados: chips con `profile_number` y `description`
- Timeline de eventos: lista cronológica de estados (taxi, takeoff, landing, engine_off) con timestamp
- Tiempos calculados: total (engine_off − taxi) y aire (landing − takeoff)

**Acciones por item**:
- Botón avanzar estado (siguiente en secuencia, visible si no es engine_off ni cancelled)
- Botón cancelar (abre diálogo de motivo obligatorio)

**Sección de perfiles** (solo draft):
- Lista de perfiles con botón eliminar (icono X)
- Botón agregar perfil: diálogo con campo `description` obligatorio

### 11.6.4 FlightOrderFormDialog

Diálogo `AlertDialog` (ancho 450px):
- **Unidad**: `DropdownButtonFormField` cargado de `units` activas (orden `name`). Validación: requerido.
- **Fecha**: `OutlinedButton` con icono calendario. Date picker rango: -30 a +90 días desde hoy.
- **Acciones**: Cancelar + Guardar (con spinner durante submit).
- Llama a `manageFlightOrder(action: 'create')` vía repositorio.

### 11.6.5 FlightItemFormDialog

Diálogo extenso con 8 secciones:

1. **Aeronave**: `DropdownButtonFormField` filtrado por unidad de la orden (`unit_id`). Muestra `registration`. Validación: requerido.
2. **Misión**: `Autocomplete` con histórico de misiones de la unidad (valores únicos de `flight_order_items.mission`).
3. **Salida programada**: Time picker.
4. **Nivel de vuelo + ETE**: Campos numéricos min/max + ETE con botones +/- (incremento 5 min). Validación: ETE > 0.
5. **Combustible**: Dropdown tipo (Jet A1, 100LL, JP-8, JP-5, MOGAS) + campo numérico lbs con conversión bidireccional a galones (1 gal = 6.7 lbs aprox Jet A1).
6. **Rutas**: Multi-segmento con botón agregar/quitar. Cada segmento: `segment_order`, `segment_type` (outbound/return), origen (airport/zone/waypoint + búsqueda), destino (mismo formato). Validación: al menos 1 ruta.
7. **Perfiles**: `FilterChip` multi-select. Muestra perfiles definidos en la orden (`profile_number - description`).
8. **Tripulación**: PC (dropdown requerido), CP (dropdown opcional), checkbox "¿Mecánico a bordo?" → MA (dropdown condicional). Function code opcional por tripulante (dropdown PS/IP/PM/CP/CO/PI/PR). Datos cargados de `crew_members` filtrados por unidad.

### 11.6.6 FlightOrderPdfService

**Formato**: A4 landscape, package `pdf`.
**Contenido**:
- Encabezado: N° Orden, Unidad, Fecha Operación
- Tabla 14 columnas: N°, Aeronave, Misión, PC, CP, MA, Origen, Destino, Nivel, ETE, Combustible, Salida, Estado, Perfiles
- Sección tiempos: total y aire por item
- Sección firmas: Comando de Unidad, Administrador de Unidad
**Descarga**: `dart:html` — `AnchorElement` con `Blob` + `URL.createObjectURL`.

### 11.6.7 Traducciones requeridas

Keys bajo prefijo `flightOrders.*` (~60 keys ES/EN):
- `orderNumber`, `unit`, `operationDate`, `status`, `add`, `submit`, `approve`, `observe`, `close`, `reopen`, `delete`, `deleteTitle`, `deleteConfirm`, `exportPdf`, `exportingPdf`, `pdfExported`, `loadFailed`, `empty`, `draft`, `submitted`, `observed`, `approved`, `closed`, `reopened`
- `aircraft`, `mission`, `scheduledDeparture`, `flightLevel`, `flightLevelMin`, `flightLevelMax`, `eteMinutes`, `fuelType`, `fuelAmount`, `fuelLbs`, `fuelGal`
- `routes`, `addRoute`, `removeRoute`, `segmentType`, `outbound`, `return`, `originType`, `destinationType`, `airport`, `zone`, `waypoint`, `origin`, `destination`
- `crew`, `pc`, `cp`, `ma`, `mechanicOnBoard`, `functionCode`, `selectCrew`
- `profiles`, `addProfile`, `removeProfile`, `profileNumber`, `description`
- `state`, `stateEvents`, `totalTime`, `airTime`, `advanceState`, `cancelItem`, `cancelReason`, `cancelConfirm`
- `signatures`, `unitCommand`, `unitAdmin`

## 12. Diseño visual

Identidad:

```txt
moderna + aeronáutica + militar + operacional
```

## 13. Responsive

Prioridad:

1. Escritorio/laptop.
2. Tablet.
3. Celular.

## 14. Internacionalización

Idiomas:

- Español.
- Inglés.

## 15. Accesibilidad

- Contraste suficiente.
- Foco visible.
- Etiquetas de formularios.
- No depender solo de color.
- Mensajes claros.
- Tamaños táctiles razonables.

---

## 16. Changelog

> Registro cronológico inverso de cambios de frontend.

### 2026-06-22 a 2026-06-23 (v1.3) — Realtime, UTC, fechas, refactor + tests

- **Realtime ops**: providers de Crew/Dashboard/Notifications invalidados por canal Supabase (sin `Timer` de polling) vía `RealtimeInvalidator`.
- **Flight item dialog**: rediseño a 3 pasos (Vuelo · Combustible y Ruta · Tripulación) con selector de tripulación completo.
- **METAR**: visibilidad en km.
- **Vuelos**: selector de fecha (calendario) heredado por la Pantalla LED (`FlightLedBoard(initialDate:)`).
- **Horas en UTC**: guardado local→UTC, carga UTC→local, LED presenter, Aircraft `_RelatedOrderCard` (→ `ConsumerWidget`) y PDF con offset inyectado.
- **Aeronaves**: `aircraft_page` modularizado en `presentation/widgets/` (6 widgets) + `aircraft_providers.dart`.
- **Dashboard**: `onReorder → onReorderItem` (deprecación Flutter 3.44.1 + off-by-one al reordenar).
- **Tests**: suite unitaria (dominios, presenters, servicios); `flutter analyze` limpio.

### 2026-06-07 a 2026-06-10 (v1.1–v1.2) — i18n, Escuadrones, Cadetes, Papelera

- **i18n completo ES/EN** (custom, ~38 archivos, toggle en login y header).
- **Perfil** completo + bienvenida + cambio de contraseña + relojes en dashboard.
- **Escuadrones** (GRU51) + rol Jefe de Escuadrón + scope `squadronId` + filtros en Tripulaciones/Aeronaves + junction M:N con aeronaves.
- **Dashboard adaptativo por rol.**
- **Cadetes temporales**: cursos, grados, PRDI, turnos, foto.
- **Papelera** (soft-delete) integrada en Auditoría.

### 2026-06-05 a 2026-06-06

### Aeronaves v2
- 2 estados (Operativo/Inoperativo, mantenimiento unificado con inoperativo)
- Chips de unidad con `NotifierProvider` (solo roles globales)
- Model cards agrupadas por modelo con dots de estado (verde/rojo)
- Modal de detalle centrado con horas reales vs programadas (RPC `get_aircraft_flight_hours`)
- BarChart de horas por modelo + curva de operatividad (fl_chart)
- `listItemsByAircraft` en repositorio para historial de OVs por aeronave
- Auto-selección inicial de unidad (primera disponible con aeronaves)

### Dashboard Fleet
- Fleet status widget con agrupación por unidad y modelo
- Aircraft KPIs por unidad (`aircraftKpiProvider`, `DashboardAircraftKpiStats`)
- `dashboardFleetProvider` para agrupación jerárquica unidad→modelo

### METAR Widget
- Mejorado con más aeropuertos y datos históricos
- Selector de aeródromo con scroll horizontal

### Airports Dataset
- Expandido con ~50 aeropuertos internacionales adicionales

### Notificaciones
- Campana con badge en AppBar, dropdown de no leídas
- Página completa con filtro leídas/no leídas
- Realtime vía Supabase stream en `notifications`

### Menú
- Dashboard > Vuelos > OV > Aeronaves > Tripulación > Unidades > Rutas > Mensajes > Usuarios
- Cierres eliminado, Auditoría en dropdown del avatar
- Usuarios al final con ícono `admin_panel_settings`

---

### 2026-06-01 a 2026-06-04

### Dashboard Modular v2

- **Layout**: Dos secciones — widgets anchos (span-2/3) a la izquierda (2/3 ancho), widgets angostos (span-1) apilados a la derecha (1/3). Sin huecos.
- **8 widgets visibles**: Mapa, KPIs, Timeline (Gantt), Próximos Vuelos, METAR, Operatividad (fl_chart), Notificaciones, Flota.
- **3 widgets ocultos**: Resumen del Día, Acciones Rápidas, Calendario Mini. Activables desde Personalizar.
- **Modo Edición**: Drag & drop con `ReorderableListView`, ajuste de ancho (-/+), toggle visibilidad.
- **Preferencias**: orden, visibilidad y span persistidos en memoria vía `DashboardPreferencesNotifier`.
- **Responsivo**: 2/3+1/3 en ≥1100px, 1/2+1/2 en ≥700px, columna única en <700px.
- **Wrapper**: `DashboardWidgetWrapper` como `StatelessWidget` con Card + header.

### Flight Orders — Mejoras

- **Numeración con año**: `ACRONYM-XXX-YYYY` (ej. EDACI-051-2026). Secuencia por unidad.
- **Perfiles**: numeración romana (I, II, III...). Sección movida debajo de la tabla de OVs, no en el panel de detalle. Visibles en cualquier estado.
- **Vuelo Local**: checkbox en el formulario de vuelo. Origen = destino = mismo aeropuerto. Zona de trabajo opcional.
- **Filtros**: unificados al estilo Crew (`DropdownButtonFormField` con `OutlineInputBorder`).
- **Borrado**: Líder puede borrar OVs en cualquier estado. Edge function `manage-flight-order` actualizada.

### Timezone

- **Sistema**: `timezoneProvider` con offset configurable (default Perú UTC-5).
- **Corrección**: `toLocalTime` ajusta desde `_sourceOffset` (-5) al offset configurado. Datos en DB están en hora local Perú.
- **Widgets actualizados**: upcoming flights, timeline, activity, calendar mini, flights page, flight orders page, LED board, dashboard providers, mensajes.

### Data Cleanup

- Borrado de OVs y Vuelos existentes. Nueva OV EDACI-051-2026 creada como draft.
