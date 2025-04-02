import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:recall/core/managers/module_manager.dart';
import '../../../../core/00_base/screen_base.dart';
import '../../../../core/managers/services_manager.dart';
import '../../../../core/services/shared_preferences.dart';
import '../../../../tools/logging/logger.dart';
import '../../../../utils/consts/theme_consts.dart';
import '../../modules/leaderboard_module/leaderboard_module.dart';

class TimerModule extends BaseScreen {
  const TimerModule({Key? key}) : super(key: key);

  @override
  String computeTitle(BuildContext context) {
    return "Leaderboard";
  }

  @override
  LeaderboardScreenState createState() => LeaderboardScreenState();
}

class LeaderboardScreenState extends BaseScreenState<TimerModule> {
  LeaderboardModule? _leaderboardModule;
  bool _isLoggedIn = false; // ✅ Track login state
  SharedPrefManager? _sharedPref;

  @override
  void initState() {
    super.initState();
    Logger().info("📊 Initializing LeaderboardScreen...");

    // ✅ Retrieve ModuleManager and SharedPrefManager
    final moduleManager = Provider.of<ModuleManager>(context, listen: false);
    final servicesManager = Provider.of<ServicesManager>(context, listen: false);

    _leaderboardModule = moduleManager.getLatestModule<LeaderboardModule>();
    _sharedPref = servicesManager.getService<SharedPrefManager>('shared_pref');

    if (_leaderboardModule == null) {
      Logger().error("❌ LeaderboardModule not found!");
    }

    _checkLoginStatus(); // ✅ Check if user is logged in
  }

  Future<void> _checkLoginStatus() async {
    if (_sharedPref == null) return;
    final isLoggedIn = _sharedPref!.getBool('is_logged_in') ?? false;

    setState(() {
      _isLoggedIn = isLoggedIn;
    });
  }

  @override
  Widget buildContent(BuildContext context) {
    return Stack(
      children: [
        // ✅ Background Color
        Container(
          color: AppColors.scaffoldBackgroundColor,
        ),

        // ✅ Show Message if User is Not Logged In
        if (!_isLoggedIn)
          Positioned(
            top: 40,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(12),
              width: double.infinity, // ✅ Ensures full width
              decoration: BoxDecoration(
                color: AppColors.darkGray.withOpacity(0.7), // ✅ Semi-transparent background
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min, // ✅ Prevents unnecessary height expansion
                children: [
                  Text(
                    "📢 Want to appear on the leaderboard?",
                    style: AppTextStyles.headingSmall(color: AppColors.accentColor),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),

                  // ✅ Make Text Tappable
                  GestureDetector(
                    onTap: () {
                      context.go("/preferences"); // ✅ Navigate to registration screen
                    },
                    child: Text(
                      "Register an account to compete with others and track your progress!",
                      style: AppTextStyles.bodyMedium.copyWith(
                        decoration: TextDecoration.underline, // ✅ Underline to indicate tap action
                        color: AppColors.white, // ✅ Use accent color for emphasis
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),

            ),
          ),


        // ✅ Display Leaderboard if Module Exists
        if (_leaderboardModule != null)
          Positioned.fill(
            top: 120,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: _leaderboardModule!.buildLeaderboardWidget(context),
            ),
          )
        else
          const Positioned.fill(
            child: Center(
              child: Text(
                "❌ Leaderboard Module Not Available",
                style: TextStyle(fontSize: 18, color: Colors.redAccent),
              ),
            ),
          ),
      ],
    );
  }
}
