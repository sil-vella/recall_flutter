import 'package:recall/plugins/main_plugin/modules/animations_module/animations_module.dart';
import 'package:flutter/material.dart';
import 'package:flutter/animation.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/00_base/screen_base.dart';
import '../../../core/managers/app_manager.dart';
import '../../../core/managers/module_manager.dart';
import '../../../core/managers/services_manager.dart';
import '../../../core/managers/state_manager.dart';
import '../../../core/services/shared_preferences.dart';
import '../../../tools/logging/logger.dart';
import '../../../utils/consts/theme_consts.dart';
import '../../game_plugin/modules/function_helper_module/function_helper_module.dart';
import '../modules/login_module/login_module.dart';
import '../modules/main_helper_module/main_helper_module.dart'; // ✅ Import Helper Module

class HomeScreen extends BaseScreen {
  const HomeScreen({Key? key}) : super(key: key);


  @override
  String computeTitle(BuildContext context) {
    return "Home";
  }

  @override
  HomeScreenState createState() => HomeScreenState();
}

class HomeScreenState extends BaseScreenState<HomeScreen>
    with SingleTickerProviderStateMixin {

  final Logger logger = Logger();
  late AnimationController _controller;
  late String _backgroundImage; // ✅ Stores the background image

  late ServicesManager _servicesManager;
  late ModuleManager _moduleManager;
  FunctionHelperModule? _functionHelperModule;
  SharedPrefManager? _sharedPref;
  LoginModule? _loginModule;

  bool _isLoggedIn = false;
  String? _username;
  String? _email;
  int? _user_id;
  bool _showRegisterForm = false;
  String? _selectedCategory = "Mixed"; // Stores the currently selected category

  @override
  void initState() {
    super.initState();

    // ✅ Retrieve managers and modules using Provider
    _servicesManager = Provider.of<ServicesManager>(context, listen: false);
    _moduleManager = Provider.of<ModuleManager>(context, listen: false);
    _sharedPref = _servicesManager.getService<SharedPrefManager>('shared_pref');
    _loginModule = _moduleManager.getLatestModule<LoginModule>();

    if (_sharedPref == null || _loginModule == null) {
      logger.error('❌ SharedPreferences or LoginModule not available.');
      return;
    }

    // ✅ Fetch user status
    _fetchUserStatus();

    // ✅ Set a random background on screen load
    _backgroundImage = MainHelperModule.getRandomBackground();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true); // Infinite bouncing effect
  }

  /// Fetches user status and updates state
  void _fetchUserStatus() async {
    final userStatus = await _loginModule!.getUserStatus(context);

    if (userStatus["is_logged_in"] == true) {
      setState(() {
        _isLoggedIn = true;
        _username = userStatus["username"];
        _email = userStatus["email"];
        _user_id = userStatus['user_id'];
      });
    } else {
      setState(() {
        _isLoggedIn = false;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget buildContent(BuildContext context) {
    final animationsModule = _moduleManager.getLatestModule<AnimationsModule>();
    final stateManager = Provider.of<StateManager>(context, listen: false);

    // Update state and navigate when Play button is pressed
    void onPlayPressed() {
      stateManager.updateMainAppState('main_state', 'in_play');
      context.go('/game'); // ✅ Use GoRouter navigation
    }

    // Navigate to account screen if not logged in
    void onLoginPressed() {
      context.go('/account'); // ✅ Redirect to account page
    }

    if (animationsModule == null) {
      return const Center(child: Text("Required modules are not available."));
    }

    return Stack(
      children: [
        // ✅ Full-Screen Background Image
        Positioned.fill(
          child: _backgroundImage.isNotEmpty
              ? Image.asset(
            _backgroundImage,
            fit: BoxFit.cover,
          )
              : Container(color: Colors.black), // Fallback background
        ),

        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ✅ Apply the side-to-side animation
              animationsModule.applySideToSideAnimation(
                child: Image.asset(
                  'assets/images/head.png', // Replace with your actual asset path
                  width: 200, // Adjust size as needed
                  height: 200,
                ),
                controller: _controller,
              ),
              const SizedBox(height: 20),

              // ✅ Show Login button if not logged in, else show Play button
              ElevatedButton(
                onPressed: _isLoggedIn ? onPlayPressed : onLoginPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.white, // 🎨 White background
                  foregroundColor: AppColors.accentColor, // 📝 Text color
                  padding: const EdgeInsets.symmetric(
                      vertical: 14, horizontal: 24),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(
                  _isLoggedIn ? 'Play' : 'Login',
                  style: AppTextStyles.buttonText
                      .copyWith(color: AppColors.accentColor),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

}
