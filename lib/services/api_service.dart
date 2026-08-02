import 'package:dio/dio.dart';

import '../config/constants.dart';
import 'api_exception.dart';
import 'storage_service.dart';

/// Central Dio HTTP client. Injects the JWT access token on every request and
/// transparently refreshes it on a 401 (TOKEN_EXPIRED), retrying once.
/// All widgets/providers call the backend through this — never raw Dio.
class ApiService {
  ApiService(this._storage, {Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: '${AppConstants.apiBaseUrl}${AppConstants.apiPrefix}',
                connectTimeout: const Duration(seconds: 15),
                receiveTimeout: const Duration(seconds: 20),
                contentType: 'application/json',
              ),
            ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _storage.accessToken;
          if (token != null && !options.headers.containsKey('X-Skip-Auth')) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          options.headers.remove('X-Skip-Auth');
          handler.next(options);
        },
        onError: (error, handler) async {
          final isExpired = error.response?.statusCode == 401 &&
              (error.response?.data is Map &&
                  error.response?.data['code'] == 'TOKEN_EXPIRED');
          if (isExpired && !_isRetry(error.requestOptions)) {
            final refreshed = await _tryRefresh();
            if (refreshed) {
              final clone = await _retry(error.requestOptions);
              return handler.resolve(clone);
            }
          }
          handler.next(error);
        },
      ),
    );
  }

  final Dio _dio;
  final StorageService _storage;

  /// Called when refresh fails so the app can route back to login.
  void Function()? onSessionExpired;

  bool _isRetry(RequestOptions o) => o.extra['__retried'] == true;

  Future<bool> _tryRefresh() async {
    final refreshToken = await _storage.refreshToken;
    if (refreshToken == null) return false;
    try {
      final res = await Dio(BaseOptions(baseUrl: _dio.options.baseUrl)).post(
        '/auth/refresh-token',
        data: {'refreshToken': refreshToken},
      );
      final access = res.data['data']['accessToken'] as String;
      await _storage.saveAccessToken(access);
      return true;
    } catch (_) {
      await _storage.clear();
      onSessionExpired?.call();
      return false;
    }
  }

  Future<Response<dynamic>> _retry(RequestOptions options) {
    options.extra['__retried'] = true;
    return _dio.fetch(options);
  }

  /// Unwraps the standard `{ success, data }` envelope, throwing [ApiException]
  /// on failure.
  Future<T> _unwrap<T>(Future<Response<dynamic>> future) async {
    try {
      final res = await future;
      return res.data['data'] as T;
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<T> get<T>(String path, {Map<String, dynamic>? query}) =>
      _unwrap<T>(_dio.get(path, queryParameters: query));

  Future<T> post<T>(String path, {Object? data, bool skipAuth = false}) =>
      _unwrap<T>(
        _dio.post(
          path,
          data: data,
          options: skipAuth ? Options(headers: {'X-Skip-Auth': true}) : null,
        ),
      );

  Future<T> put<T>(String path, {Object? data}) =>
      _unwrap<T>(_dio.put(path, data: data));

  Future<T> patch<T>(String path, {Object? data}) =>
      _unwrap<T>(_dio.patch(path, data: data));

  Future<T> delete<T>(String path) => _unwrap<T>(_dio.delete(path));

  /// Multipart upload of a single file under [field] (default `image`).
  Future<T> uploadFile<T>(
    String path,
    String filePath, {
    String field = 'image',
    String? contentType,
  }) async {
    final form = FormData.fromMap({
      field: await MultipartFile.fromFile(
        filePath,
        contentType:
            contentType != null ? DioMediaType.parse(contentType) : null,
      ),
    });
    return _unwrap<T>(_dio.post(path, data: form));
  }
}
