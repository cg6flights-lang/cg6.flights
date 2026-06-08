import 'package:cg6_flights/core/security/app_role.dart';

class AppPermission {
  const AppPermission._();

  static const usersRead = 'users.read';
  static const usersManage = 'users.manage';
  static const usersAssignAccess = 'users.assign_access';
  static const rolesRead = 'roles.read';
  static const permissionsRead = 'permissions.read';
  static const permissionsManage = 'permissions.manage';
  static const unitsRead = 'units.read';
  static const unitsManage = 'units.manage';
  static const aircraftRead = 'aircraft.read';
  static const aircraftManage = 'aircraft.manage';
  static const crewRead = 'crew.read';
  static const crewManage = 'crew.manage';
  static const routesRead = 'routes.read';
  static const routesManage = 'routes.manage';
  static const flightOrdersRead = 'flight_orders.read';
  static const flightOrdersCreate = 'flight_orders.create';
  static const flightOrdersReview = 'flight_orders.review';
  static const flightOrdersClose = 'flight_orders.close';
  static const flightsRead = 'flights.read';
  static const flightsCreate = 'flights.create';
  static const flightsUpdate = 'flights.update';
  static const flightStatusCreate = 'flight_status.create';
  static const closuresRequest = 'closures.request';
  static const closuresReview = 'closures.review';
  static const closuresReopen = 'closures.reopen';
  static const historyRead = 'history.read';
  static const auditRead = 'audit.read';
  static const notificationsRead = 'notifications.read';
  static const notificationsManage = 'notifications.manage';
  static const messagesRead = 'messages.read';
  static const messagesSend = 'messages.send';
  static const messagePostsRead = 'message_posts.read';
  static const messagePostsCreate = 'message_posts.create';
  static const messagePostsComment = 'message_posts.comment';
  static const reportsRead = 'reports.read';
  static const reportsExport = 'reports.export';
  static const calendarRead = 'calendar.read';
  static const calendarManage = 'calendar.manage';
  static const mapsRead = 'maps.read';
  static const profileUpdate = 'profile.update';
  static const settingsManage = 'settings.manage';
  static const trashRead = 'trash.read';

  static const all = <String>{
    usersRead,
    usersManage,
    usersAssignAccess,
    rolesRead,
    permissionsRead,
    permissionsManage,
    unitsRead,
    unitsManage,
    aircraftRead,
    aircraftManage,
    crewRead,
    crewManage,
    routesRead,
    routesManage,
    flightOrdersRead,
    flightOrdersCreate,
    flightOrdersReview,
    flightOrdersClose,
    flightsRead,
    flightsCreate,
    flightsUpdate,
    flightStatusCreate,
    closuresRequest,
    closuresReview,
    closuresReopen,
    historyRead,
    auditRead,
    notificationsRead,
    notificationsManage,
    messagesRead,
    messagesSend,
    messagePostsRead,
    messagePostsCreate,
    messagePostsComment,
    reportsRead,
    reportsExport,
    calendarRead,
    calendarManage,
    mapsRead,
    profileUpdate,
    settingsManage,
    trashRead,
  };
}

const rolePermissionMatrix = <AppRole, Set<String>>{
  AppRole.leader: AppPermission.all,
  AppRole.generalAdmin: {
    AppPermission.usersRead,
    AppPermission.rolesRead,
    AppPermission.permissionsRead,
    AppPermission.unitsRead,
    AppPermission.aircraftRead,
    AppPermission.crewRead,
    AppPermission.routesRead,
    AppPermission.routesManage,
    AppPermission.flightOrdersRead,
    AppPermission.flightOrdersReview,
    AppPermission.flightsRead,
    AppPermission.closuresReview,
    AppPermission.historyRead,
    AppPermission.auditRead,
    AppPermission.notificationsRead,
    AppPermission.messagesRead,
    AppPermission.messagesSend,
    AppPermission.messagePostsRead,
    AppPermission.messagePostsCreate,
    AppPermission.messagePostsComment,
    AppPermission.reportsRead,
    AppPermission.reportsExport,
    AppPermission.calendarRead,
    AppPermission.calendarManage,
    AppPermission.mapsRead,
    AppPermission.profileUpdate,
    AppPermission.trashRead,
  },
  AppRole.unitCommand: {
    AppPermission.usersRead,
    AppPermission.unitsRead,
    AppPermission.aircraftRead,
    AppPermission.crewRead,
    AppPermission.routesRead,
    AppPermission.flightOrdersRead,
    AppPermission.flightOrdersReview,
    AppPermission.flightOrdersClose,
    AppPermission.flightsRead,
    AppPermission.closuresReview,
    AppPermission.auditRead,
    AppPermission.historyRead,
    AppPermission.notificationsRead,
    AppPermission.messagesRead,
    AppPermission.messagesSend,
    AppPermission.messagePostsRead,
    AppPermission.messagePostsCreate,
    AppPermission.messagePostsComment,
    AppPermission.reportsRead,
    AppPermission.calendarRead,
    AppPermission.mapsRead,
    AppPermission.profileUpdate,
  },
  AppRole.unitAdmin: {
    AppPermission.unitsRead,
    AppPermission.aircraftRead,
    AppPermission.aircraftManage,
    AppPermission.crewRead,
    AppPermission.crewManage,
    AppPermission.flightOrdersRead,
    AppPermission.flightOrdersCreate,
    AppPermission.flightsRead,
    AppPermission.flightsCreate,
    AppPermission.flightsUpdate,
    AppPermission.flightStatusCreate,
    AppPermission.closuresRequest,
    AppPermission.historyRead,
    AppPermission.notificationsRead,
    AppPermission.messagesRead,
    AppPermission.messagesSend,
    AppPermission.messagePostsRead,
    AppPermission.messagePostsCreate,
    AppPermission.messagePostsComment,
    AppPermission.reportsRead,
    AppPermission.calendarRead,
    AppPermission.mapsRead,
    AppPermission.profileUpdate,
  },
  AppRole.ttaa: {
    AppPermission.flightsRead,
    AppPermission.flightStatusCreate,
    AppPermission.notificationsRead,
    AppPermission.messagesRead,
    AppPermission.messagePostsRead,
    AppPermission.messagePostsComment,
    AppPermission.calendarRead,
    AppPermission.mapsRead,
    AppPermission.profileUpdate,
  },
};
