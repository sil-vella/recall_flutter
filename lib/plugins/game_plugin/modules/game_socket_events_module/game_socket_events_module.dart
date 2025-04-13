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
  StreamSubscription? _eventSubscription;
  WebSocketModule? _websocketModule;

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

    _log.info("🔌 Setting up WebSocket event listeners...");
    _setupEventListeners(context);
  }

  void _setupEventListeners(BuildContext context) {
    _eventSubscription?.cancel();
    
    if (_websocketModule == null) {
      _log.error("❌ Cannot setup listeners: WebSocket module is null");
      return;
    }

    _log.info("🎯 Subscribing to WebSocket event stream...");
    _eventSubscription = _websocketModule!.eventStream.listen((event) {
      if (!context.mounted) {
        _log.info("⚠️ Context not mounted, skipping event");
        return;
      }

      try {
        _log.info("📨 Received WebSocket event: ${event.toString()}");
        if (event == null) {
          _log.error("❌ Received null event");
          return;
        }
        
        // Check for both event structures
        final eventType = event['type'] ?? event['event'];
        if (eventType == null) {
          _log.error("❌ Event type is null in event: ${event.toString()}");
          return;
        }

        final stateManager = Provider.of<StateManager>(context, listen: false);
        _handleSocketEvent(event, eventType, stateManager);
      } catch (e) {
        _log.error("❌ Error handling WebSocket event: $e");
      }
    }, onError: (error) {
      _log.error("❌ WebSocket stream error: $error");
    }, onDone: () {
      _log.info("✅ WebSocket stream closed");
    });

    _log.info("✅ WebSocket event listeners setup complete");
  }

  void _handleSocketEvent(Map<String, dynamic> event, String eventType, StateManager stateManager) {
    _log.info("🔄 Processing event type: $eventType");
    switch (eventType) {
      case 'room_joined':
        _log.info("🎮 Handling room_joined event");
        _handleRoomJoined(event, stateManager);
        break;
      case 'room_created':
        _log.info("🎮 Handling room_created event");
        _handleRoomCreated(event, stateManager);
        break;
      case 'room_state':
        _log.info("🎮 Handling room_state event");
        _handleRoomState(event, stateManager);
        break;
      case 'error':
        _log.info("🎮 Handling error event");
        _handleError(event, stateManager);
        break;
      default:
        _log.info("⚠️ Unknown event type: $eventType");
    }
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
    _eventSubscription?.cancel();
    super.dispose();
  }
} 