import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:recall/plugins/game_plugin/modules/function_helper_module/function_helper_module.dart';
import 'package:recall/plugins/game_plugin/modules/game_socket_events_module/game_socket_events_module.dart';
import 'package:recall/plugins/game_plugin/screens/game_screen/index.dart';
import '../../core/00_base/module_base.dart';
import '../../core/00_base/plugin_base.dart';
import '../../core/managers/module_manager.dart';
import '../../core/managers/navigation_manager.dart';
import '../../core/managers/services_manager.dart';
import '../../core/managers/state_manager.dart';
import '../../core/services/shared_preferences.dart';
import '../../tools/logging/logger.dart';
import '../main_plugin/modules/connections_api_module/connections_api_module.dart';
import '../main_plugin/modules/websocket_module/websocket_module.dart';

class GamePlugin extends PluginBase {
  static final Logger _log = Logger();
  late GameSocketEventsModule _gameSocketEventsModule;
  late final NavigationManager navigationManager;

  GamePlugin() : super() {
    _log.info('🚀 GamePlugin initialized.');
    _gameSocketEventsModule = GameSocketEventsModule();
  }

  @override
  void initialize(BuildContext context) {
    _log.info("🔄 Initializing GamePlugin...");
    final moduleManager = Provider.of<ModuleManager>(context, listen: false);
    final servicesManager = Provider.of<ServicesManager>(context, listen: false);
    final stateManager = Provider.of<StateManager>(context, listen: false);
    navigationManager = Provider.of<NavigationManager>(context, listen: false);
    
    // Initialize states before any other operations
    _initializeStates(stateManager);
    _initializeUserData(context);
    _registerNavigation();
    
    // Register modules
    moduleManager.registerModule(_gameSocketEventsModule);
    
    // Initialize modules
    _gameSocketEventsModule.initialize(context);

    // Check if WebSocketModule is available
    final websocketModule = moduleManager.getLatestModule<WebSocketModule>();
    if (websocketModule == null) {
      _log.error('❌ WebSocketModule not found in ModuleManager. Game functionality may be limited.');
    } else {
      _log.info('✅ Found WebSocketModule instance. Game functionality is available.');
    }
  }

  void _registerNavigation() {
    // Register the game screen route
    navigationManager.registerRoute(
      path: '/game',
      screen: (context) => const GameScreen(),
      drawerTitle: 'Dutch Card Game',
      drawerIcon: Icons.sports_esports,
      drawerPosition: 2, // Position after home screen
    );
    
    _log.info("✅ Game screen route registered with drawer entry.");
  }

  /// Initialize all plugin states
  void _initializeStates(StateManager stateManager) {
    // Initialize game room state
    if (stateManager.getPluginState<Map<String, dynamic>>("game_room") == null) {
      stateManager.registerPluginState("game_room", <String, dynamic>{
        "roomId": null,
        "isConnected": false,
        "roomState": null,
        "userId": null,
        "joinLink": null,
        "isLoading": false,
        "error": null
      });
    }

    // Initialize game timer state
    if (stateManager.getPluginState<Map<String, dynamic>>("game_timer") == null) {
      stateManager.registerPluginState("game_timer", <String, dynamic>{
        "isRunning": false,
        "duration": 30,
      });
    }

    // Initialize game round state
    if (stateManager.getPluginState<Map<String, dynamic>>("game_round") == null) {
      stateManager.registerPluginState("game_round", <String, dynamic>{
        "roundNumber": 0,
        "hint": false,
        "imagesLoaded": false,
        "factLoaded": false,
      });
    }
  }

  /// ✅ Register game-related modules
  @override
  Map<String?, ModuleBase> createModules() {
    return {
      null: FunctionHelperModule(),
      "game_socket_events": _gameSocketEventsModule,
    };
  }

  /// ✅ Define initial states for this plugin
  @override
  Map<String, Map<String, dynamic>> getInitialStates() {
    return {
      "game_room": {
        "roomId": null,
        "isConnected": false,
        "roomState": null,
        "userId": null,
        "joinLink": null,
        "isLoading": false,
        "error": null
      },
      "game_timer": {
        "isRunning": false,
        "duration": 30,
      },
      "game_round": {
        "roundNumber": 0,
        "hint": false,
        "imagesLoaded": false,
        "factLoaded": false,
      }
    };
  }

  Future<void> _initializeUserData(BuildContext context) async {
    final servicesManager = Provider.of<ServicesManager>(context, listen: false);
    final sharedPref = servicesManager.getService<SharedPrefManager>('shared_pref');

    if (sharedPref == null) {
      _log.error('❌ SharedPrefManager not found.');
      return;
    }

    // ✅ Store user profile details if not already set
    String? username = sharedPref.getString('username');
    if (username == null) {
      sharedPref.setString('username', 'Guest');
      sharedPref.setString('email', '');
      sharedPref.setString('password', '');
    }
  }

  /// ✅ Initialize SharedPreferences keys for levels, points, and guessed names
  Future<void> _initializeCategorySystem(List<String> categories, SharedPrefManager sharedPref) async {
    try {
      _log.info("⚙️ Initializing SharedPreferences for levels, points, and guessed names...");

      for (String category in categories) {
        // ✅ Fetch max levels directly
        int maxLevels = sharedPref.getInt('max_levels_$category') ?? 0;

        // ✅ Default to level 1
        String levelKey = "level_$category";
        int currentLevel = sharedPref.getInt(levelKey) ?? 1;
        sharedPref.setInt(levelKey, currentLevel);

        for (int level = 1; level <= maxLevels; level++) {
          String pointsKey = "points_${category}_level$level";
          String guessedKey = "guessed_${category}_level$level";

          // ✅ Set default points directly
          sharedPref.setInt(pointsKey, sharedPref.getInt(pointsKey) ?? 0);

          // ✅ Set empty guessed names list directly
          sharedPref.setStringList(guessedKey, sharedPref.getStringList(guessedKey) ?? []);

          _log.info("✅ Initialized keys for $category: level $level");
        }
      }
    } catch (e) {
      _log.error("❌ Error initializing category system: $e", error: e);
    }
  }

  /// Update room state
  void updateRoomState(BuildContext context, Map<String, dynamic> state) {
    if (!context.mounted) return;
    final stateManager = Provider.of<StateManager>(context, listen: false);
    final currentState = stateManager.getPluginState<Map<String, dynamic>>("game_room") ?? {};
    stateManager.updatePluginState("game_room", <String, dynamic>{...currentState, ...state});
  }

  /// Get current room state
  Map<String, dynamic> getRoomState(BuildContext context) {
    final stateManager = Provider.of<StateManager>(context, listen: false);
    return stateManager.getPluginState<Map<String, dynamic>>("game_room") ?? {};
  }

  /// Generate join links for a room
  static Map<String, String> generateJoinLinks(String roomId) {
    return ConnectionsApiModule.generateLinks('/join/$roomId');
  }

  /// Handle joining a room via deep link
  Widget handleJoinRoom(BuildContext context, String? roomId) {
    if (roomId == null || !roomId.startsWith('room__')) {
      return const Scaffold(
        body: Center(
          child: Text('Invalid room ID'),
        ),
      );
    }

    // Update state to show loading
    final stateManager = Provider.of<StateManager>(context, listen: false);
    stateManager.updatePluginState("game_room", <String, dynamic>{
      "isLoading": true,
      "error": null
    });

    // Get WebSocket module and join room
    final moduleManager = Provider.of<ModuleManager>(context, listen: false);
    final websocketModule = moduleManager.getLatestModule<WebSocketModule>();
    
    if (websocketModule == null) {
      stateManager.updatePluginState("game_room", <String, dynamic>{
        "isLoading": false,
        "error": "WebSocket connection not available"
      });
      return const Scaffold(
        body: Center(
          child: Text('WebSocket connection not available'),
        ),
      );
    }

    // Join the room
    websocketModule.joinRoom(roomId);

    // Show loading screen while joining
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GameScreen();
  }

  @override
  void dispose(BuildContext context) {
    _log.info("🧹 Disposing GamePlugin");
    _gameSocketEventsModule.dispose();
    super.dispose(context);
  }
}
