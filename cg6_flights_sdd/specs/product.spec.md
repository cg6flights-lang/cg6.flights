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

## 3. Roles

- Líder.
- Administrador General.
- Comando de Unidad.
- Administrador de Unidad.
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

### UI y plataforma

- RF-110: El sistema debe ser responsive.
- RF-111: El sistema debe ser bilingüe Español/Inglés.
- RF-112: El sistema debe tener diseño aeronáutico militar.
- RF-113: El sistema debe permitir foto de perfil máximo 5 MB.

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
