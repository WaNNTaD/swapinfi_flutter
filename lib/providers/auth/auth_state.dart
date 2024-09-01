part of 'auth_bloc.dart';

class AuthState extends Equatable {
  final bool isAuthenticated;
  final Map<String, dynamic>? user;
  final String status;

  const AuthState({
    required this.isAuthenticated,
    this.user,
    this.status = 'idle',
  });

  factory AuthState.initial() {
    return AuthState(
      isAuthenticated: false,
      user: {},
      status: 'initial',
    );
  }

  AuthState copyWith({
    bool? isAuthenticated,
    Map<String, dynamic>? user,
    String? status,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      user: user ?? this.user,
      status: status ?? this.status,
    );
  }

  @override
  List<Object?> get props => [isAuthenticated, user, status];
}
