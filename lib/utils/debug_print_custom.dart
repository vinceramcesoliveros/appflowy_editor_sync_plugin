import 'package:appflowy_editor_sync_plugin/editor_state_sync_wrapper.dart';
import 'package:flutter/foundation.dart';

void debugPrintCustom(String text) {
  if (kDebugMode && EditorStateSyncWrapper.debug) {
    debugPrint(text);
  }
}
