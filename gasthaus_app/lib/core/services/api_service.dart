import 'package:dio/dio.dart';
import 'auth_storage.dart';

class ApiException implements Exception {
  final int? statusCode;
  final String message;

  ApiException({this.statusCode, required this.message});

  @override
  String toString() => message;
}

class ApiService {
  ApiService._();
  static final ApiService instance = ApiService._();

  // Use 10.0.2.2 for Android emulator to reach host machine's localhost
  static const String _baseUrl = 'http://10.0.2.2:8080/api';

  late final Dio _dio = Dio(BaseOptions(
    baseUrl: _baseUrl,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
    headers: {'Content-Type': 'application/json'},
  ))
    ..interceptors.add(_AuthInterceptor())
    ..interceptors.add(_ErrorInterceptor());

  Dio get dio => _dio;
}

class _AuthInterceptor extends Interceptor {
  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await AuthStorage.instance.getToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }
}

class _ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final response = err.response;
    String message;

    if (response != null) {
      final data = response.data;
      if (data is Map && data['message'] != null) {
        final raw = data['message'];
        message = raw is List ? raw.first.toString() : raw.toString();
      } else {
        message = _defaultMessage(response.statusCode);
      }
      handler.reject(
        DioException(
          requestOptions: err.requestOptions,
          error: ApiException(
            statusCode: response.statusCode,
            message: message,
          ),
          response: response,
          type: err.type,
        ),
      );
    } else {
      handler.reject(
        DioException(
          requestOptions: err.requestOptions,
          error: ApiException(
            message: 'No internet connection. Please check your network.',
          ),
          type: err.type,
        ),
      );
    }
  }

  String _defaultMessage(int? code) {
    switch (code) {
      case 400:
        return 'Invalid request. Please check your input.';
      case 401:
        return 'Session expired. Please sign in again.';
      case 403:
        return 'You do not have permission to do that.';
      case 404:
        return 'Resource not found.';
      case 409:
        return 'A conflict occurred. The resource may already exist.';
      case 500:
        return 'Server error. Please try again later.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }
}
