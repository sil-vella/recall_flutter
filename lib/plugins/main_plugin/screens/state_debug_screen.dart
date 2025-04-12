import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/00_base/screen_base.dart';
import '../../../core/managers/state_manager.dart';
import '../../../tools/logging/logger.dart';
import '../../../utils/consts/theme_consts.dart';

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
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _log.info("🔄 Initializing StateDebugScreen");
    
    // Log initial state after frame is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _logState();
    });
  }

  void _logState() {
    final stateManager = Provider.of<StateManager>(context, listen: false);
    final allStates = stateManager.getAllStates();
    
    _log.info("📊 Current State Overview:");
    _log.info("┌─────────────────────────────────────────────┐");
    
    // Log main app state
    final mainAppState = allStates['main_app_state'] as Map<String, dynamic>;
    _log.info("│ Main App State:");
    _logStateMap(mainAppState, "│ ");
    
    // Log plugin states
    final pluginStates = allStates['plugin_states'] as Map<String, Map<String, dynamic>>;
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

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Widget _buildStateCard(String title, Map<String, dynamic> state) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.accentColor,
              ),
            ),
            const SizedBox(height: 8),
            ...state.entries.map((entry) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${entry.key}: ',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      entry.value.toString(),
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildPluginStateSection(Map<String, Map<String, dynamic>> pluginStates) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Plugin States (${pluginStates.length})',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.accentColor,
            ),
          ),
        ),
        ...pluginStates.entries.map((entry) => _buildStateCard(entry.key, entry.value)),
      ],
    );
  }

  Widget _buildMainAppStateSection(Map<String, dynamic> mainAppState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Main App State',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.accentColor,
            ),
          ),
        ),
        _buildStateCard('main_app_state', mainAppState),
      ],
    );
  }

  @override
  Widget buildContent(BuildContext context) {
    final stateManager = Provider.of<StateManager>(context);
    final allStates = stateManager.getAllStates();
    final pluginStates = allStates['plugin_states'] as Map<String, Map<String, dynamic>>;
    final mainAppState = allStates['main_app_state'] as Map<String, dynamic>;

    return Container(
      color: Colors.white,
      child: RefreshIndicator(
        onRefresh: () async {
          _logState();
          setState(() {});
        },
        child: ListView(
          controller: _scrollController,
          children: [
            _buildMainAppStateSection(mainAppState),
            _buildPluginStateSection(pluginStates),
          ],
        ),
      ),
    );
  }
} 