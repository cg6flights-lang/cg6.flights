import 'dart:typed_data';

import 'package:cg6_flights/core/errors/app_error.dart';
import 'package:cg6_flights/core/results/app_result.dart';
import 'package:cg6_flights/core/state/timezone_provider.dart';
import 'package:cg6_flights/features/flight_orders/domain/flight_order.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

final flightOrderPdfServiceProvider = Provider<FlightOrderPdfService>((ref) {
  return FlightOrderPdfService(tzOffset: ref.watch(timezoneProvider));
});

class FlightOrderPdfService {
  const FlightOrderPdfService({this.tzOffset = -5});

  /// Configured timezone offset used to render all times in the PDF.
  final int tzOffset;

  Future<AppResult<Uint8List>> buildFlightOrderPdf({
    required FlightOrder order,
    required List<FlightOrderItem> items,
    required List<FlightOrderProfile> orderProfiles,
  }) async {
    try {
      final document = pw.Document(
        title: 'Flight Order ${order.orderNumber ?? order.id}',
        author: 'CG6 Flights',
        creator: 'CG6 Flights',
      );

      final activeItems = items.where((item) => !item.cancelled).toList();
      final totalMinutes = activeItems.fold<int>(
        0,
        (sum, item) => sum + (item.eteMinutes ?? 0),
      );

      document.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.fromLTRB(20, 18, 20, 24),
          build: (context) => [
            _header(order),
            pw.SizedBox(height: 8),
            _flightTable(order, items, orderProfiles),
            _totalRow('TOTAL', _decimalHours(totalMinutes)),
            _totalRow('TOTAL MES', _decimalHours(totalMinutes)),
            _totalRow('TOTAL ANUAL', _decimalHours(totalMinutes)),
            pw.SizedBox(height: 24),
            _stateTimesSection(items),
            pw.SizedBox(height: 30),
            _signatureRow(),
          ],
        ),
      );

      return AppSuccess(await document.save());
    } catch (_) {
      return const AppFailure(
        AppError(
          code: 'EXPORT_NOT_ALLOWED',
          message: 'No se pudo generar el PDF de la Orden de Vuelo.',
          category: AppErrorCategory.export,
          severity: AppErrorSeverity.high,
        ),
      );
    }
  }

  String fileNameFor(FlightOrder order) {
    final number = _safeFilePart(order.orderNumber ?? order.id);
    final date = order.operationDate.toIso8601String().split('T').first;
    return 'orden-vuelo-$number-$date.pdf';
  }

  pw.Widget _header(FlightOrder order) {
    return pw.Column(
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Text(
                order.unitName?.toUpperCase() ?? 'BASE AEREA LAS PALMAS',
                style: _bold(9),
              ),
            ),
            pw.Expanded(
              child: pw.Text(
                'FLIGHT ORDER No. ${order.orderNumber ?? '--'}',
                textAlign: pw.TextAlign.center,
                style: _bold(11),
              ),
            ),
            pw.Expanded(
              child: pw.Text(
                'OPS. DEPARTMENT',
                textAlign: pw.TextAlign.right,
                style: _bold(9),
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 10),
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Container(
            width: 210,
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: _box(),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('DATE:', style: _bold(9)),
                pw.Text(
                  _formatDateNumeric(order.operationDate),
                  style: _bold(9),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  pw.Widget _flightTable(
    FlightOrder order,
    List<FlightOrderItem> items,
    List<FlightOrderProfile> orderProfiles,
  ) {
    final data = <List<String>>[
      [
        'AIRCRAFT',
        'NUMBER',
        'CALLSIGN',
        'CREW',
        'ODI',
        'PHASE',
        'MISSION',
        'CONFIG',
        'FUEL',
        'PROF',
        'ZONE',
        'DEP',
        'FT',
        'REMARKS / PROFILE',
      ],
      if (items.isEmpty)
        [
          '--',
          '--',
          '--',
          '--',
          '--',
          '--',
          '--',
          '--',
          '--',
          '--',
          '--',
          '--',
          '--',
          '--',
        ]
      else
        for (final item in items) _tableRow(item, orderProfiles),
    ];

    return pw.TableHelper.fromTextArray(
      data: data,
      border: pw.TableBorder.all(width: 0.7, color: PdfColors.grey800),
      headerStyle: _bold(7.5),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
      cellStyle: _regular(7),
      cellAlignment: pw.Alignment.center,
      headerAlignment: pw.Alignment.center,
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 5),
      columnWidths: {
        0: const pw.FlexColumnWidth(1.0),
        1: const pw.FlexColumnWidth(0.8),
        2: const pw.FlexColumnWidth(1.0),
        3: const pw.FlexColumnWidth(3.2),
        4: const pw.FlexColumnWidth(0.6),
        5: const pw.FlexColumnWidth(0.9),
        6: const pw.FlexColumnWidth(1.1),
        7: const pw.FlexColumnWidth(1.0),
        8: const pw.FlexColumnWidth(0.8),
        9: const pw.FlexColumnWidth(0.7),
        10: const pw.FlexColumnWidth(1.2),
        11: const pw.FlexColumnWidth(0.9),
        12: const pw.FlexColumnWidth(0.7),
        13: const pw.FlexColumnWidth(4.7),
      },
    );
  }

  List<String> _tableRow(
    FlightOrderItem item,
    List<FlightOrderProfile> orderProfiles,
  ) {
    final profiles = [...orderProfiles, ...item.profiles];
    final profileNumbers = profiles
        .map((profile) => profile.profileNumber.toString())
        .toSet()
        .join(', ');

    return [
      _aircraftLabel(item),
      _registrationNumber(item.aircraftRegistration),
      _callsign(item.crew),
      _crewSummary(item.crew),
      '--',
      _phase(item.status, item.cancelled),
      item.mission?.toUpperCase() ?? '--',
      item.flightLevelDisplay,
      _fuel(item),
      profileNumbers.isEmpty ? '--' : profileNumbers,
      _zone(item.routes),
      item.scheduledDeparture != null
          ? _formatTime(item.scheduledDeparture!)
          : '--',
      _decimalHours(item.eteMinutes ?? 0),
      _remarks(item, profiles),
    ];
  }

  pw.Widget _totalRow(String label, String value) {
    return pw.Container(
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          left: pw.BorderSide(width: 0.7, color: PdfColors.grey800),
          right: pw.BorderSide(width: 0.7, color: PdfColors.grey800),
          bottom: pw.BorderSide(width: 0.7, color: PdfColors.grey800),
        ),
      ),
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Center(child: pw.Text('$label: $value', style: _bold(9))),
    );
  }

  pw.Widget _stateTimesSection(List<FlightOrderItem> items) {
    final rows = [
      ['AIRCRAFT', 'TAXI', 'TAKEOFF', 'LANDING', 'ENGINE OFF', 'TOTAL', 'AIR'],
      for (final item in items)
        [
          _aircraftLabel(item),
          _eventTime(item.stateEvents, 'taxi'),
          _eventTime(item.stateEvents, 'takeoff'),
          _eventTime(item.stateEvents, 'landing'),
          _eventTime(item.stateEvents, 'engine_off'),
          _duration(item.stateEvents, 'taxi', 'engine_off'),
          _duration(item.stateEvents, 'takeoff', 'landing'),
        ],
    ];

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Text('STATE / TIMES', style: _bold(8)),
        pw.SizedBox(height: 4),
        pw.TableHelper.fromTextArray(
          data: rows,
          border: pw.TableBorder.all(width: 0.5, color: PdfColors.grey700),
          headerStyle: _bold(7),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
          cellStyle: _regular(7),
          cellAlignment: pw.Alignment.center,
          cellPadding: const pw.EdgeInsets.symmetric(
            horizontal: 4,
            vertical: 3,
          ),
        ),
      ],
    );
  }

  pw.Widget _signatureRow() {
    final blocks = [
      ('Jefe del Departamento de Operaciones', 'Nombre / Firma'),
      ('Comandante de Operaciones', 'Nombre / Firma'),
      ('Comandante de Unidad', 'Nombre / Firma'),
      ('Jefe de Departamento de Vuelo', 'Nombre / Firma'),
    ];

    return pw.Row(
      children: [
        for (final block in blocks)
          pw.Expanded(
            child: pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 10),
              child: pw.Column(
                children: [
                  pw.Container(height: 28),
                  pw.Container(height: 0.8, color: PdfColors.grey800),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    block.$1,
                    textAlign: pw.TextAlign.center,
                    style: _regular(7),
                  ),
                  pw.Text(
                    block.$2,
                    textAlign: pw.TextAlign.center,
                    style: _bold(7),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  String _aircraftLabel(FlightOrderItem item) {
    final reg = item.aircraftRegistration ?? '--';
    final model = item.aircraftModel;
    return model != null && model.isNotEmpty ? '$reg — $model' : reg;
  }

  String _registrationNumber(String? registration) {
    if (registration == null || registration.isEmpty) return '--';
    final match = RegExp(r'(\d+)$').firstMatch(registration);
    return match?.group(1) ?? '--';
  }

  String _callsign(List<FlightOrderCrew> crew) {
    for (final member in crew) {
      if (member.crewMemberCallsign != null &&
          member.crewMemberCallsign!.isNotEmpty) {
        return member.crewMemberCallsign!.toUpperCase();
      }
    }
    return '--';
  }

  String _crewSummary(List<FlightOrderCrew> crew) {
    if (crew.isEmpty) return '--';
    return crew
        .map((member) {
          final name = member.crewMemberName ?? '--';
          final function = member.functionCode?.isNotEmpty == true
              ? ' (${member.functionCode})'
              : '';
          return '$name$function';
        })
        .join(' / ');
  }

  String _phase(String status, bool cancelled) {
    if (cancelled) return 'CANCELLED';
    return switch (status) {
      'waiting' => 'WAITING',
      'taxi' => 'TAXI',
      'takeoff' => 'TAKEOFF',
      'landing' => 'LANDING',
      'engine_off' => 'ENGINE OFF',
      _ => status.toUpperCase(),
    };
  }

  String _fuel(FlightOrderItem item) {
    if (item.fuelAmount == null) return '--';
    final amount = item.fuelAmount!;
    final value = amount == amount.roundToDouble()
        ? amount.toStringAsFixed(0)
        : amount.toStringAsFixed(1);
    return item.fuelType != null ? '$value ${item.fuelType}' : value;
  }

  String _zone(List<FlightOrderRoute> routes) {
    if (routes.isEmpty) return '--';
    return routes.map((route) => _ascii(route.displayLabel)).join(' / ');
  }

  String _remarks(FlightOrderItem item, List<FlightOrderProfile> profiles) {
    final remarks = <String>[
      if (item.cancelled) 'CANCELLED: ${item.cancelReason ?? '--'}',
      for (final profile in profiles)
        '${profile.profileNumber}. ${profile.description}',
      for (final route in item.routes)
        '${route.segmentOrder}. ${_ascii(route.displayLabel)}',
    ];
    return remarks.isEmpty ? '--' : remarks.join('\n');
  }

  String _eventTime(List<FlightOrderStateEvent> events, String status) {
    final matches = events.where((event) => event.status == status);
    if (matches.isEmpty) return '--';
    return _formatTime(matches.first.occurredAt);
  }

  String _duration(List<FlightOrderStateEvent> events, String from, String to) {
    DateTime? start;
    DateTime? end;
    for (final event in events) {
      if (event.status == from) start = event.occurredAt;
      if (event.status == to) end = event.occurredAt;
    }
    if (start == null || end == null) return '--';
    final diff = end.difference(start);
    if (diff.isNegative) return '--';
    final hours = diff.inHours;
    final minutes = diff.inMinutes.remainder(60);
    return hours > 0 ? '${hours}h ${minutes}m' : '${minutes}m';
  }

  String _decimalHours(int minutes) {
    if (minutes <= 0) return '--';
    return (minutes / 60).toStringAsFixed(1);
  }

  String _formatDateNumeric(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  String _formatTime(DateTime dateTime) =>
      formatTimeWithOffset(dateTime, tzOffset);

  String _safeFilePart(String value) {
    return value.replaceAll(RegExp(r'[^a-zA-Z0-9_-]+'), '-');
  }

  String _ascii(String value) {
    return value
        .replaceAll('→', '->')
        .replaceAll('←', '<-')
        .replaceAll('°', '.');
  }

  pw.BoxDecoration _box() {
    return pw.BoxDecoration(
      border: pw.Border.all(width: 0.7, color: PdfColors.grey800),
    );
  }

  pw.TextStyle _bold(double size) {
    return pw.TextStyle(fontSize: size, fontWeight: pw.FontWeight.bold);
  }

  pw.TextStyle _regular(double size) {
    return pw.TextStyle(fontSize: size);
  }
}
