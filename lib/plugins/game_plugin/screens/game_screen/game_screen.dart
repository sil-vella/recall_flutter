import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math';
import '../../../../core/00_base/screen_base.dart';
import '../../../../core/managers/app_manager.dart';
import '../../../../core/managers/module_manager.dart';
import '../../../../core/managers/services_manager.dart';
import '../../../../core/managers/state_manager.dart';
import '../../../../core/services/shared_preferences.dart';
import '../../../../core/services/ticker_timer/ticker_timer.dart';
import '../../../../tools/logging/logger.dart';
import '../../../../utils/consts/theme_consts.dart';
import '../../../adverts_plugin/modules/admobs/rewarded/rewarded_ad.dart';
import '../../../main_plugin/modules/main_helper_module/main_helper_module.dart';
import '../../modules/game_play_module/config/gameplaymodule_config.dart';
import '../../modules/game_play_module/game_play_module.dart';
import 'components/celeb_image.dart';
import 'components/fact_box.dart';
import 'components/feedback_message.dart';
import 'components/game_image_grid.dart';
import 'components/screen_overlay.dart';
import 'components/timer_component.dart';

class GameScreen extends BaseScreen {
  const GameScreen({Key? key}) : super(key: key);

  @override
  String computeTitle(BuildContext context) {
    return "Guess Who";
  }

  @override
  GameScreenState createState() => GameScreenState();
}

class GameScreenState extends BaseScreenState<GameScreen> {
  static final Logger _log = Logger(); // ✅ Use a static logger for logging

  late final ModuleManager _moduleManager;
  late final ServicesManager _servicesManager;
  late final SharedPrefManager? _sharedPref;
  late final StateManager _stateManager;
  late final GamePlayModule? _gamePlayModule;
  late final MainHelperModule? _mainHelperModule;
  late final RewardedAdModule? _rewardedAdModule;
  TickerTimer? _roundTimer;  // ✅ Make it nullable instead of `late final`


  bool _showFeedback = false;
  bool _helpUsed = false; // ✅ Track if help has been used
  String _feedbackText = "";
  String _correctName = "";
  Timer? _feedbackTimer;
  int _level = 1;
  int _points = 0;
  String _backgroundImage = "";
  final Random _random = Random();
  Set<String> fadedNames = {}; // ✅ Tracks faded images
  CachedNetworkImageProvider? _cachedSelectedImage;
  String _actualCategory = "";

  @override
  void initState() {
    super.initState();
    _log.info("Initializing GameScreen...");

    // ✅ Retrieve managers and modules via Provider
    _moduleManager = Provider.of<ModuleManager>(context, listen: false);
    _servicesManager = Provider.of<ServicesManager>(context, listen: false);
    _stateManager = Provider.of<StateManager>(context, listen: false);

    _sharedPref = _servicesManager.getService<SharedPrefManager>('shared_pref');
    _gamePlayModule = _moduleManager.getLatestModule<GamePlayModule>();
    _mainHelperModule = _moduleManager.getLatestModule<MainHelperModule>();
    _rewardedAdModule = _moduleManager.getLatestModule<RewardedAdModule>();

    // ✅ Initialize round timer properly
    _roundTimer = _servicesManager.getService<TickerTimer>('round_timer');

    if (_roundTimer == null) {
      _log.error("⚠️ round_timer not found. Registering...");
      _servicesManager.registerService('round_timer', TickerTimer(id: 'round_timer')).then((_) {
        setState(() {
          _roundTimer = _servicesManager.getService<TickerTimer>('round_timer');
          _log.info("✅ round_timer successfully registered.");
        });
      });
    }

    _initializeGame();
    _loadLevelAndPoints();
  }

  void _onImagesLoaded(ImageProvider imageProvider) {
    final newImage = imageProvider as CachedNetworkImageProvider;

    if (_cachedSelectedImage == newImage) {
      return; // ✅ Prevent unnecessary re-renders
    }

    _log.info("🖼️ Image loaded successfully, caching...");

    setState(() {
      _cachedSelectedImage = newImage;
    });

    if (!_stateManager.getPluginState<Map<String, dynamic>>("game_round")?["imagesLoaded"] ?? false) {
      _stateManager.updatePluginState("game_round", {
        "imagesLoaded": true,
      }, force: true);
    }
  }


  void _onFactsLoaded() {
    _stateManager.updatePluginState("game_round", {
      "factLoaded": true,
    }, force: true);
  }

  bool get _isOverlayVisible {
    return context.select<StateManager, bool>((stateManager) {
      final gameRoundState = stateManager.getPluginState<Map<String, dynamic>>("game_round") ?? {};
      return !(gameRoundState["imagesLoaded"] == true && gameRoundState["factLoaded"] == true);
    });
  }
  void _useHelp() {
    _log.info("⏳ Entering _useHelp...");

    if (_helpUsed) {
      _log.info("🚫 Help already used! Button disabled.");
      return; // ✅ Prevent multiple uses
    }

    _helpUsed = true; // ✅ Mark help as used

    TickerTimer? roundTimer = _servicesManager.getService<TickerTimer>('round_timer');

    if (_rewardedAdModule != null && _mainHelperModule != null) {
      if (roundTimer != null && roundTimer.isRunning) {
        _log.info("⏸ Pausing timer before showing ad.");
        roundTimer.pauseTimer();
      }

      _stateManager.updatePluginState("game_round", {
        "hint": true,
      });

      _rewardedAdModule!.showAd(
        context,
        onUserEarnedReward: _fadeOutIncorrectName,
        onAdDismissed: () {
          _log.info("✅ Ad dismissed! Attempting to resume timer...");

          Future.delayed(const Duration(milliseconds: 500), () {
            if (roundTimer == null) {
              _log.error("❌ roundTimer instance is null after ad dismissal!");
            } else {
              _log.info("🔍 roundTimer instance exists. isPaused: ${roundTimer.isPaused}, isRunning: ${roundTimer.isRunning}");

              if (roundTimer.isPaused) {
                _log.info("▶ Resuming timer after ad...");
                roundTimer.startTimer();
              } else {
                _log.error("❌ roundTimer is NOT paused. Cannot resume.");
              }
            }
          });
        },
      );

      _log.info("🎬 Ad is being shown...");
    } else {
      _log.error("❌ RewardedAdModule or MainHelperModule not found!");
    }
  }

  void _fadeOutIncorrectName() {
    if (_correctAnswer == null) return;

    List<String> incorrectNames = _gamePlayModule?.nameOptions
        .where((name) => name != _correctAnswer && !fadedNames.contains(name))
        .toList() ?? [];

    if (incorrectNames.isNotEmpty) {
      String fadedName = incorrectNames[_random.nextInt(incorrectNames.length)];

      setState(() {
        fadedNames = Set.from(fadedNames)..add(fadedName);
      });

      _log.info("🚫 A name has been faded out: $fadedName");
    }
  }


  Future<void> _loadLevelAndPoints() async {
    if (_sharedPref == null) {
      _log.error('❌ SharedPreferences service not available.');
      return;
    }

    final String category = _sharedPref!.getString('category') ?? "Mixed";
    final int level = _sharedPref!.getInt('level_$category') ?? 1;
    int categoryPoints = 0;

    final int maxLevels = _sharedPref!.getInt('max_levels_$category') ?? 1;

    for (int lvl = 1; lvl <= maxLevels; lvl++) {
      int points = _sharedPref!.getInt('points_${category}_level$lvl') ?? 0;
      categoryPoints += points;
    }

    setState(() {
      _level = level;
      _points = categoryPoints;
    });

    _log.info("📊 Current Category: $category | Level: $_level | Points in Category: $_points");
  }

  void _initializeGame() {
    if (_gamePlayModule == null) {
      Logger().error("❌ GamePlayModule is not initialized!");
      return; // ✅ Prevent crashing
    }

    Logger().info("🔄 Initializing new game round...");

    _helpUsed = false; // ✅ Reset Help button for new round

    final stateManager = Provider.of<StateManager>(context, listen: false);
    final gameRoundState = stateManager.getPluginState<Map<String, dynamic>>("game_round") ?? {};

    bool levelUp = gameRoundState["levelUp"] ?? false;
    bool endGame = gameRoundState["endGame"] ?? false;

    if (levelUp || endGame) {
      Logger().info("🚀 Redirecting to Level-Up Screen! LevelUp: $levelUp | EndGame: $endGame");

      // ✅ Navigate to Level-Up Screen with arguments
      Navigator.pushReplacementNamed(
        context,
        "/level-up",
        arguments: {"levelUp": levelUp, "endGame": endGame},
      );

      // ✅ Reset state to prevent looping
      stateManager.updatePluginState("game_round", {
        "levelUp": false,
        "endGame": false,
      }, force: true);

      return; // ✅ Stop further execution of game logic
    }

    _setRandomBackground();

    // ✅ Clear game state BEFORE setting new data
    setState(() {
      _correctAnswer = null;
      fadedNames.clear();
      _gamePlayModule?.imageOptions = []; // ✅ Ensure images reset
      _gamePlayModule?.nameOptions = []; // ✅ Ensure images reset
      _actualCategory = "";
    });

    // ✅ Defer state update to the next frame to avoid "setState during build" error
    WidgetsBinding.instance.addPostFrameCallback((_) {
      stateManager.updatePluginState("game_round", {
        "hint": false,
        "imagesLoaded": false,
        "factLoaded": false,
      }, force: true);
    });

    // ✅ Clear the fact box content before loading new facts
    setState(() {
      _gamePlayModule?.question = null;
    });

// In GameScreen
    Future.delayed(const Duration(milliseconds: 100), () async {
      await _gamePlayModule?.roundInit(context, () {
        String newCategory = _gamePlayModule?.question?['category'] ?? "";
        // Only update UI state after the necessary data is ready
        setState(() {
          _correctAnswer = _gamePlayModule?.question?['name'];
          _actualCategory = newCategory;
          _gamePlayModule?.imageOptions = [
            _gamePlayModule?.question?['image_url']
          ];
          _gamePlayModule?.nameOptions = List<String>.from(
              (_gamePlayModule?.question?['distractor_names'] as List<dynamic>)
                  .map((e) => e.toString())
          );

          _gamePlayModule?.nameOptions.shuffle(Random());
        });
      });

      // Ensure the rest of the state is updated after fetching the question
      Logger().info("🔹 after round init ${_gamePlayModule?.question}");

      // Pass context to setTimer
      _gamePlayModule?.setTimer(context, () {
        _handleAnswer("", timeUp: true);
      });

      Logger().info("✅ New game round initialized!");
    });


  }

  String? _correctAnswer; // ✅ Stores the correct answer dynamically

  void _handleAnswer(String selectedName, {bool timeUp = false}) {
    Logger().info("🔹 Correct answer $_correctAnswer");
    Logger().info("🔹 Selected answer $selectedName");
    _gamePlayModule?.checkAnswer(context, selectedName, () {

      _updateFeedbackState(
        showFeedback: true,
        feedbackText: _gamePlayModule!.feedbackMessage,
        cachedImage: _cachedSelectedImage, // ✅ Pass Cached Image
        correctName: _gamePlayModule?.question?['name'],
        isCorrectGuess: _gamePlayModule!.isCorrectGuess,
      );

      _loadLevelAndPoints();
    }, timeUp: timeUp);
  }


  /// ✅ Select a new random background
  void _setRandomBackground() {
    setState(() {
      _backgroundImage = MainHelperModule.getRandomBackground();
    });
    Logger().info("🎨 New Background: $_backgroundImage");
  }

  void _updateFeedbackState({
    required bool showFeedback,
    String feedbackText = "",
    CachedNetworkImageProvider? cachedImage,
    String correctName = "",
    bool isCorrectGuess = false, // ✅ Added parameter
  }) {
    Logger().info("🎨 _updateFeedbackState reached with  $showFeedback $feedbackText $cachedImage $correctName | Correct? $isCorrectGuess");

    setState(() {
      _showFeedback = showFeedback;
      _feedbackText = feedbackText;
      _cachedSelectedImage = cachedImage; // ✅ Store Cached Image
      _correctName = correctName;
    });

    Logger().info("🎨 After setState -> showFeedback: $_showFeedback, feedbackText: $_feedbackText, correctName: $_correctName");

    if (showFeedback) {
      _feedbackTimer?.cancel();

      int durationSeconds = isCorrectGuess ? 5 : 2; // ✅ Set different durations

      Logger().info("⏳ Setting feedback timer for $durationSeconds seconds...");

      _feedbackTimer = Timer(Duration(seconds: durationSeconds), () {
        if (mounted) {
          _closeFeedback();
        }
      });
    }
  }


  void _closeFeedback() {
    _updateFeedbackState(showFeedback: false);
    _feedbackTimer?.cancel();

    setState(() {
      fadedNames.clear(); // ✅ Clear faded images
    });

    _initializeGame(); // ✅ Reset game and change background
  }

  @override
  Widget buildContent(BuildContext context) {
    // Get the height of the screen
    // double screenHeight = MediaQuery.of(context).size.height;
    String imageUrl = _gamePlayModule?.question?['image_url'] ?? "";
    if (imageUrl.isEmpty) {
      Logger().error("⚠️ No image URL provided for this round.");
    }

    return Stack(
      children: [
        // ✅ Background Image
        Positioned.fill(
          child: _backgroundImage.isNotEmpty
              ? Image.asset(_backgroundImage, fit: BoxFit.cover)
              : Container(color: Colors.black),
        ),

// ✅ CelebImage positioned behind everything
        Positioned.fill(
          child: CelebImage(
            imageUrl: imageUrl.isNotEmpty ? imageUrl : "assets/images/icon.png", // Use placeholder if missing
            actualCategory: _actualCategory,
            currentLevel: _gamePlayModule!.level,
            onImageLoaded: _onImagesLoaded, // ✅ Modified to receive ImageProvider
          ),
        ),

        SingleChildScrollView(
          child: Column(
            children: [
              // ✅ Top Bar with Level, TimerBar, and Points
              Padding(
                padding: const EdgeInsets.all(0.0),
                child: Column(
                  children: [
                    // ✅ Row with Background & Glow
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16), // Spacing inside
                      decoration: BoxDecoration(
                        color: AppColors.darkGray.withOpacity(0.6), // ✅ Semi-transparent dark background
                        borderRadius: BorderRadius.circular(10), // ✅ Smooth rounded corners
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "⭐ Category Level: $_level",
                            style: AppTextStyles.headingSmall(color: AppColors.white).copyWith(
                              shadows: [
                                Shadow(
                                  blurRadius: 15.0, // ✅ Glow intensity
                                  color: AppColors.accentColor.withOpacity(0.9), // ✅ Accent glow
                                  offset: const Offset(0, 0),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            "🏆 Points: $_points",
                            style: AppTextStyles.headingSmall(color: AppColors.white).copyWith(
                              shadows: [
                                Shadow(
                                  blurRadius: 15.0,
                                  color: AppColors.accentColor2.withOpacity(0.9), // ✅ Accent2 glow
                                  offset: const Offset(0, 0),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),


                    Consumer<StateManager>(
                      builder: (context, stateManager, child) {
                        final timerState =
                            stateManager.getPluginState<Map<String, dynamic>>("game_timer") ?? {};
                        final isRunning = timerState["isRunning"] ?? false;
                        final duration = (timerState["duration"] ?? 0).toDouble();
                        final int currentLevel = _level > 0 ? _level : 1;
                        final double levelTimer =
                        (GamePlayConfig.levelTimers[currentLevel] ?? 10).toDouble();
                        return isRunning
                            ? Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: SizedBox(
                            width: double.infinity,
                            child: TimerBar(remainingTime: duration, totalDuration: levelTimer),
                          ),
                        )
                            : const SizedBox.shrink();
                      },
                    ),
                  ],
                ),
              ),

              GameNameRow(
                correctName: _gamePlayModule?.question?['name'] ?? "", // ✅ Correct key name
                nameOptions: _gamePlayModule?.nameOptions ?? [], // ✅ Directly use the pre-set nameOptions
                onNameTap: _handleAnswer,
                fadedNames: fadedNames,
              ),

              const SizedBox(height: 20),

              ElevatedButton(
                onPressed: _useHelp,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentColor2,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min, // ✅ Prevents unnecessary space
                  children: [
                    Icon(Icons.ondemand_video, color: Colors.black, size: 22), // ✅ Video icon
                    SizedBox(width: 8), // ✅ Spacing between icon and text
                    Text(
                      "Get Help",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),


              const SizedBox(height: 20),
            ],
          ),
        ),

        // ✅ FactBox positioned at the bottom taking 1/3 of the screen height
        Positioned(
          bottom: 0,
          child: Container(
            width: MediaQuery.of(context).size.width,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height / 3, // ✅ Max height 1/3 of screen
            ),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.7),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)), // ✅ Ensure no overflow
              child: SingleChildScrollView(
                child: FactBox(
                  facts: (_gamePlayModule?.question?['facts'] as List<dynamic>?)
                      ?.map((e) => e.toString())
                      .toList() ??
                      [], // ✅ Ensure facts is never null
                  onFactsLoaded: _onFactsLoaded,
                ),
              ),
            ),
          ),
        ),

        // ✅ Full-Screen Feedback Overlay
        if (_showFeedback)
          Positioned.fill(
            child: FeedbackMessage(
              feedback: _feedbackText,
              onClose: _closeFeedback,
              cachedImage: _cachedSelectedImage,
              correctName: _correctName,
              actualCategory: _actualCategory,
              currentLevel: _gamePlayModule!.level,
            ),
          ),

        // ✅ Full-Screen Loading Overlay
        const ScreenOverlay(), // ✅ New External Component
      ],
    );
  }

}