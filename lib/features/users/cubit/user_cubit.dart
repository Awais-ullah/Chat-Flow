import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/user_model.dart';
import '../repository/user_repository.dart';
import 'user_state.dart';

/// Tracks the CURRENT logged-in user's own profile, live.
/// Start watching once we know the uid (after login), stop on logout.
class UserCubit extends Cubit<UserState> {
  final UserRepository _userRepository;
  StreamSubscription<UserModel?>? _subscription;

  UserCubit({required UserRepository userRepository})
      : _userRepository = userRepository,
        super(const UserState());

  void watchProfile(String uid) {
    emit(state.copyWith(status: UserStatus.loading));
    _subscription?.cancel();
    _subscription = _userRepository.watchUser(uid).listen((user) {
      emit(state.copyWith(status: UserStatus.loaded, profile: user));
    }, onError: (_) {
      emit(state.copyWith(status: UserStatus.error, errorMessage: 'Failed to load profile'));
    });
  }

  Future<void> updateProfile({String? displayName, String? bio}) async {
    final uid = state.profile?.uid;
    if (uid == null) return;
    await _userRepository.updateProfile(uid: uid, displayName: displayName, bio: bio);
    // watchProfile's stream will pick up the change automatically.
  }

  void stopWatching() {
    _subscription?.cancel();
    emit(const UserState());
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}