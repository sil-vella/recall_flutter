import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../tools/logging/logger.dart';
import '../../../core/managers/state_manager.dart';
import '../../../core/00_base/screen_base.dart';

class StateDebugScreen extends BaseScreen {
  const StateDebugScreen({Key? key}) : super(key: key);

  @override
  String computeTitle(BuildContext context) {
    return "State Debug";
  }

  @override
  StateDebugScreenState createState() => StateDebugScreenState();
}

class StateDebugScreenState extends BaseScreenState<StateDebugScreen> {
  final Logger _log = Logger();
  Map<String, dynamic> _currentState = {};

  @override
  void initState() {
    super.initState();
    _log.info("🔄 Initializing StateDebugScreen");
    _updateState();
  }

  void _updateState() {
    if (!mounted) return;
    final stateManager = Provider.of<StateManager>(context, listen: false);
    setState(() {
      _currentState = stateManager.getAllStates();
    });
  }

  void _logState() {
    _log.info("📊 Current State Overview:");
    _log.info("┌─────────────────────────────────────────────┐");
    
    // Log main app state
    final mainAppState = _currentState['main_app_state'] as Map<String, dynamic>;
    _log.info("│ Main App State:");
    _logStateMap(mainAppState, "│ ");
    
    // Log plugin states
    final pluginStates = _currentState['plugin_states'] as Map<String, Map<String, dynamic>>;
    _log.info("│ Plugin States:");
    pluginStates.forEach((pluginName, state) {
      _log.info("│ ┌─ $pluginName");
      _logStateMap(state, "│ │ ");
    });
    
    _log.info("└─────────────────────────────────────────────┘");
  }

  void _logStateMap(Map<dynamic, dynamic> state, String prefix) {
    state.forEach((key, value) {
      if (value is Map) {
        _log.info("$prefix├─ $key:");
        _logStateMap(value, "$prefix│  ");
      } else {
        _log.info("$prefix├─ $key: $value");
      }
    });
  }

  Widget _buildStateDisplay(Map<String, dynamic> state, String title) {
    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            ...state.entries.map((entry) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${entry.key}:',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    entry.value.toString(),
                    softWrap: true,
                  ),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  @override
  Widget buildContent(BuildContext context) {
    return Container(
      color: Colors.white,
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      "State Debug Screen",
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      _logState();
                      _updateState();
                    },
                    child: const Text("Log & Refresh State"),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_currentState['main_app_state'] != null)
                      _buildStateDisplay(
                        _currentState['main_app_state'] as Map<String, dynamic>,
                        'Main App State',
                      ),
                    if (_currentState['plugin_states'] != null)
                      ...(_currentState['plugin_states'] as Map<String, dynamic>)
                          .entries
                          .map((entry) => _buildStateDisplay(
                                entry.value as Map<String, dynamic>,
                                'Plugin: ${entry.key}',
                              )),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 