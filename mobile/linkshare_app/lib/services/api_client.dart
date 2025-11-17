import 'package:dio/dio.dart';
import 'storage_service.dart';

class ApiClient {
  static const String baseUrl = 'http://localhost:8080/api'; // Change for production

  final Dio _dio;
  final StorageService _storage;

  ApiClient(this._storage) : _dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 30),
    headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    },
  )) {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        // Add auth token to all requests
        final token = _storage.getToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (error, handler) {
        // Handle 401 Unauthorized (token expired)
        if (error.response?.statusCode == 401) {
          // Could trigger logout here
          _storage.clearAll();
        }
        return handler.next(error);
      },
    ));
  }

  // Generic GET request
  Future<Response> get(String path, {Map<String, dynamic>? queryParameters}) async {
    return await _dio.get(path, queryParameters: queryParameters);
  }

  // Generic POST request
  Future<Response> post(String path, {dynamic data}) async {
    return await _dio.post(path, data: data);
  }

  // Generic PUT request
  Future<Response> put(String path, {dynamic data}) async {
    return await _dio.put(path, data: data);
  }

  // Generic DELETE request
  Future<Response> delete(String path) async {
    return await _dio.delete(path);
  }
}
