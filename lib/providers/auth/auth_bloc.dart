import 'dart:io';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_provider.dart';
import 'dart:convert';
import '../storage/secure_storage_service.dart';

part 'auth_event.dart';
part 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final SecureStorageService secureStorageService;
  final AuthProvider authProvider;
  final http.Client httpClient = http.Client();

  AuthBloc({required this.authProvider, required this.secureStorageService})
      : super(AuthState.initial()) {
    on<SignInRequested>(_onSignInRequested);
    on<SignOutRequested>(_onSignOutRequested);
    on<AuthStatusChanged>(_onAuthStatusChanged);
    on<CheckAuthStatus>(_onCheckAuthStatus);
  }

  Future<void> _onSignInRequested(
    SignInRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(state.copyWith(status: 'loading'));

    try {
      // Étape 1: Obtenir le cookie CSRF
      final sanctumResponse = await httpClient.get(
        Uri.parse('https://api_swapinfi.lebourbier.be/sanctum/csrf-cookie'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      );

      if (sanctumResponse.statusCode != 204) {
        emit(state.copyWith(status: 'failed'));
        return;
      }

      // Étape 2: Extraire le jeton CSRF
      final xsrfToken = Uri.decodeFull(
          sanctumResponse.headers['set-cookie']!.split(';')[0].split('=')[1]);

      // Étape 3: Effectuer la requête de connexion
      final loginResponse = await httpClient.post(
        Uri.parse('https://api_swapinfi.lebourbier.be/api/login'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'X-XSRF-TOKEN': xsrfToken,
        },
        body: jsonEncode({
          'email': event.email,
          'password': event.password,
        }),
      );

      if (loginResponse.statusCode == 200) {
        // Étape 4: Extraire et enregistrer le jeton d'accès
        final responseBody = jsonDecode(loginResponse.body);
        final accessToken = responseBody['access_token'];
        final user = responseBody['user'];

        await secureStorageService.saveToken('Bearer', accessToken);

        // Stocker les informations de l'utilisateur dans SharedPreferences
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('user', jsonEncode(user));

        // Étape 5: Mettre à jour l'état du bloc
        emit(state.copyWith(
          isAuthenticated: true,
          user: user,
          status: 'succeeded',
        ));
      } else {
        // Si la requête de connexion échoue
        emit(state.copyWith(status: 'failed'));
      }
    } catch (error) {
      // Gérer les erreurs
      emit(state.copyWith(status: 'failed'));
    }
  }

  Future<void> _onSignOutRequested(
      SignOutRequested event, Emitter<AuthState> emit) async {
    try {
      final String apiUrl = 'https://api_swapinfi.lebourbier.be/api/logout';
      final String? accessToken = await secureStorageService.getToken('Bearer');

      final response = await httpClient.post(
        Uri.parse(apiUrl),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        await secureStorageService.removeToken('Bearer');
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.remove('user');
        emit(AuthState.initial());
      } else {
        throw Exception('Failed to logout');
      }
    } catch (error) {
      emit(state.copyWith(status: 'failed'));
    }
  }

  Future<void> _onAuthStatusChanged(
      AuthStatusChanged event, Emitter<AuthState> emit) async {
    emit(state.copyWith(user: event.user));
  }

  Future<void> _onCheckAuthStatus(
      CheckAuthStatus event, Emitter<AuthState> emit) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? userJson = prefs.getString('user');
    if (userJson != null) {
      final user = jsonDecode(userJson);
      emit(state.copyWith(
          isAuthenticated: true, user: user, status: 'succeeded'));
    } else {
      emit(AuthState.initial());
    }
  }
}
