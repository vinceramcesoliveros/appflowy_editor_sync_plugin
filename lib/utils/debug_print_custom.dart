import 'package:flutter/foundation.dart';

void debugPrintCustom(String text) {
  if (kDebugMode) {
    debugPrint(text);
  }
}
