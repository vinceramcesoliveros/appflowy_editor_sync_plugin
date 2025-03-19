import 'dart:typed_data';

import 'package:appflowy_editor_sync_plugin/core/update_clock.dart';

class LocalUpdate {
  final Uint8List update;
  final String id;
  LocalUpdate({required this.update, required this.id});
}

class DbUpdate {
  final Uint8List update;
  final String id;
  DbUpdate({required this.update, required this.id});
}
