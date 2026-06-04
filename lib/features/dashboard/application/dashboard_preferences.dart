import 'package:cg6_flights/features/dashboard/domain/dashboard_widget_config.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class WidgetPref {
  final String id;
  final bool visible;
  final int order;
  final int span;

  const WidgetPref({
    required this.id,
    required this.visible,
    required this.order,
    required this.span,
  });

  Map<String, dynamic> toJson() => {'id': id, 'visible': visible, 'order': order, 'span': span};

  factory WidgetPref.fromJson(Map<String, dynamic> json) => WidgetPref(
    id: json['id'] as String,
    visible: json['visible'] as bool,
    order: (json['order'] as num).toInt(),
    span: (json['span'] as num?)?.toInt() ?? 1,
  );

  WidgetPref copyWith({String? id, bool? visible, int? order, int? span}) =>
      WidgetPref(id: id ?? this.id, visible: visible ?? this.visible, order: order ?? this.order, span: span ?? this.span);
}

final dashboardPreferencesProvider =
    NotifierProvider<DashboardPreferencesNotifier, List<WidgetPref>>(DashboardPreferencesNotifier.new);

class DashboardPreferencesNotifier extends Notifier<List<WidgetPref>> {
  @override
  List<WidgetPref> build() {
    Future.microtask(_load);
    return _defaults();
  }

  List<WidgetPref> _defaults() {
    return DashboardWidgetConfig.registry
        .map((c) => WidgetPref(id: c.id, visible: c.defaultVisible, order: c.defaultOrder, span: c.defaultSpan))
        .toList()
      ..sort((a, b) => a.order.compareTo(b.order));
  }

  Future<void> _load() async { /* in-memory only */ }

  void toggleVisibility(String id) {
    state = state.map((p) => p.id == id ? p.copyWith(visible: !p.visible) : p).toList();
  }

  void setSpan(String id, int v) {
    state = state.map((p) => p.id == id ? p.copyWith(span: v.clamp(1, 3)) : p).toList();
  }

  void move(int oldIndex, int newIndex) {
    if (oldIndex == newIndex) return;
    final list = [...state];
    final item = list.removeAt(oldIndex);
    list.insert(newIndex.clamp(0, list.length), item);
    state = List.generate(list.length, (i) => list[i].copyWith(order: i));
  }

  void resetToDefaults() => state = _defaults();
}
