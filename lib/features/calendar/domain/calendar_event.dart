enum CalendarEventType {
  operations,
  training,
  maintenance,
  briefing,
  administrative,
  other;

  String get key => switch (this) {
    CalendarEventType.operations => 'operations',
    CalendarEventType.training => 'training',
    CalendarEventType.maintenance => 'maintenance',
    CalendarEventType.briefing => 'briefing',
    CalendarEventType.administrative => 'administrative',
    CalendarEventType.other => 'other',
  };

  static CalendarEventType fromKey(String? key) {
    return switch (key) {
      'training' => CalendarEventType.training,
      'maintenance' => CalendarEventType.maintenance,
      'briefing' => CalendarEventType.briefing,
      'administrative' => CalendarEventType.administrative,
      'other' => CalendarEventType.other,
      _ => CalendarEventType.operations,
    };
  }
}

enum CalendarEventStatus {
  scheduled,
  inProgress,
  completed,
  cancelled;

  String get key => switch (this) {
    CalendarEventStatus.scheduled => 'scheduled',
    CalendarEventStatus.inProgress => 'in_progress',
    CalendarEventStatus.completed => 'completed',
    CalendarEventStatus.cancelled => 'cancelled',
  };

  static CalendarEventStatus fromKey(String? key) {
    return switch (key) {
      'in_progress' => CalendarEventStatus.inProgress,
      'completed' => CalendarEventStatus.completed,
      'cancelled' => CalendarEventStatus.cancelled,
      _ => CalendarEventStatus.scheduled,
    };
  }
}

class CalendarEvent {
  const CalendarEvent({
    required this.id,
    required this.title,
    this.description,
    this.location,
    required this.eventType,
    required this.status,
    required this.startsAt,
    required this.endsAt,
    required this.createdBy,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String? description;
  final String? location;
  final CalendarEventType eventType;
  final CalendarEventStatus status;
  final DateTime startsAt;
  final DateTime endsAt;
  final String createdBy;
  final DateTime createdAt;

  factory CalendarEvent.fromJson(Map<String, dynamic> json) {
    return CalendarEvent(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString(),
      location: json['location']?.toString(),
      eventType: CalendarEventType.fromKey(json['event_type']?.toString()),
      status: CalendarEventStatus.fromKey(json['status']?.toString()),
      startsAt:
          DateTime.tryParse(json['starts_at']?.toString() ?? '') ??
          DateTime.now(),
      endsAt:
          DateTime.tryParse(json['ends_at']?.toString() ?? '') ??
          DateTime.now(),
      createdBy: json['created_by']?.toString() ?? '',
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  DateTime get localStart => startsAt.toLocal();
  DateTime get localEnd => endsAt.toLocal();

  bool occursOn(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    final startDay = DateTime(
      localStart.year,
      localStart.month,
      localStart.day,
    );
    final endDay = DateTime(localEnd.year, localEnd.month, localEnd.day);
    return !day.isBefore(startDay) && !day.isAfter(endDay);
  }

  String get shortTime {
    final start =
        '${localStart.hour.toString().padLeft(2, '0')}:${localStart.minute.toString().padLeft(2, '0')}';
    final end =
        '${localEnd.hour.toString().padLeft(2, '0')}:${localEnd.minute.toString().padLeft(2, '0')}';
    return '$start - $end';
  }
}
