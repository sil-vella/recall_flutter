import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import '../../../../../core/00_base/module_base.dart';
import '../../../../../core/managers/module_manager.dart';
import '../../../../../core/managers/services_manager.dart';
import '../../../../../core/services/shared_preferences.dart';
import '../../../../../tools/logging/logger.dart';

class InterstitialAdModule extends ModuleBase {
  static final Logger _log = Logger();
  final String adUnitId;
  InterstitialAd? _interstitialAd;
  bool _isAdReady = false;

  /// ✅ Constructor with module key
  InterstitialAdModule(this.adUnitId) : super("admobs_interstitial_ad_module");

  /// ✅ Loads the interstitial ad
  Future<void> loadAd() async {
    _log.info('📢 Loading Interstitial Ad for ID: $adUnitId');
    InterstitialAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isAdReady = true;
          _log.info('✅ Interstitial Ad Loaded for ID: $adUnitId.');
        },
        onAdFailedToLoad: (error) {
          _isAdReady = false;
          _log.error('❌ Failed to load Interstitial Ad for ID: $adUnitId. Error: ${error.message}');
        },
      ),
    );
  }

  /// ✅ Shows the interstitial ad
  Future<void> showAd(BuildContext context) async {
    final moduleManager = Provider.of<ModuleManager>(context, listen: false);
    final servicesManager = Provider.of<ServicesManager>(context, listen: false);
    final sharedPref = servicesManager.getService<SharedPrefManager>('shared_pref');

    if (sharedPref == null) {
      _log.error('❌ SharedPreferences service not available.');
      return;
    }

    if (_isAdReady && _interstitialAd != null) {
      _log.info('🎬 Showing Interstitial Ad for ID: $adUnitId');
      _interstitialAd!.show();
      _interstitialAd = null;
      _isAdReady = false;

      // ✅ Save ad view count
      int adViews = sharedPref.getInt('interstitial_ad_views') ?? 0;
      sharedPref.setInt('interstitial_ad_views', adViews + 1);

      // ✅ Preload next ad
      loadAd();
    } else {
      _log.error('❌ Interstitial Ad not ready for ID: $adUnitId.');
    }
  }

  /// ✅ Disposes of the interstitial ad
  @override
  void dispose() {
    _interstitialAd?.dispose();
    _interstitialAd = null;
    _log.info('🗑 Interstitial Ad Module disposed for ID: $adUnitId.');
    super.dispose();
  }
}
