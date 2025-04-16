import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/00_base/screen_base.dart';
import '../../../../core/managers/module_manager.dart';
import '../../../../core/managers/services_manager.dart';
import '../../../../core/services/shared_preferences.dart';
import '../../../../tools/logging/logger.dart';
import '../../../../utils/consts/theme_consts.dart';
import '../../../game_plugin/modules/function_helper_module/function_helper_module.dart';
import '../../modules/login_module/login_module.dart';
import 'components/user_login.dart';
import 'components/user_register.dart';

class AccountScreen extends BaseScreen {
  const AccountScreen({Key? key}) : super(key: key);

  @override
  String computeTitle(BuildContext context) {
    return "Account";
  }

  @override
  AccountScreenState createState() => AccountScreenState();
}

class AccountScreenState extends BaseScreenState<AccountScreen> {
  final Logger logger = Logger();

  late ServicesManager _servicesManager;
  late ModuleManager _moduleManager;
  SharedPrefManager? _sharedPref;
  LoginModule? _loginModule;
  FunctionHelperModule? _functionHelperModule;


  bool _isLoggedIn = false;
  String? _username;
  String? _email;
  bool _showRegisterForm = false;
  int? _user_id;

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    logger.info("🔧 Initializing AccountScreen...");
    // ✅ Retrieve managers and modules using Provider
    _servicesManager = Provider.of<ServicesManager>(context, listen: false);
    _moduleManager = Provider.of<ModuleManager>(context, listen: false);
    _sharedPref = _servicesManager.getService<SharedPrefManager>('shared_pref');
    _loginModule = _moduleManager.getLatestModule<LoginModule>();
    _functionHelperModule =
        _moduleManager.getLatestModule<FunctionHelperModule>();

    if (_sharedPref == null) {
      logger.error('❌ SharedPreferences service not available.');
      return;
    }

    // Check login status when screen loads
    _fetchUserStatus();
  }

  /// Fetches user status and updates state
  Future<void> _fetchUserStatus() async {
    final userStatus = await _loginModule!.getUserStatus(context);

    if (userStatus["status"] == "logged_in") {
      setState(() {
        _isLoggedIn = true;
        _username = userStatus["username"];
        _email = userStatus["email"];
        _user_id = userStatus['user_id'];
      });
    } else {
      setState(() {
        _isLoggedIn = false;
        _username = null;
        _email = null;
        _user_id = null;
      });
    }
  }

  /// ✅ Handle user login
  Future<void> _loginUser() async {
    if (_loginModule == null) return;

    final response = await _loginModule!.loginUser(
      context: context,
      email: _emailController.text.trim(),
      password: _passwordController.text.trim(),
    );

    if (response.containsKey("success")) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(response["success"])),
      );
      await _fetchUserStatus();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(response["error"] ?? "Login failed."),
            backgroundColor: Colors.red),
      );
    }
  }

  /// ✅ Handle user logout
  Future<void> _logoutUser() async {
    if (_sharedPref == null || _loginModule == null) return;

    try {
      // Call backend logout endpoint
      final response = await _loginModule!.logoutUser(context);

      if (response.containsKey("message")) {
        setState(() {
          _isLoggedIn = false;
          _username = null;
          _email = null;
          _user_id = null;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Logged out successfully.")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response["error"] ?? "Failed to logout."),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      logger.error("❌ Error during logout: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Failed to logout. Please try again."),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// ✅ Show confirmation dialog before deleting the account
  Future<void> _confirmDeleteAccount() async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) =>
          AlertDialog(
            title: const Text("Delete Account"),
            content: const Text(
                "Are you sure you want to delete your account? This will undo all your progress"),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text("Cancel"),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                    "Delete", style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
    );

    if (shouldDelete == true) {
      await _deleteUser();
    }
  }

  Future<void> _deleteUser() async {
    if (_loginModule == null || _functionHelperModule == null) return;

    try {
      log.info("🧹 Deleting user...");
      final response = await _loginModule!.deleteUser(context);

      if (response.containsKey("success")) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response["success"])),
        );
        await _functionHelperModule!.clearUserProgress(context);
        await _logoutUser();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(response["error"] ?? "Failed to delete account."),
              backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      log.error("❌ Error deleting user: $e");
    }
  }

  @override
  Widget buildContent(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),

            _isLoggedIn
                ? _buildUserSection()
                : _showRegisterForm
                ? RegisterWidget(
              onRegister: (username, email, password) async {
                final result = await _loginModule!.registerUser(
                  context: context, // ✅ Pass context here
                  username: username,
                  email: email,
                  password: password,
                );

                if (result.containsKey("success")) {
                  await _fetchUserStatus();
                  setState(() => _showRegisterForm = false);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(result["error"] ?? "Registration failed."),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              onBackToLogin: () => setState(() => _showRegisterForm = false),
            )
                : LoginWidget(
              emailController: _emailController,
              passwordController: _passwordController,
              onLogin: _loginUser,
              onRegisterToggle: () => setState(() => _showRegisterForm = true),
            ),

          ],
        ),
      ),
    );
  }

  /// ✅ Improved User Info Section with Card Layout
  Widget _buildUserSection() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      color: AppColors.primaryColor,
      elevation: 4,
      margin: AppPadding.defaultPadding,
      child: Padding(
        padding: AppPadding.cardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Account Details",
              style: AppTextStyles.headingMedium(color: AppColors.accentColor),
            ),
            const Divider(
              color: AppColors.lightGray,
              thickness: 1,
            ),
            const SizedBox(height: 10),
            Text(
              "👤 Username: $_username",
              style: AppTextStyles.bodyMedium,
            ),
            Text(
              "📧 Email: $_email",
              style: AppTextStyles.bodyMedium,
            ),
            const SizedBox(height: 20),

            // Action Buttons - Logout & Delete
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Logout Button
                OutlinedButton(
                  onPressed: _logoutUser,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.accentColor,
                    side: const BorderSide(color: AppColors.accentColor),
                  ),
                  child: const Text("Logout"),
                ),

                // Delete Account Button
                ElevatedButton(
                  onPressed: _confirmDeleteAccount,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.redAccent,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text(
                    "Delete Account",
                    style: AppTextStyles.buttonText,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}