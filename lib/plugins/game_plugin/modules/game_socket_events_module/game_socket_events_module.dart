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
    final moduleManager = Provider.of<ModuleManager>(context, listen: false);
    _websocketModule = moduleManager.getLatestModule<WebSocketModule>();
    
    if (_websocketModule == null) {
      _log.error("❌ WebSocket module not available");
      return;
    }

    _setupEventListeners(context);
  }

  void _setupEventListeners(BuildContext context) {
    _eventSubscription?.cancel();
    _eventSubscription = _websocketModule!.eventStream.listen((event) {
      if (!context.mounted) return;

      try {
        final stateManager = Provider.of<StateManager>(context, listen: false);
        _handleSocketEvent(event, stateManager);
      } catch (e) {
        _log.error("❌ Error handling WebSocket event: $e");
      }
    });
  }

  void _handleSocketEvent(Map<String, dynamic> event, StateManager stateManager) {
    switch (event['type']) {
      case 'room_joined':
        _handleRoomJoined(event, stateManager);
        break;
      case 'room_created':
        _handleRoomCreated(event, stateManager);
        break;
      case 'room_state':
        _handleRoomState(event, stateManager);
        break;
      case 'error':
        _handleError(event, stateManager);
        break;
    }
  }

  void _handleRoomJoined(Map<String, dynamic> event, StateManager stateManager) {
    stateManager.updatePluginState("game_room", <String, dynamic>{
      "roomId": event['data']['room_id'],
      "isConnected": true,
      "roomState": <String, dynamic>{
        "current_size": event['data']['current_size'],
        "max_size": event['data']['max_size'],
      },
      "isLoading": false,
      "error": null,
    });
    _log.info("✅ Room joined: ${event['data']['room_id']}");
  }

  void _handleRoomCreated(Map<String, dynamic> event, StateManager stateManager) {
    stateManager.updatePluginState("game_room", <String, dynamic>{
      "roomId": event['data']['room_id'],
      "isConnected": true,
      "roomState": <String, dynamic>{
        "current_size": event['data']['current_size'],
        "max_size": event['data']['max_size'],
        "owner_id": event['data']['owner_id'],
        "owner_username": event['data']['owner_username'],
        "permission": event['data']['permission'],
        "allowed_users": event['data']['allowed_users'],
        "allowed_roles": event['data']['allowed_roles'],
        "join_link": event['data']['join_link'],
      },
      "joinLink": event['data']['join_link'],
      "isLoading": false,
      "error": null,
    });
    _log.info("✅ Room created: ${event['data']['room_id']}");
  }

  void _handleRoomState(Map<String, dynamic> event, StateManager stateManager) {
    final currentState = stateManager.getPluginState<Map<String, dynamic>>("game_room") ?? {};
    stateManager.updatePluginState("game_room", <String, dynamic>{
      ...currentState,
      "roomState": <String, dynamic>{
        ...currentState["roomState"] ?? {},
        ...event['data'],
      },
    });
    _log.info("📊 Room state updated");
  }

  void _handleError(Map<String, dynamic> event, StateManager stateManager) {
    if (event['data']['message']?.contains('Failed to join room') == true) {
      stateManager.updatePluginState("game_room", <String, dynamic>{
        "roomId": null,
        "roomState": null,
        "isLoading": false,
        "error": event['data']['message'],
      });
    }
    _log.error("❌ Error: ${event['data']['message']}");
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    super.dispose();
  }
} 