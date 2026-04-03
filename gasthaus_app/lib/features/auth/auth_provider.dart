import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../core/models/user.dart';
import '../../core/services/api_service.dart';
import '../../core/services/auth_storage.dart';
import '../../core/services/socket_service.dart';

class AuthProvider extends ChangeNotifier {
  User? _currentUser;
  bool _isLoading = false;
  String? _error;

  User? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Called at app startup to restore saved session.
  /// Also connects the WebSocket so real-time features work without a fresh login.
  /// Without this, restoring a saved session skips login() entirely, meaning
  /// SocketService.connect() was never called and STOMP never connected —
  /// breaking all real-time updates (menu push, order status, etc.).
  Future<void> restoreSession() async {
    final token = await AuthStorage.instance.getToken();
    final user = await AuthStorage.instance.getUser();
    if (token != null && user != null) {
      _currentUser = user;
      // Connect WebSocket for restored sessions — same as we do after login().
      unawaited(SocketService.instance.connect());
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
      // Connect WebSocket after successful login so real-time order updates
      // are available immediately without waiting for the first order screen visit.
      unawaited(SocketService.instance.connect());
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
    // Disconnect WebSocket on logout so the server session is released
    // and we don't receive events for a different user on re-login.
    SocketService.instance.disconnect();
    _currentUser = null;
    notifyListeners();
  }

  String _extractMessage(Exception e) {
    // DioException wraps our ApiException inside its .error field.
    // The interceptor in ApiService constructs the DioException this way:
    //   DioException(error: ApiException(message: "..."), ...)
    // So we must unwrap one level to get the human-readable message.
    if (e is DioException && e.error is ApiException) {
      return (e.error as ApiException).message;
    }
    // Direct ApiException (shouldn't normally happen but safe to handle).
    if (e is ApiException) return e.message;
    // Fallback — never expose raw toString() / JSON to the user.
    return 'Something went wrong. Please try again.';
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
