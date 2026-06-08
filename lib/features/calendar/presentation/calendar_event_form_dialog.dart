import 'package:cg6_flights/app/i18n/app_localizations.dart';
import 'package:cg6_flights/core/results/app_result.dart';
import 'package:cg6_flights/features/calendar/data/calendar_repository.dart';
import 'package:cg6_flights/features/calendar/domain/calendar_event.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CalendarEventFormDialog extends ConsumerStatefulWidget {
  const CalendarEventFormDialog({super.key, this.event, this.initialDate});

  final CalendarEvent? event;
  final DateTime? initialDate;

  @override
  ConsumerState<CalendarEventFormDialog> createState() =>
      _CalendarEventFormDialogState();
}

class _CalendarEventFormDialogState
    extends ConsumerState<CalendarEventFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();

  late DateTime _startsAt;
  late DateTime _endsAt;
  CalendarEventType _eventType = CalendarEventType.operations;
  CalendarEventStatus _status = CalendarEventStatus.scheduled;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final event = widget.event;
    if (event != null) {
      _titleController.text = event.title;
      _descriptionController.text = event.description ?? '';
      _locationController.text = event.location ?? '';
      _startsAt = event.localStart;
      _endsAt = event.localEnd;
      _eventType = event.eventType;
      _status = event.status;
      return;
    }

    final base = widget.initialDate ?? DateTime.now();
    final roundedHour = DateTime(
      base.year,
      base.month,
      base.day,
      base.hour + 1,
    );
    _startsAt = roundedHour;
    _endsAt = roundedHour.add(const Duration(hours: 1));
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startsAt,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _startsAt = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _startsAt.hour,
        _startsAt.minute,
      );
      if (_endsAt.isBefore(_startsAt)) {
        _endsAt = _startsAt.add(const Duration(hours: 1));
      }
    });
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endsAt,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _endsAt = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _endsAt.hour,
        _endsAt.minute,
      );
    });
  }

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_startsAt),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _startsAt = DateTime(
        _startsAt.year,
        _startsAt.month,
        _startsAt.day,
        picked.hour,
        picked.minute,
      );
      if (_endsAt.isBefore(_startsAt)) {
        _endsAt = _startsAt.add(const Duration(hours: 1));
      }
    });
  }

  Future<void> _pickEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_endsAt),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _endsAt = DateTime(
        _endsAt.year,
        _endsAt.month,
        _endsAt.day,
        picked.hour,
        picked.minute,
      );
    });
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    if (!_formKey.currentState!.validate()) return;
    if (_endsAt.isBefore(_startsAt)) {
      setState(() => _error = l10n.t('calendar.invalidRange'));
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final result = await ref
        .read(calendarRepositoryProvider)
        .saveEvent(
          eventId: widget.event?.id,
          title: _titleController.text,
          description: _descriptionController.text,
          location: _locationController.text,
          eventType: _eventType,
          status: _status,
          startsAt: _startsAt,
          endsAt: _endsAt,
        );
    if (!mounted) return;
    setState(() => _saving = false);
    switch (result) {
      case AppSuccess<void>():
        Navigator.of(context).pop(true);
      case AppFailure<void>(error: final error):
        setState(() => _error = error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final viewport = MediaQuery.sizeOf(context);
    final dialogWidth = (viewport.width - 80).clamp(240.0, 560.0).toDouble();
    final dialogMaxHeight = (viewport.height * 0.76)
        .clamp(320.0, 720.0)
        .toDouble();
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      title: Text(
        widget.event == null
            ? l10n.t('calendar.newEvent')
            : l10n.t('calendar.editEvent'),
      ),
      content: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 560, maxHeight: dialogMaxHeight),
        child: SizedBox(
          width: dialogWidth,
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: _titleController,
                    enabled: !_saving,
                    decoration: InputDecoration(
                      labelText: l10n.t('calendar.titleField'),
                      prefixIcon: const Icon(Icons.event_note_outlined),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return l10n.t('validation.required');
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _descriptionController,
                    enabled: !_saving,
                    minLines: 2,
                    maxLines: 4,
                    decoration: InputDecoration(
                      labelText: l10n.t('calendar.descriptionField'),
                      prefixIcon: const Icon(Icons.notes_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _locationController,
                    enabled: !_saving,
                    decoration: InputDecoration(
                      labelText: l10n.t('calendar.locationField'),
                      prefixIcon: const Icon(Icons.place_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<CalendarEventType>(
                          initialValue: _eventType,
                          decoration: InputDecoration(
                            labelText: l10n.t('calendar.typeField'),
                          ),
                          items: [
                            for (final type in CalendarEventType.values)
                              DropdownMenuItem(
                                value: type,
                                child: Text(_eventTypeLabel(type, l10n)),
                              ),
                          ],
                          onChanged: _saving
                              ? null
                              : (value) {
                                  if (value != null) {
                                    setState(() => _eventType = value);
                                  }
                                },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<CalendarEventStatus>(
                          initialValue: _status,
                          decoration: InputDecoration(
                            labelText: l10n.t('calendar.statusField'),
                          ),
                          items: [
                            for (final status in CalendarEventStatus.values)
                              DropdownMenuItem(
                                value: status,
                                child: Text(_eventStatusLabel(status, l10n)),
                              ),
                          ],
                          onChanged: _saving
                              ? null
                              : (value) {
                                  if (value != null) {
                                    setState(() => _status = value);
                                  }
                                },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _DateTimePickerRow(
                    label: l10n.t('calendar.startsAt'),
                    value: _formatDateTime(_startsAt),
                    onPickDate: _saving ? null : _pickStartDate,
                    onPickTime: _saving ? null : _pickStartTime,
                  ),
                  const SizedBox(height: 10),
                  _DateTimePickerRow(
                    label: l10n.t('calendar.endsAt'),
                    value: _formatDateTime(_endsAt),
                    onPickDate: _saving ? null : _pickEndDate,
                    onPickTime: _saving ? null : _pickEndTime,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: Text(l10n.t('common.cancel')),
        ),
        FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: theme.colorScheme.onPrimary,
                  ),
                )
              : const Icon(Icons.save_outlined),
          label: Text(l10n.t('common.save')),
        ),
      ],
    );
  }
}

class _DateTimePickerRow extends StatelessWidget {
  const _DateTimePickerRow({
    required this.label,
    required this.value,
    required this.onPickDate,
    required this.onPickTime,
  });

  final String label;
  final String value;
  final VoidCallback? onPickDate;
  final VoidCallback? onPickTime;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(value, style: theme.textTheme.bodyMedium),
                ],
              ),
            ),
            IconButton(
              tooltip: label,
              onPressed: onPickDate,
              icon: const Icon(Icons.calendar_month_outlined),
            ),
            IconButton(
              tooltip: label,
              onPressed: onPickTime,
              icon: const Icon(Icons.schedule_outlined),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatDateTime(DateTime value) {
  final date =
      '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
  final time =
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
  return '$date  $time';
}

String _eventTypeLabel(CalendarEventType type, AppLocalizations l10n) {
  return switch (type) {
    CalendarEventType.operations => l10n.t('calendar.typeOperations'),
    CalendarEventType.training => l10n.t('calendar.typeTraining'),
    CalendarEventType.maintenance => l10n.t('calendar.typeMaintenance'),
    CalendarEventType.briefing => l10n.t('calendar.typeBriefing'),
    CalendarEventType.administrative => l10n.t('calendar.typeAdministrative'),
    CalendarEventType.other => l10n.t('calendar.typeOther'),
  };
}

String _eventStatusLabel(CalendarEventStatus status, AppLocalizations l10n) {
  return switch (status) {
    CalendarEventStatus.scheduled => l10n.t('calendar.statusScheduled'),
    CalendarEventStatus.inProgress => l10n.t('calendar.statusInProgress'),
    CalendarEventStatus.completed => l10n.t('calendar.statusCompleted'),
    CalendarEventStatus.cancelled => l10n.t('calendar.statusCancelled'),
  };
}
