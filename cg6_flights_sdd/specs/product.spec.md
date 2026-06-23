# /specs/product.spec.md

# Product Specification — CG6 Flights

## 1. Visión

CG6 Flights será una plataforma web para el control diario de operaciones aéreas por unidad, con trazabilidad histórica, auditoría, paneles por rol, notificaciones, reportes y permisos granulares.

## 2. Alcance funcional completo

El sistema incluirá:

1. Autenticación.
2. Usuarios.
3. Roles.
4. Permisos granulares.
5. Unidades.
6. Aeronaves.
7. Tripulación.
8. Orden de Vuelo diaria.
9. Vuelos.
10. Estados de vuelo.
11. Rutas y escalas.
12. Cierres.
13. Históricos.
14. Reportes PDF.
15. Exportación Excel.
16. Auditoría.
17. Notificaciones.
18. Mensajería.
19. Calendario.
20. Mapas.
21. Geolocalización futura.
22. Perfil.
23. Internacionalización.
24. Responsive UI.
25. Diseño aeronáutico militar.
26. Escuadrones de vuelo.
27. Cadetes temporales (cursos, grados, turnos).
28. Papelera (soft-delete con restauración).
29. Realtime operacional.

## 3. Roles (6)

- Líder.
- Administrador General.
- Comando de Unidad.
- Administrador de Unidad.
- Jefe de Escuadrón.  ← añadido en v1.2 (GRU51).
- TTAA.

## 4. Workflows principales

- Registro y acceso.
- Asignación de rol y unidad.
- Gestión de unidades.
- Gestión de aeronaves.
- Gestión de tripulación.
- Carga de Orden de Vuelo diaria.
- Seguimiento de estados.
- Cálculo de tiempos.
- Cierre de ficha diaria.
- Consulta histórica.
- Exportación PDF.
- Exportación Excel.
- Auditoría.
- Notificaciones.
- Mensajería.
- Calendario.
- Mapas.
- Confirmación remota futura.
- Perfil.
- Cambio de idioma.

## 5. Reglas de negocio principales

- Un Líder máximo.
- Cinco Administradores Generales máximo.
- Usuario sin rol no opera.
- Usuario sin unidad no opera en roles de unidad.
- Los roles de unidad solo ven su unidad.
- TTAA solo ve información limitada del vuelo asignado.
- Toda acción crítica requiere permiso.
- Toda acción crítica se audita.
- No eliminación física ordinaria de registros operativos.
- Vuelos cerrados no se modifican salvo reapertura autorizada.
- PDF/Excel siempre deben pasar por Reports Module.
- Notificación vista no elimina auditoría.
- Geolocalización remota requiere política futura.

## 6. Requisitos funcionales consolidados

### Autenticación y usuarios

- RF-001: El sistema debe permitir registro con correo.
- RF-002: El sistema debe permitir login.
- RF-003: El sistema debe permitir logout.
- RF-004: El sistema debe bloquear usuarios sin rol operativo.
- RF-005: El sistema debe bloquear usuarios inactivos.
- RF-006: El sistema debe permitir administrar usuarios según permisos.

### Roles y permisos

- RF-010: El sistema debe soportar roles oficiales.
- RF-011: El sistema debe impedir más de un Líder.
- RF-012: El sistema debe impedir más de cinco Administradores Generales.
- RF-013: El sistema debe soportar permisos por acción.
- RF-014: El sistema debe permitir activar/desactivar permisos.
- RF-015: El sistema debe auditar cambios de permisos.
- RF-016: El sistema debe soportar el rol Jefe de Escuadrón con scope acotado a su escuadrón (`squadronId`).

### Escuadrones (implementado v1.2)

- RF-017: El sistema debe gestionar escuadrones de vuelo dentro de una unidad (GRU51).
- RF-018: El sistema debe asociar aeronaves a escuadrones mediante relación M:N (`aircraft_squadrons`).
- RF-019: El sistema debe filtrar Tripulaciones y Aeronaves por escuadrón.

### Unidades

- RF-020: El sistema debe crear unidades.
- RF-021: El sistema debe editar unidades.
- RF-022: El sistema debe desactivar unidades.
- RF-023: El sistema debe asociar usuarios a unidad.
- RF-024: El sistema debe consultar datos por unidad según permisos.

### Aeronaves

- RF-030: El sistema debe registrar aeronaves.
- RF-031: El sistema debe marcar aeronaves operativas/inoperativas.
- RF-032: El sistema debe asociar aeronaves a unidad.
- RF-033: El sistema debe consultar histórico por aeronave.

Nota de implementación v1.0: RF-033 pertenece al módulo Históricos y debe resolverse allí mediante filtro por aeronave; el CRUD Aircraft solo expone la gestión maestra de aeronaves.

### Tripulación

- RF-040: El sistema debe registrar pilotos.
- RF-041: El sistema debe registrar copilotos si aplica.
- RF-042: El sistema debe registrar mecánicos o Ingenieros de Vuelo si aplica.
- RF-043: El sistema debe asociar tripulación a unidad.
- RF-044: El sistema debe filtrar histórico por tripulante.

### Cadetes temporales (implementado v1.2)

- RF-045: El sistema debe gestionar cadetes temporales con curso (`cadet_courses`) y grado.
- RF-046: El sistema debe asignar turnos de cadetes a vuelos (PRDI / turnos).
- RF-047: El sistema debe soportar foto de cadete/tripulante (`photo_path`, Storage).

### Orden de Vuelo

- RF-050: El sistema debe crear Orden de Vuelo diaria por unidad y fecha con número auto-generado (`ACRONYM-XXX`) y estado inicial `draft`.
- RF-051: El sistema debe agregar vuelos (items) a una orden draft, especificando: aeronave, misión, nivel de vuelo (min/max), ETE en minutos, tipo y cantidad de combustible (lbs con conversión galones), salida programada, rutas multi-segmento (origen/destino con tipo airport/zone/waypoint), perfiles asignados, y tripulación (PC obligatorio, CP opcional, MA opcional con function codes PS/IP/PM/CP/CO/PI/PR).
- RF-052: El sistema debe validar secuencia estricta de estados de vuelo por item: waiting → taxi → takeoff → landing → engine_off, registrando timestamp en cada transición vía `flight_order_state_events`.
- RF-053: El sistema debe permitir revisar órdenes con transiciones validadas: submit (draft→submitted), approve (submitted/observed→approved), observe (submitted→observed), close (approved→closed), reopen (closed→reopened).
- RF-054: El sistema debe cerrar y reabrir órdenes con permisos específicos (`flight_orders.review`).
- RF-055: El sistema debe cancelar vuelos individuales con motivo obligatorio (`cancel_reason`), restringido a roles globales o `flight_orders.close`.
- RF-056: El sistema debe gestionar perfiles de vuelo por orden (agregar/eliminar) con numeración auto-incremental (`profile_number`), solo en estado draft.
- RF-057: El sistema debe generar PDF A4 landscape de la Orden de Vuelo con tabla de 14 columnas (N°, Aeronave, Misión, PC, CP, MA, Origen, Destino, Nivel, ETE, Combustible, Salida, Estado, Perfiles), tiempos calculados por item (total y aire), y sección de firmas.
- RF-058: El sistema debe permitir borrar órdenes solo en estado draft y solo a roles globales o `flight_orders.close`.
- RF-059: El sistema debe aislar órdenes por unidad mediante RLS, Edge Function y guards frontend — usuarios de unidad solo ven y operan su propia unidad.

### Vuelos y estados

- RF-060: El sistema debe crear vuelos.
- RF-061: El sistema debe asociar aeronave.
- RF-062: El sistema debe asociar tripulación.
- RF-063: El sistema debe asociar ruta.
- RF-064: El sistema debe registrar Arranque de Motor.
- RF-065: El sistema debe registrar Inicio de Taxeo.
- RF-066: El sistema debe registrar Despegue.
- RF-067: El sistema debe registrar Aterrizaje.
- RF-068: El sistema debe registrar Apagado de motor.
- RF-069: El sistema debe validar secuencia.
- RF-070: El sistema debe calcular tiempos.

### Cierres

- RF-080: El sistema debe solicitar cierre.
- RF-081: El sistema debe aprobar cierre.
- RF-082: El sistema debe rechazar cierre.
- RF-083: El sistema debe observar cierre.
- RF-084: El sistema debe reabrir con permiso especial.

### Históricos y reportes

- RF-090: El sistema debe consultar histórico diario.
- RF-091: El sistema debe consultar histórico semanal.
- RF-092: El sistema debe consultar histórico mensual.
- RF-093: El sistema debe consultar histórico anual.
- RF-094: El sistema debe filtrar por unidad, aeronave, piloto, mecánico y ruta.
- RF-095: El sistema debe exportar Excel.
- RF-096: El sistema debe generar PDF histórico.

### Auditoría y comunicaciones

- RF-100: El sistema debe auditar acciones críticas.
- RF-101: El sistema debe mostrar auditoría global a roles autorizados.
- RF-102: El sistema debe generar notificaciones.
- RF-103: El sistema debe permitir mensajería interna.
- RF-104: El sistema debe soportar disposiciones generales y por unidad.
- RF-105: El sistema debe permitir que Líder y Administrador General programen actividades globales en calendario para visualización de todos los usuarios activos.
- RF-106: El sistema debe mostrar actividades próximas con fecha, hora, ubicación, tipo y estado.
- RF-107: El sistema debe mostrar un preview rápido de calendario desde el header con alertas próximas y acceso `Ampliar` a la sección completa.
- RF-108: El sistema debe visualizar actividades del mes en formato Gantt y permitir control diario de estado: iniciar, reprogramar y confirmar realización.

### Papelera y realtime (implementado v1.1–v1.3)

- RF-114: El sistema debe aplicar borrado lógico (soft-delete) con Papelera y restauración desde Auditoría, en lugar de borrado físico ordinario.
- RF-115: El sistema debe reflejar cambios operacionales en tiempo real (Crew, Dashboard, Notifications) sin polling, mediante invalidación de providers por canal Supabase.

### UI y plataforma

- RF-110: El sistema debe ser responsive.
- RF-111: El sistema debe ser bilingüe Español/Inglés. **(Implementado: i18n completo ES/EN, ~38 archivos, toggle en login y header.)**
- RF-112: El sistema debe tener diseño aeronáutico militar.
- RF-113: El sistema debe permitir foto de perfil máximo 5 MB.

> **Estado de implementación (2026-06-23)**: implementados los RF de autenticación, usuarios, roles (6), escuadrones, unidades, aeronaves, tripulación, cadetes, órdenes de vuelo (RF-050–059), vuelos/estados, auditoría, notificaciones, mensajería, calendario, papelera, realtime, i18n y perfil. **Pendientes**: exportación Excel (RF-095) y los módulos transversales History/Reports (RF-090–096) como sección autónoma.

## 7. Requisitos no funcionales

- Seguridad alta.
- Auditoría exhaustiva.
- Trazabilidad histórica 5 años.
- Rendimiento con paginación y filtros.
- Escalabilidad progresiva.
- Accesibilidad.
- Compatibilidad web multiplataforma.
- Mantenibilidad modular.
- Observabilidad futura.
- Calidad gobernada por pruebas.
- Uso de herramientas gratuitas iniciales cuando sea viable.

## 8. Riesgos

- RLS mal diseñado.
- Permisos demasiado complejos.
- Exportaciones confidenciales.
- Realtime inseguro.
- IA generando código fuera de specs.
- Dependencia de planes gratuitos.
- Geolocalización sin política.
