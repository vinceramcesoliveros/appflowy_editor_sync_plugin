import 'dart:async';
import 'dart:typed_data';

import 'package:appflowy_editor_sync_plugin/src/rust/doc/document_service.dart';
import 'package:appflowy_editor_sync_plugin/src/rust/doc/document_types.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mutex/mutex.dart'; // Import the mutex library

// Wrapper class to handle mutex synchronization on the Dart side using the mutex library
class DocumentServiceWrapper {
  // Use mutex library for thread-safe locking

  DocumentServiceWrapper._(this._rustService);
  final DocumentService _rustService;
  final Mutex _mutex = Mutex();

  // Factory constructor to create a new instance with mutex handling
  // This uses flutter_rust_bridge's generated method
  static Future<DocumentServiceWrapper> newInstance() async {
    final rustService = await DocumentService.newInstance();
    return DocumentServiceWrapper._(rustService);
  }

  //Return if the mutex is available now
  bool isMutexNotAvailable() {
    return _mutex.isLocked;
  }

  @override
  Future<Option<Uint8List>> applyAction({
    required List<BlockActionDoc> actions,
  }) async {
    try {
      // Acquire the mutex lock asynchronously
      await _mutex.acquire();
      final res = await _rustService.applyAction(actions: actions);
      return Option.of(res);
    } catch (e) {
      // Handle any errors from Rust, including ConcurrentAccessError

      print('Failed to apply action: $e');
      return const None();
    } finally {
      // Release the mutex lock
      _mutex.release();
    }
  }

  /// Setting a root node id in the root map
  Future<Option<Uint8List>> setRootNodeId({required String id}) async {
    try {
      // Acquire the mutex lock asynchronously
      await _mutex.acquire();
      final res = await _rustService.setRootNodeId(id: id);
      return Option.of(res);
    } catch (e) {
      // Handle any errors from Rust, including ConcurrentAccessError

      print('Failed to set root id: $e');
      return const None();
    } finally {
      // Release the mutex lock
      _mutex.release();
    }
  }

  @override
  Future<Either<Error, Unit>> applyUpdates({
    required List<Uint8List> update,
  }) async {
    try {
      await _mutex.acquire();
      await _rustService.applyUpdates(updates: update);
      return Either.right(unit);
    } catch (e) {
      print('Failed to apply updates: $e');
      return Either.left(Error());
    } finally {
      _mutex.release();
    }
  }

  @override
  Future<DocumentState> getDocumentJson() async {
    try {
      await _mutex.acquire();
      return await _rustService.getDocumentState();
    } catch (e) {
      throw Exception('Failed to get document JSON: $e');
    } finally {
      _mutex.release();
    }
  }

  @override
  Future<Uint8List> initEmptyDoc() async {
    try {
      await _mutex.acquire();
      return await _rustService.initEmptyDoc();
    } catch (e) {
      throw Exception('Failed to initialize empty document: $e');
    } finally {
      _mutex.release();
    }
  }

  //Write override for mergeUpdates
  Future<Uint8List> mergeUpdates(List<Uint8List> updates) async {
    //There is no need to acquire the mutex lock here. Because it doesn't use the editor at all.
    try {
      return await _rustService.mergeUpdates(updates: updates);
    } catch (e) {
      throw Exception('Failed to merge updates: $e');
    } finally {}
  }
}
