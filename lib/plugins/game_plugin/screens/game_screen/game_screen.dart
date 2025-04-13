import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../../core/managers/module_manager.dart';
import '../../../../../core/managers/services_manager.dart';
import '../../../../../tools/logging/logger.dart';
import '../../../../../core/00_base/screen_base.dart';
import '../../../../../core/managers/navigation_manager.dart';
import '../../../../../core/managers/state_manager.dart';
import '../../../../../core/services/shared_preferences.dart';
import '../../../../../utils/consts/theme_consts.dart';
import '../../../main_plugin/modules/websocket_module/components/result_handler.dart';
import '../../../main_plugin/modules/websocket_module/websocket_module.dart';
import '../../../main_plugin/modules/login_module/login_module.dart';
import '../../modules/game_socket_events_module/game_socket_events_module.dart';
import 'components/components.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';

class GameScreen extends BaseScreen {
  const GameScreen({Key? key}) : super(key: key);

  @override
  String computeTitle(BuildContext context) => 'Dutch Card Game';

  @override
  BaseScreenState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends BaseScreenState<GameScreen> {
  static final Logger _log = Logger();
  late ModuleManager _moduleManager;
  late ServicesManager _servicesManager;
  WebSocketModule? _websocketModule;
  LoginModule? _loginModule;
  
  final TextEditingController _roomController = TextEditingController();
  final TextEditingController _logController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _initDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _getUserId();
    });
  }

  void _initDependencies() {
    try {
      _moduleManager = Provider.of<ModuleManager>(context, listen: false);
      _servicesManager = Provider.of<ServicesManager>(context, listen: false);
      _websocketModule = _moduleManager.getLatestModule<WebSocketModule>();
      _loginModule = _moduleManager.getLatestModule<LoginModule>();
      
      // Initialize the game socket events module
      final gameSocketEventsModule = _moduleManager.getLatestModule<GameSocketEventsModule>();
      if (gameSocketEventsModule != null) {
        gameSocketEventsModule.initialize(context);
      }
    } catch (e) {
      _log.error("❌ Error initializing dependencies: $e");
      _logController.text += "❌ Error initializing dependencies: $e\n";
      _scrollToBottom();
    }
  }

  Future<void> _getUserId() async {
    if (!mounted) return;
    
    try {
      if (_loginModule == null) {
        _log.error("❌ LoginModule not available");
        _logController.text += "❌ Error: Login module not available\n";
        _scrollToBottom();
        return;
      }

      final userStatus = await _loginModule!.getUserStatus(context);
      
      if (userStatus["status"] != "logged_in") {
        _log.error("❌ User is not logged in");
        _logController.text += "❌ Error: User is not logged in\n";
        _scrollToBottom();
        if (mounted) {
          _log.info("🔀 Navigating to account screen due to token expiration");
          context.go('/account');
        }
        return;
      }

      final userId = userStatus["user_id"];
      if (userId == null) {
        _log.error("❌ User ID not found");
        _logController.text += "❌ Error: User ID not found\n";
        _scrollToBottom();
        return;
      }

      final stateManager = Provider.of<StateManager>(context, listen: false);
      stateManager.updatePluginState("game_room", <String, dynamic>{"userId": userId.toString()});
      _logController.text += "✅ User ID retrieved: $userId\n";
      _scrollToBottom();
    } catch (e) {
      _log.error("❌ Error getting user ID: $e");
      _logController.text += "❌ Error getting user ID: $e\n";
      _scrollToBottom();
    }
  }

  Future<void> _connectToWebSocket() async {
    try {
      _logController.text += "⏳ Connecting to WebSocket server...\n";
      _scrollToBottom();
      
      if (_loginModule != null) {
        final userStatus = await _loginModule!.getUserStatus(context);
        if (userStatus["status"] != "logged_in") {
          _logController.text += "❌ User is not logged in. Please log in to play the game.\n";
          _scrollToBottom();
          if (mounted) {
            _log.info("🔀 Navigating to account screen due to user not being logged in");
            context.go('/account');
          }
          return;
        }
      }
      
      final result = await _websocketModule?.connect(context);
      if (result == null || !result) {
        final stateManager = Provider.of<StateManager>(context, listen: false);
        final websocketState = stateManager.getPluginState<Map<String, dynamic>>("websocket") ?? {};
        final error = websocketState['error'] ?? "Failed to connect to WebSocket server";
        
        stateManager.updatePluginState("game_room", <String, dynamic>{
          "isConnected": false,
          "roomId": null,
          "isLoading": false,
          "error": error
        });
        
        if (error.contains("No valid access token available")) {
          _logController.text += "❌ Authentication error. Please log in to play the game.\n";
          _logController.text += "🔀 Logging out and redirecting to login page...\n";
          if (mounted) {
            _log.info("🔀 Logging out user due to invalid token");
            final logoutResult = await _loginModule?.logoutUser(context);
            if (logoutResult?["error"] != null) {
              _log.error("❌ Error during logout: ${logoutResult!["error"]}");
              _logController.text += "❌ Error during logout: ${logoutResult["error"]}\n";
            } else {
              _log.info("✅ User logged out successfully");
              _logController.text += "✅ User logged out successfully\n";
            }
            _log.info("🔀 Navigating to account screen");
            context.go('/account');
          }
        } else {
          _logController.text += "❌ $error\n";
        }
        _scrollToBottom();
        return;
      }

      final stateManager = Provider.of<StateManager>(context, listen: false);
      stateManager.updatePluginState("game_room", <String, dynamic>{
        "isConnected": true,
        "isLoading": false,
        "error": null
      });
      _logController.text += "✅ Connected to WebSocket server\n";
      _scrollToBottom();
      
    } catch (e) {
      final stateManager = Provider.of<StateManager>(context, listen: false);
      stateManager.updatePluginState("game_room", <String, dynamic>{
        "isConnected": false,
        "roomId": null,
        "isLoading": false,
        "error": e.toString()
      });
      _logController.text += "❌ Error connecting to WebSocket server: $e\n";
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    _roomController.dispose();
    _logController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget buildContent(BuildContext context) {
    return Consumer<StateManager>(
      builder: (context, stateManager, child) {
        final gameRoomState = stateManager.getPluginState<Map<String, dynamic>>("game_room") ?? {};
        final websocketState = stateManager.getPluginState<Map<String, dynamic>>("websocket") ?? {};

        final isConnected = gameRoomState['isConnected'] ?? false;
        final isLoading = gameRoomState['isLoading'] ?? false;
        final error = gameRoomState['error'];

        return Column(
          children: [
            // Top Section - Room Status and Game Options
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Room Status Card
                Expanded(
                  flex: 1,
                  child: BaseCard(
                    child: RoomStatusSection(
                      roomState: gameRoomState,
                      websocketState: websocketState,
                      onConnect: _connectToWebSocket,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Game Options Card (only show when not in a game)
                if (isConnected && !isLoading && error == null)
                  Consumer<StateManager>(
                    builder: (context, stateManager, child) {
                      final roomState = stateManager.getPluginState<Map<String, dynamic>>("game_room") ?? {};
                      final roomId = roomState['roomId'];
                      
                      if (roomId == null) {
                        return Expanded(
                          flex: 1,
                          child: BaseCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Game Options',
                                  style: AppTextStyles.headingMedium(),
                                ),
                                const SizedBox(height: 16),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    BaseButton(
                                      text: 'Create Game',
                                      onPressed: () {
                                        _logController.text += "🎮 Creating new game...\n";
                                        _scrollToBottom();
                                        _createGame();
                                      },
                                      icon: Icons.add_circle_outline,
                                    ),
                                    BaseButton(
                                      text: 'Join Game',
                                      onPressed: () {
                                        _logController.text += "🔗 Joining game...\n";
                                        _scrollToBottom();
                                        _showJoinGameDialog();
                                      },
                                      icon: Icons.login,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                // Game Room Card (only show when in a game)
                if (isConnected && !isLoading && error == null)
                  Consumer<StateManager>(
                    builder: (context, stateManager, child) {
                      final roomState = stateManager.getPluginState<Map<String, dynamic>>("game_room") ?? {};
                      final roomId = roomState['roomId'];
                      
                      if (roomId != null) {
                        return Expanded(
                          flex: 1,
                          child: BaseCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Game Room',
                                  style: AppTextStyles.headingMedium(),
                                ),
                                const SizedBox(height: 8),
                                Text('Room ID: $roomId', style: AppTextStyles.bodyMedium),
                                if (roomState['joinLink'] != null)
                                  Text('Join Link: ${roomState['joinLink']}', style: AppTextStyles.bodyMedium),
                                const SizedBox(height: 16),
                                BaseButton(
                                  text: 'Leave Room',
                                  onPressed: () {
                                    _logController.text += "🚪 Leaving room...\n";
                                    _scrollToBottom();
                                    _leaveRoom();
                                  },
                                  icon: Icons.logout,
                                  isPrimary: false,
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
              ],
            ),
            const SizedBox(height: 16),
            // Game Timer and Round Info (only show when in a game)
            Consumer<StateManager>(
              builder: (context, stateManager, child) {
                final roomState = stateManager.getPluginState<Map<String, dynamic>>("game_room") ?? {};
                final roomId = roomState['roomId'];
                
                if (roomId != null) {
                  final gameTimerState = stateManager.getPluginState<Map<String, dynamic>>("game_timer") ?? {};
                  final gameRoundState = stateManager.getPluginState<Map<String, dynamic>>("game_round") ?? {};
                  
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Game Timer Card
                      Expanded(
                        flex: 1,
                        child: BaseCard(
                          child: GameTimerSection(
                            timerState: gameTimerState,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Game Round Card
                      Expanded(
                        flex: 1,
                        child: BaseCard(
                          child: GameRoundSection(
                            roundState: gameRoundState,
                          ),
                        ),
                      ),
                    ],
                  );
                }
                return const SizedBox.shrink();
              },
            ),
            const SizedBox(height: 16),
            // Log Section
            BaseCard(
              child: LogSection(
                controller: _logController,
                scrollController: _scrollController,
              ),
            ),
          ],
        );
      },
    );
  }

  void _createGame() {
    if (_websocketModule == null) return;
    
    final stateManager = Provider.of<StateManager>(context, listen: false);
    final websocketState = stateManager.getPluginState<Map<String, dynamic>>("websocket") ?? {};
    final userId = websocketState['userId'];
    
    if (userId == null) {
      _logController.text += "❌ User ID not found. Please log in first.\n";
      _scrollToBottom();
      return;
    }
    
    _logController.text += "🎮 Creating new game room...\n";
    _scrollToBottom();
    
    // Update state to show loading
    stateManager.updatePluginState("game_room", <String, dynamic>{
      "isLoading": true,
      "error": null
    });
    
    // Emit create room event
    _websocketModule!.createRoom(userId);
  }

  void _showJoinGameDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Join Game', style: AppTextStyles.headingMedium()),
        content: BaseTextField(
          controller: _roomController,
          label: 'Room ID',
          hint: 'Enter room ID to join',
        ),
        actions: [
          BaseButton(
            text: 'Cancel',
            onPressed: () {
              Navigator.pop(context);
            },
            isPrimary: false,
          ),
          BaseButton(
            text: 'Join',
            onPressed: () {
              Navigator.pop(context);
              _joinGame();
            },
          ),
        ],
      ),
    );
  }

  void _joinGame() {
    if (_websocketModule == null) return;
    
    final roomId = _roomController.text.trim();
    if (roomId.isEmpty) {
      _logController.text += "❌ Please enter a room ID\n";
      _scrollToBottom();
      return;
    }

    _logController.text += "🔗 Joining room: $roomId\n";
    _scrollToBottom();
    
    final stateManager = Provider.of<StateManager>(context, listen: false);
    
    // Update state to show loading
    stateManager.updatePluginState("game_room", <String, dynamic>{
      "isLoading": true,
      "error": null
    });
    
    // Emit join room event
    _websocketModule!.joinRoom(roomId);
  }

  void _leaveRoom() {
    if (_websocketModule == null) return;
    
    final roomId = _roomController.text.trim();
    _websocketModule!.leaveRoom(roomId);
    
    final stateManager = Provider.of<StateManager>(context, listen: false);
    stateManager.updatePluginState("game_room", <String, dynamic>{
      "roomId": null,
      "roomState": null,
      "joinLink": null,
      "isLoading": false,
      "error": null,
    });
  }
}

class RoomStatusSection extends StatelessWidget {
  final Map<String, dynamic> roomState;
  final Map<String, dynamic> websocketState;
  final VoidCallback onConnect;

  const RoomStatusSection({
    Key? key,
    required this.roomState,
    required this.websocketState,
    required this.onConnect,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isConnected = roomState['isConnected'] ?? false;
    final roomId = roomState['roomId'];
    final error = roomState['error'] ?? websocketState['error'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Room Status',
          style: AppTextStyles.headingMedium(),
        ),
        const SizedBox(height: 8),
        Text('Connected: ${isConnected ? 'Yes' : 'No'}', style: AppTextStyles.bodyMedium),
        if (roomId != null) Text('Room ID: $roomId', style: AppTextStyles.bodyMedium),
        if (error != null) Text('Error: $error', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.redAccent)),
        const SizedBox(height: 8),
        BaseButton(
          text: 'Connect',
          onPressed: isConnected ? () {} : onConnect,
          icon: Icons.wifi,
          isPrimary: !isConnected,
        ),
      ],
    );
  }
}

class GameTimerSection extends StatelessWidget {
  final Map<String, dynamic> timerState;

  const GameTimerSection({
    Key? key,
    required this.timerState,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isRunning = timerState['isRunning'] ?? false;
    final duration = timerState['duration'] ?? 30;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Game Timer',
          style: AppTextStyles.headingMedium(),
        ),
        const SizedBox(height: 8),
        Text('Status: ${isRunning ? 'Running' : 'Stopped'}', style: AppTextStyles.bodyMedium),
        Text('Duration: $duration seconds', style: AppTextStyles.bodyMedium),
      ],
    );
  }
}

class GameRoundSection extends StatelessWidget {
  final Map<String, dynamic> roundState;

  const GameRoundSection({
    Key? key,
    required this.roundState,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final roundNumber = roundState['roundNumber'] ?? 0;
    final hint = roundState['hint'] ?? false;
    final imagesLoaded = roundState['imagesLoaded'] ?? false;
    final factLoaded = roundState['factLoaded'] ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Game Round',
          style: AppTextStyles.headingMedium(),
        ),
        const SizedBox(height: 8),
        Text('Round Number: $roundNumber', style: AppTextStyles.bodyMedium),
        Text('Hint Available: ${hint ? 'Yes' : 'No'}', style: AppTextStyles.bodyMedium),
        Text('Images Loaded: ${imagesLoaded ? 'Yes' : 'No'}', style: AppTextStyles.bodyMedium),
        Text('Fact Loaded: ${factLoaded ? 'Yes' : 'No'}', style: AppTextStyles.bodyMedium),
      ],
    );
  }
}

class LogSection extends StatelessWidget {
  final TextEditingController controller;
  final ScrollController scrollController;

  const LogSection({
    Key? key,
    required this.controller,
    required this.scrollController,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BaseTextField(
      controller: controller,
      label: 'Log Output',
      readOnly: true,
      maxLines: null,
    );
  }
} 