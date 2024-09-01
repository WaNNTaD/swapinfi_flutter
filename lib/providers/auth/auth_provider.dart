import 'dart:convert';
import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthProvider with ChangeNotifier {
  User? _user;
  bool _isLoggedIn = false;

  User? get user => _user;
  bool get isLoggedIn => _isLoggedIn;

  void login(User user) {
    _user = user;
    print('User: $user');
    _isLoggedIn = true;
    saveUser(user);
    notifyListeners();
  }

  void logout() {
    _user = null;
    _isLoggedIn = false;
    notifyListeners();
  }

  Future<void> saveUser(User user) async {
    final prefs = await SharedPreferences.getInstance();

    prefs.setString('userId', user.id.toString());
    prefs.setString('userName', user.name);
    prefs.setString('userEmail', user.email);
  }

  Future<void> fetchUser(String userId) async {
    final response = await http
        .get(Uri.parse('https://api_swapinfi.lebourbier.be/api/user/$userId'));

    if (response.statusCode == 200) {
      // Si le serveur retourne une réponse OK, parsez le JSON.
      _user = User.fromJson(jsonDecode(response.body));
      _isLoggedIn = true;
    } else {
      // Si cette réponse n'est pas OK, lancez une exception.
      throw Exception('Failed to load user');
    }

    notifyListeners();
  }
}
