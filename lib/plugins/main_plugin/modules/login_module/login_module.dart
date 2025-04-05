import 'package:flutter/material.dart';
import 'package:recall/plugins/main_plugin/modules/connections_api_module/connections_api_module.dart';
import 'package:provider/provider.dart';
import '../../../../core/00_base/module_base.dart';
import '../../../../core/managers/module_manager.dart';
import '../../../../core/managers/services_manager.dart';
import '../../../../core/services/shared_preferences.dart';
import '../../../../tools/logging/logger.dart';
import '../../../../core/managers/state_manager.dart';

class LoginModule extends ModuleBase {
  static final Logger _log = Logger(); // ✅ Static logger for logging

  late ModuleManager _moduleManager;
  late ServicesManager _servicesManager;
  SharedPrefManager? _sharedPref;
  ConnectionsApiModule? _connectionModule;
  BuildContext? _currentContext;

  /// ✅ Constructor - Initializes the module
  LoginModule() : super("login_module") {
    _log.info('✅ LoginModule initialized.');
  }

  /// ✅ Fetch dependencies once per context
  void _initDependencies(BuildContext context) {
    _moduleManager = Provider.of<ModuleManager>(context, listen: false);
    _servicesManager = Provider.of<ServicesManager>(context, listen: false);
    _sharedPref = _servicesManager.getService<SharedPrefManager>('shared_pref');
    _connectionModule = _moduleManager.getLatestModule<ConnectionsApiModule>();
    _currentContext = context;
  }

  Future<Map<String, dynamic>> getUserStatus(BuildContext context) async {
    _initDependencies(context);

    if (_sharedPref == null) {
      _log.error("❌ SharedPrefManager not available.");
      return {"error": "Service not available."};
    }

    bool isLoggedIn = _sharedPref!.getBool('is_logged_in') ?? false;

    if (!isLoggedIn) {
      return {"status": "logged_out"};
    }

    return {
      "status": "logged_in",
      "user_id": _sharedPref!.getInt('user_id'),
      "username": _sharedPref!.getString('username'),
      "email": _sharedPref!.getString('email'),
    };
  }

  Future<Map<String, dynamic>> registerUser({
    required BuildContext context,
    required String username,
    required String email,
    required String password,
  }) async {
    _initDependencies(context);

    if (_connectionModule == null) {
      _log.error("❌ Connection module not available.");
      return {"error": "Service not available."};
    }

    try {
      _log.info("⚡ Sending registration request...");
      _log.info("📤 Registration data: username=$username, email=$email");
      
      final response = await _connectionModule!.sendPostRequest(
        "/register",
        {
          "username": username,
          "email": email,
          "password": password,
        },
      );

      _log.info("📥 Registration response: $response");

      if (response is Map) {
        if (response["message"] == "User registered successfully") {
          _log.info("✅ User registered successfully.");
          return {"success": "Registration successful. Please log in."};
        } else if (response["error"] != null) {
          _log.error("❌ Registration failed: ${response["error"]}");
          return {"error": response["error"]};
        }
      }

      _log.error("❌ Unexpected response format: $response");
      return {"error": "Unexpected server response format"};
    } catch (e) {
      _log.error("❌ Registration error: $e");
      return {"error": "Server error. Check network connection."};
    }
  }

  Future<Map<String, dynamic>> loginUser({
    required BuildContext context,
    required String email,
    required String password,
  }) async {
    _initDependencies(context);

    if (_connectionModule == null || _sharedPref == null) {
      _log.error("❌ Missing required modules.");
      return {"error": "Service not available."};
    }

    try {
      _log.info("⚡ Sending login request...");
      final response = await _connectionModule!.sendPostRequest(
        "/login",
        {"email": email, "password": password},
      );

      if (response?["message"] == "Login successful" && response?["user"]?["id"] != null) {
        final user = response!["user"];
        final tokens = response!["tokens"];

        // Store non-sensitive user data in SharedPrefs
        _sharedPref!.setString('email', email);
        _sharedPref!.setString('username', user["username"]);
        _sharedPref!.setInt('user_id', user["id"]);
        _sharedPref!.setBool('is_logged_in', true);

        // Store sensitive tokens in secure storage
        await _connectionModule!.updateAuthTokens(
          accessToken: tokens["access_token"],
          refreshToken: tokens["refresh_token"],
        );

        return {"success": "Login Successful!"};
      } else {
        return {"error": response?["error"] ?? "Invalid email or password."};
      }
    } catch (e) {
      _log.error("❌ Login error: $e");
      return {"error": "Server error. Check network connection."};
    }
  }

  Future<Map<String, dynamic>> logoutUser(BuildContext context) async {
    _initDependencies(context);

    if (_connectionModule == null || _sharedPref == null) {
      _log.error("❌ Missing required modules.");
      return {"error": "Service not available."};
    }

    int? userId = _sharedPref!.getInt('user_id');
    if (userId == null) {
      _log.error("❌ No user ID found. Cannot logout.");
      return {"error": "User not logged in or ID missing."};
    }

    try {
      _log.info("⚡ Sending logout request...");
      final response = await _connectionModule!.sendPostRequest(
        "/logout",
        {"user_id": userId},
      );

      if (response?.containsKey('message') == true) {
        // Clear all stored data
        _sharedPref!.remove('user_id');
        _sharedPref!.remove('username');
        _sharedPref!.remove('email');
        _sharedPref!.remove('is_logged_in');
        _sharedPref!.remove('access_token');
        _sharedPref!.remove('refresh_token');

        // Clear connection module tokens
        _connectionModule!.clearAuthTokens();

        return {"success": "Logged out successfully!"};
      } else {
        return {"error": response?["error"] ?? "Failed to logout."};
      }
    } catch (e) {
      _log.error("❌ Logout error: $e");
      return {"error": "Server error. Check network connection."};
    }
  }

  Future<Map<String, dynamic>> refreshToken(BuildContext context) async {
    _initDependencies(context);

    if (_connectionModule == null || _sharedPref == null) {
      _log.error("❌ Missing required modules.");
      return {"error": "Service not available."};
    }

    String? refreshToken = _sharedPref!.getString('refresh_token');
    if (refreshToken == null) {
      _log.error("❌ No refresh token found.");
      return {"error": "No refresh token available."};
    }

    try {
      _log.info("⚡ Refreshing token...");
      final response = await _connectionModule!.sendPostRequest(
        "/refresh-token",
        {"refresh_token": refreshToken},
      );

      if (response?.containsKey('access_token') == true) {
        // Store new tokens
        _sharedPref!.setString('access_token', response!["access_token"]);
        _sharedPref!.setString('refresh_token', response["refresh_token"]);

        // Update connection module with new tokens
        _connectionModule!.updateAuthTokens(
          accessToken: response["access_token"],
          refreshToken: response["refresh_token"],
        );

        return {"success": "Token refreshed successfully!"};
      } else {
        return {"error": response?["error"] ?? "Failed to refresh token."};
      }
    } catch (e) {
      _log.error("❌ Token refresh error: $e");
      return {"error": "Server error. Check network connection."};
    }
  }

  Future<Map<String, dynamic>> deleteUser(BuildContext context) async {
    _initDependencies(context);

    if (_connectionModule == null || _sharedPref == null) {
      _log.error("❌ Missing required modules.");
      return {"error": "Service not available."};
    }

    int? userId = _sharedPref!.getInt('user_id');
    if (userId == null) {
      _log.error("❌ No user ID found. Cannot delete account.");
      return {"error": "User not logged in or ID missing."};
    }

    try {
      _log.info("⚡ Sending delete request for User ID: $userId...");
      final response = await _connectionModule!.sendPostRequest(
        "/delete-user",
        {"user_id": userId},
      );

      if (response?.containsKey('message') == true) {
        // Clear all stored data
        _sharedPref!.remove('user_id');
        _sharedPref!.remove('username');
        _sharedPref!.remove('email');
        _sharedPref!.remove('is_logged_in');
        _sharedPref!.remove('access_token');
        _sharedPref!.remove('refresh_token');

        // Clear connection module tokens
        _connectionModule!.clearAuthTokens();

        return {"success": "Account deleted successfully!"};
      } else {
        return {"error": response?["error"] ?? "Failed to delete account."};
      }
    } catch (e) {
      _log.error("❌ Error deleting user: $e");
      return {"error": "Server error. Check network connection."};
    }
  }

  /// Handles session expiration by logging out the user and updating state
  Future<void> handleSessionExpired() async {
    _log.info("🔄 Handling session expiration...");

    try {
      // 1. Call the logout endpoint
      await _connectionModule?.sendPostRequest("/logout", {"user_id": "current"});
      
      // 2. Clear local auth state
      await _connectionModule?.clearAuthTokens();
      
      // 3. Clear shared preferences
      await _sharedPref?.remove('user_id');
      await _sharedPref?.remove('username');
      await _sharedPref?.remove('email');
      await _sharedPref?.remove('is_logged_in');
      
      // 4. Update app state to reflect logged out status
      if (_currentContext != null) {
        final stateManager = Provider.of<StateManager>(_currentContext!, listen: false);
        stateManager.updateMainAppState('auth_status', 'logged_out');
        stateManager.updateMainAppState('user', null);
        
        // 5. Navigate to login screen
        Navigator.of(_currentContext!).pushNamedAndRemoveUntil('/login', (route) => false);
      }
      
      _log.info("✅ Session expiration handled successfully");
    } catch (e) {
      _log.error("❌ Error handling session expiration: $e");
    }
  }
}
