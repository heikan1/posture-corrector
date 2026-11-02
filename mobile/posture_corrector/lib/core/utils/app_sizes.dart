import 'package:flutter/material.dart';

class AppSizes {
  AppSizes._();

  static const double cardRadiusBig = 16.0;

  static const double p4 = 4.0;
  static const double p8 = 8.0;
  static const double p12 = 12.0;
  static const double p16 = 16.0;
  static const double p24 = 24.0;
  static const double p32 = 32.0;

  static const EdgeInsets pagePadding = EdgeInsets.all(p16);
  static const EdgeInsets cardPadding = EdgeInsets.symmetric(
    horizontal: p16,
    vertical: p12,
  );
  static const EdgeInsets horizontalPadding = EdgeInsets.symmetric(
    horizontal: p16,
  );

  static const gapH8 = SizedBox(height: p8);
  static const gapH16 = SizedBox(height: p16);
  static const gapW16 = SizedBox(width: p16);
}
