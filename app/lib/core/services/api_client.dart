import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../constants/backend_config.dart';
import '../errors/app_errors.dart';
import 'request_log.dart';
export '../errors/app_errors.dart';

/// The sole HTTP entry point. Keep API keys on the server, never in this app.
class ApiClient {
  ApiClient._() {
    final resolved = resolveBackendUrl(
      dartDefineUrl: const String.fromEnvironment('BACKEND_URL'),
      dotenvUrl: dotenv.isInitialized ? dotenv.env['BACKEND_URL'] : null,
    );
    _dio = Dio(BaseOptions(
      baseUrl: resolved,
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 60),
      headers: {'Accept': 'application/json'},
      validateStatus: (s) => s != null && s < 500,
    ));
    _dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      options.headers['Accept-Language'] = _language;
      handler.next(options);
    }));
  }
  static final ApiClient instance = ApiClient._();
  late final Dio _dio;
  String _language = 'en';
  void setLanguage(String value) => _language = value;
  String get baseUrl => _dio.options.baseUrl;

  Future<Map<String, dynamic>> get(String path, {Map<String, dynamic>? query}) async {
    final started = DateTime.now();
    final sw = Stopwatch()..start();
    try {
      final response = await _dio.get<Map<String, dynamic>>(path, queryParameters: query);
      final status = response.statusCode ?? 0;
      if (status >= 400) {
        throw DioException(requestOptions: response.requestOptions, response: response, type: DioExceptionType.badResponse);
      }
      final body = response.data ?? const {};
      _log(started, sw, 'GET', path, query, status: status, body: body);
      return body;
    } on DioException catch (error) {
      final mapped = _map(error);
      _log(started, sw, 'GET', path, query, status: error.response?.statusCode, error: mapped.toString());
      throw mapped;
    }
  }

  Future<Map<String, dynamic>> post(String path, {Object? data}) async {
    final started = DateTime.now();
    final sw = Stopwatch()..start();
    try {
      final response = await _dio.post<Map<String, dynamic>>(path, data: data);
      final status = response.statusCode ?? 0;
      if (status >= 400) {
        throw DioException(requestOptions: response.requestOptions, response: response, type: DioExceptionType.badResponse);
      }
      final body = response.data ?? const {};
      _log(started, sw, 'POST', path, const {}, status: status, body: body);
      return body;
    } on DioException catch (error) {
      final mapped = _map(error);
      _log(started, sw, 'POST', path, const {}, status: error.response?.statusCode, error: mapped.toString());
      throw mapped;
    }
  }

  void _log(DateTime started, Stopwatch sw, String method, String path, Map<String, dynamic>? query,
      {int? status, Map<String, dynamic>? body, String? error}) {
    if (RequestLog.active == null) return;
    String? summary;
    if (body != null) {
      final parts = <String>[];
      final prov = body['provenance'];
      final source = body['selected_source'] ?? (prov is Map ? prov['selected_source'] : null) ?? body['source'];
      if (source != null) parts.add('source=$source');
      final run = prov is Map ? prov['run_id'] : body['run_id'];
      if (run != null) parts.add('run=$run');
      if (body['status'] != null) parts.add('status=${body['status']}');
      if (body['hourly'] is List) parts.add('hourly=${(body['hourly'] as List).length}');
      if (body['daily'] is List) parts.add('daily=${(body['daily'] as List).length}');
      if (body['forecast'] is List) parts.add('forecast=${(body['forecast'] as List).length}');
      if (body['degraded'] == true) parts.add('DEGRADED');
      summary = parts.isEmpty ? null : parts.join(' · ');
    }
    RequestLog.record(RequestLogEntry(
      startedAt: started,
      method: method,
      path: path,
      query: query ?? const {},
      statusCode: status,
      durationMs: sw.elapsedMilliseconds,
      error: error,
      summary: summary,
    ));
  }

  AppApiError _map(DioException error) {
    if (error.type == DioExceptionType.receiveTimeout) {
      return const NetworkError('WeatherGPT is taking longer than usual. Please try again in a moment.');
    }
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.connectionError) {
      return const NetworkError('Could not reach WeatherGPT. Check your connection and try again.');
    }
    final status = error.response?.statusCode ?? 0;
    if (status == 400 || status == 422) return ValidationError(_detail(error) ?? 'Please check the requested weather data.');
    return ServerError(_detail(error) ?? 'WeatherGPT is temporarily unavailable. Please try again.');
  }
  String? _detail(DioException error) {
    final data = error.response?.data;
    if (data is Map) {
      if (data['detail'] != null) return '${data['detail']}';
      if (data['message'] != null) return '${data['message']}';
    }
    return null;
  }
}
