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
import 'package:cg6_flights/features/crew/presentation/crew_page.dart';
import 'package:cg6_flights/features/dashboard/presentation/dashboard_page.dart';
import 'package:cg6_flights/features/flight_orders/presentation/flight_orders_page.dart';
import 'package:cg6_flights/features/flights/presentation/flights_page.dart';
import 'package:cg6_flights/features/messages/presentation/messages_page.dart';
import 'package:cg6_flights/features/notifications/presentation/notifications_page.dart';
import 'package:cg6_flights/features/profile/presentation/profile_page.dart';
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
            builder: (context, state) => FlightsPage(),
          ),
          GoRoute(
            path: '/routes',
            builder: (context, state) => const RoutesPage(),
          ),
          GoRoute(
            path: '/audit',
            builder: (context, state) => AuditPage(),
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
            path: '/calendar',
            builder: (context, state) => const CalendarPage(),
          ),
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

      if (location == '/profile') {
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
  '/routes': AppPermission.routesRead,
  '/closures': AppPermission.closuresRequest,
  '/audit': AppPermission.auditRead,
  '/messages': AppPermission.messagesRead,
  '/calendar': AppPermission.calendarRead,
  '/settings': AppPermission.settingsManage,
};

const _navigationItems = [
  NavigationItem(path: '/dashboard', labelKey: 'nav.dashboard', icon: Icons.space_dashboard_outlined),
  NavigationItem(path: '/flights', labelKey: 'nav.flights', icon: Icons.flight_takeoff, permission: AppPermission.flightsRead),
  NavigationItem(path: '/flight-orders', labelKey: 'nav.flightOrders', icon: Icons.assignment_outlined, permission: AppPermission.flightOrdersRead),
  NavigationItem(path: '/aircraft', labelKey: 'nav.aircraft', icon: Icons.flight, permission: AppPermission.aircraftRead),
  NavigationItem(path: '/crew', labelKey: 'nav.crew', icon: Icons.groups_2_outlined, permission: AppPermission.crewRead),
  NavigationItem(path: '/units', labelKey: 'nav.units', icon: Icons.flag_outlined, permission: AppPermission.unitsRead),
  NavigationItem(path: '/routes', labelKey: 'nav.routes', icon: Icons.route_outlined, permission: AppPermission.routesRead),
  NavigationItem(path: '/messages', labelKey: 'nav.messages', icon: Icons.mark_unread_chat_alt_outlined, permission: AppPermission.messagesRead),
  NavigationItem(path: '/users', labelKey: 'nav.users', icon: Icons.admin_panel_settings, permission: AppPermission.usersRead),
];
