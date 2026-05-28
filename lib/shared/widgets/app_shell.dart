import 'package:cg6_flights/app/i18n/app_localizations.dart';
import 'package:cg6_flights/core/state/locale_controller.dart';
import 'package:cg6_flights/features/auth/application/session_controller.dart';
import 'package:cg6_flights/features/auth/domain/app_user.dart';
import 'package:cg6_flights/shared/widgets/app_badges.dart';
import 'package:cg6_flights/shared/widgets/profile_modal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class NavigationItem {
  const NavigationItem({
    required this.path,
    required this.labelKey,
    required this.icon,
    this.permission,
  });

  final String path;
  final String labelKey;
  final IconData icon;
  final String? permission;
}

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.child, required this.items});

  final Widget child;
  final List<NavigationItem> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider);
    final user = session.user;
    final location = GoRouterState.of(context).uri.path;
    final visibleItems = items
        .where(
          (item) => item.permission == null || session.can(item.permission!),
        )
        .toList();
    final selectedIndex = visibleItems.indexWhere(
      (item) => location == item.path || location.startsWith('${item.path}/'),
    );
    final safeIndex = selectedIndex < 0 ? 0 : selectedIndex;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 860;
        return Scaffold(
          appBar: AppBar(
            titleSpacing: 12,
            title: const Text('CG6 Flights'),
            actions: [
              _NotificationBell(),
              Tooltip(
                message: ref.watch(localeControllerProvider).languageCode == 'es'
                    ? 'Switch to English'
                    : 'Cambiar a Espanol',
                child: IconButton(
                  onPressed: () =>
                      ref.read(localeControllerProvider.notifier).toggle(),
                  icon: Text(
                    ref.watch(localeControllerProvider).languageCode == 'es'
                        ? 'EN'
                        : 'ES',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              ),
              if (user != null) _UserAvatarMenu(user: user),
              const SizedBox(width: 8),
            ],
          ),
          drawer: compact
              ? _ShellDrawer(
                  items: visibleItems,
                  selectedIndex: safeIndex,
                  onSelected: (path) {
                    Navigator.of(context).pop();
                    context.go(path);
                  },
                )
              : null,
          body: Row(
            children: [
              if (!compact)
                SizedBox(
                  width: 104,
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        const SizedBox(height: 8),
                        for (var i = 0; i < visibleItems.length; i++)
                          Tooltip(
                            message: AppLocalizations.of(context)
                                .t(visibleItems[i].labelKey),
                            child: _NavRailTile(
                              icon: visibleItems[i].icon,
                              selected: i == safeIndex,
                              onTap: () => context.go(visibleItems[i].path),
                            ),
                          ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
              Expanded(child: child),
            ],
          ),
        );
      },
    );
  }
}

class _NotificationBell extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      offset: const Offset(0, 48),
      tooltip: 'Notificaciones',
      icon: const Icon(Icons.notifications_outlined),
      onSelected: (value) {
        if (value == 'all') context.go('/notifications');
      },
      itemBuilder: (context) => [
        const PopupMenuItem<String>(
          enabled: false,
          child: Text(
            'Notificaciones',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          enabled: false,
          child: SizedBox(
            width: 280,
            child: Column(
              children: [
                Icon(Icons.notifications_off_outlined, size: 36),
                SizedBox(height: 8),
                Text('Sin notificaciones nuevas'),
              ],
            ),
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'all',
          child: Row(
            children: [
              Icon(Icons.history, size: 18),
              SizedBox(width: 8),
              Text('Ver todas'),
            ],
          ),
        ),
      ],
    );
  }
}

class _UserAvatarMenu extends ConsumerWidget {
  const _UserAvatarMenu({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final initial = user.displayName.isNotEmpty
        ? user.displayName[0].toUpperCase()
        : '?';

    return PopupMenuButton<String>(
      offset: const Offset(0, 48),
      tooltip: user.displayName,
      onSelected: (value) {
        switch (value) {
          case 'profile':
            showProfileModal(context, user);
          case 'logout':
            ref.read(sessionControllerProvider.notifier).signOut();
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          enabled: false,
          child: _UserInfoHeader(user: user),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'profile',
          child: Row(
            children: [
              Icon(Icons.edit_outlined, size: 20),
              SizedBox(width: 8),
              Text('Editar perfil'),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'logout',
          child: Row(
            children: [
              Icon(Icons.logout, size: 20, color: Theme.of(context).colorScheme.error),
              SizedBox(width: 8),
              Text('Cerrar sesion', style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
          ),
        ),
      ],
      child: CircleAvatar(
        radius: 16,
        child: Text(initial, style: const TextStyle(fontSize: 14)),
      ),
    );
  }
}

class _UserInfoHeader extends StatelessWidget {
  const _UserInfoHeader({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 280,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                child: Text(
                  user.displayName.isNotEmpty
                      ? user.displayName[0].toUpperCase()
                      : '?',
                  style: const TextStyle(fontSize: 14),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  user.displayName,
                  style: Theme.of(context).textTheme.titleSmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            user.email,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              RoleBadge(role: user.role),
              if (user.unitName != null) UnitBadge(unitName: user.unitName),
            ],
          ),
        ],
      ),
    );
  }
}

class _NavRailTile extends StatelessWidget {
  const _NavRailTile({
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
        color: selected
            ? Theme.of(context).colorScheme.primaryContainer
            : Colors.transparent,
        child: InkWell(
          borderRadius: const BorderRadius.all(Radius.circular(16)),
          onTap: onTap,
          child: SizedBox(
            width: 72,
            height: 52,
            child: Icon(icon, color: color, size: 24),
          ),
        ),
      ),
    );
  }
}

class _ShellDrawer extends StatelessWidget {
  const _ShellDrawer({
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<NavigationItem> items;
  final int selectedIndex;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return NavigationDrawer(
      selectedIndex: selectedIndex,
      onDestinationSelected: (index) => onSelected(items[index].path),
      children: [
        const SizedBox(height: 16),
        for (final item in items)
          NavigationDrawerDestination(
            icon: Icon(item.icon),
            label: Text(AppLocalizations.of(context).t(item.labelKey)),
          ),
      ],
    );
  }
}
