import 'package:cg6_flights/app/i18n/app_localizations.dart';
import 'package:cg6_flights/app/router/app_router.dart';
import 'package:cg6_flights/app/theme/app_theme.dart';
import 'package:cg6_flights/core/state/locale_controller.dart';
import 'package:cg6_flights/core/state/theme_mode_controller.dart';
import 'package:cg6_flights/features/auth/application/session_controller.dart';
import 'package:cg6_flights/shared/widgets/welcome_splash.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CG6App extends ConsumerWidget {
  const CG6App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final locale = ref.watch(localeControllerProvider);
    final themeMode = ref.watch(themeModeProvider);
    final session = ref.watch(sessionControllerProvider);

    final showSplash = session.isAuthenticated &&
        session.user != null &&
        session.justLoggedIn;

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'CG6 Flights',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      themeAnimationDuration: const Duration(milliseconds: 80),
      themeAnimationCurve: Curves.easeInOut,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      routerConfig: router,
      builder: (context, child) {
        if (showSplash && child != null) {
          return WelcomeSplash(
            user: session.user!,
            onDone: () =>
                ref.read(sessionControllerProvider.notifier).dismissWelcome(),
          );
        }
        return child ?? const SizedBox.shrink();
      },
    );
  }
}
