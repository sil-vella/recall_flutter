import 'dart:io';
import 'dart:ui'; // Required for BackdropFilter

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../../../tools/logging/logger.dart';

class CelebImage extends StatelessWidget {
  final String imageUrl;
  final Function(ImageProvider) onImageLoaded;
  final int currentLevel;
  final String actualCategory;

  const CelebImage({
    Key? key,
    required this.imageUrl,
    required this.onImageLoaded,
    required this.currentLevel,
    required this.actualCategory,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Ensure category and level are valid
    String safeCategory = actualCategory.isNotEmpty ? actualCategory : "default";
    int safeLevel = currentLevel > 0 ? currentLevel : 1;

    // Construct the background image paths
    String backgroundImagePath = actualCategory.isNotEmpty
        ? 'assets/images/backgrounds/lev$safeLevel/$safeCategory/main_background_$safeCategory.png'
        : 'assets/images/backgrounds/main_background_default.png';

    String backgroundImageOverlayPath = actualCategory.isNotEmpty
        ? 'assets/images/backgrounds/lev$safeLevel/$safeCategory/main_background_overlay_$safeCategory.png'
        : 'assets/images/backgrounds/main_background_overlay_default.png';

    return Stack(
      fit: StackFit.expand,
      children: [
        // Full background image
        Image.asset(
          backgroundImagePath,
          fit: BoxFit.cover, // Covers the full screen
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (context, error, stackTrace) {
            Logger().error("⚠️ Possible issue loading background image: $backgroundImagePath | Error: $error");
            return Container(color: Colors.black); // Fallback background
          },
        ),

        Align(
          alignment: Alignment.center,
          child: FractionallySizedBox(
            widthFactor: 0.2, // 10% of the screen width
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 6.0, sigmaY: 6.0), // ✅ Directly blur the image
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.contain,
                placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                errorWidget: (context, url, error) {
                  Logger().error("⚠️ Issue loading network image: $imageUrl | Error: $error");
                  return Image.asset('assets/images/icon.png', fit: BoxFit.contain);
                },
                imageBuilder: (context, imageProvider) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    Logger().info("📸 Image Loaded and cached: $imageUrl");
                    onImageLoaded(imageProvider);
                  });
                  return Image(image: imageProvider, fit: BoxFit.contain);
                },
              ),
            ),
          ),
        ),


        Image.asset(
          backgroundImageOverlayPath,
          fit: BoxFit.cover, // Covers the full screen
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (context, error, stackTrace) {
            Logger().error("⚠️ Possible issue loading background image: $backgroundImageOverlayPath | Error: $error");
            return Container(color: Colors.black); // Fallback background
          },
        ),
      ],
    );
  }
}
