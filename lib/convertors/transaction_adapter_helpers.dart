// transaction_adapter_helpers.dart
import 'dart:typed_data';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:appflowy_editor_sync_plugin/document_service_helpers/document_with_metadata.dart';
import 'package:appflowy_editor_sync_plugin/extensions/operation_extensions.dart';
import 'package:appflowy_editor_sync_plugin/src/rust/doc/document_types.dart';
import 'package:appflowy_editor_sync_plugin/types/operation_wrapper.dart';
import 'package:dartx/dartx.dart';
import 'package:flutter/foundation.dart';
import 'package:fpdart/fpdart.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

class TransactionAdapterHelpers {
  // Check if a Delete and Insert pair represents a Move
  static bool _isMoveOperation(
    DeleteOperation deleteOp,
    InsertOperation insertOp,
  ) {
    debugPrint('🔍 Checking if operation is a move...');
    if (deleteOp.nodes.length != 1 || insertOp.nodes.length != 1) {
      debugPrint('❌ Not a move: Node count mismatch');
      return false;
    }

    final deleteNode = deleteOp.nodes.first;
    final insertNode = insertOp.nodes.first;

    debugPrint(
      '🔄 Comparing nodes - ID: ${deleteNode.id} == ${insertNode.id}, Type: ${deleteNode.type} == ${insertNode.type}',
    );

    final result =
        deleteNode.id == insertNode.id &&
        deleteNode.type == insertNode.type &&
        _nodesEqual(deleteNode, insertNode);

    debugPrint(
      result ? '✅ Identified as move operation' : '❌ Not a move operation',
    );
    return result;
  }

  // Recursively compare nodes for equality (ID, type, attributes, delta, children)
  static bool _nodesEqual(Node node1, Node node2) {
    debugPrint('  🔍 Comparing nodes ${node1.id} and ${node2.id}');

    if (node1.id != node2.id || node1.type != node2.type) {
      debugPrint('  ❌ Node ID or type mismatch');
      return false;
    }

    if (!const DeepCollectionEquality().equals(
      node1.attributes,
      node2.attributes,
    )) {
      debugPrint('  ❌ Node attributes mismatch');
      return false;
    }

    if (node1.delta?.toJson().toString() != node2.delta?.toJson().toString()) {
      debugPrint('  ❌ Node delta mismatch');
      return false;
    }

    if (node1.children.length != node2.children.length) {
      debugPrint(
        '  ❌ Node children length mismatch: ${node1.children.length} vs ${node2.children.length}',
      );
      return false;
    }

    for (var i = 0; i < node1.children.length; i++) {
      if (!_nodesEqual(node1.children[i], node2.children[i])) {
        debugPrint('  ❌ Child node mismatch at index $i');
        return false;
      }
    }

    debugPrint('  ✅ Nodes are equal');
    return true;
  }

  /// Convert a list of operations to operation wrappers, detecting moves
  static List<OperationWrapper> convertToOperationWrappers(
    List<Operation> operations,
    ModifiableDocumentWithMetadata currentDocument,
  ) {
    debugPrint('🔄 Converting ${operations.length} operations to wrappers');
    // debugPrint(
    //   '📄 Document state: ${currentDocument.prettyPrint()} root children',
    // );

    final wrappers = <OperationWrapper>[];

    for (var i = 0; i < operations.length; i++) {
      final op = operations[i];
      debugPrint(
        '🔍 Processing operation ${i + 1}/${operations.length}: ${op.runtimeType}',
      );

      // Check for move operations (delete followed by insert of same node)
      if (op is DeleteOperation && i + 1 < operations.length) {
        final nextOp = operations[i + 1];
        if (nextOp is InsertOperation && _isMoveOperation(op, nextOp)) {
          debugPrint('🔄 Creating Move wrapper for delete+insert pair');
          wrappers.add(
            OperationWrapper(
              type: OperationWrapperType.Move,
              firstOperation: op,
              optionalSecondOperation: Some(nextOp),
            ),
          );
          debugPrint('⏩ Skipping next operation (part of move)');
          i++; // Skip the next operation
          continue;
        }
      }

      // Handle other operation types
      if (op is InsertOperation) {
        debugPrint('📥 Creating Insert wrapper');
        wrappers.add(
          OperationWrapper(
            type: OperationWrapperType.Insert,
            firstOperation: op,
            optionalSecondOperation: const None(),
          ),
        );
      } else if (op is DeleteOperation) {
        debugPrint('🗑️ Creating Delete wrapper');
        wrappers.add(
          OperationWrapper(
            type: OperationWrapperType.Delete,
            firstOperation: op,
            optionalSecondOperation: const None(),
          ),
        );
      } else if (op is UpdateOperation) {
        debugPrint('🔄 Creating Update wrapper');
        wrappers.add(
          OperationWrapper(
            type: OperationWrapperType.Update,
            firstOperation: op,
            optionalSecondOperation: const None(),
          ),
        );
      }
    }

    debugPrint('✅ Created ${wrappers.length} operation wrappers');
    return wrappers;
  }

  static List<BlockActionDoc> operationWrappersToBlockActions(
    List<OperationWrapper> wrapped,
    ModifiableDocumentWithMetadata currentDocument,
  ) {
    debugPrint(
      '🔄 Converting ${wrapped.length} operation wrappers to block actions',
    );
    // debugPrint(
    //   '📄 Document state before conversion: ${currentDocument.prettyPrint()} root children',
    // );

    final converted = wrapped.map((e) {
      debugPrint('🔍 Converting wrapper of type ${e.type}');
      return operationWrapperToBlockActions(e, currentDocument);
    });

    final result = IterableIterableX(converted).flatten().toList();
    debugPrint('✅ Created ${result.length} block actions');
    return result;
  }

  //Converting OperationWrapper to BlockActionDoc
  static List<BlockActionDoc> operationWrapperToBlockActions(
    OperationWrapper e,
    ModifiableDocumentWithMetadata currentDocument,
  ) {
    if (e.type == OperationWrapperType.Move) {
      debugPrint('🔄 Processing Move operation');
      final op = e.firstOperation as DeleteOperation;
      final nextOp = e.optionalSecondOperation.toNullable()! as InsertOperation;
      final deleteNode = op.nodes.first;
      final insertNode = nextOp.nodes.first;

      debugPrint(
        '🔍 Move node - ID: ${deleteNode.id}, Type: ${deleteNode.type}',
      );
      debugPrint('🔍 Path change - Old: ${op.path}, New: ${nextOp.path}');

      final newPath = nextOp.path;
      final oldPath = op.path;

      //If the path is the same, return an empty list
      if (newPath.equals(oldPath)) {
        debugPrint('⚠️ Move operation skipped: paths are identical');
        return [];
      }

      // debugPrint(
      //   '📄 Current document state: ${jsonEncode(currentDocument.document.toJsonWithIds()).substring(0, 100)}...',
      // );

      var prevId = '';

      debugPrint('🔄 Creating document copy for move simulation');
      // final documentCopy = DocumentExtensions.fromJsonWithIds(
      //   jsonDecode(jsonEncode(currentDocument.document.toJsonWithIds())),
      // );
      final oldParent = parentFromPath(currentDocument.document, op.path);
      debugPrint('👆 Old parent ID: ${oldParent.id}');

      debugPrint('🗑️ Simulating delete at path: ${op.path}');
      currentDocument.document.delete(op.path, op.nodes.length);

      // if the node is the first child of the parent, then its prevId should be empty.
      final isFirstChild = newPath.previous.equals(newPath);
      debugPrint('🔍 Is first child at new position: $isFirstChild');

      if (!isFirstChild) {
        prevId =
            currentDocument.document.nodeAtPath(newPath.previous)?.id ?? '';
        debugPrint('👈 Previous node ID: $prevId');
      } else {
        debugPrint('👈 No previous node (first child)');
      }

      var nextId = '';

      //If the node is the last child of the parent, then its nextId should be empty.
      final isLastChild = newPath.next.equals(newPath);
      debugPrint('🔍 Is last child at new position: $isLastChild');

      if (!isLastChild) {
        nextId = currentDocument.document.nodeAtPath(newPath)?.id ?? '';
        debugPrint('👉 Next node ID: $nextId');
      } else {
        debugPrint('👉 No next node (last child)');
      }

      final newParent = parentFromPath(currentDocument.document, newPath);
      debugPrint('👆 New parent ID: ${newParent.id}');

      debugPrint('📥 Simulating insert at path: ${nextOp.path}');
      currentDocument.document.insert(nextOp.path, nextOp.nodes);

      // debugPrint(
      //   '📄 Document structure after simulation: ${jsonEncode(currentDocument.document.toJsonWithIds())}',
      // );

      final blockAction = BlockActionDoc(
        action: BlockActionTypeDoc.move,
        block: BlockDoc(
          id: deleteNode.id,
          ty: deleteNode.type,
          attributes: {},
          parentId: newParent.id,
          oldParentId: oldParent.id,
          prevId: prevId == '' ? null : prevId, // Previous ID
          nextId: nextId == '' ? null : nextId, // Next ID
        ),
        path: Uint32List.fromList(nextOp.path.toList()), // New path
        oldPath: Uint32List.fromList(op.path.toList()), // Old path
      );

      debugPrint('✅ Created move BlockActionDoc:');
      debugPrint('  - Block ID: ${blockAction.block.id}');
      debugPrint(
        '  - oldParentId: ${blockAction.block.oldParentId}, parentId: ${blockAction.block.parentId}',
      );
      debugPrint(
        '  - prevId: ${blockAction.block.prevId}, nextId: ${blockAction.block.nextId}',
      );

      return [blockAction];
    } else if (e.type == OperationWrapperType.Insert) {
      debugPrint('📥 Processing Insert operation');
      final actions = e.firstOperation.toBlockAction(currentDocument);
      debugPrint('✅ Created ${actions.length} insert action(s)');
      return actions;
    } else if (e.type == OperationWrapperType.Update) {
      debugPrint('🔄 Processing Update operation');
      final actions = e.firstOperation.toBlockAction(currentDocument);
      debugPrint('✅ Created ${actions.length} update action(s)');
      return actions;
    } else if (e.type == OperationWrapperType.Delete) {
      debugPrint('🗑️ Processing Delete operation');
      final actions = e.firstOperation.toBlockAction(currentDocument);
      debugPrint('✅ Created ${actions.length} delete action(s)');
      return actions;
    }
    debugPrint('❌ Unknown operation type: ${e.type}');
    throw UnimplementedError('Unknown operation type: ${e.type}');
  }

  static List<BlockActionDoc> operationsToBlockActions(
    List<Operation> operations,
    ModifiableDocumentWithMetadata currentDocumentCopy,
  ) {
    debugPrint(
      '🔄 Converting ${operations.length} operations to block actions',
    );
    debugPrint(
      '📄 Document state: ${currentDocumentCopy.prettyPrint()} root children',
    );

    final wrapped = convertToOperationWrappers(operations, currentDocumentCopy);
    debugPrint('✅ Created ${wrapped.length} operation wrappers');

    final result = operationWrappersToBlockActions(
      wrapped,
      currentDocumentCopy,
    );
    debugPrint('✅ Final result: ${result.length} block actions');

    return result;
  }

  static Node parentFromPath(Document doc, Path path) {
    debugPrint('🔍 Finding parent for path: $path');
    // Makes from [0, 1] -> [0]
    final withoutLast = path.parent;

    if (withoutLast.isEmpty) {
      debugPrint('👆 Parent is root node');
      return doc.root;
    }

    //Take node based on withoutLast
    final parent = doc.nodeAtPath(withoutLast) ?? doc.root;
    debugPrint('👆 Found parent with ID: ${parent.id}');
    return parent;
  }
}
