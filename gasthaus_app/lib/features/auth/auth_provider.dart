import 'package:flutter/material.dart';
import '../../core/models/user.dart';
import '../../core/services/api_service.dart';
import '../../core/services/auth_storage.dart';

class AuthProvider extends ChangeNotifier {
  User? _currentUser;
  bool _isLoading = false;
  String? _error;

  User? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Called at app startup to restore saved session.
  Future<void> restoreSession() async {
    final token = await AuthStorage.instance.getToken();
    final user = await AuthStorage.instance.getUser();
    if (token != null && user != null) {
      _currentUser = user;
      notifyListeners();
    }
  }

  Future<void> login(String email, String password) async {
    _setLoading(true);
    try {
      final response = await ApiService.instance.dio.post('/auth/login', data: {
        'email': email,
        'password': password,
      });
      final data = response.data as Map<String, dynamic>;
      final token = data['token'] as String;
      final user = User.fromJson(data['user'] as Map<String, dynamic>);

      await AuthStorage.instance.saveToken(token);
      await AuthStorage.instance.saveUser(user);

      _currentUser = user;
      _error = null;
    } on Exception catch (e) {
      _error = _extractMessage(e);
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> register(String name, String email, String password) async {
    _setLoading(true);
    try {
      final response =
          await ApiService.instance.dio.post('/auth/register', data: {
        'name': name,
        'email': email,
        'password': password,
        'role': 'CUSTOMER',
      });
      final data = response.data as Map<String, dynamic>;
      final token = data['token'] as String;
      final user = User.fromJson(data['user'] as Map<String, dynamic>);

      await AuthStorage.instance.saveToken(token);
      await AuthStorage.instance.saveUser(user);

      _currentUser = user;
      _error = null;
    } on Exception catch (e) {
      _error = _extractMessage(e);
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> logout() async {
    await AuthStorage.instance.clear();
    _currentUser = null;
    notifyListeners();
  }

  String _extractMessage(Exception e) {
    if (e is ApiException) return e.message;
    return e.toString();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
