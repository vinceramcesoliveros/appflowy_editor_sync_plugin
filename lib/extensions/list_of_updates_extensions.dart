import 'dart:typed_data';

import 'package:appflowy_editor_sync_plugin/core/update_clock.dart';
import 'package:appflowy_editor_sync_plugin/types/update_types.dart';

extension ListOfLocalUpadateExtension on List<LocalUpdate> {
  List<Uint8List> get updates => map((e) => e.update).toList();

  bool syncCanBeDone(UpdateClock updateClock) {
    final isInitialUpdate = updateClock.isInitialState();
    if (isInitialUpdate) {
      return true;
    }
    return map((e) => e.id).contains(updateClock.getLatestClock());
  }
}
