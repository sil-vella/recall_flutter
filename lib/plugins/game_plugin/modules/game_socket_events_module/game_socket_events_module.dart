import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/00_base/module_base.dart';
import '../../../../core/managers/module_manager.dart';
import '../../../../core/managers/services_manager.dart';
import '../../../../core/managers/state_manager.dart';
import '../../../../tools/logging/logger.dart';
import '../../../main_plugin/modules/websocket_module/websocket_module.dart';
import 'dart:async';

class GameSocketEventsModule extends ModuleBase {
  static final Logger _log = Logger();
  WebSocketModule? _websocketModule;
  StreamSubscription? _connectionSubscription;

  GameSocketEventsModule() : super("game_socket_events_module") {
    _log.info('🚀 GameSocketEventsModule initialized and auto-registered.');
  }

  void initialize(BuildContext context) {
    _log.info("🔄 Initializing GameSocketEventsModule...");
    final moduleManager = Provider.of<ModuleManager>(context, listen: false);
    
    // Get WebSocket module
    _websocketModule = moduleManager.getLatestModule<WebSocketModule>();
    _log.info("🔍 WebSocket module found: ${_websocketModule != null}");
    
    if (_websocketModule == null) {
      _log.error("❌ WebSocket module not available");
      return;
    }

    // Listen to connection state changes
    _connectionSubscription = _websocketModule!.eventStream.listen((event) {
      if (event['event'] == 'connect' && context.mounted) {
        _log.info("🔌 WebSocket connected, setting up game event listeners...");
        _setupEventListeners(context);
      }
    });

    // If already connected, setup listeners immediately
    if (_websocketModule!.socket != null) {
      _log.info("🔌 WebSocket already connected, setting up game event listeners...");
      _setupEventListeners(context);
    }
  }

  void _setupEventListeners(BuildContext context) {
    if (_websocketModule == null || _websocketModule!.socket == null) {
      _log.error("❌ Cannot setup listeners: WebSocket module or socket is null");
      return;
    }

    final socket = _websocketModule!.socket!;
    
    // Remove any existing listeners first
    socket.off('room_created');
    socket.off('room_joined');
    socket.off('room_state');
    socket.off('error');
    
    // Room events
    socket.on('room_created', (data) {
      if (!context.mounted) {
        _log.info("⚠️ Context not mounted, skipping event");
        return;
      }
      _log.info("📨 Received room_created event: $data");
      _handleRoomCreated(data, Provider.of<StateManager>(context, listen: false));
    });

    socket.on('room_joined', (data) {
      if (!context.mounted) {
        _log.info("⚠️ Context not mounted, skipping event");
        return;
      }
      _log.info("📨 Received room_joined event: $data");
      _handleRoomJoined(data, Provider.of<StateManager>(context, listen: false));
    });

    socket.on('room_state', (data) {
      if (!context.mounted) {
        _log.info("⚠️ Context not mounted, skipping event");
        return;
      }
      _log.info("📨 Received room_state event: $data");
      _handleRoomState(data, Provider.of<StateManager>(context, listen: false));
    });

    socket.on('error', (data) {
      if (!context.mounted) {
        _log.info("⚠️ Context not mounted, skipping event");
        return;
      }
      _log.info("📨 Received error event: $data");
      _handleError(data, Provider.of<StateManager>(context, listen: false));
    });

    _log.info("✅ Game WebSocket event listeners setup complete");
  }

  void _handleRoomJoined(Map<String, dynamic> event, StateManager stateManager) {
    _log.info("🔄 Processing room_joined event data: $event");
    try {
      // Get current state to preserve existing data
      final currentState = stateManager.getPluginState<Map<String, dynamic>>("game_room") ?? {};
      
      stateManager.updatePluginState("game_room", <String, dynamic>{
        ...currentState, // Preserve existing state
        "roomId": event['room_id'],
        "isConnected": true,
        "roomState": <String, dynamic>{
          ...currentState["roomState"] ?? {}, // Preserve existing room state
          "current_size": event['current_size'],
          "max_size": event['max_size'],
        },
        "isLoading": false,
        "error": null,
      });
      _log.info("✅ Room joined successfully: ${event['room_id']}");
    } catch (e) {
      _log.error("❌ Error in _handleRoomJoined: $e");
    }
  }

  void _handleRoomCreated(Map<String, dynamic> event, StateManager stateManager) {
    _log.info("🔄 Processing room_created event data: $event");
    try {
      stateManager.updatePluginState("game_room", <String, dynamic>{
        "roomId": event['room_id'],
        "isConnected": true,
        "roomState": <String, dynamic>{
          "current_size": event['current_size'],
          "max_size": event['max_size'],
          "owner_id": event['owner_id'],
          "owner_username": event['owner_username'],
          "permission": event['permission'],
          "allowed_users": event['allowed_users'],
          "allowed_roles": event['allowed_roles'],
          "join_link": event['join_link'],
        },
        "joinLink": event['join_link'],
        "isLoading": false,
        "error": null,
      });
      _log.info("✅ Room created successfully: ${event['room_id']}");
    } catch (e) {
      _log.error("❌ Error in _handleRoomCreated: $e");
    }
  }

  void _handleRoomState(Map<String, dynamic> event, StateManager stateManager) {
    _log.info("🔄 Processing room_state event data: $event");
    try {
      final currentState = stateManager.getPluginState<Map<String, dynamic>>("game_room") ?? {};
      stateManager.updatePluginState("game_room", <String, dynamic>{
        ...currentState,
        "roomState": <String, dynamic>{
          ...currentState["roomState"] ?? {},
          ...event,
        },
      });
      _log.info("✅ Room state updated successfully");
    } catch (e) {
      _log.error("❌ Error in _handleRoomState: $e");
    }
  }

  void _handleError(Map<String, dynamic> event, StateManager stateManager) {
    _log.info("🔄 Processing error event data: $event");
    try {
      if (event['message']?.contains('Failed to join room') == true) {
        stateManager.updatePluginState("game_room", <String, dynamic>{
          "roomId": null,
          "roomState": null,
          "isLoading": false,
          "error": event['message'],
        });
        _log.error("❌ Room join failed: ${event['message']}");
      } else {
        _log.error("❌ WebSocket error: ${event['message']}");
      }
    } catch (e) {
      _log.error("❌ Error in _handleError: $e");
    }
  }

  @override
  void dispose() {
    _log.info("🧹 Disposing GameSocketEventsModule");
    _connectionSubscription?.cancel();
    if (_websocketModule?.socket != null) {
      final socket = _websocketModule!.socket!;
      socket.off('room_created');
      socket.off('room_joined');
      socket.off('room_state');
      socket.off('error');
    }
    super.dispose();
  }
} 