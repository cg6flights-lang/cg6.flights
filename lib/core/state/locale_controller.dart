import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final localeControllerProvider = NotifierProvider<LocaleController, Locale>(
  LocaleController.new,
);

class LocaleController extends Notifier<Locale> {
  @override
  Locale build() => const Locale('es');

  void toggle() {
    state = state.languageCode == 'es'
        ? const Locale('en')
        : const Locale('es');
  }
}
