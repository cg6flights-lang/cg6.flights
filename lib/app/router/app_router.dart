import 'package:cg6_flights/core/security/app_permission.dart';
import 'package:cg6_flights/features/aircraft/presentation/aircraft_page.dart';
import 'package:cg6_flights/features/audit/presentation/audit_page.dart';
import 'package:cg6_flights/features/auth/application/session_controller.dart';
import 'package:cg6_flights/features/auth/presentation/forgot_password_page.dart';
import 'package:cg6_flights/features/auth/presentation/login_page.dart';
import 'package:cg6_flights/features/auth/presentation/pending_access_page.dart';
import 'package:cg6_flights/features/auth/presentation/permission_denied_page.dart';
import 'package:cg6_flights/features/auth/presentation/register_page.dart';
import 'package:cg6_flights/features/calendar/presentation/calendar_page.dart';
import 'package:cg6_flights/features/closures/presentation/closures_page.dart';
import 'package:cg6_flights/features/crew/presentation/crew_page.dart';
import 'package:cg6_flights/features/dashboard/presentation/dashboard_page.dart';
import 'package:cg6_flights/features/flight_orders/presentation/flight_orders_page.dart';
import 'package:cg6_flights/features/flight_status/presentation/flight_status_page.dart';
import 'package:cg6_flights/features/flights/presentation/flights_page.dart';
import 'package:cg6_flights/features/history/presentation/history_page.dart';
import 'package:cg6_flights/features/maps/presentation/maps_page.dart';
import 'package:cg6_flights/features/messages/presentation/messages_page.dart';
import 'package:cg6_flights/features/notifications/presentation/notifications_page.dart';
import 'package:cg6_flights/features/profile/presentation/profile_page.dart';
import 'package:cg6_flights/features/reports/presentation/reports_page.dart';
import 'package:cg6_flights/features/routes/presentation/routes_page.dart';
import 'package:cg6_flights/features/settings/presentation/settings_page.dart';
import 'package:cg6_flights/features/units/presentation/units_page.dart';
import 'package:cg6_flights/features/users/presentation/users_page.dart';
import 'package:cg6_flights/shared/widgets/app_shell.dart';
import 'package:cg6_flights/shared/widgets/data_state_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: '/login',
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterPage(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordPage(),
      ),
      GoRoute(
        path: '/pending-access',
        builder: (context, state) => const PendingAccessPage(),
      ),
      GoRoute(
        path: '/permission-denied',
        builder: (context, state) => const PermissionDeniedPage(),
      ),
      ShellRoute(
        builder: (context, state, child) =>
            AppShell(items: _navigationItems, child: child),
        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (context, state) => const DashboardPage(),
          ),
          GoRoute(
            path: '/users',
            builder: (context, state) => const UsersPage(),
          ),
          GoRoute(
            path: '/units',
            builder: (context, state) => const UnitsPage(),
          ),
          GoRoute(
            path: '/aircraft',
            builder: (context, state) => const AircraftPage(),
          ),
          GoRoute(path: '/crew', builder: (context, state) => const CrewPage()),
          GoRoute(
            path: '/flight-orders',
            builder: (context, state) => const FlightOrdersPage(),
          ),
          GoRoute(
            path: '/flights',
            builder: (context, state) => const FlightsPage(),
          ),
          GoRoute(
            path: '/flight-status',
            builder: (context, state) => const FlightStatusPage(),
          ),
          GoRoute(
            path: '/routes',
            builder: (context, state) => const RoutesPage(),
          ),
          GoRoute(
            path: '/closures',
            builder: (context, state) => const ClosuresPage(),
          ),
          GoRoute(
            path: '/history',
            builder: (context, state) => const HistoryPage(),
          ),
          GoRoute(
            path: '/audit',
            builder: (context, state) => const AuditPage(),
          ),
          GoRoute(
            path: '/notifications',
            builder: (context, state) => const NotificationsPage(),
          ),
          GoRoute(
            path: '/messages',
            builder: (context, state) => const MessagesPage(),
          ),
          GoRoute(
            path: '/reports',
            builder: (context, state) => const ReportsPage(),
          ),
          GoRoute(
            path: '/calendar',
            builder: (context, state) => const CalendarPage(),
          ),
          GoRoute(path: '/maps', builder: (context, state) => const MapsPage()),
          GoRoute(
            path: '/profile',
            builder: (context, state) => const ProfilePage(),
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsPage(),
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => const Scaffold(
      body: DataStateView(
        kind: DataStateKind.empty,
        title: 'Ruta no encontrada',
      ),
    ),
    redirect: (context, state) {
      final session = ref.read(sessionControllerProvider);
      final location = state.uri.path;
      final publicRoute = _publicRoutes.contains(location);
      final specialRoute =
          location == '/pending-access' || location == '/permission-denied';

      if (location == '/roles' || location == '/permissions') {
        return '/users';
      }

      if (location == '/notifications' || location == '/profile') {
        return '/dashboard';
      }

      if (session.isLoading) return null;

      if (!session.isAuthenticated && !publicRoute) {
        return '/login';
      }

      if (session.isAuthenticated && publicRoute) {
        return session.canOperate ? '/dashboard' : '/pending-access';
      }

      if (session.isAuthenticated && !session.canOperate && !specialRoute) {
        return '/pending-access';
      }

      final requiredPermission = _routePermissions[location];
      if (requiredPermission != null && !session.can(requiredPermission)) {
        return '/permission-denied';
      }

      return null;
    },
  );

  ref.listen(sessionControllerProvider, (_, _) => router.refresh());
  ref.onDispose(router.dispose);
  return router;
});

const _publicRoutes = {'/login', '/register', '/forgot-password'};

const _routePermissions = <String, String>{
  '/users': AppPermission.usersRead,
  '/units': AppPermission.unitsRead,
  '/aircraft': AppPermission.aircraftRead,
  '/crew': AppPermission.crewRead,
  '/flight-orders': AppPermission.flightOrdersRead,
  '/flights': AppPermission.flightsRead,
  '/flight-status': AppPermission.flightStatusCreate,
  '/routes': AppPermission.routesRead,
  '/closures': AppPermission.closuresRequest,
  '/history': AppPermission.historyRead,
  '/audit': AppPermission.auditRead,
  '/messages': AppPermission.messagesRead,
  '/reports': AppPermission.reportsRead,
  '/calendar': AppPermission.calendarRead,
  '/maps': AppPermission.mapsRead,
  '/settings': AppPermission.settingsManage,
};

const _navigationItems = [
  NavigationItem(
    path: '/dashboard',
    labelKey: 'nav.dashboard',
    icon: Icons.space_dashboard_outlined,
  ),
  NavigationItem(
    path: '/users',
    labelKey: 'nav.users',
    icon: Icons.people_alt_outlined,
    permission: AppPermission.usersRead,
  ),
  NavigationItem(
    path: '/units',
    labelKey: 'nav.units',
    icon: Icons.flag_outlined,
    permission: AppPermission.unitsRead,
  ),
  NavigationItem(
    path: '/aircraft',
    labelKey: 'nav.aircraft',
    icon: Icons.flight,
    permission: AppPermission.aircraftRead,
  ),
  NavigationItem(
    path: '/crew',
    labelKey: 'nav.crew',
    icon: Icons.groups_2_outlined,
    permission: AppPermission.crewRead,
  ),
  NavigationItem(
    path: '/flight-orders',
    labelKey: 'nav.flightOrders',
    icon: Icons.assignment_outlined,
    permission: AppPermission.flightOrdersRead,
  ),
  NavigationItem(
    path: '/flights',
    labelKey: 'nav.flights',
    icon: Icons.flight_takeoff,
    permission: AppPermission.flightsRead,
  ),
  NavigationItem(
    path: '/flight-status',
    labelKey: 'nav.flightStatus',
    icon: Icons.timeline_outlined,
    permission: AppPermission.flightStatusCreate,
  ),
  NavigationItem(
    path: '/routes',
    labelKey: 'nav.routes',
    icon: Icons.route_outlined,
    permission: AppPermission.routesRead,
  ),
  NavigationItem(
    path: '/closures',
    labelKey: 'nav.closures',
    icon: Icons.task_alt,
    permission: AppPermission.closuresRequest,
  ),
  NavigationItem(
    path: '/history',
    labelKey: 'nav.history',
    icon: Icons.history,
    permission: AppPermission.historyRead,
  ),
  NavigationItem(
    path: '/audit',
    labelKey: 'nav.audit',
    icon: Icons.fact_check_outlined,
    permission: AppPermission.auditRead,
  ),
  NavigationItem(
    path: '/messages',
    labelKey: 'nav.messages',
    icon: Icons.mark_unread_chat_alt_outlined,
    permission: AppPermission.messagesRead,
  ),
  NavigationItem(
    path: '/reports',
    labelKey: 'nav.reports',
    icon: Icons.picture_as_pdf_outlined,
    permission: AppPermission.reportsRead,
  ),
  NavigationItem(
    path: '/calendar',
    labelKey: 'nav.calendar',
    icon: Icons.calendar_month_outlined,
    permission: AppPermission.calendarRead,
  ),
  NavigationItem(
    path: '/maps',
    labelKey: 'nav.maps',
    icon: Icons.map_outlined,
    permission: AppPermission.mapsRead,
  ),
  NavigationItem(
    path: '/settings',
    labelKey: 'nav.settings',
    icon: Icons.tune,
    permission: AppPermission.settingsManage,
  ),
];
