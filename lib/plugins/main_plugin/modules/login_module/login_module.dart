import 'package:flutter/material.dart';
import 'package:recall/plugins/main_plugin/modules/connections_api_module/connections_api_module.dart';
import 'package:provider/provider.dart';
import '../../../../core/00_base/module_base.dart';
import '../../../../core/managers/module_manager.dart';
import '../../../../core/managers/services_manager.dart';
import '../../../../core/services/shared_preferences.dart';
import '../../../../tools/logging/logger.dart';

class LoginModule extends ModuleBase {
  static final Logger _log = Logger(); // ✅ Static logger for logging

  late ModuleManager _moduleManager;
  late ServicesManager _servicesManager;
  SharedPrefManager? _sharedPref;
  ConnectionsApiModule? _connectionModule;

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
      final response = await _connectionModule!.sendPostRequest(
        "/register",
        {
          "username": username,
          "email": email,
          "password": password,
        },
      );

      if (response?["message"] == "User registered successfully") {
        _log.info("✅ User registered successfully.");
        return {"success": "Registration successful. Please log in."};
      } else {
        return {"error": response?["error"] ?? "Failed to register user."};
      }
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
        _sharedPref!.setString('email', email);
        _sharedPref!.setString('username', user["username"]);
        _sharedPref!.setInt('user_id', user["id"]);
        _sharedPref!.setBool('is_logged_in', true);

        return {"success": "Login Successful!"};
      } else {
        return {"error": response?["error"] ?? "Invalid email or password."};
      }
    } catch (e) {
      _log.error("❌ Login error: $e");
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
        _sharedPref!.remove('user_id');
        _sharedPref!.remove('username');
        _sharedPref!.remove('email');
        _sharedPref!.remove('is_logged_in');

        return {"success": "Account deleted successfully!"};
      } else {
        return {"error": response?["error"] ?? "Failed to delete account."};
      }
    } catch (e) {
      _log.error("❌ Error deleting user: $e");
      return {"error": "Server error. Check network connection."};
    }
  }
}
