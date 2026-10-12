import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../users/repository/user_repository.dart';
import '../repository/auth_repository.dart';
import 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  final AuthRepository _authRepository;
  final UserRepository _userRepository;
  StreamSubscription<User?>? _authSubscription;

  AuthCubit({
    required AuthRepository authRepository,
    required UserRepository userRepository,
  })  : _authRepository = authRepository,
        _userRepository = userRepository,
        super(const AuthState()) {
    _authSubscription = _authRepository.authStateChanges.listen((user) {
      emit(state.copyWith(
        status: user != null ? AuthStatus.authenticated : AuthStatus.unauthenticated,
        user: user,
      ));
    });
  }

  Future<void> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    emit(state.copyWith(status: AuthStatus.loading));
    try {
      final user = await _authRepository.register(email: email, password: password);
      if (user != null) {
        await _userRepository.createUserProfile(
          uid: user.uid,
          email: email,
          displayName: displayName,
        );
      }
      // authStateChanges listener above will emit authenticated automatically
    } on FirebaseAuthException catch (e) {
      emit(state.copyWith(status: AuthStatus.error, errorMessage: _mapError(e)));
    }
  }

  Future<void> login({required String email, required String password}) async {
    emit(state.copyWith(status: AuthStatus.loading));
    try {
      await _authRepository.login(email: email, password: password);
    } on FirebaseAuthException catch (e) {
      emit(state.copyWith(status: AuthStatus.error, errorMessage: _mapError(e)));
    }
  }

  Future<void> sendPasswordReset(String email) async {
    try {
      await _authRepository.sendPasswordResetEmail(email);
    } on FirebaseAuthException catch (e) {
      emit(state.copyWith(status: AuthStatus.error, errorMessage: _mapError(e)));
    }
  }

  Future<void> logout() async {
    await _authRepository.logout();
  }

  String _mapError(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'invalid-email':
        return 'That email address looks invalid.';
      case 'weak-password':
        return 'Password should be at least 6 characters.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      default:
        return e.message ?? 'Something went wrong. Please try again.';
    }
  }

  @override
  Future<void> close() {
    _authSubscription?.cancel();
    return super.close();
  }
}