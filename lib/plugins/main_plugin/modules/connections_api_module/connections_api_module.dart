import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../../core/00_base/module_base.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:http_interceptor/http_interceptor.dart';
import '../../../../tools/logging/logger.dart';
import 'interceptor.dart';

class ConnectionsApiModule extends ModuleBase {
  static final Logger _log = Logger();
  final String baseUrl;

  /// ✅ Use InterceptedClient instead of normal `http`
  final InterceptedClient client = InterceptedClient.build(
    interceptors: [AuthInterceptor()],
    requestTimeout: const Duration(seconds: 10),
  );

  ConnectionsApiModule(this.baseUrl) : super('connections_module') {
    _log.info('🔌 ConnectionsModule initialized with baseUrl: $baseUrl');

    _sendTestRequest();
  }

  /// ✅ GET Request without manually adding tokens
  Future<dynamic> sendGetRequest(String route) async {
    final url = Uri.parse('$baseUrl$route');

    try {
      final response = await client.get(url);
      _log.info('📡 GET Request: $url | Status: ${response.statusCode}');
      return _processResponse(response);
    } catch (e) {
      return _handleError('GET', url, e);
    }
  }

  /// ✅ POST Request without manually adding tokens
  Future<dynamic> sendPostRequest(String route, Map<String, dynamic> data) async {
    final url = Uri.parse('$baseUrl$route');

    try {
      final response = await client.post(
        url,
        body: jsonEncode(data),
      );
      return _processResponse(response);
    } catch (e) {
      return _handleError('POST', url, e);
    }
  }

  /// ✅ Unified Request Method
  Future<dynamic> sendRequest(String route, {required String method, Map<String, dynamic>? data}) async {
    final url = Uri.parse('$baseUrl$route');
    http.Response response;

    try {
      switch (method.toUpperCase()) {
        case 'GET':
          response = await client.get(url);
          break;
        case 'POST':
          response = await client.post(url, body: jsonEncode(data ?? {}));
          break;
        case 'PUT':
          response = await client.put(url, body: jsonEncode(data ?? {}));
          break;
        case 'DELETE':
          response = await client.delete(url);
          break;
        default:
          throw Exception('❌ Unsupported HTTP method: $method');
      }

      _log.info('📡 $method Request: $url | Status: ${response.statusCode}');
      return _processResponse(response);
    } catch (e) {
      return _handleError(method, url, e);
    }
  }

  /// ✅ Process Server Response
  dynamic _processResponse(http.Response response) {
    if (response.body.isNotEmpty) {
      _log.debug('📥 Response Body: [Redacted for Security]');
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body);
    } else if (response.statusCode == 401) {
      _log.error('⚠️ Unauthorized: Clearing token...');
      const FlutterSecureStorage().delete(key: 'auth_token');
      return {"error": "Unauthorized"};
    } else {
      _log.error('⚠️ Server Error: ${response.statusCode}');
      return jsonDecode(response.body);
    }
  }

  /// ✅ Handle Errors with Detailed Logging
  Map<String, dynamic> _handleError(String method, Uri url, Object e) {
    _log.error('❌ $method request failed for $url: $e');
    return {"message": "$method request failed", "error": e.toString()};
  }

  void _sendTestRequest() async {
    final result = await sendGetRequest('/test');
    if (result is Map && result.containsKey("error")) {
      _log.error("🚨 /test request failed: ${result['error']}");
    } else {
      _log.info("✅ /test request successful: $result");
    }
  }
}