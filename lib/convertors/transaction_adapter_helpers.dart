// transaction_adapter_helpers.dart
import 'dart:typed_data';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:appflowy_editor_sync_plugin/document_service_helpers/document_with_metadata.dart';
import 'package:appflowy_editor_sync_plugin/extensions/operation_extensions.dart';
import 'package:appflowy_editor_sync_plugin/src/rust/doc/document_types.dart';
import 'package:appflowy_editor_sync_plugin/types/operation_wrapper.dart';
import 'package:appflowy_editor_sync_plugin/utils/debug_print_custom.dart';
import 'package:dartx/dartx.dart';
import 'package:fpdart/fpdart.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

class TransactionAdapterHelpers {
  // Check if a Delete and Insert pair represents a Move
  static bool _isMoveOperation(
    DeleteOperation deleteOp,
    InsertOperation insertOp,
  ) {
    debugPrintCustom('🔍 Checking if operation is a move...');
    if (deleteOp.nodes.length != 1 || insertOp.nodes.length != 1) {
      debugPrintCustom('❌ Not a move: Node count mismatch');
      return false;
    }

    final deleteNode = deleteOp.nodes.first;
    final insertNode = insertOp.nodes.first;

    debugPrintCustom(
      '🔄 Comparing nodes - ID: ${deleteNode.id} == ${insertNode.id}, Type: ${deleteNode.type} == ${insertNode.type}',
    );

    final result =
        deleteNode.id == insertNode.id &&
        deleteNode.type == insertNode.type &&
        _nodesEqual(deleteNode, insertNode);

    debugPrintCustom(
      result ? '✅ Identified as move operation' : '❌ Not a move operation',
    );
    return result;
  }

  // Recursively compare nodes for equality (ID, type, attributes, delta, children)
  static bool _nodesEqual(Node node1, Node node2) {
    debugPrintCustom('  🔍 Comparing nodes ${node1.id} and ${node2.id}');

    if (node1.id != node2.id || node1.type != node2.type) {
      debugPrintCustom('  ❌ Node ID or type mismatch');
      return false;
    }

    if (!const DeepCollectionEquality().equals(
      node1.attributes,
      node2.attributes,
    )) {
      debugPrintCustom('  ❌ Node attributes mismatch');
      return false;
    }

    if (node1.delta?.toJson().toString() != node2.delta?.toJson().toString()) {
      debugPrintCustom('  ❌ Node delta mismatch');
      return false;
    }

    if (node1.children.length != node2.children.length) {
      debugPrintCustom(
        '  ❌ Node children length mismatch: ${node1.children.length} vs ${node2.children.length}',
      );
      return false;
    }

    for (var i = 0; i < node1.children.length; i++) {
      if (!_nodesEqual(node1.children[i], node2.children[i])) {
        debugPrintCustom('  ❌ Child node mismatch at index $i');
        return false;
      }
    }

    debugPrintCustom('  ✅ Nodes are equal');
    return true;
  }

  /// Convert a list of operations to operation wrappers, detecting moves
  static List<OperationWrapper> convertToOperationWrappers(
    List<Operation> operations,
    ModifiableDocumentWithMetadata currentDocument,
  ) {
    debugPrintCustom(
      '🔄 Converting ${operations.length} operations to wrappers',
    );
    // debugPrintCustom(
    //   '📄 Document state: ${currentDocument.prettyPrint()} root children',
    // );

    final wrappers = <OperationWrapper>[];

    for (var i = 0; i < operations.length; i++) {
      final op = operations[i];
      debugPrintCustom(
        '🔍 Processing operation ${i + 1}/${operations.length}: ${op.runtimeType}',
      );

      // Check for move operations (delete followed by insert of same node)
      if (op is DeleteOperation && i + 1 < operations.length) {
        final nextOp = operations[i + 1];
        if (nextOp is InsertOperation && _isMoveOperation(op, nextOp)) {
          debugPrintCustom('🔄 Creating Move wrapper for delete+insert pair');
          wrappers.add(
            OperationWrapper(
              type: OperationWrapperType.Move,
              firstOperation: op,
              optionalSecondOperation: Some(nextOp),
            ),
          );
          debugPrintCustom('⏩ Skipping next operation (part of move)');
          i++; // Skip the next operation
          continue;
        }
      }

      // Handle other operation types
      if (op is InsertOperation) {
        debugPrintCustom('📥 Creating Insert wrapper');
        wrappers.add(
          OperationWrapper(
            type: OperationWrapperType.Insert,
            firstOperation: op,
            optionalSecondOperation: const None(),
          ),
        );
      } else if (op is DeleteOperation) {
        debugPrintCustom('🗑️ Creating Delete wrapper');
        wrappers.add(
          OperationWrapper(
            type: OperationWrapperType.Delete,
            firstOperation: op,
            optionalSecondOperation: const None(),
          ),
        );
      } else if (op is UpdateOperation) {
        debugPrintCustom('🔄 Creating Update wrapper');
        wrappers.add(
          OperationWrapper(
            type: OperationWrapperType.Update,
            firstOperation: op,
            optionalSecondOperation: const None(),
          ),
        );
      }
    }

    debugPrintCustom('✅ Created ${wrappers.length} operation wrappers');
    return wrappers;
  }

  static List<BlockActionDoc> operationWrappersToBlockActions(
    List<OperationWrapper> wrapped,
    ModifiableDocumentWithMetadata currentDocument,
  ) {
    debugPrintCustom(
      '🔄 Converting ${wrapped.length} operation wrappers to block actions',
    );
    // debugPrintCustom(
    //   '📄 Document state before conversion: ${currentDocument.prettyPrint()} root children',
    // );

    final converted = wrapped.map((e) {
      debugPrintCustom('🔍 Converting wrapper of type ${e.type}');
      return operationWrapperToBlockActions(e, currentDocument);
    });

    final result = IterableIterableX(converted).flatten().toList();
    debugPrintCustom('✅ Created ${result.length} block actions');
    return result;
  }

  //Converting OperationWrapper to BlockActionDoc
  static List<BlockActionDoc> operationWrapperToBlockActions(
    OperationWrapper e,
    ModifiableDocumentWithMetadata currentDocument,
  ) {
    if (e.type == OperationWrapperType.Move) {
      debugPrintCustom('🔄 Processing Move operation');
      final op = e.firstOperation as DeleteOperation;
      final nextOp = e.optionalSecondOperation.toNullable()! as InsertOperation;
      final deleteNode = op.nodes.first;

      debugPrintCustom(
        '🔍 Move node - ID: ${deleteNode.id}, Type: ${deleteNode.type}',
      );
      debugPrintCustom('🔍 Path change - Old: ${op.path}, New: ${nextOp.path}');

      final newPath = nextOp.path;
      final oldPath = op.path;

      //If the path is the same, return an empty list
      if (newPath.equals(oldPath)) {
        debugPrintCustom('⚠️ Move operation skipped: paths are identical');
        return [];
      }

      // debugPrintCustom(
      //   '📄 Current document state: ${jsonEncode(currentDocument.document.toJsonWithIds()).substring(0, 100)}...',
      // );

      var prevId = '';

      debugPrintCustom('🔄 Creating document copy for move simulation');
      // final documentCopy = DocumentExtensions.fromJsonWithIds(
      //   jsonDecode(jsonEncode(currentDocument.document.toJsonWithIds())),
      // );
      final oldParent = parentFromPath(currentDocument.document, op.path);
      debugPrintCustom('👆 Old parent ID: ${oldParent.id}');

      debugPrintCustom('🗑️ Simulating delete at path: ${op.path}');
      currentDocument.document.delete(op.path, op.nodes.length);

      // if the node is the first child of the parent, then its prevId should be empty.
      final isFirstChild = newPath.previous.equals(newPath);
      debugPrintCustom('🔍 Is first child at new position: $isFirstChild');

      if (!isFirstChild) {
        prevId =
            currentDocument.document.nodeAtPath(newPath.previous)?.id ?? '';
        debugPrintCustom('👈 Previous node ID: $prevId');
      } else {
        debugPrintCustom('👈 No previous node (first child)');
      }

      var nextId = '';

      //If the node is the last child of the parent, then its nextId should be empty.
      final isLastChild = newPath.next.equals(newPath);
      debugPrintCustom('🔍 Is last child at new position: $isLastChild');

      if (!isLastChild) {
        nextId = currentDocument.document.nodeAtPath(newPath)?.id ?? '';
        debugPrintCustom('👉 Next node ID: $nextId');
      } else {
        debugPrintCustom('👉 No next node (last child)');
      }

      final newParent = parentFromPath(currentDocument.document, newPath);
      debugPrintCustom('👆 New parent ID: ${newParent.id}');

      debugPrintCustom('📥 Simulating insert at path: ${nextOp.path}');
      currentDocument.document.insert(nextOp.path, nextOp.nodes);

      // debugPrintCustom(
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

      debugPrintCustom('✅ Created move BlockActionDoc:');
      debugPrintCustom('  - Block ID: ${blockAction.block.id}');
      debugPrintCustom(
        '  - oldParentId: ${blockAction.block.oldParentId}, parentId: ${blockAction.block.parentId}',
      );
      debugPrintCustom(
        '  - prevId: ${blockAction.block.prevId}, nextId: ${blockAction.block.nextId}',
      );

      return [blockAction];
    } else if (e.type == OperationWrapperType.Insert) {
      debugPrintCustom('📥 Processing Insert operation');
      final actions = e.firstOperation.toBlockAction(currentDocument);
      debugPrintCustom('✅ Created ${actions.length} insert action(s)');
      return actions;
    } else if (e.type == OperationWrapperType.Update) {
      debugPrintCustom('🔄 Processing Update operation');
      final actions = e.firstOperation.toBlockAction(currentDocument);
      debugPrintCustom('✅ Created ${actions.length} update action(s)');
      return actions;
    } else if (e.type == OperationWrapperType.Delete) {
      debugPrintCustom('🗑️ Processing Delete operation');
      final actions = e.firstOperation.toBlockAction(currentDocument);
      debugPrintCustom('✅ Created ${actions.length} delete action(s)');
      return actions;
    }
    debugPrintCustom('❌ Unknown operation type: ${e.type}');
    throw UnimplementedError('Unknown operation type: ${e.type}');
  }

  static List<BlockActionDoc> operationsToBlockActions(
    List<Operation> operations,
    ModifiableDocumentWithMetadata currentDocumentCopy,
  ) {
    debugPrintCustom(
      '🔄 Converting ${operations.length} operations to block actions',
    );
    debugPrintCustom(
      '📄 Document state: ${currentDocumentCopy.prettyPrint()} root children',
    );

    final wrapped = convertToOperationWrappers(operations, currentDocumentCopy);
    debugPrintCustom('✅ Created ${wrapped.length} operation wrappers');

    final result = operationWrappersToBlockActions(
      wrapped,
      currentDocumentCopy,
    );
    debugPrintCustom('✅ Final result: ${result.length} block actions');

    return result;
  }

  static Node parentFromPath(Document doc, Path path) {
    debugPrintCustom('🔍 Finding parent for path: $path');
    // Makes from [0, 1] -> [0]
    final withoutLast = path.parent;

    if (withoutLast.isEmpty) {
      debugPrintCustom('👆 Parent is root node');
      return doc.root;
    }

    //Take node based on withoutLast
    final parent = doc.nodeAtPath(withoutLast) ?? doc.root;
    debugPrintCustom('👆 Found parent with ID: ${parent.id}');
    return parent;
  }
}
