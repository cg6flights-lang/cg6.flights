import 'package:cg6_flights/app/i18n/app_localizations.dart';
import 'package:cg6_flights/core/state/locale_controller.dart';
import 'package:cg6_flights/core/state/theme_mode_controller.dart';
import 'package:cg6_flights/features/auth/application/session_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController(text: 'lider@cg6.local');
  final _passwordController = TextEditingController(text: 'password-local');

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context).t;
    final session = ref.watch(sessionControllerProvider);

    return _AuthScaffold(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 280),
                child: Image.asset(
                  'cg6_logo/logo_cg6.png',
                  height: 132,
                  fit: BoxFit.contain,
                  semanticLabel: 'CG6 Flights',
                ),
              ),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: InputDecoration(
                labelText: t('auth.email'),
                prefixIcon: const Icon(Icons.mail_outline),
              ),
              validator: _required,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _passwordController,
              obscureText: true,
              autofillHints: const [AutofillHints.password],
              decoration: InputDecoration(
                labelText: t('auth.password'),
                prefixIcon: const Icon(Icons.lock_outline),
              ),
              validator: _required,
            ),
            if (session.error != null) ...[
              const SizedBox(height: 12),
              Text(
                session.error!.message,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: session.isLoading ? null : _submit,
              icon: const Icon(Icons.login),
              label: Text(t('auth.login')),
            ),
            const SizedBox(height: 10),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () => context.go('/register'),
                  child: Text(t('auth.register')),
                ),
                TextButton(
                  onPressed: () => context.go('/forgot-password'),
                  child: Text(t('auth.forgot')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) return 'Campo requerido';
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await ref
        .read(sessionControllerProvider.notifier)
        .signIn(_emailController.text.trim(), _passwordController.text);
  }
}

class _AuthScaffold extends ConsumerWidget {
  const _AuthScaffold({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final langCode = ref.watch(localeControllerProvider).languageCode;
    final theme = Theme.of(context);
    final nextLang = langCode == 'es' ? 'EN' : 'ES';

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Card(
                    child:
                        Padding(padding: const EdgeInsets.all(24), child: child),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Language toggle
                  Material(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(999),
                    child: InkWell(
                      onTap: () => ref.read(localeControllerProvider.notifier).toggle(),
                      borderRadius: BorderRadius.circular(999),
                      child: Container(
                        height: 36,
                        constraints: const BoxConstraints(minWidth: 58),
                        padding: const EdgeInsets.symmetric(horizontal: 9),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: theme.colorScheme.outlineVariant),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.language, size: 17, color: theme.colorScheme.primary),
                            const SizedBox(width: 5),
                            Text(nextLang, style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurface, fontWeight: FontWeight.w900, letterSpacing: 0)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Theme toggle
                  IconButton(
                    tooltip: themeMode == ThemeMode.dark ? 'Modo claro' : 'Modo oscuro',
                    onPressed: () => ref.read(themeModeProvider.notifier).toggle(),
                    icon: Icon(themeMode == ThemeMode.dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
