part of 'auth_bloc.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object> get props => [];
}

class SignInRequested extends AuthEvent {
  final String email;
  final String password;

  const SignInRequested(this.email, this.password);

  @override
  List<Object> get props => [email, password];
}

class SignOutRequested extends AuthEvent {}

class AuthStatusChanged extends AuthEvent {
  final Map<String, dynamic>? user;

  const AuthStatusChanged(this.user);

  @override
  List<Object> get props => [user ?? {}];
}

class CheckAuthStatus extends AuthEvent {}