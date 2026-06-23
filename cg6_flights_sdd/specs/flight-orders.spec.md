# /specs/flight-orders.spec.md

# Flight Orders — Module Specification

## Estado

Implementado v1.0. Spec redactada post-implementación para gobernar mejoras futuras de UI/UX.

## 1. Responsabilidad

Gestión completa de la Orden de Vuelo diaria por unidad:

- Crear orden de vuelo diaria con número auto-generado (`ACRONYM-XXX`).
- Cargar vuelos (items) con aeronave, tripulación, rutas, perfiles, niveles, ETE y combustible.
- Ciclo de revisión: draft → submitted → approved/observed → closed/reopened.
- Seguimiento de estados de vuelo en tiempo real con registro de timestamps.
- Cancelación de vuelos individuales con motivo.
- Gestión de perfiles de vuelo por orden.
- Exportación PDF A4 landscape.

## 2. No responsabilidad

- No gestiona cierres de ficha diaria → Closures module (`closure_requests`).
- No gestiona consultas históricas → History module.
- No genera reportes Excel → Reports module.
- No envía notificaciones → Notifications module.
- No gestiona aeronaves, tripulación ni rutas maestras → módulos respectivos.

## 3. Entidades

### 3.1 FlightOrder

| Campo | Tipo | Descripción |
|---|---|---|
| `id` | UUID | PK |
| `unit_id` | UUID FK units | Unidad propietaria |
| `operation_date` | date | Fecha de operación |
| `order_number` | varchar | Auto-generado: `ACRONYM-XXX` |
| `status` | flight_order_status | draft, submitted, observed, approved, closed, reopened |
| `submitted_at` | timestamptz | Fecha de envío a revisión |
| `approved_at` | timestamptz | Fecha de aprobación |
| `closed_at` | timestamptz | Fecha de cierre |
| `created_by` | UUID FK profiles | Creador |
| `approved_by` | UUID FK profiles | Aprobador |
| `closed_by` | UUID FK profiles | Responsable de cierre |
| `created_at`, `updated_at` | timestamptz | Timestamps |

Restricción: `UNIQUE(unit_id, operation_date)` — una orden por unidad y fecha.

### 3.2 FlightOrderItem

| Campo | Tipo | Descripción |
|---|---|---|
| `id` | UUID | PK |
| `flight_order_id` | UUID FK flight_orders | Orden padre |
| `aircraft_id` | UUID FK aircraft | Aeronave asignada |
| `mission` | text | Descripción de misión |
| `flight_level_min` | integer | Nivel de vuelo mínimo |
| `flight_level_max` | integer | Nivel de vuelo máximo |
| `ete_minutes` | integer | Estimated Time Enroute (minutos) |
| `fuel_type` | varchar | Jet A1, 100LL, JP-8, JP-5, MOGAS |
| `fuel_amount` | numeric | Cantidad (lbs) |
| `scheduled_departure` | timestamptz | Salida programada |
| `status` | varchar | waiting, taxi, takeoff, landing, engine_off, cancelled |
| `cancelled` | boolean | Flag de cancelación |
| `cancelled_at` | timestamptz | Fecha de cancelación |
| `cancelled_by` | UUID | Responsable |
| `cancel_reason` | text | Motivo obligatorio |

Campos poblados en frontend (no persisten en DB, obtenidos via joins):
- `aircraftRegistration` — `tail_number` de la tabla `aircraft`
- `aircraftModel` — `model` de la tabla `aircraft`

Relaciones anidadas (cargadas en el modelo via copyWith):
- `routes[]` → FlightOrderRoute
- `crew[]` → FlightOrderCrew
- `profiles[]` → FlightOrderProfile (via junction table)
- `stateEvents[]` → FlightOrderStateEvent

### 3.3 FlightOrderRoute

| Campo | Tipo | Descripción |
|---|---|---|
| `id` | UUID | PK |
| `flight_order_item_id` | UUID FK flight_order_items | Item padre |
| `segment_order` | integer | Orden del segmento |
| `segment_type` | varchar | outbound / return |
| `origin_type` | varchar | airport / zone / waypoint |
| `origin_route_id` | UUID FK routes | Ruta maestra opcional |
| `origin_label` | varchar | Etiqueta descriptiva |
| `origin_lat`, `origin_lng` | double | Coordenadas |
| `destination_type` | varchar | airport / zone / waypoint |
| `destination_route_id` | UUID FK routes | Ruta maestra opcional |
| `destination_label` | varchar | Etiqueta descriptiva |
| `destination_lat`, `destination_lng` | double | Coordenadas |

### 3.4 FlightOrderCrew

| Campo | Tipo | Descripción |
|---|---|---|
| `id` | UUID | PK |
| `flight_order_item_id` | UUID FK flight_order_items | Item padre |
| `crew_member_id` | UUID FK crew_members | Tripulante |
| `role_code` | varchar | PC (Piloto al Mando), CP (Copiloto), MA (Mecánico) |
| `function_code` | varchar | PS, IP, PM, CP, CO, PI, PR (opcional) |

Restricción: `UNIQUE(flight_order_item_id, crew_member_id)`.

### 3.5 FlightOrderStateEvent

| Campo | Tipo | Descripción |
|---|---|---|
| `id` | UUID | PK |
| `flight_order_item_id` | UUID FK flight_order_items | Item padre |
| `status` | varchar | Estado registrado |
| `occurred_at` | timestamptz | Timestamp del evento |
| `recorded_by` | UUID FK profiles | Operador |

Restricción: `UNIQUE(flight_order_item_id, status)` — no se puede duplicar un estado.

### 3.6 FlightOrderProfile

| Campo | Tipo | Descripción |
|---|---|---|
| `id` | UUID | PK |
| `flight_order_id` | UUID FK flight_orders | Orden padre |
| `profile_number` | integer | Auto-numerado por orden |
| `description` | text | Descripción del perfil |

### 3.7 FlightOrderItemProfile (Junction)

| Campo | Tipo | Descripción |
|---|---|---|
| `id` | UUID | PK |
| `flight_order_item_id` | UUID FK flight_order_items | Item |
| `profile_id` | UUID FK flight_order_profiles | Perfil asignado |

## 4. Máquinas de estado

### 4.1 Estados de orden

```
draft ──submit──▶ submitted ──approve──▶ approved ──close──▶ closed
                     │         observe        ▲                │
                     │            │           │              reopen
                     │            ▼           │                │
                     └─────── observed ───────┘                │
                                                               │
                                           reopened ◀──────────┘
```

Transiciones válidas:
- `draft` → `submit`
- `submitted` → `approve` | `observe`
- `observed` → `approve`
- `approved` → `close`
- `closed` → `reopen`
- `reopened` → `submit`

### 4.2 Estados de vuelo (item)

Secuencia estricta, no se puede saltar estados:

```
waiting → taxi → takeoff → landing → engine_off
```

Cada transición registra un `FlightOrderStateEvent` con timestamp. El estado `cancelled` es terminal y se alcanza desde cualquier estado con motivo obligatorio.

### 4.3 Cálculo de tiempos

- **Tiempo total**: `engine_off.occurred_at` − `taxi.occurred_at`
- **Tiempo de aire**: `landing.occurred_at` − `takeoff.occurred_at`

## 5. Casos de uso

### UC-FO01: Crear orden de vuelo
- **Actor**: UnitAdmin, Leader
- **Permiso**: `flight_orders.create`
- **Input**: `unit_id`, `operation_date`, `items[]` opcional
- **Reglas**: Una orden por unidad y fecha. Número auto-generado (`ACRONYM-XXX`). Scope: solo tu unidad (no-global).
- **Resultado**: Orden en estado `draft`.

### UC-FO02: Agregar item/vuelo
- **Actor**: UnitAdmin, Leader
- **Permiso**: `flight_orders.create`
- **Input**: `flight_order_id`, `item` con aeronave, misión, niveles, ETE, combustible, rutas, tripulación, perfiles
- **Reglas**: Solo en órdenes `draft`. Aeronave obligatoria. Scope por unidad.
- **Resultado**: Item en estado `waiting` con rutas, tripulación y perfiles asociados.

### UC-FO03: Listar órdenes
- **Actor**: Usuarios con `flight_orders.read`
- **Permiso**: `flight_orders.read`
- **Reglas**: RLS filtra por unidad (no-global solo ven su unidad). Ordenado por `operation_date DESC`. Limit 100.
- **Resultado**: Lista de órdenes con nombre de unidad.

### UC-FO04: Listar items de una orden
- **Actor**: Usuarios con `flight_orders.read`
- **Permiso**: `flight_orders.read`
- **Reglas**: Carga datos base de `flight_order_items` vía `select('*')` y luego 4 consultas paralelas batch con `inFilter` para: `aircraft` (tail_number, model), `flight_order_routes` (con airport_name), `flight_order_crew` (con datos del tripulante), `flight_order_state_events`. Los datos se mergean via `copyWith`. RLS por unidad.
- **Resultado**: Lista de items con todos sus datos relacionales.

### UC-FO05: Enviar a revisión (submit)
- **Actor**: UnitAdmin, Leader
- **Permiso**: `flight_orders.create`
- **Transición**: draft → submitted
- **Reglas**: Scope por unidad. Registra `submitted_at`.

### UC-FO06: Aprobar orden
- **Actor**: UnitCommand, Leader, GeneralAdmin
- **Permiso**: `flight_orders.review`
- **Transición**: submitted → approved | observed → approved
- **Reglas**: Scope por unidad. Registra `approved_at` y `approved_by`.

### UC-FO07: Observar orden
- **Actor**: UnitCommand, Leader, GeneralAdmin
- **Permiso**: `flight_orders.review`
- **Transición**: submitted → observed
- **Reglas**: La orden vuelve a editable al pasar por observed → submit → approved. Scope por unidad.

### UC-FO08: Cerrar orden
- **Actor**: UnitCommand, Leader
- **Permiso**: `flight_orders.review`
- **Transición**: approved → closed
- **Reglas**: Registra `closed_at` y `closed_by`. Ítems no finalizados requieren observación.

### UC-FO09: Reabrir orden
- **Actor**: UnitCommand, Leader
- **Permiso**: `flight_orders.review`
- **Transición**: closed → reopened

### UC-FO10: Avanzar estado de vuelo
- **Actor**: Usuarios con `flight_orders.read`
- **Permiso**: `flight_orders.read`
- **Input**: `item_id`, `next_status`
- **Reglas**: Secuencia estricta (no saltar estados). Registra timestamp en `flight_order_state_events`. Scope por unidad.

### UC-FO11: Cancelar vuelo
- **Actor**: UnitCommand, Leader, GeneralAdmin
- **Permiso**: Rol global o `flight_orders.close`
- **Input**: `item_id`, `cancel_reason` obligatorio
- **Reglas**: No se puede cancelar un vuelo ya cancelado. Solo disponible cuando el item está en `waiting` o `taxi`. El botón de cancelar no se muestra cuando la orden padre está en estado `closed`. El estado cambia a `cancelled`.

### UC-FO12: Gestionar perfiles de orden
- **Actor**: UnitAdmin, Leader
- **Permiso**: `flight_orders.create`
- **Acciones**: `add_profile` (crea perfil auto-numerado), `remove_profile` (elimina perfil)
- **Reglas**: Solo en órdenes `draft`. Scope por unidad.

### UC-FO13: Borrar orden
- **Actor**: UnitCommand, Leader, GeneralAdmin
- **Permiso**: Rol global o `flight_orders.close`
- **Reglas**: Solo órdenes en `draft`. Scope por unidad. Eliminación física (no soft-delete).

### UC-FO14: Exportar PDF
- **Actor**: Usuarios con `reports.export`
- **Permiso**: `reports.export`
- **Formato**: A4 landscape, tabla de 14 columnas, estados/tiempos, sección de firmas.
- **Reglas**: Generado en frontend con package `pdf`. Descarga vía `dart:html` en web.

## 6. Permisos

| Permiso | Descripción | Roles asignados |
|---|---|---|
| `flight_orders.read` | Ver órdenes de vuelo | Leader, GeneralAdmin, UnitCommand, UnitAdmin |
| `flight_orders.create` | Crear y modificar órdenes en draft | Leader, UnitAdmin |
| `flight_orders.review` | Revisar, aprobar, observar, cerrar, reabrir | Leader, GeneralAdmin, UnitCommand |
| `flight_orders.close` | Cerrar, cancelar vuelos, borrar órdenes | Leader, UnitCommand |

TTAA no tiene ningún permiso de flight_orders.

## 7. Scope por unidad

Validado en tres capas:

1. **RLS (PostgreSQL)**: `flight_orders_read_by_scope` y políticas hijas — `same_unit(unit_id)` para roles no-globales.
2. **Edge Function**: Cada acción verifica `actorProfile.unit_id === order.unit_id` (excepto roles globales).
3. **Frontend**: `listFlightOrders()` confía en RLS para filtrar. Formulario de creación muestra dropdown de unidades; Edge Function rechaza si el usuario intenta crear para otra unidad.

## 8. Reglas de negocio

- Una orden por unidad y fecha (`UNIQUE unit_id, operation_date`).
- Solo órdenes `draft` aceptan agregar/eliminar items y perfiles.
- Secuencia de estados de vuelo estricta: no se puede saltar de waiting a landing sin pasar por taxi y takeoff.
- Cancelación de vuelo requiere `cancel_reason` no vacío. Solo disponible en estados `waiting` y `taxi`.
- Botón de cancelar es un icono sutil (`cancel_outlined`) en el header de la card, sin texto. No se muestra cuando la orden padre está `closed`.
- Vuelo cancelado no puede avanzar estado.
- Número de orden: `ACRONYM-XXX` usando `acronym` de la unidad (fallback a `code`). Secuencia auto-incremental por unidad.
- Tripulación: PC obligatorio, CP opcional, MA opcional (checkbox "¿Mecánico a bordo?").
- Function codes de tripulación: PS, IP, PM, CP, CO, PI, PR (opcionales).
- Combustible: tipo (Jet A1, 100LL, JP-8, JP-5, MOGAS) + cantidad en lbs con conversión desde galones.
- PDF solo disponible si `reports.export`. Tabla de 14 columnas en A4 landscape.
- Borrado solo en draft, solo roles globales o `flight_orders.close`.
- Perfiles auto-numerados por orden (`profile_number` secuencial).
- No hay edición de items existentes (v1.0) — para modificar un vuelo, cancelarlo y crear uno nuevo.

## 9. Auditoría

Toda acción del Edge Function registra entrada en `audit_logs`:

| Acción | `resource_type` | `result` |
|---|---|---|
| `create` | `flight_order` | success / failed |
| `add_item` | `flight_order_item` | success |
| `submit` / `approve` / `observe` / `close` / `reopen` | `flight_order` | success / failed |
| `advance_state` | `flight_order_item` | success (implícito) |
| `cancel_item` | `flight_order_item` | success / failed |
| `add_profile` / `remove_profile` | `flight_order_profile` | success |
| `delete` | `flight_order` | success / failed |

Las denegaciones de autorización también se auditan con `result: denied`.

## 10. Errores específicos

| Código | Categoría | Escenario |
|---|---|---|
| `BUSINESS_DUPLICATE_ORDER` | BUSINESS_RULE | Ya existe orden para esa unidad y fecha |
| `BUSINESS_ORDER_NOT_DRAFT` | BUSINESS_RULE | Operación solo permitida en draft |
| `BUSINESS_INVALID_TRANSITION` | BUSINESS_RULE | Transición de estado de orden inválida |
| `BUSINESS_INVALID_STATE_SEQUENCE` | BUSINESS_RULE | Secuencia de estado de vuelo inválida |
| `BUSINESS_ALREADY_CANCELLED` | BUSINESS_RULE | El vuelo ya está cancelado |
| `BUSINESS_CANCELLED` | BUSINESS_RULE | No se puede avanzar un vuelo cancelado |
| `AUTH_UNIT_MISMATCH` | AUTHORIZATION | Usuario intenta operar en unidad ajena |
| `AUTH_PERMISSION_DENIED` | AUTHORIZATION | Sin permiso para la acción |
| `DATA_NOT_FOUND` | DATA | Orden, item o perfil no encontrado |
| `VALIDATION_REQUIRED` | VALIDATION | Campo obligatorio ausente |
| `VALIDATION_INVALID_INPUT` | VALIDATION | Datos de entrada inválidos |

## 11. Estructura de archivos

```
/lib/features/flight_orders/
  domain/
    flight_order.dart                    # Modelos (6 entidades)
  data/
    flight_orders_repository.dart        # Repositorio + implementación Supabase
  application/
    flight_order_pdf_service.dart        # Generación PDF
    flight_order_pdf_downloader.dart     # Descarga web (conditional export)
  presentation/
    flight_orders_page.dart              # Página principal (tabla + panel)
    flight_order_detail_panel.dart       # Panel de detalle de orden
    flight_order_form_dialog.dart        # Diálogo crear orden
    flight_item_form_dialog.dart         # Diálogo agregar/editar item (8 secciones)
    flight_item_detail_dialog.dart       # Diálogo detalle de vuelo (stepper, timeline, avance, cancelación)
```

## 12. UI/UX — Especificación de componentes

### 12.1 FlightOrdersPage

**Layout responsivo**:
- ≥ 1100px: Row con DataTable (flex 3, altura fija 550px con scroll) + VerticalDivider + Panel detalle (flex 2).
- < 1100px: Column con DataTable (altura 300px) + Divider + Panel detalle.

**Estados**:
- `loading`: DataStateView con spinner.
- `empty`: Icono + mensaje "No hay órdenes de vuelo" + botón crear (si `canCreate`).
- `error`: DataStateView con mensaje de error + botón retry.
- `success`: DataTable con filas seleccionables.

**DataTable**: Columnas: Número de Orden, Unidad, Fecha Operación, Estado (chip de color), Acciones (iconos). Ordenado por `operation_date DESC`.

**Chips de estado**:
- draft: gris
- submitted: azul
- observed: naranja
- approved: verde
- closed: rojo
- reopened: púrpura

**Acciones por estado**:
- draft: Submit (si canCreate), Delete (si canDelete), PDF (si canExport)
- submitted/observed: Approve + Observe (si canReview), PDF
- approved: Close (si canReview), PDF
- closed: Reopen (si canReview), PDF

**Provider**: `_ordersListProvider` (FutureProvider local). Se invalida al crear, cambiar estado o borrar.

### 12.2 FlightOrderDetailPanel

**Encabezado**: Número de orden, unidad, fecha de operación, estado (chip). Incluye `OrderStepper` con soporte para sub-estado `observed` (círculo draft con badge de advertencia cuando `hasObservations` es true).

**Sección de items**: Lista de Cards (`_FlightItemCard`), una por item. Cada card muestra:
- **Header row**: Icono de aeronave + matrícula y modelo (`registration — model`), StatusChip de estado, icono `open_in_new`, botón de cancelar (icono sutil `cancel_outlined`, solo si status es `waiting`/`taxi` y orden padre no está `closed`)
- **Misión** (si no está vacía)
- **Info chips**: ETE, nivel de vuelo, combustible
- **Rutas**: segmentos con icono `alt_route`, unidos por `|`
- **Tripulación**: roleCode: nombre [functionCode], uno por línea

**Nota**: El mini stepper y el botón de avance de estado fueron removidos de las cards. Esas funcionalidades residen en `FlightItemDetailDialog`.

**Sección de perfiles** (solo en draft):
- Lista de perfiles de la orden
- Botón agregar: diálogo con campo `description`
- Botón eliminar por perfil

**Acciones de orden**:
- Botón "+" para agregar item (solo draft, si canCreate) → abre FlightItemFormDialog

### 12.2.1 FlightItemDetailDialog

Diálogo modal (`AlertDialog`) que muestra el detalle completo de un item de vuelo:

- **Título**: Matrícula + modelo de aeronave, StatusChip, botón editar (si `canEdit`)
- **Misión**: Texto completo
- **Datos de vuelo**: ETE, nivel de vuelo, combustible, salida programada (Wrap de info chips)
- **Tripulación**: Lista vertical con roleCode, nombre, function code
- **Rutas**: Lista con íconos de dirección (↪ outbound, ↩ return) y display label
- **Perfiles**: Chips con número y descripción
- **Mini Stepper**: 5 pasos (waiting, taxi, takeoff, landing, engine_off) con dots de colores. Estados completados o con evento registrado muestran check. Estado actual muestra círculo relleno.
- **Timeline de eventos**: Lista de StatusChip + hora de cada evento registrado
- **Tiempos calculados**: Total (taxi → engine_off) y Aire (takeoff → landing) en chips de color
- **Acciones**: Botón avanzar estado (siguiente en secuencia, con icono) + Botón cancelar (solo si `flight_orders.close` o rol global, abre diálogo de motivo)

### 12.3 FlightOrderFormDialog

Diálogo modal (AlertDialog) con:
- Dropdown de unidades (todas las activas, ordenadas por nombre)
- Date picker para fecha de operación (rango: -30 días a +90 días)
- Validación: unidad requerida
- Submit → `manageFlightOrder(action: 'create')`

### 12.4 FlightItemFormDialog

Diálogo extenso con 8 secciones:

1. **Aeronave**: Dropdown filtrado por unidad de la orden. Muestra `registration` de aeronaves operativas.
2. **Misión**: Autocomplete con histórico de misiones previas de la unidad.
3. **Salida programada**: Time picker.
4. **Nivel de vuelo + ETE**: Min/Max (text fields) + ETE en minutos con control +/- 5 min.
5. **Combustible**: Dropdown de tipo (Jet A1, 100LL, JP-8, JP-5, MOGAS) + entrada en lbs con conversión bidireccional a galones.
6. **Rutas**: Multi-segmento. Cada segmento: tipo (outbound/return), origen (airport/zone/waypoint con búsqueda), destino (mismo formato). Botón agregar/quitar segmento.
7. **Perfiles**: FilterChip multi-select de los perfiles definidos en la orden.
8. **Tripulación**: Dropdown PC (obligatorio), dropdown CP (opcional), checkbox "¿Mecánico a bordo?" → dropdown MA (condicional). Function code opcional por tripulante.

Validaciones:
- Aeronave requerida.
- Al menos una ruta.
- PC requerido.
- ETE > 0.

### 12.5 FlightOrderPdfService

Genera PDF A4 landscape con package `pdf`:
- Encabezado: número de orden, unidad, fecha
- Tabla de 14 columnas: N°, Aeronave, Misión, PC, CP, MA, Origen, Destino, Nivel, ETE, Combustible, Salida, Estado, Perfiles
- Sección de tiempos por item: total y aire
- Sección de firmas: Comando de Unidad, Administrador de Unidad
- Descarga en web vía `dart:html` (`AnchorElement` con `Blob`).

## 13. Tests requeridos

### Unitarios
- [ ] `FlightOrder.fromJson()` y `toJson()` con todas las entidades
- [ ] `FlightOrderItem.copyWith()` preserva campos no modificados
- [ ] `FlightOrderPdfService.buildFlightOrderPdf()` genera PDF válido (existe test básico)
- [ ] Cálculo de tiempos: total = engine_off − taxi, aire = landing − takeoff

### Integración (repository)
- [ ] `listFlightOrders()` retorna solo órdenes de la unidad del usuario (verificar RLS)
- [x] `listItems()` carga relaciones anidadas (routes, crew, profiles, state_events) — vía batch loading + `inFilter`
- [ ] `manageFlightOrder(action: 'create')` crea orden con número auto-generado
- [ ] `manageFlightOrder(action: 'create')` rechaza duplicado unidad+fecha

### Edge Function
- [ ] JWT ausente → 401
- [ ] Sin permiso → 403
- [ ] Transición inválida → 400 con `BUSINESS_INVALID_TRANSITION`
- [ ] Secuencia de estados de vuelo inválida → 400 con `BUSINESS_INVALID_STATE_SEQUENCE`
- [ ] Cancelación sin motivo → 400 con `VALIDATION_REQUIRED`
- [ ] Unidad cruzada → 403 con `AUTH_UNIT_MISMATCH`
- [ ] Éxito → `ok: true` + audit_log

### Widget/UI
- [ ] `FlightOrdersPage` muestra loading, empty, error, success
- [ ] `FlightOrderDetailPanel` muestra items con todos sus datos
- [ ] `FlightOrderFormDialog` valida campos requeridos
- [ ] `FlightItemFormDialog` muestra/oculta MA según checkbox
- [ ] Responsive: layout horizontal ≥ 1100px, vertical < 1100px

## 14. ADRs relacionadas

- ADR-001: Arquitectura modular por dominios
- ADR-003: Supabase como backend
- ADR-004: PostgreSQL y RLS
- ADR-005: Reports Module centralizado

## 15. Changelog

| Fecha | Cambio |
|---|---|
| 2026-05-27 | Spec inicial redactada post-implementación v1.0 |
| 2026-05-29 | Rediseño de cards: removido mini stepper, cancelar como icono sutil en header, oculto en orden cerrada. Agregado `aircraftModel` al modelo. `listItems` reescrito con 5 consultas batch + `inFilter`. Creado `FlightItemDetailDialog`. `OrderStepper` soporta sub-estado `observed`. |
| 2026-05-30 | **Separación de responsabilidades**: removido mini stepper y botón de avance de estado del `FlightItemDetailDialog` (pasan a sección Vuelos). Cancelar vuelo permanece como exclusivo de Flight Orders. **Filtros**: reemplazados `FilterChip`s por dropdowns `PopupMenuButton` (Unidad, Fecha, Estado) con chips activos. **Carga**: dots pulsantes + fade en detalle de items (3s). **Colorización**: extraídos colores a `status_colors.dart`, unificados `StatusChip` y `OrderStepper`. Cards con barra de acento izquierda por estado. **Navegación global**: `AppShell` con overlay de dots pulsantes + fade entre secciones. **UI Modernization**: tema premium con toggle claro/oscuro, TextTheme completo, 12 widget themes, DataTable global, cards unificadas 10px. **Menú**: reducido a 11 items, calendario en AppBar, configuración en perfil. |
| 2026-06-22 | **Estandarización a UTC**: `scheduled_departure` guardado local→UTC y mostrado UTC→local con offset de `timezoneProvider`; PDF con offset inyectado por el provider. **Diálogo de item a 3 pasos** (Vuelo · Combustible y Ruta · Tripulación) con selector de tripulación completo (function codes + checkbox mecánico + i18n). Migración `fix_scheduled_departure_utc` corrige datos históricos. |
| 2026-06-23 | Tests de dominio (`test/features/flight_orders/domain/flight_order_test.dart`) y de PDF (`flight_order_pdf_service_test.dart`) implementados. `listItems` con batch loading confirmado: relaciones (routes, crew, state_events) cargan correctamente. |
