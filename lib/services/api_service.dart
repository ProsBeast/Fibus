import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:fibus/core/constants/api_endpoints.dart';

/// Generic outcome container for API operations.
class ApiResult<T> {
  /// Whether the request succeeded with a 2xx HTTP response.
  final bool isSuccess;

  /// Parsed response payload if [isSuccess] is true.
  final T? data;

  /// User-friendly error message if [isSuccess] is false.
  final String? errorMessage;

  /// HTTP status code returned by the server, if available.
  final int? statusCode;

  const ApiResult._({
    required this.isSuccess,
    this.data,
    this.errorMessage,
    this.statusCode,
  });

  /// Creates a successful result holding [data].
  factory ApiResult.success(T data, {int statusCode = 200}) {
    return ApiResult._(isSuccess: true, data: data, statusCode: statusCode);
  }

  /// Creates a failure result with an [errorMessage] and optional [statusCode].
  factory ApiResult.failure(String errorMessage, {int? statusCode, T? data}) {
    return ApiResult._(
      isSuccess: false,
      errorMessage: errorMessage,
      statusCode: statusCode,
      data: data,
    );
  }

  /// Convenience boolean inverse of [isSuccess].
  bool get isFailure => !isSuccess;

  /// Pattern matching utility.
  R fold<R>({
    required R Function(T data) onSuccess,
    required R Function(String error, int? statusCode) onFailure,
  }) {
    if (isSuccess && data != null) {
      return onSuccess(data as T);
    } else {
      return onFailure(errorMessage ?? 'Unknown error', statusCode);
    }
  }
}

/// HTTP API service communicating with the Vercel serverless backend.
///
/// Dispatches authenticated requests for trip lifecycle transitions,
/// route progress calculations, ETA calculations, and departure alert evaluations.
class ApiService {
  final http.Client _client;

  /// Timeout for all backend API requests.
  static const Duration requestTimeout = Duration(seconds: 15);

  /// Singleton instance.
  static final ApiService _instance = ApiService._internal();

  /// Factory constructor returning the singleton or injected instance.
  factory ApiService({http.Client? client}) {
    if (client != null) {
      return ApiService._internal(client: client);
    }
    return _instance;
  }

  ApiService._internal({http.Client? client})
    : _client = client ?? http.Client();

  // ---------------------------------------------------------------------------
  // Headers Helper
  // ---------------------------------------------------------------------------

  Map<String, String> _buildHeaders(String token) {
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // ---------------------------------------------------------------------------
  // Trip Lifecycle Endpoints
  // ---------------------------------------------------------------------------

  /// Initiates an authoritative tracking session for [busId] by [operatorUid].
  ///
  /// Calls `POST /trips/start` with Bearer auth token.
  Future<ApiResult<Map<String, dynamic>>> startTrip({
    required String busId,
    required String operatorUid,
    required String token,
  }) async {
    final url = Uri.parse('${ApiEndpoints.vercelBaseUrl}/trips/start');
    final body = jsonEncode({
      'busId': busId,
      'operatorUid': operatorUid,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });

    return _post(url, headers: _buildHeaders(token), body: body);
  }

  /// Concludes the active tracking session for [busId].
  ///
  /// Calls `POST /trips/stop` with Bearer auth token.
  Future<ApiResult<Map<String, dynamic>>> stopTrip({
    required String busId,
    required String operatorUid,
    required String token,
  }) async {
    final url = Uri.parse('${ApiEndpoints.vercelBaseUrl}/trips/stop');
    final body = jsonEncode({
      'busId': busId,
      'operatorUid': operatorUid,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });

    return _post(url, headers: _buildHeaders(token), body: body);
  }

  /// Claims tracking authority for [busId] from an inactive or stale operator session.
  ///
  /// Calls `POST /trips/takeover` with Bearer auth token.
  Future<ApiResult<Map<String, dynamic>>> takeoverTrip({
    required String busId,
    required String operatorUid,
    required String token,
  }) async {
    final url = Uri.parse('${ApiEndpoints.vercelBaseUrl}/trips/takeover');
    final body = jsonEncode({
      'busId': busId,
      'operatorUid': operatorUid,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });

    return _post(url, headers: _buildHeaders(token), body: body);
  }

  // ---------------------------------------------------------------------------
  // Location & Progress Processing
  // ---------------------------------------------------------------------------

  /// Submits a GPS fix to the server-side map-matching and ETA engine.
  ///
  /// Calls `POST /trips/process-location` with Bearer auth token.
  Future<ApiResult<Map<String, dynamic>>> processLocation({
    required String busId,
    required double lat,
    required double lng,
    required double speed,
    required double heading,
    required double accuracy,
    required String token,
  }) async {
    final url = Uri.parse(
      '${ApiEndpoints.vercelBaseUrl}/trips/process-location',
    );
    final body = jsonEncode({
      'busId': busId,
      'latitude': lat,
      'longitude': lng,
      'speed': speed,
      'heading': heading,
      'accuracy': accuracy,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });

    return _post(url, headers: _buildHeaders(token), body: body);
  }

  // ---------------------------------------------------------------------------
  // Departure & ETA Calculation
  // ---------------------------------------------------------------------------

  /// Requests the server to compute the commuter's latest leave-by time.
  ///
  /// Combines live bus ETA, Google Routes two-wheeler duration, target arrival buffer,
  /// and dynamic safety margins.
  ///
  /// Calls `GET /eta/calculate?busId=...&stopId=...&homeLat=...&homeLng=...`
  Future<ApiResult<Map<String, dynamic>>> computeLeaveTime({
    required String busId,
    required String stopId,
    required double homeLat,
    required double homeLng,
    required String token,
  }) async {
    final queryParams = {
      'busId': busId,
      'stopId': stopId,
      'homeLat': homeLat.toString(),
      'homeLng': homeLng.toString(),
    };

    final uri = Uri.parse(ApiEndpoints.calculateEta)
        .replace(queryParameters: queryParams);

    return _get(uri, headers: _buildHeaders(token));
  }

  // ---------------------------------------------------------------------------
  // Alert Session State Evaluation
  // ---------------------------------------------------------------------------

  /// Evaluates an active commuter alert session and triggers FCM notifications if due.
  ///
  /// Calls `POST /alerts/evaluate` with Bearer auth token.
  Future<ApiResult<Map<String, dynamic>>> evaluateAlerts({
    required String sessionId,
    required String token,
  }) async {
    final url = Uri.parse(ApiEndpoints.evaluateAlerts);
    final body = jsonEncode({
      'sessionId': sessionId,
      'evaluatedAt': DateTime.now().toIso8601String(),
    });

    return _post(url, headers: _buildHeaders(token), body: body);
  }

  // ---------------------------------------------------------------------------
  // Internal HTTP Execution Helpers
  // ---------------------------------------------------------------------------

  Future<ApiResult<Map<String, dynamic>>> _get(
    Uri uri, {
    required Map<String, String> headers,
  }) async {
    try {
      final response = await _client
          .get(uri, headers: headers)
          .timeout(requestTimeout);
      return _parseJsonResponse(response);
    } on SocketException catch (e) {
      return ApiResult.failure('Network connection error: ${e.message}');
    } on TimeoutException {
      return ApiResult.failure('Backend request timed out. Please try again.');
    } on FormatException catch (e) {
      return ApiResult.failure(
        'Malformed JSON response from server: ${e.message}',
      );
    } catch (e) {
      return ApiResult.failure('Unexpected network error: $e');
    }
  }

  Future<ApiResult<Map<String, dynamic>>> _post(
    Uri uri, {
    required Map<String, String> headers,
    required String body,
  }) async {
    try {
      final response = await _client
          .post(uri, headers: headers, body: body)
          .timeout(requestTimeout);

      return _parseJsonResponse(response);
    } on SocketException catch (e) {
      return ApiResult.failure('Network connection error: ${e.message}');
    } on TimeoutException {
      return ApiResult.failure('Backend request timed out. Please try again.');
    } on FormatException catch (e) {
      return ApiResult.failure(
        'Malformed JSON response from server: ${e.message}',
      );
    } catch (e) {
      return ApiResult.failure('Unexpected network error: $e');
    }
  }

  ApiResult<Map<String, dynamic>> _parseJsonResponse(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      final Map<String, dynamic> data = decoded is Map<String, dynamic>
          ? decoded
          : {'result': decoded};

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return ApiResult.success(data, statusCode: response.statusCode);
      } else {
        final errorMsg =
            data['error'] ??
            data['message'] ??
            'Request failed with HTTP status ${response.statusCode}.';
        return ApiResult.failure(
          errorMsg.toString(),
          statusCode: response.statusCode,
          data: data,
        );
      }
    } catch (e) {
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return ApiResult.success({
          'body': response.body,
        }, statusCode: response.statusCode);
      }
      return ApiResult.failure(
        'Server returned HTTP ${response.statusCode}: ${response.body}',
        statusCode: response.statusCode,
      );
    }
  }

  /// Disposes underlying HTTP client if needed.
  void dispose() {
    _client.close();
  }
}
