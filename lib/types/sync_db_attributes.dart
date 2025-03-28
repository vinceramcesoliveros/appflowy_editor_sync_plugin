import 'dart:typed_data';

import 'package:appflowy_editor_sync_plugin/types/update_types.dart';

/// Defines the required database operations for document synchronization
class SyncAttributes {
  /// Stream that emits database updates when they occur
  /// Used for real-time monitoring of changes to sync state
  final Stream<List<DbUpdate>> getUpdatesStream;

  /// Function to save a binary update to persistent storage
  /// Takes a serialized update as Uint8List (binary data)
  final Future<void> Function(Uint8List update) saveUpdate;

  /// Function to retrieve all stored updates from persistence layer
  /// Returns a list of tuples containing update ID and binary update data
  final Future<List<DbUpdate>> Function() getInitialUpdates;

  SyncAttributes({
    required this.getUpdatesStream,
    required this.saveUpdate,
    required this.getInitialUpdates,
  });
}
