import 'package:flutter/material.dart';
import 'package:recall/core/managers/module_manager.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/00_base/screen_base.dart';
import '../../../../core/managers/services_manager.dart';
import '../../../../core/services/shared_preferences.dart';
import '../../../../tools/logging/logger.dart';
import '../../../../utils/consts/theme_consts.dart';

class ActivityScreen extends BaseScreen {
  const ActivityScreen({Key? key}) : super(key: key);

  @override
  String computeTitle(BuildContext context) {
    return "Activity";
  }

  @override
  ActivityScreenState createState() => ActivityScreenState();
}

class ActivityScreenState extends BaseScreenState<ActivityScreen> {
  final Logger logger = Logger();
  late ServicesManager _servicesManager;
  late ModuleManager _moduleManager;
  SharedPrefManager? _sharedPref;

  List<String> _pendingInvites = [];
  List<String> _activeGames = [];
  List<String> _ongoingGames = [];

  @override
  void initState() {
    super.initState();
    Logger().info("Initializing ActivityScreen...");

    _servicesManager = Provider.of<ServicesManager>(context, listen: false);
    _moduleManager = Provider.of<ModuleManager>(context, listen: false);
    _sharedPref = _servicesManager.getService<SharedPrefManager>('shared_pref');

    _fetchActivityData();
  }

  void _fetchActivityData() {
    if (_sharedPref == null) {
      logger.error('❌ SharedPreferences service not available.');
      return;
    }

    setState(() {
      _pendingInvites = _sharedPref!.getStringList("pending_invites") ?? [];
      _activeGames = _sharedPref!.getStringList("active_games") ?? [];
      _ongoingGames = _sharedPref!.getStringList("ongoing_games") ?? [];
    });

    logger.info("🎮 Loaded Activity Data: Pending: ${_pendingInvites.length}, Active: ${_activeGames.length}, Ongoing: ${_ongoingGames.length}");
  }

  @override
  Widget buildContent(BuildContext context) {
    return Padding(
      padding: AppPadding.defaultPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSection("Pending Invites", _pendingInvites),
          const SizedBox(height: 20),
          _buildSection("Active Games", _activeGames),
          const SizedBox(height: 20),
          _buildSection("Ongoing Games", _ongoingGames),
          const SizedBox(height: 30),
          Center(
            child: ElevatedButton(
              onPressed: () => context.go('/create-game'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentColor,
                foregroundColor: AppColors.white,
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text("Create Game", style: AppTextStyles.buttonText),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<String> items) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      color: AppColors.primaryColor,
      elevation: 4,
      child: Padding(
        padding: AppPadding.cardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: AppTextStyles.headingMedium(color: AppColors.accentColor2),
            ),
            const Divider(color: AppColors.lightGray, thickness: 1),
            items.isEmpty
                ? Text("None", style: AppTextStyles.bodyLarge)
                : Column(
              children: items.map((item) {
                return ListTile(
                  title: Text(item, style: AppTextStyles.bodyMedium),
                  leading: const Icon(Icons.notifications, color: AppColors.accentColor2),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.lightGray),
                  onTap: () {
                    logger.info("Tapped on: $item");
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
