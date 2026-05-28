enum AppErrorCategory {
  auth,
  authorization,
  validation,
  businessRule,
  data,
  network,
  storage,
  realtime,
  export,
  system,
}

enum AppErrorSeverity { low, medium, high, critical }

class AppError {
  const AppError({
    required this.code,
    required this.message,
    required this.category,
    required this.severity,
  });

  final String code;
  final String message;
  final AppErrorCategory category;
  final AppErrorSeverity severity;
}
