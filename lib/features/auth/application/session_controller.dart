import 'package:cg6_flights/core/errors/app_error.dart';
import 'package:cg6_flights/core/results/app_result.dart';
import 'package:cg6_flights/features/auth/data/auth_repository.dart';
import 'package:cg6_flights/features/auth/domain/app_user.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final sessionControllerProvider =
    NotifierProvider<SessionController, SessionState>(SessionController.new);

enum SessionStatus { initial, loading, unauthenticated, authenticated, blocked }

class SessionState {
  const SessionState({required this.status, this.user, this.error, this.justLoggedIn = false});

  const SessionState.initial() : this(status: SessionStatus.initial);

  final SessionStatus status;
  final AppUser? user;
  final AppError? error;
  final bool justLoggedIn;

  bool get isLoading =>
      status == SessionStatus.loading || status == SessionStatus.initial;

  bool get isAuthenticated =>
      status == SessionStatus.authenticated || status == SessionStatus.blocked;

  bool get canOperate =>
      status == SessionStatus.authenticated && (user?.canOperate ?? false);

  bool can(String permission) => user?.can(permission) ?? false;

  SessionState copyWith({bool? justLoggedIn}) {
    return SessionState(
      status: status,
      user: user,
      error: error,
      justLoggedIn: justLoggedIn ?? this.justLoggedIn,
    );
  }
}

class SessionController extends Notifier<SessionState> {
  late final AuthRepository _repository;

  @override
  SessionState build() {
    _repository = ref.read(authRepositoryProvider);
    Future.microtask(restore);
    return const SessionState.initial();
  }

  Future<void> restore() async {
    state = const SessionState(status: SessionStatus.loading);
    final result = await _repository.currentUser();
    switch (result) {
      case AppSuccess<AppUser?>(data: final user):
        _setUser(user, justLoggedIn: false);
      case AppFailure<AppUser?>(error: final error):
        state = SessionState(
          status: SessionStatus.unauthenticated,
          error: error,
        );
    }
  }

  Future<void> signIn(String email, String password) async {
    state = const SessionState(status: SessionStatus.loading);
    final result = await _repository.signIn(email: email, password: password);
    switch (result) {
      case AppSuccess<AppUser>(data: final user):
        _setUser(user, justLoggedIn: true);
      case AppFailure<AppUser>(error: final error):
        state = SessionState(
          status: SessionStatus.unauthenticated,
          error: error,
        );
    }
  }

  Future<void> register({
    required String email,
    required String password,
    required String displayName,
    String? firstName,
    String? lastName,
    String? documentType,
    String? documentId,
    String? phoneCountryCode,
    String? phone,
    DateTime? birthDate,
    String? grade,
  }) async {
    state = const SessionState(status: SessionStatus.loading);
    final result = await _repository.register(
      email: email,
      password: password,
      displayName: displayName,
      firstName: firstName,
      lastName: lastName,
      documentType: documentType,
      documentId: documentId,
      phoneCountryCode: phoneCountryCode,
      phone: phone,
      birthDate: birthDate,
      grade: grade,
    );
    switch (result) {
      case AppSuccess<AppUser>(data: final user):
        _setUser(user, justLoggedIn: true);
      case AppFailure<AppUser>(error: final error):
        state = SessionState(
          status: SessionStatus.unauthenticated,
          error: error,
        );
    }
  }

  Future<void> claimFirstLeader() async {
    state = SessionState(status: SessionStatus.loading, user: state.user);
    final result = await _repository.claimFirstLeader();
    switch (result) {
      case AppSuccess<AppUser>(data: final user):
        _setUser(user, justLoggedIn: true);
      case AppFailure<AppUser>(error: final error):
        state = SessionState(
          status: SessionStatus.blocked,
          user: state.user,
          error: error,
        );
    }
  }

  Future<void> signOut() async {
    await _repository.signOut();
    state = const SessionState(status: SessionStatus.unauthenticated);
  }

  void dismissWelcome() {
    if (state.justLoggedIn) {
      state = state.copyWith(justLoggedIn: false);
    }
  }

  void updateUser(AppUser user) {
    state = SessionState(
      status: state.status,
      user: user,
      justLoggedIn: state.justLoggedIn,
    );
  }

  void _setUser(AppUser? user, {bool justLoggedIn = false}) {
    if (user == null) {
      state = const SessionState(status: SessionStatus.unauthenticated);
      return;
    }

    state = SessionState(
      status: user.canOperate
          ? SessionStatus.authenticated
          : SessionStatus.blocked,
      user: user,
      justLoggedIn: justLoggedIn,
    );
  }
}
