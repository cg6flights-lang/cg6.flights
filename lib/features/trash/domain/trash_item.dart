class TrashItem {
  const TrashItem({
    required this.id,
    required this.section,
    required this.sectionKey,
    required this.identifier,
    required this.secondaryInfo,
    required this.deletedBy,
    required this.deletedAt,
    this.metadata = const {},
  });

  final String id;
  final String section; // 'aircraft', 'crew', 'routes', 'units', 'users', 'flight_orders', 'flights', 'calendar_events', 'messages', 'flight_order_profiles'
  final String sectionKey; // i18n key: 'trash.section.aircraft', etc.
  final String identifier; // e.g. "FAP-123 — C-130"
  final String secondaryInfo; // e.g. unit name, email, date
  final String deletedBy; // display name of who deleted/archived
  final DateTime deletedAt;
  final Map<String, dynamic> metadata; // extra data for restore context

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TrashItem &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          section == other.section;

  @override
  int get hashCode => Object.hash(id, section);
}
