import 'package:cg6_flights/features/auth/domain/app_user.dart';
import 'package:flutter/material.dart';

class WelcomeSplash extends StatefulWidget {
  const WelcomeSplash({
    super.key,
    required this.user,
    required this.onDone,
  });

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
                  width: 500,
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

        return Opacity(
          opacity: logoAlpha,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'cg6_logo/favicon_cg6.png',
                height: 120,
                width: 200,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 16),
              Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(
                      text: 'CG6',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        fontStyle: FontStyle.italic,
                        color: Color(0xFF005AD2),
                        shadows: [
                          Shadow(color: Color(0x660846B4), offset: Offset(1.2, 1.2), blurRadius: 0.8),
                          Shadow(color: Color(0x380846B4), offset: Offset(0.5, 0.5), blurRadius: 2.0),
                        ],
                      ),
                    ),
                    const TextSpan(
                      text: ' Flights',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                        fontStyle: FontStyle.italic,
                        color: Color(0xFF596F97),
                      ),
                    ),
                    const TextSpan(
                      text: ' v1.2',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        fontStyle: FontStyle.italic,
                        color: Color(0xFF4E6082),
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

  Widget _greetingPhase(String? grade, String fullName) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final alpha = _greetingFadeIn.value;
        if (alpha <= 0.01) return const SizedBox.shrink();

        return Opacity(
          opacity: alpha,
          child: Transform.translate(
            offset: Offset(0, _greetingSlideUp.value),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // "Bienvenido/a"
                Text(
                  'Bienvenido/a',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w300,
                    color: const Color(0xFF8A9BB5),
                    letterSpacing: 4,
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
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                        fontStyle: FontStyle.italic,
                        color: Color(0xFF005AD2),
                        letterSpacing: 3,
                        shadows: [
                          Shadow(color: Color(0x550052C8), offset: Offset(1, 1), blurRadius: 2),
                          Shadow(color: Color(0x300052C8), offset: Offset(0, 2), blurRadius: 8),
                        ],
                      ),
                    ),
                  ),
                // Full name — artistic with gradient-like deep blue
                Text(
                  fullName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    fontStyle: FontStyle.italic,
                    color: Color(0xFF061028),
                    letterSpacing: 3.5,
                    shadows: [
                      Shadow(color: Color(0x25000000), offset: Offset(0, 2), blurRadius: 4),
                      Shadow(color: Color(0x400052C8), offset: Offset(1, 1), blurRadius: 1),
                    ],
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
