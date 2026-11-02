import 'package:flutter/material.dart';

import 'package:flutter/widgets.dart';

class ResponsiveMobile {
  static final double _baseHeight = 19.5;
  static final double _baseWidth = 9;

  static double _heightRatio(BuildContext context) {
    return MediaQuery.sizeOf(context).height / _baseHeight;
  }

  static double _widthRatio(BuildContext context) {
    return MediaQuery.sizeOf(context).width / _baseWidth;
  }

  static double rh(BuildContext context, double height) {
    return height * _heightRatio(context);
  }

  static double rw(BuildContext context, double width) {
    return width * _widthRatio(context);
  }

  static double sp(BuildContext context, double size) {
    double ratio = (_heightRatio(context) + _widthRatio(context)) / 2;
    return size * ratio;
  }
}
