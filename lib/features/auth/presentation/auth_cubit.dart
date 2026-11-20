import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/app_user.dart';
import '../domain/auth_exception.dart';
import '../domain/auth_repository.dart';
import '../../../core/errors/repository_exception.dart';

class AuthState {
  const AuthState({
    this.user,
    this.initializing = true,
    this.busy = false,
    this.issue,
    this.message,
  });
  final AppUser? user;
  final bool initializing;
  final bool busy;
  final String? issue;
  final String? message;
}

class AuthCubit extends Cubit<AuthState> {
  AuthCubit(this.repository) : super(const AuthState()) {
    _subscription = repository.watchUser().listen(
      (user) {
        if (!isClosed) {
          emit(
            AuthState(
              user: user,
              initializing: state.initializing,
              busy: state.busy,
              issue: repository.configurationIssue,
            ),
          );
        }
      },
      onError: (Object error) {
        if (!isClosed) {
          emit(
            AuthState(
              initializing: false,
              issue: repository.configurationIssue,
              message: error is AuthException
                  ? error.message
                  : const AuthException(AuthFailure.denied).message,
            ),
          );
        }
      },
    );
  }
  final AuthRepository repository;
  late final StreamSubscription<AppUser?> _subscription;
  Future<void> initialize() async {
    try {
      await repository.initialize();
      if (!isClosed) {
        emit(
          AuthState(
            user: repository.currentUser,
            initializing: false,
            issue: repository.configurationIssue,
          ),
        );
      }
    } catch (error) {
      if (!isClosed) {
        emit(
          AuthState(
            initializing: false,
            issue: repository.configurationIssue,
            message: error is AuthException
                ? error.message
                : const AuthException(AuthFailure.unknown).message,
          ),
        );
      }
    }
  }

  Future<void> _perform(Future<void> Function() action) async {
    if (state.busy || state.initializing) return;
    emit(
      AuthState(
        user: state.user,
        initializing: false,
        busy: true,
        issue: state.issue,
      ),
    );
    try {
      await action();
      if (!isClosed) {
        emit(
          AuthState(
            user: repository.currentUser,
            initializing: false,
            issue: repository.configurationIssue,
          ),
        );
      }
    } catch (error) {
      if (!isClosed) {
        emit(
          AuthState(
            user: repository.currentUser,
            initializing: false,
            issue: repository.configurationIssue,
            message: error is AuthException
                ? error.message
                : error is RepositoryException &&
                      error.code == RepositoryError.invalidInput
                ? error.message
                : const AuthException(AuthFailure.unknown).message,
          ),
        );
      }
    }
  }

  Future<void> signIn() => _perform(() async {
    await repository.signInWithGoogle();
  });
  Future<void> completeName(String name) =>
      _perform(() => repository.completeProfile(name));
  Future<void> signOut() => _perform(repository.signOut);
  @override
  Future<void> close() async {
    await _subscription.cancel();
    return super.close();
  }
}
