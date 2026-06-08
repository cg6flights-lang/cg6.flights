import 'package:cg6_flights/app/i18n/app_localizations.dart';
import 'package:cg6_flights/features/auth/domain/app_user.dart';
import 'package:flutter/material.dart';

class WelcomeSplash extends StatefulWidget {
  const WelcomeSplash({super.key, required this.user, required this.onDone});

  final AppUser user;
  final VoidCallback onDone;

  @override
  State<WelcomeSplash> createState() => _WelcomeSplashState();
}

class _WelcomeSplashState extends State<WelcomeSplash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  // Phase 1: Logo fade in (0.00 → 0.25)
  late final Animation<double> _logoFadeIn;
  // Phase 2: Logo fade out (0.30 → 0.42)
  late final Animation<double> _logoFadeOut;
  // Phase 3: Greeting fade in (0.42 → 0.60)
  late final Animation<double> _greetingFadeIn;
  late final Animation<double> _greetingSlideUp;
  // Phase 4: Explosion (0.70 → 1.00)
  late final Animation<double> _explosionScale;
  late final Animation<double> _explosionFade;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3800),
    );

    _logoFadeIn = CurvedAnimation(
      parent: _c,
      curve: const Interval(0.00, 0.22, curve: Curves.easeOut),
    );
    _logoFadeOut = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _c,
        curve: const Interval(0.28, 0.42, curve: Curves.easeIn),
      ),
    );
    _greetingFadeIn = CurvedAnimation(
      parent: _c,
      curve: const Interval(0.42, 0.58, curve: Curves.easeOut),
    );
    _greetingSlideUp = Tween<double>(begin: 24.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _c,
        curve: const Interval(0.42, 0.62, curve: Curves.easeOutCubic),
      ),
    );
    _explosionScale = Tween<double>(begin: 1.0, end: 2.5).animate(
      CurvedAnimation(
        parent: _c,
        curve: const Interval(0.70, 1.00, curve: Curves.easeInCubic),
      ),
    );
    _explosionFade = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _c,
        curve: const Interval(0.76, 1.00, curve: Curves.easeIn),
      ),
    );

    _c.addStatusListener((s) {
      if (s == AnimationStatus.completed && mounted) widget.onDone();
    });

    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final grade = widget.user.grade;
    final fullName = widget.user.fullName;
    final splashWidth = (MediaQuery.sizeOf(context).width - 32)
        .clamp(280.0, 500.0)
        .toDouble();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Center(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            // Overall explosion transform
            return Opacity(
              opacity: _explosionFade.value,
              child: Transform.scale(
                scale: _explosionScale.value,
                child: SizedBox(
                  width: splashWidth,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // ── Phase 1+2: Logo ─────────────────────
                      _logoPhase(),
                      // ── Phase 3: Greeting ────────────────────
                      _greetingPhase(grade, fullName),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _logoPhase() {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final logoAlpha = _logoFadeIn.value * _logoFadeOut.value;
        if (logoAlpha <= 0.01) return const SizedBox.shrink();
        final compact = MediaQuery.sizeOf(context).width < 430;

        return Opacity(
          opacity: logoAlpha,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'cg6_logo/favicon_cg6.png',
                height: compact ? 92 : 120,
                width: compact ? 160 : 200,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 16),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: 'CG6',
                        style: TextStyle(
                          fontSize: compact ? 30 : 36,
                          fontWeight: FontWeight.w900,
                          fontStyle: FontStyle.italic,
                          color: const Color(0xFF005AD2),
                          shadows: const [
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
                      TextSpan(
                        text: ' Flights',
                        style: TextStyle(
                          fontSize: compact ? 30 : 36,
                          fontWeight: FontWeight.w800,
                          fontStyle: FontStyle.italic,
                          color: const Color(0xFF596F97),
                        ),
                      ),
                      TextSpan(
                        text: ' v1.2',
                        style: TextStyle(
                          fontSize: compact ? 18 : 22,
                          fontWeight: FontWeight.w700,
                          fontStyle: FontStyle.italic,
                          color: const Color(0xFF4E6082),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _greetingPhase(String? grade, String fullName) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final alpha = _greetingFadeIn.value;
        if (alpha <= 0.01) return const SizedBox.shrink();
        final screenWidth = MediaQuery.sizeOf(context).width;
        final compact = screenWidth < 430;
        final textWidth = (screenWidth - 40).clamp(260.0, 500.0).toDouble();

        return Opacity(
          opacity: alpha,
          child: Transform.translate(
            offset: Offset(0, _greetingSlideUp.value),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // "Bienvenido/a"
                Text(
                  AppLocalizations.of(context).t('welcome.greeting'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: compact ? 13 : 15,
                    fontWeight: FontWeight.w300,
                    color: const Color(0xFF8A9BB5),
                    letterSpacing: compact ? 2.4 : 4,
                  ),
                ),
                const SizedBox(height: 14),
                // Grade
                if (grade != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      grade,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: compact ? 16 : 19,
                        fontWeight: FontWeight.w900,
                        fontStyle: FontStyle.italic,
                        color: const Color(0xFF005AD2),
                        letterSpacing: compact ? 1.8 : 3,
                        shadows: const [
                          Shadow(
                            color: Color(0x550052C8),
                            offset: Offset(1, 1),
                            blurRadius: 2,
                          ),
                          Shadow(
                            color: Color(0x300052C8),
                            offset: Offset(0, 2),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                    ),
                  ),
                // Full name — artistic with gradient-like deep blue
                SizedBox(
                  width: textWidth,
                  child: Text(
                    fullName,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: compact ? 20 : 24,
                      fontWeight: FontWeight.w900,
                      fontStyle: FontStyle.italic,
                      color: const Color(0xFF061028),
                      letterSpacing: compact ? 1.6 : 3.5,
                      shadows: const [
                        Shadow(
                          color: Color(0x25000000),
                          offset: Offset(0, 2),
                          blurRadius: 4,
                        ),
                        Shadow(
                          color: Color(0x400052C8),
                          offset: Offset(1, 1),
                          blurRadius: 1,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
