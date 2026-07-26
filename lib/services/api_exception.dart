import 'package:dio/dio.dart';

/// Normalized API error surfaced to the UI. Mirrors the backend error envelope
/// `{ success:false, message, code?, errors? }`.
class ApiException implements Exception {
  ApiException(this.message, {this.statusCode, this.code, this.fieldErrors});

  final String message;
  final int? statusCode;
  final String? code;
  final Map<String, String>? fieldErrors;

  factory ApiException.fromDio(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['message'] is String) {
      Map<String, String>? fields;
      if (data['errors'] is List) {
        fields = {
          for (final item in (data['errors'] as List))
            if (item is Map && item['field'] != null)
              item['field'].toString(): item['message'].toString(),
        };
      }
      return ApiException(
        data['message'] as String,
        statusCode: e.response?.statusCode,
        code: data['code'] as String?,
        fieldErrors: fields,
      );
    }
    return ApiException(
      _fallbackMessage(e),
      statusCode: e.response?.statusCode,
    );
  }

  static String _fallbackMessage(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return 'Connection timed out. Please try again.';
      case DioExceptionType.connectionError:
        return 'Cannot reach the server. Check your connection.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }

  @override
  String toString() => message;
}
