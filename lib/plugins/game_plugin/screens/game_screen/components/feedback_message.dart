import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';
import '../../../../../core/managers/module_manager.dart';
import '../../../../../utils/consts/theme_consts.dart';
import '../../../../main_plugin/modules/animations_module/animations_module.dart';
import '../../../../main_plugin/modules/audio_module/audio_module.dart'; // ✅ Import AudioModule

class FeedbackMessage extends StatefulWidget {
  final String feedback;
  final String correctName;
  final VoidCallback onClose;
  final String? selectedImageUrl;
  final CachedNetworkImageProvider? cachedImage;
  final String actualCategory;
  final int currentLevel;

  const FeedbackMessage({
    Key? key,
    required this.feedback,
    required this.correctName,
    required this.onClose,
    this.selectedImageUrl,
    this.cachedImage,
    required this.actualCategory,
    required this.currentLevel,
  }) : super(key: key);

  @override
  _FeedbackMessageState createState() => _FeedbackMessageState();
}

class _FeedbackMessageState extends State<FeedbackMessage> with SingleTickerProviderStateMixin {
  late final ModuleManager _moduleManager;
  late final AnimationsModule? _animationModule;
  late final AudioModule? _audioModule; // ✅ AudioModule instance
  late ConfettiController _confettiController;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _moduleManager = Provider.of<ModuleManager>(context, listen: false);
    _animationModule = _moduleManager.getLatestModule<AnimationsModule>();
    _audioModule = _moduleManager.getLatestModule<AudioModule>(); // ✅ Get AudioModule instance

    _confettiController = ConfettiController(duration: const Duration(seconds: 2));

    bool isCorrect = widget.feedback.contains("Correct");

    // ✅ Play the correct or incorrect sound
    if (_audioModule != null) {
      if (isCorrect) {
        final correctSoundPath = _audioModule!.correctSounds["correct_1"];

        if (correctSoundPath != null) {
          final player = AudioPlayer();

          player.setAsset(correctSoundPath).then((_) async {
            Duration? soundDuration = player.duration ?? const Duration(milliseconds: 1500); // Default to 1.5s if null

            // ✅ Play the correct sound
            await player.play();

            // ✅ Wait for the correct sound to finish
            await Future.delayed(soundDuration);

            // ✅ Play the flushing sound after the correct sound finishes
            _audioModule!.playSpecific("flushing_1", _audioModule!.flushingFiles);

            // ✅ Dispose player after use to free memory
            await player.dispose();
          });
        }

        _confettiController.play();
      }
 else {
        _audioModule!.playSpecific("incorrect_1", _audioModule!.incorrectSounds); // ✅ Play incorrect sound
      }
    }

    // ✅ Initialize the animation controller
    _animationController = AnimationController(
      duration: const Duration(seconds: 4), // ✅ 4 seconds total (3s shake + 1s drop)
      vsync: this,
    );

    // ✅ Start animation when widget loads
    if (isCorrect && widget.cachedImage != null) {
      _animationController.forward();
    }
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  String _formatCorrectName(String name) {
    return name
        .replaceAll("_", " ")
        .split(" ")
        .map((word) => word.isNotEmpty ? word[0].toUpperCase() + word.substring(1).toLowerCase() : "")
        .join(" ");
  }

  @override
  Widget build(BuildContext context) {
    bool isCorrect = widget.feedback.contains("Correct");
    String safeCategory = widget.actualCategory.isNotEmpty ? widget.actualCategory : "default";
    int safeLevel = widget.currentLevel > 0 ? widget.currentLevel : 1;

    String backgroundImagePath = isCorrect
        ? 'assets/images/backgrounds/lev$safeLevel/$safeCategory/main_background_$safeCategory.png'
        : 'assets/images/backgrounds/main_background_default.png';

    String backgroundImageOverlayPath = isCorrect
        ? 'assets/images/backgrounds/lev$safeLevel/$safeCategory/main_background_overlay_$safeCategory.png'
        : 'assets/images/backgrounds/main_background_overlay_default.png';

    return Stack(
      alignment: Alignment.center,
      children: [
        if (isCorrect) ...[
          // ✅ Full-Screen Background
          Positioned.fill(
            child: Image.asset(
              backgroundImagePath,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
            ),
          ),

          // ✅ Cached Celeb Image (Shake & Drop Animation Applied)
          if (widget.cachedImage != null)
            Align(
              alignment: Alignment.center,
              child: _animationModule != null
                  ? _animationModule!.applyShakeAndDropAnimation( // ✅ Use the registered instance
                child: FractionallySizedBox(
                  widthFactor: 0.2, // ✅ 10% of the screen width
                  child: Image(
                    image: widget.cachedImage!,
                    fit: BoxFit.contain,
                  ),
                ),
                controller: _animationController, // ✅ Apply animation
              )
                  : FractionallySizedBox( // 🔄 Fallback (if module is null)
                widthFactor: 0.2,
                child: Image(
                  image: widget.cachedImage!,
                  fit: BoxFit.contain,
                ),
              ),
            ),

          // ✅ Full-Screen Overlay
          Positioned.fill(
            child: Image.asset(
              backgroundImageOverlayPath,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
            ),
          ),
        ] else ...[
          // ❌ Black Half-Opacity Background (Only if incorrect)
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.8),
            ),
          ),
        ],

        // ✅ Name/Message Section (Always at the Top)
        Positioned(
          top: MediaQuery.of(context).size.height * 0.15, // ✅ Push to top
          left: 0,
          right: 0,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  widget.feedback,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: isCorrect ? AppColors.accentColor : Colors.redAccent,
                  ),
                ),
              ),

              if (isCorrect)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    _formatCorrectName(widget.correctName),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
        ),

        // ✅ Close Button (Always at the Very Bottom)
        Positioned(
          bottom: MediaQuery.of(context).size.height * 0.05, // ✅ Push to bottom
          left: 0,
          right: 0,
          child: Center(
            child: ElevatedButton(
              onPressed: widget.onClose,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
              ),
              child: const Text("Close", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ),
        ),

        // ✅ Confetti Animation (Only if Correct)
        if (isCorrect)
          Positioned(
            top: MediaQuery.of(context).size.height * 0.20, // ✅ 1/4 from the top
            left: 0,
            right: 0, // ✅ Ensures full width for centering
            child: Align(
              alignment: Alignment.topCenter, // ✅ Center it horizontally
              child: ConfettiWidget(
                confettiController: _confettiController,
                blastDirectionality: BlastDirectionality.explosive,
                emissionFrequency: 0.15,
                numberOfParticles: 15,
                maxBlastForce: 20,
                minBlastForce: 10,
                gravity: 0.1,
              ),
            ),
          ),
      ],
    );
  }
}
