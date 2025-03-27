import 'dart:async';

import 'package:appflowy_editor_sync_plugin/core/batcher.dart';
import 'package:rxdart/rxdart.dart';
import 'package:uuid/uuid.dart';

/// Delayed remove batcher that processes elements as batcher, but waits for some duration before it fully removes them
class DelayedRemoveBatcher<T> extends Batcher<T> {
  DelayedRemoveBatcher({
    required super.debounceDuration,
    required this.removalDelay,
  });

  /// Duration to wait before fully removing processed items
  final Duration removalDelay;

  /// Map of processed items and their scheduled removal time
  final Map<String, (DateTime removalTime, T item)> _processedItems = {};

  /// Stream controller for all items (both pending and processed but not yet removed)
  late final BehaviorSubject<List<T>> allItemsController =
      BehaviorSubject<List<T>>.seeded([]);

  /// Timer for cleanup
  Timer? _cleanupTimer;

  @override
  void onBatchReady(Future<bool> Function(List<T> batch) processCallback) {
    super.onBatchReady((batch) async {
      final result = await processCallback(batch);

      if (result) {
        // When a batch is successfully processed, store the items with removal time
        final now = DateTime.now();
        final removalTime = now.add(removalDelay);

        for (final val in updatesBatch.map((e) => e.$2).toList()) {
          _processedItems[Uuid().v4()] = (removalTime, val);
        }

        // Start cleanup
        _cleanupExpiredItems();
      }

      return result;
    });
  }

  /// Get a stream of all items (both pending and processed but not yet removed)
  Stream<List<T>> getAllItems() {
    return allItemsController.stream;
  }

  /// Update the all items stream with current values
  void _updateAllItemsStream() {
    final pendingItems = updatesBatch.map((e) => e.$2).toList();
    final processedItems = _processedItems.values.map((e) => e.$2).toList();

    allItemsController.add([...pendingItems, ...processedItems]);
  }

  /// Remove items that have exceeded their retention period
  void _cleanupExpiredItems() {
    final now = DateTime.now();
    final expiredKeys = <String>[];

    for (final entry in _processedItems.entries) {
      if (entry.value.$1.isBefore(now)) {
        expiredKeys.add(entry.key);
      }
    }

    if (expiredKeys.isNotEmpty) {
      for (final key in expiredKeys) {
        _processedItems.remove(key);
      }
    }

    // If no more processed items, cancel the timer
    if (_processedItems.isEmpty) {
      _cleanupTimer?.cancel();
      _cleanupTimer = null;
    }
  }

  @override
  void emitCurrentValues() {
    _updateAllItemsStream();
  }

  @override
  void dispose() {
    super.dispose();
    _cleanupTimer?.cancel();
    allItemsController.close();
  }

  /// Get all items that have been processed but not yet removed
  List<T> getProcessedItems() {
    return _processedItems.values.map((e) => e.$2).toList();
  }

  /// Check if there are any processed items not yet removed
  bool hasProcessedItems() {
    return _processedItems.isNotEmpty;
  }

  //Get all items stream
  Stream<List<T>> get allItemsStream => allItemsController.stream;
}
