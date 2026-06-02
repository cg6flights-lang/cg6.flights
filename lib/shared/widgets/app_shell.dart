import 'package:cg6_flights/app/i18n/app_localizations.dart';
import 'package:cg6_flights/core/state/locale_controller.dart';
import 'package:cg6_flights/core/state/theme_mode_controller.dart';
import 'package:cg6_flights/features/auth/application/session_controller.dart';
import 'package:cg6_flights/features/auth/domain/app_user.dart';
import 'package:cg6_flights/shared/widgets/app_badges.dart';
import 'package:cg6_flights/shared/widgets/profile_modal.dart';
import 'package:flutter/gestures.dart';
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

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.child, required this.items});

  final Widget child;
  final List<NavigationItem> items;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  bool _overlayVisible = false;
  double _overlayOpacity = 1.0;

  @override
  void didUpdateWidget(covariant AppShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.child != oldWidget.child) {
      _startNavigationTransition();
    }
  }

  void _startNavigationTransition() {
    if (_overlayVisible) return;
    setState(() {
      _overlayVisible = true;
      _overlayOpacity = 1.0;
    });
    Future<void>.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() => _overlayOpacity = 0.0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionControllerProvider);
    final user = session.user;
    final langCode = ref.watch(localeControllerProvider).languageCode;
    final themeMode = ref.watch(themeModeProvider);
    final localeNotifier = ref.read(localeControllerProvider.notifier);
    final location = GoRouterState.of(context).uri.path;
    final visibleItems = widget.items
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
            title: _HeaderBrand(compact: compact),
            actions: [
              _CalendarIcon(),
              const SizedBox(width: 4),
              _NotificationBell(),
              Tooltip(
                message: themeMode == ThemeMode.dark
                    ? 'Modo claro'
                    : 'Modo oscuro',
                child: IconButton(
                  onPressed: () =>
                      ref.read(themeModeProvider.notifier).toggle(),
                  icon: Icon(
                    themeMode == ThemeMode.dark
                        ? Icons.light_mode_outlined
                        : Icons.dark_mode_outlined,
                  ),
                ),
              ),
              Tooltip(
                message: langCode == 'es'
                    ? 'Switch to English'
                    : 'Cambiar a Espanol',
                child: IconButton(
                  onPressed: () => localeNotifier.toggle(),
                  icon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.language, size: 18),
                      const SizedBox(width: 4),
                      Text(
                        langCode == 'es' ? 'EN' : 'ES',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
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
                            message: AppLocalizations.of(
                              context,
                            ).t(visibleItems[i].labelKey),
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
              Expanded(
                child: Stack(
                  children: [
                    // Page always mounted — loads data in background
                    widget.child,
                    // Dots overlay — covers page during 3s then fades out
                    if (_overlayVisible)
                      Positioned.fill(
                        child: AnimatedOpacity(
                          opacity: _overlayOpacity,
                          duration: const Duration(milliseconds: 350),
                          onEnd: () {
                            if (_overlayOpacity == 0.0 && mounted) {
                              setState(() => _overlayVisible = false);
                            }
                          },
                          child: const _AppLoadingOverlay(),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Loading overlay for section navigation ──────────────────────────

class _AppLoadingOverlay extends StatefulWidget {
  const _AppLoadingOverlay();

  @override
  State<_AppLoadingOverlay> createState() => _AppLoadingOverlayState();
}

class _AppLoadingOverlayState extends State<_AppLoadingOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _dotsController;

  @override
  void initState() {
    super.initState();
    _dotsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _dotsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (int i = 0; i < 3; i++)
                  _OverlayDot(controller: _dotsController, index: i),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              'Cargando...',
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OverlayDot extends StatelessWidget {
  const _OverlayDot({required this.controller, required this.index});
  final AnimationController controller;
  final int index;

  @override
  Widget build(BuildContext context) {
    const size = 10.0;
    final delay = index * 0.25;
    final alpha = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(
        parent: controller,
        curve: Interval(delay, delay + 0.4, curve: Curves.easeInOut),
      ),
    );
    final scale = Tween<double>(begin: 0.7, end: 1.1).animate(
      CurvedAnimation(
        parent: controller,
        curve: Interval(delay, delay + 0.4, curve: Curves.easeInOut),
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, child) => Transform.scale(
          scale: scale.value,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: alpha.value),
            ),
          ),
        ),
      ),
    );
  }
}

class _CalendarIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final day = now.day.toString();
    return Tooltip(
      message: 'Calendario',
      child: IconButton(
        onPressed: () => context.go('/calendar'),
        icon: Badge(
          smallSize: 14,
          largeSize: 18,
          padding: const EdgeInsets.all(1),
          label: Text(
            day,
            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700),
          ),
          child: const Icon(Icons.calendar_month_outlined),
        ),
      ),
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
          case 'settings':
            context.go('/settings');
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
        const PopupMenuItem<String>(
          value: 'settings',
          child: Row(
            children: [
              Icon(Icons.tune, size: 20),
              SizedBox(width: 8),
              Text('Configuración'),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'logout',
          child: Row(
            children: [
              Icon(
                Icons.logout,
                size: 20,
                color: Theme.of(context).colorScheme.error,
              ),
              SizedBox(width: 8),
              Text(
                'Cerrar sesion',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
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

class _NavRailTile extends StatefulWidget {
  const _NavRailTile({
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_NavRailTile> createState() => _NavRailTileState();
}

class _NavRailTileState extends State<_NavRailTile> {
  bool _hovered = false;
  int _exitToken = 0;

  void _handleEnter(PointerEnterEvent event) {
    _exitToken++;
    if (!_hovered) setState(() => _hovered = true);
  }

  void _handleExit(PointerExitEvent event) {
    final token = ++_exitToken;
    Future<void>.delayed(const Duration(milliseconds: 80), () {
      if (!mounted || token != _exitToken) return;
      if (_hovered) setState(() => _hovered = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.selected
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: MouseRegion(
        onEnter: _handleEnter,
        onExit: _handleExit,
        child: AnimatedScale(
          scale: _hovered ? 1.35 : 1,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutCubic,
          child: GestureDetector(
            onTap: widget.onTap,
            child: SizedBox(
              width: 72,
              height: 52,
              child: Icon(widget.icon, color: color, size: 24),
            ),
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

class _HeaderBrand extends StatelessWidget {
  const _HeaderBrand({required this.compact});
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'cg6_logo/favicon_cg6.png',
          height: compact ? 28 : 34,
          width: compact ? 48 : 58,
          fit: BoxFit.contain,
          semanticLabel: 'CG6 Flights',
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text.rich(
            TextSpan(
              children: [
                const TextSpan(
                  text: 'CG6',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    fontStyle: FontStyle.italic,
                    color: Color(0xFF005AD2),
                    shadows: [
                      Shadow(
                        color: Color(0x660846B4),
                        offset: Offset(1.2, 1.2),
                        blurRadius: 0.8,
                      ),
                      Shadow(
                        color: Color(0x380846B4),
                        offset: Offset(0.5, 0.5),
                        blurRadius: 2.0,
                      ),
                    ],
                  ),
                ),
                if (!compact)
                  const TextSpan(
                    text: ' Flights',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      fontStyle: FontStyle.italic,
                      color: Color(0xFF596F97),
                    ),
                  ),
                const TextSpan(
                  text: ' v1.0',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    fontStyle: FontStyle.italic,
                    color: Color(0xFF4E6082),
                  ),
                ),
              ],
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
      ],
    );
  }
}
