import 'package:flutter/material.dart';

class DashboardWidgetConfig {
  final String id;
  final String titleKey;
  final IconData icon;
  final int defaultOrder;
  final bool defaultVisible;
  final int defaultSpan;

  const DashboardWidgetConfig({
    required this.id,
    required this.titleKey,
    required this.icon,
    required this.defaultOrder,
    required this.defaultVisible,
    this.defaultSpan = 1,
  });

  static const List<DashboardWidgetConfig> registry = [
    // CLOCKS: independent compact widgets above the map
    DashboardWidgetConfig(
      id: 'zulu_clock',
      titleKey: 'dashboard.widget.zuluClock',
      icon: Icons.schedule_outlined,
      defaultOrder: -2,
      defaultVisible: true,
    ),
    DashboardWidgetConfig(
      id: 'romeo_clock',
      titleKey: 'dashboard.widget.romeoClock',
      icon: Icons.access_time_filled_outlined,
      defaultOrder: -1,
      defaultVisible: true,
    ),
    // WIDE (col 0+1): mapa → timeline → flota
    DashboardWidgetConfig(
      id: 'map',
      titleKey: 'dashboard.widget.map',
      icon: Icons.map_outlined,
      defaultOrder: 0,
      defaultVisible: true,
      defaultSpan: 2,
    ),
    // NARROW (col 2): stacked vertically
    DashboardWidgetConfig(
      id: 'kpis',
      titleKey: 'dashboard.widget.kpis',
      icon: Icons.bar_chart,
      defaultOrder: 1,
      defaultVisible: true,
    ),
    // WIDE
    DashboardWidgetConfig(
      id: 'timeline',
      titleKey: 'dashboard.widget.timeline',
      icon: Icons.timeline,
      defaultOrder: 2,
      defaultVisible: true,
      defaultSpan: 2,
    ),
    // NARROW
    DashboardWidgetConfig(
      id: 'metar',
      titleKey: 'dashboard.widget.metar',
      icon: Icons.cloud_outlined,
      defaultOrder: 3,
      defaultVisible: true,
    ),
    // NARROW
    DashboardWidgetConfig(
      id: 'upcoming',
      titleKey: 'dashboard.widget.upcoming',
      icon: Icons.flight_takeoff,
      defaultOrder: 4,
      defaultVisible: true,
    ),
    // NARROW
    DashboardWidgetConfig(
      id: 'notifications',
      titleKey: 'dashboard.widget.notifications',
      icon: Icons.campaign_outlined,
      defaultOrder: 5,
      defaultVisible: true,
    ),
    // NARROW
    DashboardWidgetConfig(
      id: 'operability',
      titleKey: 'dashboard.widget.operability',
      icon: Icons.show_chart,
      defaultOrder: 6,
      defaultVisible: true,
    ),
    // WIDE
    DashboardWidgetConfig(
      id: 'fleet',
      titleKey: 'dashboard.widget.fleet',
      icon: Icons.pie_chart_outline,
      defaultOrder: 7,
      defaultVisible: true,
      defaultSpan: 3,
    ),
    // Hidden
    DashboardWidgetConfig(
      id: 'activity',
      titleKey: 'dashboard.widget.activity',
      icon: Icons.fact_check_outlined,
      defaultOrder: 8,
      defaultVisible: false,
    ),
    DashboardWidgetConfig(
      id: 'resumen',
      titleKey: 'dashboard.widget.resumen',
      icon: Icons.summarize_outlined,
      defaultOrder: 9,
      defaultVisible: false,
    ),
    DashboardWidgetConfig(
      id: 'quick_actions',
      titleKey: 'dashboard.widget.quick_actions',
      icon: Icons.touch_app_outlined,
      defaultOrder: 10,
      defaultVisible: false,
    ),
    DashboardWidgetConfig(
      id: 'calendar_mini',
      titleKey: 'dashboard.widget.calendar_mini',
      icon: Icons.calendar_today,
      defaultOrder: 11,
      defaultVisible: false,
    ),
  ];

  static DashboardWidgetConfig? byId(String id) {
    for (final c in registry) {
      if (c.id == id) return c;
    }
    return null;
  }
}
