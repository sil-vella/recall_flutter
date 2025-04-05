import 'dart:convert';
import 'dart:async';
import '../../../../../../tools/logging/logger.dart';
import '../../../../../../plugins/main_plugin/modules/connections_api_module/connections_api_module.dart';

class TokenManager {
  static final Logger _log = Logger();
  final ConnectionsApiModule _connectionModule;
  String? _currentToken;
  Timer? _tokenRefreshTimer;

  TokenManager(this._connectionModule);

  String? get currentToken => _currentToken;

  Future<String?> getValidToken() async {
    try {
      // Get token from secure storage
      String? token = await _connectionModule.getAccessToken();
      if (token == null) {
        _log.error("❌ No access token found in secure storage");
        return null;
      }

      // Check if token is expired
      if (_isTokenExpired(token)) {
        _log.info("🔄 Access token expired, refreshing...");
        // Try to refresh token
        token = await _refreshToken();
        if (token == null) {
          _log.error("❌ Failed to refresh token");
          return null;
        }
      }

      _currentToken = token;
      return token;
    } catch (e) {
      _log.error("❌ Error getting valid token: $e");
      return null;
    }
  }

  bool _isTokenExpired(String token) {
    try {
      // Decode token without verification
      final parts = token.split('.');
      if (parts.length != 3) return true;

      final payload = json.decode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))));
      final exp = payload['exp'] as int?;
      
      if (exp == null) return true;
      
      // Add 5 minutes buffer for token refresh
      return DateTime.now().millisecondsSinceEpoch >= (exp * 1000) - 300000;
    } catch (e) {
      _log.error("❌ Error checking token expiration: $e");
      return true;
    }
  }

  Future<String?> _refreshToken() async {
    try {
      // Get refresh token from secure storage
      String? refreshToken = await _connectionModule.getRefreshToken();
      if (refreshToken == null) {
        _log.error("❌ No refresh token available");
        return null;
      }

      // Try to refresh the token
      final response = await _connectionModule.refreshAccessToken(refreshToken);
      if (response == null) {
        _log.error("❌ Failed to refresh token");
        return null;
      }

      return response;
    } catch (e) {
      _log.error("❌ Error refreshing token: $e");
      return null;
    }
  }

  void startTokenRefreshTimer() {
    _stopTokenRefreshTimer();
    _tokenRefreshTimer = Timer.periodic(const Duration(minutes: 4), (timer) async {
      _log.info("🔄 Refreshing token...");
      await getValidToken();
    });
  }

  void _stopTokenRefreshTimer() {
    _tokenRefreshTimer?.cancel();
    _tokenRefreshTimer = null;
  }

  void dispose() {
    _stopTokenRefreshTimer();
    _currentToken = null;
  }
} 