import 'package:flutter/material.dart';

extension ResponsiveHelper on BuildContext {
  double get screenWidth => MediaQuery.of(this).size.width;
  double get screenHeight => MediaQuery.of(this).size.height;

  bool get isMobile => screenWidth < 600;
  bool get isTablet => screenWidth >= 600 && screenWidth < 1200;
  bool get isDesktop => screenWidth >= 1200;

  /// Scales the width based on a reference width (default: 375 for mobile)
  double scaleW(double factor, {double? referenceWidth}) {
    final ref = referenceWidth ?? (isMobile ? 375.0 : 1280.0);
    return factor * (screenWidth / ref);
  }

  /// Scales the height based on a reference height (default: 812 for mobile)
  double scaleH(double factor, {double? referenceHeight}) {
    final ref = referenceHeight ?? (isMobile ? 812.0 : 800.0);
    return factor * (screenHeight / ref);
  }

  /// Returns a responsive value based on screen type
  T responsive<T>(T mobile, {T? tablet, T? desktop}) {
    if (isDesktop && desktop != null) return desktop;
    if (isTablet && tablet != null) return tablet;
    return mobile;
  }
}
