import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/00_base/screen_base.dart';
import '../../../../core/managers/module_manager.dart';
import '../../../../core/managers/navigation_manager.dart';
import '../../../../core/managers/services_manager.dart';
import '../../../../core/services/shared_preferences.dart';
import '../../../../tools/logging/logger.dart';
import '../../../../utils/consts/theme_consts.dart';
import '../../../game_plugin/modules/function_helper_module/function_helper_module.dart';
import '../../modules/login_module/login_module.dart';
import 'components/user_login.dart';
import 'components/user_register.dart';

class PreferencesScreen extends BaseScreen {
  const PreferencesScreen({Key? key}) : super(key: key);

  @override
  String computeTitle(BuildContext context) {
    return "Profile";
  }

  @override
  PreferencesScreenState createState() => PreferencesScreenState();
}

class PreferencesScreenState extends BaseScreenState<PreferencesScreen> {
  final Logger logger = Logger();

  late ServicesManager _servicesManager;
  late ModuleManager _moduleManager;
  FunctionHelperModule? _functionHelperModule;
  SharedPrefManager? _sharedPref;

  String? _selectedCategory = "Mixed"; // Stores the currently selected category

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    logger.info("🔧 Initializing PreferencesScreen...");

    // ✅ Retrieve managers and modules using Provider
    _servicesManager = Provider.of<ServicesManager>(context, listen: false);
    _moduleManager = Provider.of<ModuleManager>(context, listen: false);

    _functionHelperModule =
        _moduleManager.getLatestModule<FunctionHelperModule>();
    _sharedPref = _servicesManager.getService<SharedPrefManager>('shared_pref');

    if (_sharedPref == null) {
      logger.error('❌ SharedPreferences service not available.');
      return;
    }

    _loadSelectedCategory();
  }

  /// ✅ Fetch stored category selection from SharedPreferences
  Future<void> _loadSelectedCategory() async {
    if (_sharedPref == null) return;

    final savedCategory = _sharedPref!.getString('category') ?? "Mixed";

    setState(() {
      _selectedCategory = savedCategory;
    });

    logger.info("📊 Loaded selected category: $_selectedCategory");
  }

  /// ✅ Handle category selection & update SharedPreferences
  Future<void> _updateCategory(String category) async {
    if (_sharedPref == null) return;

    await _sharedPref!.setString('category', category);

    setState(() {
      _selectedCategory = category;
    });

    logger.info("✅ Selected Category Updated: $category");
    Navigator.pop(context); // Close modal after selection
  }

  /// ✅ UI for showing category selection modal
  void _showCategorySelector() async {
    if (_sharedPref == null) return;

    // ✅ Fetch categories from SharedPreferences
    List<String> categories = _sharedPref!.getStringList(
        'available_categories');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16.0),
          height: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Select Category",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Divider(),
              Expanded(
                child: ListView.builder(
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    final category = categories[index];
                    final formattedCategory = _formatCategory(category);
                    return ListTile(
                      title: Text(formattedCategory),
                      trailing: _selectedCategory == category
                          ? const Icon(Icons.check, color: Colors.green)
                          : null,
                      onTap: () => _updateCategory(category),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// ✅ Helper function to format category names
  String _formatCategory(String category) {
    return category.replaceAll("_", " ").splitMapJoin(
      RegExp(r'(\w+)'),
      onMatch: (m) => m[0]![0].toUpperCase() + m[0]!.substring(1).toLowerCase(),
    );
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

            // ✅ Select Category Button
            OutlinedButton.icon(
              onPressed: _showCategorySelector,
              icon: const Icon(Icons.category, color: AppColors.accentColor),
              label: Text(
                "Selected Category: ${_formatCategory(_selectedCategory!)}",
                style: AppTextStyles.buttonText,
              ),
            ),
            const SizedBox(height: 10),

          ],
        ),
      ),
    );
  }

}