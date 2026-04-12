import 'package:flutter/material.dart';

class ResponsiveHelper {
  /// Screen size breakpoints
  static const double mobileBreakpoint = 600;
  static const double tabletBreakpoint = 900;

  /// Get screen width
  static double screenWidth(BuildContext context) {
    return MediaQuery.of(context).size.width;
  }

  /// Get screen height
  static double screenHeight(BuildContext context) {
    return MediaQuery.of(context).size.height;
  }

  /// Check if device is mobile
  static bool isMobile(BuildContext context) {
    return screenWidth(context) < mobileBreakpoint;
  }

  /// Check if device is tablet
  static bool isTablet(BuildContext context) {
    return screenWidth(context) >= mobileBreakpoint &&
        screenWidth(context) < tabletBreakpoint;
  }

  /// Check if device is desktop
  static bool isDesktop(BuildContext context) {
    return screenWidth(context) >= tabletBreakpoint;
  }

  /// Get responsive width (percentage of screen width)
  static double responsiveWidth(BuildContext context, double percentage) {
    return screenWidth(context) * (percentage / 100);
  }

  /// Get responsive height (percentage of screen height)
  static double responsiveHeight(BuildContext context, double percentage) {
    return screenHeight(context) * (percentage / 100);
  }

  /// Get responsive padding based on screen size
  static EdgeInsets responsivePadding(
    BuildContext context, {
    double mobileValue = 16,
    double tabletValue = 24,
    double desktopValue = 32,
  }) {
    double paddingValue;
    if (isMobile(context)) {
      paddingValue = mobileValue;
    } else if (isTablet(context)) {
      paddingValue = tabletValue;
    } else {
      paddingValue = desktopValue;
    }
    return EdgeInsets.all(paddingValue);
  }

  /// Get responsive font size
  static double responsiveFontSize(
    BuildContext context, {
    double mobileSize = 14,
    double tabletSize = 16,
    double desktopSize = 18,
  }) {
    if (isMobile(context)) {
      return mobileSize;
    } else if (isTablet(context)) {
      return tabletSize;
    } else {
      return desktopSize;
    }
  }

  /// Get responsive heading size
  static double headingSize(
    BuildContext context, {
    double mobileSize = 24,
    double tabletSize = 28,
    double desktopSize = 32,
  }) {
    if (isMobile(context)) {
      return mobileSize;
    } else if (isTablet(context)) {
      return tabletSize;
    } else {
      return desktopSize;
    }
  }

  /// Get responsive button height
  static double buttonHeight(BuildContext context) {
    return isMobile(context) ? 48 : 56;
  }

  /// Get responsive icon size
  static double iconSize(
    BuildContext context, {
    double mobileSize = 24,
    double tabletSize = 28,
    double desktopSize = 32,
  }) {
    if (isMobile(context)) {
      return mobileSize;
    } else if (isTablet(context)) {
      return tabletSize;
    } else {
      return desktopSize;
    }
  }

  /// Get columns for grid layout
  static int gridColumns(BuildContext context) {
    if (isMobile(context)) {
      return 1;
    } else if (isTablet(context)) {
      return 2;
    } else {
      return 3;
    }
  }

  /// Get max width for content (useful for tablets/desktops)
  static double maxContentWidth(BuildContext context) {
    return isDesktop(context) ? 1200 : screenWidth(context);
  }

  /// Get responsive spacing
  static double spacing(BuildContext context, double baseValue) {
    final width = screenWidth(context);
    return baseValue * (width / 375); // 375 is reference mobile width
  }
}
