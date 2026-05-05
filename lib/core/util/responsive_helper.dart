import 'dart:math' as math;
import 'package:flutter/material.dart';

extension ResponsiveHelper on BuildContext {
  double get screenWidth => MediaQuery.of(this).size.width;
  double get screenHeight => MediaQuery.of(this).size.height;

  bool get isSmallPhone => screenWidth < 360;
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

  /// Width for dialogs, capped to viewport on small screens.
  double dialogWidth({double max = 400}) =>
      math.min(max, screenWidth * 0.92);

  /// Height for dialogs, capped to 70% of viewport.
  double dialogHeight({double max = 300}) =>
      math.min(max, screenHeight * 0.7);

  /// Standard mobile-first font sizes.
  double get titleFont => responsive<double>(18, tablet: 20, desktop: 22);
  double get bodyFont => responsive<double>(13, tablet: 14, desktop: 15);
  double get labelFont => responsive<double>(11, tablet: 12, desktop: 13);

  /// Default page padding.
  double get pagePadding => responsive<double>(8, tablet: 12, desktop: 16);
}
