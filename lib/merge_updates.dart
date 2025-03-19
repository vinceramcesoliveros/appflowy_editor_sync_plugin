import 'dart:typed_data';

import 'package:appflowy_editor_sync_plugin/src/rust/doc/document.dart';

/// Merges multiple document updates into a single update
///
/// This is a utility function that doesn't require a document instance
/// and can be used for offline update processing.
Future<Uint8List> mergeUpdates(List<Uint8List> updates) async {
  // Using the DocumentService directly since we don't need the wrapper's mutex
  final documentService = await DocumentService.newInstance(
    docId: "temp_id_for_merging",
  );
  try {
    return await documentService.mergeUpdates(updates: updates);
  } catch (e) {
    throw Exception('Failed to merge updates: $e');
  }
}
