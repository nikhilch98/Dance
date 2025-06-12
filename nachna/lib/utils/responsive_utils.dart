import 'package:flutter/material.dart';

class ResponsiveUtils {
  static double screenWidth(BuildContext context) {
    return MediaQuery.of(context).size.width;
  }
  
  static double screenHeight(BuildContext context) {
    return MediaQuery.of(context).size.height;
  }
  
  // Font Size Utilities
  static double h1(BuildContext context) {
    // Main headers (28px -> responsive)
    return (screenWidth(context) * 0.07).clamp(24.0, 32.0);
  }
  
  static double h2(BuildContext context) {
    // Section headers (24px -> responsive)
    return (screenWidth(context) * 0.06).clamp(20.0, 28.0);
  }
  
  static double h3(BuildContext context) {
    // Sub headers (20px -> responsive)
    return (screenWidth(context) * 0.05).clamp(18.0, 24.0);
  }
  
  static double body1(BuildContext context) {
    // Main body text (16px -> responsive)
    return (screenWidth(context) * 0.04).clamp(14.0, 18.0);
  }
  
  static double body2(BuildContext context) {
    // Secondary body text (14px -> responsive)
    return (screenWidth(context) * 0.035).clamp(12.0, 16.0);
  }
  
  static double caption(BuildContext context) {
    // Small text (12px -> responsive)
    return (screenWidth(context) * 0.03).clamp(10.0, 14.0);
  }
  
  static double micro(BuildContext context) {
    // Very small text (10px -> responsive)
    return (screenWidth(context) * 0.025).clamp(8.0, 12.0);
  }
  
  // Icon Size Utilities
  static double iconXSmall(BuildContext context) {
    return (screenWidth(context) * 0.035).clamp(12.0, 16.0);
  }
  
  static double iconSmall(BuildContext context) {
    return (screenWidth(context) * 0.045).clamp(16.0, 20.0);
  }
  
  static double iconMedium(BuildContext context) {
    return (screenWidth(context) * 0.055).clamp(20.0, 24.0);
  }
  
  static double iconLarge(BuildContext context) {
    return (screenWidth(context) * 0.07).clamp(24.0, 32.0);
  }
  
  static double iconXLarge(BuildContext context) {
    return (screenWidth(context) * 0.1).clamp(36.0, 48.0);
  }
  
  // Spacing Utilities
  static double spacingXSmall(BuildContext context) {
    return screenWidth(context) * 0.01; // ~4px on 400px screen
  }
  
  static double spacingSmall(BuildContext context) {
    return screenWidth(context) * 0.02; // ~8px on 400px screen
  }
  
  static double spacingMedium(BuildContext context) {
    return screenWidth(context) * 0.03; // ~12px on 400px screen
  }
  
  static double spacingLarge(BuildContext context) {
    return screenWidth(context) * 0.04; // ~16px on 400px screen
  }
  
  static double spacingXLarge(BuildContext context) {
    return screenWidth(context) * 0.05; // ~20px on 400px screen
  }
  
  static double spacingXXLarge(BuildContext context) {
    return screenWidth(context) * 0.06; // ~24px on 400px screen
  }
  
  // Padding Utilities
  static EdgeInsets paddingSmall(BuildContext context) {
    return EdgeInsets.all(spacingSmall(context));
  }
  
  static EdgeInsets paddingMedium(BuildContext context) {
    return EdgeInsets.all(spacingMedium(context));
  }
  
  static EdgeInsets paddingLarge(BuildContext context) {
    return EdgeInsets.all(spacingLarge(context));
  }
  
  static EdgeInsets paddingXLarge(BuildContext context) {
    return EdgeInsets.all(spacingXLarge(context));
  }
  
  static EdgeInsets paddingSymmetricH(BuildContext context) {
    return EdgeInsets.symmetric(horizontal: spacingLarge(context));
  }
  
  static EdgeInsets paddingSymmetricV(BuildContext context) {
    return EdgeInsets.symmetric(vertical: spacingMedium(context));
  }
  
  // Container Size Utilities
  static double cardBorderRadius(BuildContext context) {
    return (screenWidth(context) * 0.04).clamp(16.0, 24.0);
  }
  
  static double buttonHeight(BuildContext context) {
    return (screenHeight(context) * 0.055).clamp(44.0, 60.0);
  }
  
  static double avatarSize(BuildContext context) {
    return (screenWidth(context) * 0.12).clamp(40.0, 60.0);
  }
  
  static double avatarSizeLarge(BuildContext context) {
    return (screenWidth(context) * 0.2).clamp(60.0, 100.0);
  }
  
  // Border Width Utilities
  static double borderWidthThin(BuildContext context) {
    return (screenWidth(context) * 0.002).clamp(1.0, 1.5);
  }
  
  static double borderWidthMedium(BuildContext context) {
    return (screenWidth(context) * 0.004).clamp(1.5, 2.5);
  }
  
  // Screen Size Helpers
  static bool isSmallScreen(BuildContext context) {
    return screenWidth(context) < 360;
  }
  
  static bool isMediumScreen(BuildContext context) {
    return screenWidth(context) >= 360 && screenWidth(context) < 768;
  }
  
  static bool isLargeScreen(BuildContext context) {
    return screenWidth(context) >= 768;
  }
  
  // Grid Helpers
  static int getGridColumns(BuildContext context) {
    if (isSmallScreen(context)) return 2;
    if (isMediumScreen(context)) return 2;
    return 3; // Large screens
  }
  
  static double getChildAspectRatio(BuildContext context) {
    if (isSmallScreen(context)) return 0.9; // More compact for small screens
    if (isMediumScreen(context)) return 0.95;  // More compact for better fit
    return 1.0; // Closer to square for large screens
  }
  
  // Dynamic Container Sizing
  static double artistCardWidth(BuildContext context) {
    // Dynamic width based on screen size and grid columns
    final screenW = screenWidth(context);
    final columns = getGridColumns(context);
    final gridSpacing = spacingLarge(context);
    final horizontalPadding = spacingLarge(context) * 2; // Left and right padding
    
    return (screenW - horizontalPadding - (gridSpacing * (columns - 1))) / columns;
  }
  
  static double artistCardHeight(BuildContext context) {
    // Dynamic height based on card width and aspect ratio
    return artistCardWidth(context) / getChildAspectRatio(context);
  }
  
  static double artistImageHeight(BuildContext context) {
    // Image takes up about 75% of the card height for more visual impact
    return artistCardHeight(context) * 0.75;
  }
  
  static double artistCardPadding(BuildContext context) {
    // Reduced padding for more compact cards
    return (artistCardWidth(context) * 0.06).clamp(8.0, 16.0);
  }
  
  static double artistCardInnerSpacing(BuildContext context) {
    // Minimal spacing inside cards for compact design
    return (artistCardHeight(context) * 0.015).clamp(4.0, 8.0);
  }
} 