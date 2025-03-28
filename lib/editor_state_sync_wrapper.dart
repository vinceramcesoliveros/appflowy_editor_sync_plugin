// ignore_for_file: public_member_api_docs, sort_constructors_first
// editor_state_sync_wrapper.dart
import 'dart:convert';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:appflowy_editor_sync_plugin/convertors/transaction_adapter_helpers.dart';
import 'package:appflowy_editor_sync_plugin/core/update_clock.dart';
import 'package:appflowy_editor_sync_plugin/document_initializer.dart';
import 'package:appflowy_editor_sync_plugin/document_service_helpers/document_service_wrapper.dart';
import 'package:appflowy_editor_sync_plugin/document_sync_db.dart';
import 'package:appflowy_editor_sync_plugin/editor_state_helpers/editor_state_wrapper.dart';
import 'package:appflowy_editor_sync_plugin/extensions/list_of_updates_extensions.dart';
import 'package:appflowy_editor_sync_plugin/src/rust/doc/document_types.dart';
import 'package:appflowy_editor_sync_plugin/types/sync_db_attributes.dart';
import 'package:appflowy_editor_sync_plugin/types/update_types.dart';
import 'package:flutter/widgets.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

class EditorStateSyncWrapper {
  EditorStateSyncWrapper({required this.syncAttributes});

  final SyncAttributes syncAttributes;

  late final DocumentServiceWrapper docService;
  late final DocumentSyncDB syncDB;
  late final DocumentInitializer initializer;
  late final EditorStateWrapper editorStateWrapper;
  final mapEquality = const DeepCollectionEquality();
  bool isSyncing = false;

  (List<LocalUpdate>, List<DbUpdate>)? pendingSyncUpdates;

  UpdateClock updateClock = UpdateClock();

  Future<EditorState> initAndHandleChanges() async {
    docService = await DocumentServiceWrapper.newInstance();
    initializer = DocumentInitializer(documentService: docService);
    syncDB = DocumentSyncDB(
      docService: docService,
      syncAttributes: syncAttributes,
    );

    editorStateWrapper = await _init();

    // Logic to synchronize document with database
    _listenOnDBUpdates();
    _listenOnEditorUpdates();

    return editorStateWrapper.editorState;
  }

  void dispose() {
    syncDB.dispose();
  }

  Future<EditorStateWrapper> _init() async {
    final documentUpdates = await syncDB.getInitialUpdates();
    if (documentUpdates.isEmpty) {
      final (editorStateWrapper, updates) =
          await initializer.initEmptyDocument();

      final newClock = updateClock.incrementClock();
      syncDB.addUpdates(
        updates.map((e) => LocalUpdate(update: e, id: newClock)).toList(),
      );
      return editorStateWrapper;
    } else {
      final editorStateWrapper = await initializer.initDocumentWithUpdates(
        documentUpdates,
      );
      return editorStateWrapper;
    }
  }

  void _listenOnDBUpdates() {
    syncDB.getAllUpdatesStream().listen((data) async {
      if (isSyncing) {
        pendingSyncUpdates = data;
        return;
      }

      await _startSyncOperation(data);
    });
  }

  Future<void> _startSyncOperation(
    (List<LocalUpdate>, List<DbUpdate>) updates,
  ) async {
    isSyncing = true;

    try {
      await _processSyncOperation(updates);
    } finally {
      isSyncing = false;

      // Check if new updates arrived during processing
      final pending = pendingSyncUpdates;
      if (pending != null) {
        pendingSyncUpdates = null;
        await _startSyncOperation(pending);
      }
    }
  }

  Future<void> _processSyncOperation(
    (List<LocalUpdate>, List<DbUpdate>) updates,
  ) async {
    //Check if I have latest update // Or if it is not in
    if (!updates.$1.syncCanBeDone(updateClock)) {
      return;
    }

    try {
      await docService.applyUpdates(
        update:
            updates.$1.map((e) => e.update).toList() +
            updates.$2.map((e) => e.update).toList(),
      );
    } catch (e) {
      print(e);
    }
    //Check if I have latest update // Or if it is not in
    if (!updates.$1.syncCanBeDone(updateClock)) {
      return;
    }

    final result = await docService.getDocumentJson();

    //Check if I have latest update
    if (!updates.$1.syncCanBeDone(updateClock)) {
      return;
    }

    // Create a new state from the current document and apply operations
    // that were not yet recorded in that CRDT Document
    final newEditorStateWrapper = EditorStateWrapper.factoryFromDocumentState(
      result,
    );

    final diffOperations = editorStateWrapper.diffEditorStateWrappers(
      newEditorStateWrapper,
    );
    if (diffOperations.isEmpty) {
      return;
    }

    if (diffOperations.isNotEmpty) {
      // Apply the operations to the editor state
      editorStateWrapper.applyRemoteChanges(diffOperations);

      prettyfyAndPrintInChunksDocumentState(result);
    }
  }

  void prettyfyAndPrintInChunksDocumentState(DocumentState docState) {
    final json = docState.toJson();
    final prettyJson = JsonEncoder.withIndent('  ').convert(json);
    final lines = prettyJson.split('\n');
    for (var line in lines) {
      debugPrint(line);
    }
  }

  void _listenOnEditorUpdates() {
    editorStateWrapper.listenEditorChanges().listen((data) async {
      final (transactionTime, transaction, options) = data;

      if (TransactionTime.before != transactionTime) {
        print("Transaction done");
        return;
      }

      final actions = TransactionAdapterHelpers.operationsToBlockActions(
        transaction.operations,
        editorStateWrapper,
      );

      final newClock = updateClock.incrementClock();

      final update = await docService.applyAction(actions: actions);
      await update.match(
        () async {
          // //Recreate document with all available updates
          // final latestUpdates = syncDB.getLastUpdates();
          // if (latestUpdates != null) {
          //   final mergedUpdates = latestUpdates.$2
          //     ..addAll(latestUpdates.$1.map((e) => (uuid.v4(), e)).toList());
          //   await docService.applyUpdates(
          //     update: mergedUpdates,
          //   );
          // }

          // final update = await docService.applyAction(actions: actions);

          // update.match(() => null, (update) {
          //   syncDB.addUpdates([update]);
          // });
        },
        (update) {
          syncDB.addUpdates([LocalUpdate(update: update, id: newClock)]);
        },
      );
    });
  }
}
//I will save with each local update its Datetime and then I will check inside the sync,
// that the latest id of local updates is the same as the latest datetime of local updates
// Or maybe by using some kind of int version number


// What I need to guraentee:
// If the sync is executed, I have all local updates + db updates available, including updates
// for the latest state of the document.

