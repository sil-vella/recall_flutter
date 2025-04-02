import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:recall/plugins/game_plugin/modules/function_helper_module/function_helper_module.dart';
import 'package:recall/utils/consts/theme_consts.dart';
import '../../../../../tools/logging/logger.dart';
import '../../../modules/game_play_module/game_play_module.dart';
import '../../../../../core/managers/module_manager.dart';

class GameNameRow extends StatefulWidget {
  final List<String> nameOptions; // ✅ Correct name + 2 distractors
  final Function(String) onNameTap;
  final Set<String> fadedNames;
  final String correctName;

  const GameNameRow({
    Key? key,
    required this.nameOptions,
    required this.onNameTap,
    required this.fadedNames,
    required this.correctName,
  }) : super(key: key);

  @override
  _GameNameRowState createState() => _GameNameRowState();
}

class _GameNameRowState extends State<GameNameRow> {
  String? selectedName;

  @override
  void initState() {
    super.initState();
    selectedName = null;
  }

  /// ✅ Helper function to format names: replaces `_` with spaces and capitalizes each word
  String _formatName(String name) {
    return name
        .replaceAll('_', ' ') // Replace underscores with spaces
        .split(' ') // Split words
        .map((word) => word.isNotEmpty ? word[0].toUpperCase() + word.substring(1) : '') // Capitalize first letter
        .join(' '); // Rejoin words
  }

  void _handleNameTap(String name) {
    if (widget.fadedNames.contains(name)) return; // ✅ Ignore faded names

    setState(() {
      selectedName = name; // ✅ Mark the tapped name as selected
      Logger().info("🎭 Name tapped: $name | selectedName now: $selectedName");
    });

    // ✅ Ensure UI updates before calling onNameTap
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        setState(() {}); // ✅ Refresh UI
        widget.onNameTap(name);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Shuffle the options (correct + 2 distractors) to randomize their order
    List<String> names = [widget.correctName, ...widget.nameOptions];
    names.shuffle(); // Randomize the order

    return Row( // ✅ Ensures buttons stay in a single row
      mainAxisAlignment: MainAxisAlignment.center,
      children: names.map((name) => _buildNameBox(name)).toList(),
    );
  }

  Widget _buildNameBox(String name) {
    bool isSelected = selectedName == name;
    bool isFaded = widget.fadedNames.contains(name);
    String formattedName = _formatName(name); // ✅ Apply formatting

    Logger().info("🎭 Checking if selected: $name -> ${isSelected ? "Selected" : "Not Selected"}");

    return Expanded( // ✅ Makes all name boxes share the space evenly
      child: GestureDetector(
        onTap: isFaded ? null : () => _handleNameTap(name), // ✅ Disable taps on faded names
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 300),
          opacity: isFaded ? 0.3 : 1.0, // ✅ Reduce opacity for faded names
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            margin: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: isSelected
                  ? Colors.greenAccent.withOpacity(0.8)
                  : (isFaded ? Colors.grey[300] : AppColors.accentColor),
              border: Border.all(
                color: isSelected
                    ? Colors.greenAccent
                    : (isFaded ? Colors.grey : AppColors.accentColor2),
                width: isSelected ? 4.0 : (isFaded ? 2.0 : 3.0),
              ),
              borderRadius: BorderRadius.circular(8.0),
              boxShadow: isSelected
                  ? [
                BoxShadow(
                  color: Colors.greenAccent.withOpacity(0.8),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ]
                  : [],
            ),
            child: Center(
              child: Text(
                formattedName, // ✅ Use formatted name
                textAlign: TextAlign.center,
                maxLines: 2, // ✅ Allows word wrapping for long names
                overflow: TextOverflow.ellipsis, // ✅ If too long, add "..."
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isFaded ? Colors.grey[700] : Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
