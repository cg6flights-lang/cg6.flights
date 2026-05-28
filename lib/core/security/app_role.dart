enum AppRole {
  leader,
  generalAdmin,
  unitCommand,
  unitAdmin,
  ttaa;

  String get key => switch (this) {
    AppRole.leader => 'leader',
    AppRole.generalAdmin => 'general_admin',
    AppRole.unitCommand => 'unit_command',
    AppRole.unitAdmin => 'unit_admin',
    AppRole.ttaa => 'ttaa',
  };

  String get labelEs => switch (this) {
    AppRole.leader => 'Lider',
    AppRole.generalAdmin => 'Administrador General',
    AppRole.unitCommand => 'Comando de Unidad',
    AppRole.unitAdmin => 'Administrador de Unidad',
    AppRole.ttaa => 'TTAA',
  };

  bool get isGlobal => this == AppRole.leader || this == AppRole.generalAdmin;

  bool get requiresUnit => !isGlobal;

  static AppRole? fromKey(String? key) {
    for (final role in values) {
      if (role.key == key) return role;
    }
    return null;
  }
}
