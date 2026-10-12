import 'package:equatable/equatable.dart';
import '../models/user_model.dart';

enum UserStatus { initial, loading, loaded, error }

class UserState extends Equatable {
  final UserStatus status;
  final UserModel? profile;
  final String? errorMessage;

  const UserState({
    this.status = UserStatus.initial,
    this.profile,
    this.errorMessage,
  });

  UserState copyWith({
    UserStatus? status,
    UserModel? profile,
    String? errorMessage,
  }) {
    return UserState(
      status: status ?? this.status,
      profile: profile ?? this.profile,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, profile, errorMessage];
}