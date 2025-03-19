// document_sync_db.dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:appflowy_editor_sync_plugin/core/delay_remove_batcher.dart';
import 'package:appflowy_editor_sync_plugin/document_service_helpers/document_service_wrapper.dart';
import 'package:appflowy_editor_sync_plugin/editor_state_sync_wrapper.dart';
import 'package:drift/drift.dart';
import 'package:rxdart/rxdart.dart';
import 'package:uuid/uuid.dart';

class DocumentSyncDB {
  DocumentSyncDB(this.db, this.taskId, this.docService) {
    _initBatcher();
  }
  final DocumentServiceWrapper docService;
  final AppDatabase
  db; // Placeholder for database instance (e.g., Drift or SQLite)
  final String taskId;

  late final syncId = Uuid().v4();

  //I need to keep track of already sended updates in order to avoid sending them again
  //Each update is identified by id

  final List<String> _sendedUpdates = [];

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

  // void onUpdateListener(List<Uint8List> updates) {
  //   // Logic to handle updates
  // }
  //Listen on updates on db.docUpdates table and return changes as a stream
  Stream<List<DbUpdate>> getDBUpdatesStream() async* {
    final updatesSel =
        db.select(db.docUpdates)
          ..where((u) => u.taskId.equals(taskId))
          ..orderBy([(u) => OrderingTerm.asc(u.createdAt)]);
    final stream = updatesSel.watch();

    // Change the type to match what watch() returns
    await for (final List<DocUpdate> updates in stream) {
      yield updates
          .map((u) => DbUpdate(update: base64Decode(u.dataB64), id: u.id))
          .toList();
      final filteredUpdates = updates.where(
        (u) => !_sendedUpdates.contains(u.id),
      );
      if (filteredUpdates.isNotEmpty) {
        //Print in detail the updates
        print('Current syncid: $syncId');
        print(
          'Received updates: ${const JsonEncoder.withIndent(' ').convert({'updates': filteredUpdates.map((u) => u.toJson()).toList()})}',
        );
        // yield filteredUpdates.map((u) => base64Decode(u.dataB64)).toList();
        // yield filteredUpdates
        //     .map((u) => (u.id, base64Decode(u.dataB64)))
        //     .toList();
        _sendedUpdates.addAll(filteredUpdates.map((u) => u.id));
      }
    }
  }

  //Get updates stream - that will combine updates from the DB with updates from the batcher
  Stream<(List<LocalUpdate>, List<DbUpdate>)> getUpdatesStream() {
    final dbUpdatesStream = getDBUpdatesStream();

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

  //Get all Updates length

  //Helper private function to get taskData for taskId
  Future<TaskData> getTaskData() async {
    final taskDataSel = db.select(db.task)..where((t) => t.id.equals(taskId));
    return taskDataSel.getSingle();
  }

  Future<String?> getRootNodeId() async {
    final taskData = await getTaskData();

    return taskData.docRootNode;
  }

  //Save root node id
  Future<void> saveRootNodeId(String rootNodeId) async {
    await (db.update(db.task)..where(
      (tbl) => tbl.id.equals(taskId),
    )).write(TaskCompanion(docRootNode: Value(rootNodeId)));
  }

  Future<void> _addUpdateToDB(Uint8List update) async {
    final accountId = (await getTaskData()).accountId;

    await db
        .into(db.docUpdates)
        .insert(
          DocUpdatesCompanion.insert(
            taskId: taskId,
            accountId: accountId,
            createdAt: DateTime.now(),
            dataB64: base64Encode(update),
            syncId: syncId,
          ),
        );
  }

  void addUpdate(LocalUpdate update) {
    updatesBatcher.addValue(update);
  }

  void addUpdates(List<LocalUpdate> updates) {
    updatesBatcher.addValues(updates);
  }

  Future<List<(String, Uint8List)>> getUpdates() async {
    final updatesSel = db.select(db.docUpdates)
      ..where((u) => u.taskId.equals(taskId));
    final updates = await updatesSel.get();

    _sendedUpdates.addAll(updates.map((u) => u.id));
    return updates.map((u) => (u.id, base64Decode(u.dataB64))).toList();
  }

  String localUpdatesLastModificationId() {
    return updatesBatcher.lastModificationId;
  }
}
