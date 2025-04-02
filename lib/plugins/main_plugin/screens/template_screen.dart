import 'package:flutter/material.dart';
import 'package:recall/core/managers/module_manager.dart';
import 'package:provider/provider.dart';
import '../../../../core/00_base/screen_base.dart';
import '../../../../core/managers/services_manager.dart';
import '../../../../tools/logging/logger.dart';
import '../../../core/services/shared_preferences.dart';

class TemplateScreen extends BaseScreen {
  const TemplateScreen({Key? key}) : super(key: key);

  @override
  String computeTitle(BuildContext context) {
    return "TemplateScreen";
  }

  @override
  TemplateScreenState createState() => TemplateScreenState();
}

class TemplateScreenState extends BaseScreenState<TemplateScreen> {
  final Logger logger = Logger();
  late ServicesManager _servicesManager;
  late ModuleManager _moduleManager;
  SharedPrefManager? _sharedPref;


  @override
  void initState() {
    super.initState();
    Logger().info("Initializing TemplateScreen...");

    // ✅ Retrieve managers and modules using Provider
    _servicesManager = Provider.of<ServicesManager>(context, listen: false);
    _moduleManager = Provider.of<ModuleManager>(context, listen: false);
    _sharedPref = _servicesManager.getService<SharedPrefManager>('shared_pref');

  }

  @override
  Widget buildContent(BuildContext context) {
    return Stack(
      children: [

      ],
    );
  }
}
