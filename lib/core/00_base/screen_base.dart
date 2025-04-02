import 'package:recall/plugins/adverts_plugin/modules/admobs/banner/banner_ad.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../tools/logging/logger.dart';
import '../managers/app_manager.dart';
import '../managers/module_manager.dart';
import '../managers/navigation_manager.dart';
import '../../utils/consts/config.dart';
import '../../utils/consts/theme_consts.dart';
import 'drawer_base.dart';

abstract class BaseScreen extends StatefulWidget {
  const BaseScreen({Key? key}) : super(key: key);

  /// Define a method to compute the title dynamically
  String computeTitle(BuildContext context);

  @override
  BaseScreenState createState();
}

abstract class BaseScreenState<T extends BaseScreen> extends State<T> {
  late final AppManager appManager;
  final ModuleManager _moduleManager = ModuleManager();

  final Logger log = Logger();
  BannerAdModule? bannerAdModule;

  @override
  void initState() {
    super.initState();

    appManager = Provider.of<AppManager>(context, listen: false);
    bannerAdModule = _moduleManager.getLatestModule<BannerAdModule>();

    if (bannerAdModule != null) {
      bannerAdModule!.loadBannerAd(Config.admobsTopBanner);
      bannerAdModule!.loadBannerAd(Config.admobsBottomBanner);
      log.info('✅ Banner Ads preloaded.');
    } else {
      log.error("❌ BannerAdModule not found.");
    }
  }

  @override
  Widget build(BuildContext context) {
    final navigationManager = Provider.of<NavigationManager>(context);

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          widget.computeTitle(context),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.white),
        ),
        backgroundColor: AppColors.accentColor,
        iconTheme: const IconThemeData(color: AppColors.white),
      ),
      drawer:  CustomDrawer(), // ✅ Use the correct drawer

      body: Column(
        children: [
          // Display top banner dynamically
          if (bannerAdModule != null)
            Container(
              alignment: Alignment.center,
              child: bannerAdModule!.getBannerWidget(context, Config.admobsTopBanner),
            ),

          // The main content area that takes up all remaining space
          Expanded(
            child: buildContent(context), // The content between top and bottom banners
          ),

          // Display bottom banner dynamically
          if (bannerAdModule != null)
            Container(
              alignment: Alignment.center,
              child: bannerAdModule!.getBannerWidget(context, Config.admobsBottomBanner),
            ),
        ],
      ),
    );
  }

  /// Abstract method to be implemented in subclasses
  Widget buildContent(BuildContext context);
}
