import 'package:cg6_flights/core/errors/app_error.dart';

sealed class AppResult<T> {
  const AppResult();

  bool get ok => this is AppSuccess<T>;
}

class AppSuccess<T> extends AppResult<T> {
  const AppSuccess(this.data);

  final T data;
}

class AppFailure<T> extends AppResult<T> {
  const AppFailure(this.error);

  final AppError error;
}
