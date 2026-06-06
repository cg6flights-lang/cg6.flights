import 'package:cg6_flights/core/security/app_permission.dart';
import 'package:cg6_flights/core/security/app_role.dart';

class PermissionSection {
  final String title;
  final String description;
  final List<_PermDef> permissions;

  const PermissionSection({required this.title, required this.description, required this.permissions});

  int activeCount(Set<String> granted) => permissions.where((p) => granted.contains(p.key)).length;
  int get total => permissions.length;
}

class _PermDef {
  final String key;
  final String title;
  final String description;

  const _PermDef({required this.key, required this.title, required this.description});
}

final permissionSections = <PermissionSection>[
  PermissionSection(title: 'Usuarios y Roles', description: 'Gestión de usuarios, roles y permisos del sistema', permissions: [
    _PermDef(key: AppPermission.usersRead, title: 'Ver lista de usuarios', description: 'Visualiza la lista completa de usuarios con sus roles, estados y unidades asignadas.'),
    _PermDef(key: AppPermission.usersManage, title: 'Crear y gestionar usuarios', description: 'Permite registrar nuevos usuarios en el sistema, editar sus perfiles y administrar sus accesos.'),
    _PermDef(key: AppPermission.usersAssignAccess, title: 'Asignar roles y permisos', description: 'Otorga o revoca roles, unidades y autorizaciones a cualquier usuario del sistema.'),
    _PermDef(key: AppPermission.rolesRead, title: 'Ver roles del sistema', description: 'Consulta los roles disponibles y sus permisos asociados.'),
    _PermDef(key: AppPermission.permissionsRead, title: 'Ver permisos del sistema', description: 'Consulta la lista de permisos y autorizaciones disponibles en el sistema.'),
    _PermDef(key: AppPermission.permissionsManage, title: 'Gestionar permisos', description: 'Modifica la matriz de permisos y autorizaciones del sistema.'),
  ]),
  PermissionSection(title: 'Unidades', description: 'Visualización y administración de unidades operativas', permissions: [
    _PermDef(key: AppPermission.unitsRead, title: 'Ver unidades', description: 'Visualiza la lista de unidades operativas con sus códigos, nombres y estados.'),
    _PermDef(key: AppPermission.unitsManage, title: 'Gestionar unidades', description: 'Crea, edita y desactiva unidades operativas en el sistema.'),
  ]),
  PermissionSection(title: 'Aeronaves', description: 'Consulta y gestión del inventario de aeronaves', permissions: [
    _PermDef(key: AppPermission.aircraftRead, title: 'Ver aeronaves', description: 'Consulta el inventario de aeronaves, sus estados operativos y características técnicas.'),
    _PermDef(key: AppPermission.aircraftManage, title: 'Gestionar aeronaves', description: 'Registra nuevas aeronaves, edita sus datos y gestiona bajas del inventario.'),
  ]),
  PermissionSection(title: 'Tripulación', description: 'Visualización y administración de tripulantes', permissions: [
    _PermDef(key: AppPermission.crewRead, title: 'Ver tripulación', description: 'Consulta la lista de tripulantes, sus grados, calificaciones y tipos de asignación.'),
    _PermDef(key: AppPermission.crewManage, title: 'Gestionar tripulación', description: 'Registra nuevos tripulantes, edita sus datos y gestiona bajas.'),
  ]),
  PermissionSection(title: 'Rutas', description: 'Consulta y gestión de rutas y aeropuertos', permissions: [
    _PermDef(key: AppPermission.routesRead, title: 'Ver rutas', description: 'Visualiza aeropuertos, aeródromos y helipuertos registrados con sus coordenadas.'),
    _PermDef(key: AppPermission.routesManage, title: 'Gestionar rutas', description: 'Registra, edita y desactiva rutas y puntos geográficos.'),
  ]),
  PermissionSection(title: 'Órdenes de Vuelo', description: 'Lectura, creación, revisión y cierre de OVs', permissions: [
    _PermDef(key: AppPermission.flightOrdersRead, title: 'Ver órdenes de vuelo', description: 'Accede a la lista de OVs con sus estados, vuelos programados y tripulación asignada.'),
    _PermDef(key: AppPermission.flightOrdersCreate, title: 'Crear y editar OVs', description: 'Crea nuevas órdenes de vuelo y edita las existentes en estado borrador. Agrega vuelos, rutas y perfiles.'),
    _PermDef(key: AppPermission.flightOrdersReview, title: 'Revisar OVs', description: 'Aprueba u observa órdenes de vuelo enviadas a revisión. Puede aprobar o rechazar.'),
    _PermDef(key: AppPermission.flightOrdersClose, title: 'Cerrar OVs', description: 'Cierra órdenes de vuelo aprobadas y las reabre si es necesario. Solo el Líder puede borrar OVs en cualquier estado.'),
  ]),
  PermissionSection(title: 'Vuelos', description: 'Visualización y gestión de vuelos activos', permissions: [
    _PermDef(key: AppPermission.flightsRead, title: 'Ver vuelos', description: 'Accede al tablero de vuelos con estados en tiempo real, panel LED y detalle de cada vuelo.'),
    _PermDef(key: AppPermission.flightsCreate, title: 'Crear vuelos', description: 'Crea nuevos vuelos dentro de una orden de vuelo existente.'),
    _PermDef(key: AppPermission.flightsUpdate, title: 'Actualizar vuelos', description: 'Modifica datos de vuelos programados antes de su ejecución.'),
  ]),
  PermissionSection(title: 'Estados de Vuelo', description: 'Control de estados de vuelos en ejecución', permissions: [
    _PermDef(key: AppPermission.flightStatusCreate, title: 'Avanzar estados de vuelo', description: 'Controla el avance de estados: En Espera → Taxeo → Despegue → Aterrizaje → Motor Apagado.'),
  ]),
  PermissionSection(title: 'Cierres de Jornada', description: 'Solicitar, revisar y reabrir cierres de jornada diaria', permissions: [
    _PermDef(key: AppPermission.closuresRequest, title: 'Solicitar cierre', description: 'Solicita el cierre de la jornada diaria de vuelos para la unidad.'),
    _PermDef(key: AppPermission.closuresReview, title: 'Revisar cierres', description: 'Aprueba u observa las solicitudes de cierre de jornada.'),
    _PermDef(key: AppPermission.closuresReopen, title: 'Reabrir cierres', description: 'Reabre una jornada ya cerrada si se requiere modificar datos. Solo para Líder.'),
  ]),
  PermissionSection(title: 'Históricos', description: 'Acceso a registros y datos históricos', permissions: [
    _PermDef(key: AppPermission.historyRead, title: 'Ver históricos', description: 'Accede a registros históricos de vuelos, órdenes y operaciones pasadas.'),
  ]),
  PermissionSection(title: 'Auditoría', description: 'Visualización de registros de auditoría del sistema', permissions: [
    _PermDef(key: AppPermission.auditRead, title: 'Ver auditoría', description: 'Accede al registro de auditoría con todas las acciones realizadas en el sistema, filtros por recurso y análisis de rendimiento.'),
  ]),
  PermissionSection(title: 'Notificaciones', description: 'Recepción y gestión de notificaciones del sistema', permissions: [
    _PermDef(key: AppPermission.notificationsRead, title: 'Recibir notificaciones', description: 'Recibe alertas y notificaciones del sistema en tiempo real.'),
    _PermDef(key: AppPermission.notificationsManage, title: 'Gestionar notificaciones', description: 'Configura y administra el sistema de notificaciones. Solo para Líder.'),
  ]),
  PermissionSection(title: 'Mensajes', description: 'Sistema de mensajería interna y publicaciones operacionales', permissions: [
    _PermDef(key: AppPermission.messagesRead, title: 'Leer mensajes', description: 'Accede a la bandeja de mensajes y conversaciones.'),
    _PermDef(key: AppPermission.messagesSend, title: 'Enviar mensajes', description: 'Envía mensajes privados a otros usuarios del sistema.'),
    _PermDef(key: AppPermission.messagePostsRead, title: 'Ver publicaciones', description: 'Visualiza publicaciones y avisos operacionales de la unidad o globales.'),
    _PermDef(key: AppPermission.messagePostsCreate, title: 'Crear publicaciones', description: 'Publica avisos y actualizaciones operacionales visibles para la unidad o todo el sistema.'),
    _PermDef(key: AppPermission.messagePostsComment, title: 'Comentar publicaciones', description: 'Agrega comentarios en las publicaciones operacionales.'),
  ]),
  PermissionSection(title: 'Reportes', description: 'Visualización y exportación de reportes', permissions: [
    _PermDef(key: AppPermission.reportsRead, title: 'Ver reportes', description: 'Accede a reportes operacionales, estadísticas y resúmenes.'),
    _PermDef(key: AppPermission.reportsExport, title: 'Exportar reportes', description: 'Descarga reportes en formato PDF o Excel.'),
  ]),
  PermissionSection(title: 'Calendario', description: 'Consulta y gestión de eventos del calendario', permissions: [
    _PermDef(key: AppPermission.calendarRead, title: 'Ver calendario', description: 'Accede al calendario con eventos operacionales programados.'),
    _PermDef(key: AppPermission.calendarManage, title: 'Gestionar calendario', description: 'Crea, edita y elimina eventos del calendario operacional.'),
  ]),
  PermissionSection(title: 'Mapas', description: 'Acceso a visualización de mapas interactivos', permissions: [
    _PermDef(key: AppPermission.mapsRead, title: 'Ver mapas', description: 'Accede al mapa interactivo con rutas, aeropuertos y geolocalización.'),
  ]),
  PermissionSection(title: 'Perfil y Configuración', description: 'Gestión del perfil personal y configuración del sistema', permissions: [
    _PermDef(key: AppPermission.profileUpdate, title: 'Editar perfil propio', description: 'Modifica los datos de su propio perfil de usuario.'),
    _PermDef(key: AppPermission.settingsManage, title: 'Gestionar configuración', description: 'Administra la configuración global del sistema. Solo para Líder.'),
  ]),
];
