import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  final FlutterSecureStorage _storage = FlutterSecureStorage();

  Future<void> saveToken(String tokenKey, String tokenValue) async {
    await _storage.write(key: tokenKey, value: tokenValue);
  }

  Future<String?> getToken(String tokenKey) async {
    return await _storage.read(key: tokenKey);
  }

  Future<void> removeToken(String tokenKey) async {
    await _storage.delete(key: tokenKey);
  }
}