import 'package:dio/dio.dart';
import 'storage_service.dart';

class AuthInterceptor extends Interceptor {
  final Dio _dio;
  final StorageService _storage;
  bool _isRefreshing = false;
  final List<({RequestOptions options, ErrorInterceptorHandler handler})> _requestQueue = [];

  AuthInterceptor(this._dio, this._storage);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // Add access token to all requests
    final accessToken = _storage.getAccessToken();
    if (accessToken != null) {
      options.headers['Authorization'] = 'Bearer $accessToken';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    // Handle 401 Unauthorized (token expired or revoked)
    if (err.response?.statusCode == 401) {
      // Don't try to refresh if the error is from /auth/refresh or /auth/login
      final path = err.requestOptions.path;
      if (path.contains('/auth/refresh') || path.contains('/auth/login')) {
        // Clear tokens and proceed with error
        await _storage.deleteTokens();
        return handler.next(err);
      }

      // Try to refresh the token
      if (!_isRefreshing) {
        _isRefreshing = true;

        try {
          final refreshToken = _storage.getRefreshToken();
          if (refreshToken == null) {
            // No refresh token available, clear all and proceed with error
            await _storage.clearAll();
            _isRefreshing = false;
            return handler.next(err);
          }

          // Call refresh endpoint
          final response = await _dio.post(
            'http://localhost:8080/api/auth/refresh',
            data: {'refreshToken': refreshToken},
            options: Options(
              headers: {
                'Content-Type': 'application/json',
              },
            ),
          );

          // Save new tokens
          final newAccessToken = response.data['accessToken'] as String;
          final newRefreshToken = response.data['refreshToken'] as String;

          await _storage.saveTokens(
            accessToken: newAccessToken,
            refreshToken: newRefreshToken,
          );

          _isRefreshing = false;

          // Retry the original request
          final options = err.requestOptions;
          options.headers['Authorization'] = 'Bearer $newAccessToken';

          try {
            final retryResponse = await _dio.fetch(options);
            return handler.resolve(retryResponse);
          } catch (e) {
            return handler.next(err);
          }
        } catch (refreshError) {
          // Refresh failed, clear all tokens and logout
          await _storage.clearAll();
          _isRefreshing = false;
          return handler.next(err);
        }
      } else {
        // Another request is already refreshing, wait for it
        // This is a simplified approach - in production you'd queue the requests
        return handler.next(err);
      }
    }

    // For other errors, proceed normally
    handler.next(err);
  }
}
