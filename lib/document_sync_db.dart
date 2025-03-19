// ignore_for_file: public_member_api_docs, sort_constructors_first
// document_sync_db.dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:appflowy_editor_sync_plugin/types/sync_db_attributes.dart';
import 'package:drift/drift.dart';
import 'package:rxdart/rxdart.dart';
import 'package:uuid/uuid.dart';

import 'package:appflowy_editor_sync_plugin/core/delay_remove_batcher.dart';
import 'package:appflowy_editor_sync_plugin/document_service_helpers/document_service_wrapper.dart';
import 'package:appflowy_editor_sync_plugin/editor_state_sync_wrapper.dart';
import 'package:appflowy_editor_sync_plugin/types/update_types.dart';

class DocumentSyncDB {
  DocumentSyncDB({required this.docService, required this.syncDBAttributes}) {
    _initBatcher();
  }
  final DocumentServiceWrapper docService;
  final SyncDBAttributes syncDBAttributes;

  late final syncId = Uuid().v4();

  //I need to keep track of already sended updates in order to avoid sending them again
  //Each update is identified by id

  late final updatesBatcher = DelayedRemoveBatcher<LocalUpdate>(
    debounceDuration: const Duration(milliseconds: 500),
    removalDelay: const Duration(seconds: 5),
  );

  // Add this field to your class
  late final BehaviorSubject<(List<LocalUpdate>, List<DbUpdate>)>
  _updatesSubject;

  void dispose() {
    updatesBatcher.dispose();
    _updatesSubject.close();
  }

  // Initialize the batcher with callback in constructor
  void _initBatcher() {
    updatesBatcher.onBatchReady((updates) async {
      try {
        final mergedUpdate = await docService.mergeUpdates(
          updates.map((u) => u.update).toList(),
        );
        await _addUpdateToDB(mergedUpdate);
        return true;
      } catch (e) {
        print('Error processing update batch: $e');
        return false;
      }
    });

    // Initialize the BehaviorSubject
    _updatesSubject = BehaviorSubject<(List<LocalUpdate>, List<DbUpdate>)>();

    // Connect the stream to the subject
    getUpdatesStream().listen(_updatesSubject.add);
  }

  //Get updates stream - that will combine updates from the DB with updates from the batcher
  Stream<(List<LocalUpdate>, List<DbUpdate>)> getUpdatesStream() {
    final dbUpdatesStream = syncDBAttributes.getDBUpdatesStream;

    final batcherUpdatesStream = updatesBatcher.getAllItems();

    // Combine both streams using Rx.combineLatest2
    return Rx.combineLatest2(dbUpdatesStream, batcherUpdatesStream, (
      List<DbUpdate> dbUpdates,
      List<LocalUpdate> batcherUpdates,
    ) {
      return (batcherUpdates, dbUpdates);
    });
  }

  // Update your getLastUpdates method
  (List<LocalUpdate>, List<DbUpdate>)? getLastUpdates() {
    if (!_updatesSubject.hasValue) {
      // Return a default value or null
      return ([], []); // Empty default
    }
    return _updatesSubject.value;
  }

  Future<String?> getRootNodeId() async {
    return syncDBAttributes.getRootNodeId();
  }

  //Save root node id
  Future<void> saveRootNodeId(String rootNodeId) async {
    syncDBAttributes.saveRootNodeId(rootNodeId);
  }

  Future<void> _addUpdateToDB(Uint8List update) async {
    syncDBAttributes.saveUpdate(update);
  }

  void addUpdate(LocalUpdate update) {
    updatesBatcher.addValue(update);
  }

  void addUpdates(List<LocalUpdate> updates) {
    updatesBatcher.addValues(updates);
  }

  Future<List<(String, Uint8List)>> getUpdates() async {
    return syncDBAttributes.getUpdates();
  }

  String localUpdatesLastModificationId() {
    return updatesBatcher.lastModificationId;
  }
}
