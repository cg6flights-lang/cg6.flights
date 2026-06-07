import 'package:flutter/material.dart';

enum PasswordStrength { empty, weak, fair, good, strong }

class PasswordStrengthBar extends StatelessWidget {
  const PasswordStrengthBar({super.key, required this.password});

  final String password;

  PasswordStrength get _strength {
    if (password.isEmpty) return PasswordStrength.empty;

    int score = 0;
    if (password.length >= 6) score++;
    if (RegExp(r'[A-Z]').hasMatch(password)) score++;
    if (RegExp(r'[a-z]').hasMatch(password)) score++;
    if (RegExp(r'[0-9]').hasMatch(password)) score++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(password)) score++;

    return switch (score) {
      0 || 1 => PasswordStrength.weak,
      2 => PasswordStrength.fair,
      3 || 4 => PasswordStrength.good,
      _ => PasswordStrength.strong,
    };
  }

  Color get _color => switch (_strength) {
        PasswordStrength.empty => Colors.grey.shade300,
        PasswordStrength.weak => const Color(0xFFE53935),
        PasswordStrength.fair => const Color(0xFFFF9800),
        PasswordStrength.good => const Color(0xFF8BC34A),
        PasswordStrength.strong => const Color(0xFF2E9D57),
      };

  String get _label => switch (_strength) {
        PasswordStrength.empty => '',
        PasswordStrength.weak => 'Débil',
        PasswordStrength.fair => 'Regular',
        PasswordStrength.good => 'Buena',
        PasswordStrength.strong => 'Segura',
      };

  double get _fill => switch (_strength) {
        PasswordStrength.empty => 0.0,
        PasswordStrength.weak => 0.25,
        PasswordStrength.fair => 0.5,
        PasswordStrength.good => 0.75,
        PasswordStrength.strong => 1.0,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: _fill,
            minHeight: 6,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation(_color),
          ),
        ),
        if (_strength != PasswordStrength.empty) ...[
          const SizedBox(height: 4),
          Text(
            _label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: _color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ],
    );
  }
}
