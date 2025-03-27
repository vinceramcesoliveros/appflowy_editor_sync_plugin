// editor_state_changes_batcher.dart

// Interface for EditorUpdatesBatcher
import 'dart:async';

import 'package:easy_debounce/easy_debounce.dart';
import 'package:flutter/foundation.dart';
import 'package:mutex/mutex.dart';
import 'package:rxdart/rxdart.dart';
import 'package:uuid/uuid.dart';

abstract class BatcherInterface<T> {
  /// Adds an update to the batch.
  void addValue(T update);

  /// Adds multiple updates to the batch.
  void addValues(List<T> updates);

  /// Registers a callback to process batches when they are ready.
  /// The callback returns true if the batch was processed successfully, false otherwise.
  void onBatchReady(Future<bool> Function(List<T> batch) processCallback);

  /// Return unprocessed values
  Stream<List<T>> getUprocessedValues();

  /// Last modification id
  /// Everytime a new element it added to the batch, it gets a new id
  String getLastModificationId();

  //Dispose
  void dispose();
}

// Implementation of the batcher
class Batcher<T> implements BatcherInterface<T> {
  Batcher({required this.debounceDuration}) {
    _streamController = BehaviorSubject<List<T>>.seeded([]);
  }

  final Duration debounceDuration;

  late final tag = uuid.v4();
  @protected
  final List<(String, T)> updatesBatch = [];
  @protected
  final Mutex modifyUpdatesMutex = Mutex();
  Future<bool> Function(List<T>)? _processCallback;
  late final BehaviorSubject<List<T>> _streamController;

  final uuid = const Uuid();

  ///Last modification id
  /// Everytime a new element it added to the batch, it gets a new id
  /// This is used to track the last modification
  late String lastModificationId = uuid.v4();

  @override
  void addValue(T update) {
    final batchId = uuid.v4();
    updatesBatch.add((batchId, update));
    emitCurrentValues();
    _debounceBatchProcessing();
    lastModificationId = batchId;
  }

  @override
  void addValues(List<T> updates) {
    final batchId = uuid.v4();
    updatesBatch.addAll(updates.map((e) => (batchId, e)));
    emitCurrentValues();
    _debounceBatchProcessing();
    lastModificationId = batchId;
  }

  @override
  void onBatchReady(Future<bool> Function(List<T> batch) processCallback) {
    _processCallback = processCallback;
  }

  void _debounceBatchProcessing() {
    EasyDebounce.debounce(tag, debounceDuration, _processBatch);
  }

  Future<void> _processBatch() async {
    await modifyUpdatesMutex.protect(() async {
      if (updatesBatch.isEmpty || _processCallback == null) return;

      final batch = List<(String, T)>.from(updatesBatch);
      final batchUpdates = batch.map((e) => e.$2).toList();
      final batchUuids = batch.map((e) => e.$1).toList();

      final success = await _processCallback!(batchUpdates);
      if (success) {
        updatesBatch.removeWhere((element) => batchUuids.contains(element.$1));
      }
    });
  }

  // Helper method to emit current values to the stream
  @protected
  void emitCurrentValues() {
    final values = updatesBatch.map((e) => e.$2).toList();
    _streamController.add(values);
  }

  @override
  Stream<List<T>> getUprocessedValues() {
    return _streamController.stream;
  }

  // Remember to close the stream controller when done
  @override
  void dispose() {
    _streamController.close();
  }

  @override
  String getLastModificationId() {
    return lastModificationId;
  }
}
