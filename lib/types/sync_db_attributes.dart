import 'dart:typed_data';

import 'package:appflowy_editor_sync_plugin/types/update_types.dart';

/// Defines the required database operations for document synchronization
class SyncDBAttributes {
  /// Stream that emits database updates when they occur
  /// Used for real-time monitoring of changes to sync state
  final Stream<List<DbUpdate>> getUpdatesStream;

  /// Function to retrieve the current root node ID from storage
  /// Returns null if no root node has been established yet
  final Future<String?> Function() getRootNodeId;

  /// Function to persist the root node ID to storage
  /// Called when a new document is initialized or when the root changes
  final Future<void> Function(String rootNodeId) saveRootNodeId;

  /// Function to save a binary update to persistent storage
  /// Takes a serialized update as Uint8List (binary data)
  final Future<void> Function(Uint8List update) saveUpdate;

  /// Function to retrieve all stored updates from persistence layer
  /// Returns a list of tuples containing update ID and binary update data
  final Future<List<(String, Uint8List)>> Function() getUpdates;

  SyncDBAttributes({
    required this.getUpdatesStream,
    required this.getRootNodeId,
    required this.saveRootNodeId,
    required this.saveUpdate,
    required this.getUpdates,
  });
}
