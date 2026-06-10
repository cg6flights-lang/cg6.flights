import 'package:cg6_flights/app/i18n/app_localizations.dart';
import 'package:cg6_flights/features/crew/domain/cadet_course.dart';
import 'package:cg6_flights/features/crew/domain/crew_member.dart';
import 'package:cg6_flights/features/crew/domain/grade_option.dart';
import 'package:flutter/material.dart';

class CadetFormResult {
  final String grade;
  final String firstName;
  final String lastName;
  final String nsa;
  final String cadetCourseId;
  final DateTime trainingStart;
  final DateTime trainingEnd;

  CadetFormResult({
    required this.grade,
    required this.firstName,
    required this.lastName,
    required this.nsa,
    required this.cadetCourseId,
    required this.trainingStart,
    required this.trainingEnd,
  });
}

Future<CadetFormResult?> showCadetFormDialog(
  BuildContext context, {
  required List<GradeOption> cadetGrades,
  required CadetCourse course,
  CrewMember? cadet,
}) {
  final gradeCtrl = TextEditingController(text: cadet?.grade ?? '');
  final firstNameCtrl = TextEditingController(text: cadet?.firstName ?? '');
  final lastNameCtrl = TextEditingController(text: cadet?.lastName ?? '');
  final nsaCtrl = TextEditingController(text: cadet?.nsa ?? '');
  DateTime trainingStart = cadet?.trainingStart ?? course.startDate;
  DateTime trainingEnd = cadet?.trainingEnd ?? course.endDate;

  return showDialog<CadetFormResult>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: Text(cadet != null ? 'Editar Cadete' : 'Nuevo Cadete'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: gradeCtrl.text.isNotEmpty ? gradeCtrl.text : null,
                decoration: const InputDecoration(labelText: 'Grado', border: OutlineInputBorder()),
                items: cadetGrades.map((g) => DropdownMenuItem(value: g.code, child: Text(g.code))).toList(),
                onChanged: (v) => gradeCtrl.text = v ?? '',
              ),
              const SizedBox(height: 12),
              TextFormField(controller: firstNameCtrl, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Nombres', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              TextFormField(controller: lastNameCtrl, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Apellidos', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              TextFormField(controller: nsaCtrl, decoration: const InputDecoration(labelText: 'NSA', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final d = await showDatePicker(context: ctx, initialDate: trainingStart, firstDate: DateTime(2020), lastDate: DateTime(2030));
                      if (d != null) setState(() => trainingStart = d);
                    },
                    child: InputDecorator(decoration: const InputDecoration(labelText: 'Inicio', border: OutlineInputBorder(), isDense: true), child: Text('${trainingStart.day}/${trainingStart.month}/${trainingStart.year}')),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final d = await showDatePicker(context: ctx, initialDate: trainingEnd, firstDate: DateTime(2020), lastDate: DateTime(2030));
                      if (d != null) setState(() => trainingEnd = d);
                    },
                    child: InputDecorator(decoration: const InputDecoration(labelText: 'Fin', border: OutlineInputBorder(), isDense: true), child: Text('${trainingEnd.day}/${trainingEnd.month}/${trainingEnd.year}')),
                  ),
                ),
              ]),
              const SizedBox(height: 8),
              Text('Curso: ${course.name}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              if (firstNameCtrl.text.trim().isEmpty || lastNameCtrl.text.trim().isEmpty || nsaCtrl.text.trim().isEmpty || gradeCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx, CadetFormResult(grade: gradeCtrl.text.trim(), firstName: firstNameCtrl.text.trim(), lastName: lastNameCtrl.text.trim(), nsa: nsaCtrl.text.trim(), cadetCourseId: course.id, trainingStart: trainingStart, trainingEnd: trainingEnd));
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    ),
  );
}
