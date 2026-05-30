class FlightOrder {
  const FlightOrder({
    required this.id,
    required this.unitId,
    required this.operationDate,
    required this.status,
    this.orderNumber,
    this.unitName,
    this.submittedAt,
    this.approvedAt,
    this.closedAt,
    this.createdBy,
    this.approvedBy,
    this.closedBy,
    required this.createdAt,
    required this.updatedAt,
    this.itemsCount,
  });

  final String id;
  final String unitId;
  final DateTime operationDate;
  final String status;
  final String? orderNumber;
  final String? unitName;
  final int? itemsCount;
  final DateTime? submittedAt;
  final DateTime? approvedAt;
  final DateTime? closedAt;
  final String? createdBy;
  final String? approvedBy;
  final String? closedBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get hasObservations => status == 'draft' && submittedAt != null;

  String get effectiveStatus => status == 'observed' ? 'draft' : status;

  factory FlightOrder.fromJson(Map<String, dynamic> json) {
    return FlightOrder(
      id: json['id'].toString(),
      unitId: json['unit_id'].toString(),
      operationDate: DateTime.parse(json['operation_date'].toString()),
      status: json['status']?.toString() ?? 'draft',
      orderNumber: json['order_number']?.toString(),
      unitName: json['units'] is Map
          ? (json['units'] as Map)['name']?.toString()
          : json['unit_name']?.toString(),
      submittedAt: json['submitted_at'] != null
          ? DateTime.tryParse(json['submitted_at'].toString())
          : null,
      approvedAt: json['approved_at'] != null
          ? DateTime.tryParse(json['approved_at'].toString())
          : null,
      closedAt: json['closed_at'] != null
          ? DateTime.tryParse(json['closed_at'].toString())
          : null,
      createdBy: json['created_by']?.toString(),
      approvedBy: json['approved_by']?.toString(),
      closedBy: json['closed_by']?.toString(),
      itemsCount: json['items_count'] is int
          ? json['items_count'] as int
          : json['items_count'] != null
              ? int.tryParse(json['items_count'].toString())
              : null,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'unit_id': unitId,
      'operation_date': operationDate.toIso8601String().split('T').first,
      'order_number': orderNumber,
    };
  }
}

class FlightOrderItem {
  const FlightOrderItem({
    required this.id,
    required this.flightOrderId,
    required this.aircraftId,
    this.mission,
    this.flightLevelMin,
    this.flightLevelMax,
    this.eteMinutes,
    this.fuelAmount,
    this.fuelType,
    this.scheduledDeparture,
    this.status = 'waiting',
    this.cancelled = false,
    this.cancelledAt,
    this.cancelledBy,
    this.cancelReason,
    required this.createdAt,
    required this.updatedAt,
    this.aircraftRegistration,
    this.aircraftModel,
    this.orderNumber,
    this.unitName,
    this.unitId,
    this.routes = const [],
    this.crew = const [],
    this.profiles = const [],
    this.profileIds = const [],
    this.stateEvents = const [],
  });

  final String id;
  final String flightOrderId;
  final String aircraftId;
  final String? mission;
  final int? flightLevelMin;
  final int? flightLevelMax;
  final int? eteMinutes;
  final double? fuelAmount;
  final String? fuelType;
  final DateTime? scheduledDeparture;
  final String status;
  final bool cancelled;
  final DateTime? cancelledAt;
  final String? cancelledBy;
  final String? cancelReason;
  final DateTime createdAt;
  final DateTime updatedAt;

  final String? aircraftRegistration;
  final String? aircraftModel;
  final String? orderNumber;
  final String? unitName;
  final String? unitId;
  final List<FlightOrderRoute> routes;
  final List<FlightOrderCrew> crew;
  final List<FlightOrderProfile> profiles;
  final List<String> profileIds;
  final List<FlightOrderStateEvent> stateEvents;

  String get flightLevelDisplay {
    if (flightLevelMin == null) return '--';
    if (flightLevelMax != null && flightLevelMax != flightLevelMin) {
      return '$flightLevelMin - $flightLevelMax fts';
    }
    return '$flightLevelMin fts';
  }

  bool get isDelayed =>
      status == 'waiting' &&
      scheduledDeparture != null &&
      scheduledDeparture!.isBefore(DateTime.now());

  FlightOrderItem copyWith({
    String? id,
    String? flightOrderId,
    String? aircraftId,
    String? mission,
    int? flightLevelMin,
    int? flightLevelMax,
    int? eteMinutes,
    double? fuelAmount,
    String? fuelType,
    DateTime? scheduledDeparture,
    String? status,
    bool? cancelled,
    DateTime? cancelledAt,
    String? cancelledBy,
    String? cancelReason,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? aircraftRegistration,
    String? aircraftModel,
    String? orderNumber,
    String? unitName,
    String? unitId,
    List<FlightOrderRoute>? routes,
    List<FlightOrderCrew>? crew,
    List<FlightOrderProfile>? profiles,
    List<String>? profileIds,
    List<FlightOrderStateEvent>? stateEvents,
  }) {
    return FlightOrderItem(
      id: id ?? this.id,
      flightOrderId: flightOrderId ?? this.flightOrderId,
      aircraftId: aircraftId ?? this.aircraftId,
      mission: mission ?? this.mission,
      flightLevelMin: flightLevelMin ?? this.flightLevelMin,
      flightLevelMax: flightLevelMax ?? this.flightLevelMax,
      eteMinutes: eteMinutes ?? this.eteMinutes,
      fuelAmount: fuelAmount ?? this.fuelAmount,
      fuelType: fuelType ?? this.fuelType,
      scheduledDeparture: scheduledDeparture ?? this.scheduledDeparture,
      status: status ?? this.status,
      cancelled: cancelled ?? this.cancelled,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      cancelledBy: cancelledBy ?? this.cancelledBy,
      cancelReason: cancelReason ?? this.cancelReason,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      aircraftRegistration:
          aircraftRegistration ?? this.aircraftRegistration,
      aircraftModel: aircraftModel ?? this.aircraftModel,
      orderNumber: orderNumber ?? this.orderNumber,
      unitName: unitName ?? this.unitName,
      unitId: unitId ?? this.unitId,
      routes: routes ?? this.routes,
      crew: crew ?? this.crew,
      profiles: profiles ?? this.profiles,
      profileIds: profileIds ?? this.profileIds,
      stateEvents: stateEvents ?? this.stateEvents,
    );
  }

  factory FlightOrderItem.fromJson(Map<String, dynamic> json) {
    return FlightOrderItem(
      id: json['id'].toString(),
      flightOrderId: json['flight_order_id'].toString(),
      aircraftId: json['aircraft_id'].toString(),
      mission: json['mission']?.toString(),
      flightLevelMin: json['flight_level_min'] != null
          ? int.tryParse(json['flight_level_min'].toString())
          : null,
      flightLevelMax: json['flight_level_max'] != null
          ? int.tryParse(json['flight_level_max'].toString())
          : null,
      eteMinutes: json['ete_minutes'] != null
          ? int.tryParse(json['ete_minutes'].toString())
          : null,
      fuelAmount: json['fuel_amount'] != null
          ? double.tryParse(json['fuel_amount'].toString())
          : null,
      fuelType: json['fuel_type']?.toString(),
      scheduledDeparture: json['scheduled_departure'] != null
          ? DateTime.tryParse(json['scheduled_departure'].toString())
          : null,
      status: json['status']?.toString() ?? 'waiting',
      cancelled: json['cancelled'] == true,
      cancelledAt: json['cancelled_at'] != null
          ? DateTime.tryParse(json['cancelled_at'].toString())
          : null,
      cancelledBy: json['cancelled_by']?.toString(),
      cancelReason: json['cancel_reason']?.toString(),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? '') ??
          DateTime.now(),
      aircraftRegistration: json['aircraft'] is Map
          ? ((json['aircraft'] as Map)['registration']?.toString() ??
              (json['aircraft'] as Map)['tail_number']?.toString())
          : json['aircraft_registration']?.toString(),
      aircraftModel: json['aircraft'] is Map
          ? (json['aircraft'] as Map)['model']?.toString()
          : null,
      orderNumber: json['order_number']?.toString(),
      unitName: json['unit_name']?.toString(),
      unitId: json['unit_id']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'flight_order_id': flightOrderId,
      'aircraft_id': aircraftId,
      'mission': mission,
      'flight_level_min': flightLevelMin,
      'flight_level_max': flightLevelMax,
      'ete_minutes': eteMinutes,
      'fuel_amount': fuelAmount,
      'fuel_type': fuelType,
      'scheduled_departure': scheduledDeparture?.toIso8601String(),
      'status': status,
      'cancelled': cancelled,
      'cancelled_at': cancelledAt?.toIso8601String(),
      'cancelled_by': cancelledBy,
      'cancel_reason': cancelReason,
    };
  }
}

class FlightOrderRoute {
  const FlightOrderRoute({
    required this.id,
    required this.flightOrderItemId,
    this.segmentOrder = 1,
    this.segmentType = 'outbound',
    this.originType = 'airport',
    this.originRouteId,
    this.originLabel,
    this.originLat,
    this.originLng,
    this.destinationType = 'airport',
    this.destinationRouteId,
    this.destinationLabel,
    this.destinationLat,
    this.destinationLng,
    this.originRouteName,
    this.destinationRouteName,
  });

  final String id;
  final String flightOrderItemId;
  final int segmentOrder;
  final String segmentType;
  final String originType;
  final String? originRouteId;
  final String? originLabel;
  final double? originLat;
  final double? originLng;
  final String destinationType;
  final String? destinationRouteId;
  final String? destinationLabel;
  final double? destinationLat;
  final double? destinationLng;
  final String? originRouteName;
  final String? destinationRouteName;

  String get originDisplay {
    if (originType == 'airport' && originRouteName != null) return originRouteName!;
    return originLabel ?? '--';
  }

  String get destinationDisplay {
    if (destinationType == 'airport' && destinationRouteName != null) {
      return destinationRouteName!;
    }
    return destinationLabel ?? '--';
  }

  String get displayLabel => '$originDisplay → $destinationDisplay';

  factory FlightOrderRoute.fromJson(Map<String, dynamic> json) {
    return FlightOrderRoute(
      id: json['id'].toString(),
      flightOrderItemId: json['flight_order_item_id'].toString(),
      segmentOrder: json['segment_order'] != null
          ? int.tryParse(json['segment_order'].toString()) ?? 1
          : 1,
      segmentType: json['segment_type']?.toString() ?? 'outbound',
      originType: json['origin_type']?.toString() ?? 'airport',
      originRouteId: json['origin_route_id']?.toString(),
      originLabel: json['origin_label']?.toString(),
      originLat: json['origin_lat'] != null
          ? double.tryParse(json['origin_lat'].toString())
          : null,
      originLng: json['origin_lng'] != null
          ? double.tryParse(json['origin_lng'].toString())
          : null,
      destinationType: json['destination_type']?.toString() ?? 'airport',
      destinationRouteId: json['destination_route_id']?.toString(),
      destinationLabel: json['destination_label']?.toString(),
      destinationLat: json['destination_lat'] != null
          ? double.tryParse(json['destination_lat'].toString())
          : null,
      destinationLng: json['destination_lng'] != null
          ? double.tryParse(json['destination_lng'].toString())
          : null,
      originRouteName: json['origin_route'] is Map
          ? (json['origin_route'] as Map)['airport_name']?.toString()
          : null,
      destinationRouteName: json['destination_route'] is Map
          ? (json['destination_route'] as Map)['airport_name']?.toString()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'flight_order_item_id': flightOrderItemId,
      'segment_order': segmentOrder,
      'segment_type': segmentType,
      'origin_type': originType,
      'origin_route_id': originRouteId,
      'origin_label': originLabel,
      'origin_lat': originLat,
      'origin_lng': originLng,
      'destination_type': destinationType,
      'destination_route_id': destinationRouteId,
      'destination_label': destinationLabel,
      'destination_lat': destinationLat,
      'destination_lng': destinationLng,
    };
  }
}

class FlightOrderCrew {
  const FlightOrderCrew({
    required this.id,
    required this.flightOrderItemId,
    required this.crewMemberId,
    required this.roleCode,
    this.crewMemberName,
    this.crewMemberCallsign,
    this.functionCode,
  });

  final String id;
  final String flightOrderItemId;
  final String crewMemberId;
  final String roleCode;
  final String? crewMemberName;
  final String? crewMemberCallsign;
  final String? functionCode;

  factory FlightOrderCrew.fromJson(Map<String, dynamic> json) {
    return FlightOrderCrew(
      id: json['id'].toString(),
      flightOrderItemId: json['flight_order_item_id'].toString(),
      crewMemberId: json['crew_member_id'].toString(),
      roleCode: json['role_code']?.toString() ?? 'PC',
      crewMemberName: json['crew_member'] is Map
          ? _fullName(Map<String, dynamic>.from(json['crew_member'] as Map))
          : null,
      crewMemberCallsign: json['crew_member'] is Map
          ? (Map<String, dynamic>.from(json['crew_member'] as Map))['callsign']?.toString()
          : null,
      functionCode: json['function_code']?.toString(),
    );
  }

  static String _fullName(Map<String, dynamic> cm) {
    final grade = cm['grade']?.toString() ?? '';
    final first = cm['first_name']?.toString() ?? '';
    final last = cm['last_name']?.toString() ?? '';
    final parts = [grade, first, last].where((s) => s.isNotEmpty);
    return parts.isNotEmpty ? parts.join(' ') : '--';
  }

  Map<String, dynamic> toJson() {
    return {
      'flight_order_item_id': flightOrderItemId,
      'crew_member_id': crewMemberId,
      'role_code': roleCode,
      'function_code': functionCode,
    };
  }
}

class FlightOrderProfile {
  const FlightOrderProfile({
    required this.id,
    required this.flightOrderId,
    required this.profileNumber,
    required this.description,
  });

  final String id;
  final String flightOrderId;
  final int profileNumber;
  final String description;

  factory FlightOrderProfile.fromJson(Map<String, dynamic> json) {
    return FlightOrderProfile(
      id: json['id'].toString(),
      flightOrderId: json['flight_order_id'].toString(),
      profileNumber: json['profile_number'] != null
          ? int.tryParse(json['profile_number'].toString()) ?? 1
          : 1,
      description: json['description']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'flight_order_id': flightOrderId,
      'profile_number': profileNumber,
      'description': description,
    };
  }
}

class FlightOrderStateEvent {
  const FlightOrderStateEvent({
    required this.id,
    required this.flightOrderItemId,
    required this.status,
    required this.occurredAt,
    required this.recordedBy,
  });

  final String id;
  final String flightOrderItemId;
  final String status;
  final DateTime occurredAt;
  final String recordedBy;

  factory FlightOrderStateEvent.fromJson(Map<String, dynamic> json) {
    return FlightOrderStateEvent(
      id: json['id'].toString(),
      flightOrderItemId: json['flight_order_item_id'].toString(),
      status: json['status']?.toString() ?? '',
      occurredAt: DateTime.tryParse(json['occurred_at']?.toString() ?? '') ??
          DateTime.now(),
      recordedBy: json['recorded_by']?.toString() ?? '',
    );
  }
}
