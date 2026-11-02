import 'package:flutter/foundation.dart';

class AppEvents {

  static final ValueNotifier<int> refreshNotifier = ValueNotifier(0);

  static void fireRefresh() {
    refreshNotifier.value++;
  }
}
