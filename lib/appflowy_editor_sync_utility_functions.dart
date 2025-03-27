import 'dart:typed_data';

import 'package:appflowy_editor_sync_plugin/document_initializer.dart';
import 'package:appflowy_editor_sync_plugin/document_service_helpers/document_service_wrapper.dart';
import 'package:appflowy_editor_sync_plugin/src/rust/doc/document_service.dart';
import 'package:appflowy_editor_sync_plugin/src/rust/frb_generated.dart';

class AppflowyEditorSyncUtilityFunctions {
  /// It must be called on initialization of the app. It will call RustLib.init
  // So that the Rust library is initialized and ready to use.
  static Future<void> initAppFlowyEditorSync() async {
    await RustLib.init();
  }

  // This function will create default state for a document without the need to open it
  // This is important in collaborative environment as when task can have a text area and thanks to this inisializaiton it
  // the necessary synchronization structure already setup.
  static Future<List<Uint8List>> initDocument() async {
    final docService = await DocumentServiceWrapper.newInstance();
    final initializer = DocumentInitializer(documentService: docService);
    final (editorStateWrapper, updates) = await initializer.initEmptyDocument();
    return updates;
  }

  /// Merges multiple document updates into a single update
  ///
  /// This is a utility function that doesn't require a document instance
  /// and can be used for offline update processing.
  Future<Uint8List> mergeUpdates(List<Uint8List> updates) async {
    // Using the DocumentService directly since we don't need the wrapper's mutex
    final documentService = await DocumentService.newInstance();
    try {
      return await documentService.mergeUpdates(updates: updates);
    } catch (e) {
      throw Exception('Failed to merge updates: $e');
    }
  }
}
