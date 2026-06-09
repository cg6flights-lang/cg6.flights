class CrewMember {
  const CrewMember({
    required this.id,
    required this.unitId,
    required this.grade,
    required this.firstName,
    required this.lastName,
    required this.nsa,
    required this.crewCategory,
    required this.appointmentDate,
    required this.active,
    required this.assignmentType,
    this.callsign,
    this.qualifications = const [],
    this.squadronId,
    this.squadronName,
    this.trainingStart,
    this.trainingEnd,
    this.courseGroup,
    this.photoPath,
  });

  final String id;
  final String unitId;
  final String grade;
  final String firstName;
  final String lastName;
  final String nsa;
  final String crewCategory;
  final DateTime appointmentDate;
  final bool active;
  final String assignmentType;
  final String? callsign;
  final List<String> qualifications;
  final String? squadronId;
  final String? squadronName;
  final DateTime? trainingStart;
  final DateTime? trainingEnd;
  final String? courseGroup;
  final String? photoPath;

  static const validQualifications = ['IP', 'PS', 'CO', 'PM', 'CP', 'OB'];

  String get fullName => '$grade $firstName $lastName'.trim();
  bool get isPilot => crewCategory == 'pilot';
  bool get isMechanic => crewCategory == 'mechanic';
  bool get isNato => assignmentType == 'nato';

  factory CrewMember.fromJson(Map<String, dynamic> json) {
    final quals = json['qualifications'];
    final List<String> qualList;
    if (quals is List) {
      qualList = quals.map<String>((e) => e.toString()).toList();
    } else {
      qualList = [];
    }

    return CrewMember(
      id: json['id'].toString(),
      unitId: json['unit_id']?.toString() ?? '',
      grade: json['grade']?.toString() ?? '',
      firstName: json['first_name']?.toString() ?? '',
      lastName: json['last_name']?.toString() ?? '',
      nsa: json['nsa']?.toString() ?? '',
      crewCategory: json['crew_category']?.toString() ?? 'pilot',
      assignmentType: json['assignment_type']?.toString() ?? 'nato',
      callsign: json['callsign']?.toString(),
      appointmentDate: json['appointment_date'] != null
          ? DateTime.tryParse(json['appointment_date'].toString()) ??
              DateTime.now()
          : DateTime.now(),
      active: json['active'] == true,
      qualifications: qualList,
      squadronId: json['squadron_id']?.toString(),
      squadronName: json['flight_squadrons'] is Map
          ? (json['flight_squadrons'] as Map)['name']?.toString()
          : json['squadron_name']?.toString(),
      trainingStart: json['training_start'] != null
          ? DateTime.tryParse(json['training_start'].toString())
          : null,
      trainingEnd: json['training_end'] != null
          ? DateTime.tryParse(json['training_end'].toString())
          : null,
      courseGroup: json['course_group']?.toString(),
      photoPath: json['photo_path']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'unit_id': unitId,
      'grade': grade,
      'first_name': firstName,
      'last_name': lastName,
      'nsa': nsa,
      'crew_category': crewCategory,
      'assignment_type': assignmentType,
      if (callsign != null) 'callsign': callsign,
      'appointment_date':
          '${appointmentDate.year.toString().padLeft(4, '0')}-${appointmentDate.month.toString().padLeft(2, '0')}-${appointmentDate.day.toString().padLeft(2, '0')}',
      'qualifications': qualifications,
    };
  }
}
