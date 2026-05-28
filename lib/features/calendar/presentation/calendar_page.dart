import 'package:cg6_flights/shared/widgets/module_page.dart';
import 'package:flutter/material.dart';

class CalendarPage extends StatelessWidget {
  const CalendarPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const ModulePage(
      title: 'Calendario',
      icon: Icons.calendar_month_outlined,
      summary: 'Vista temporal de operaciones autorizadas y eventos de unidad.',
      actions: ['Ver dia', 'Ver semana', 'Ver mes'],
    );
  }
}
