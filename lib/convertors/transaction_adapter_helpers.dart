// transaction_adapter_helpers.dart
import 'dart:typed_data';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:appflowy_editor_sync_plugin/editor_state_helpers/editor_state_wrapper.dart';
import 'package:appflowy_editor_sync_plugin/extensions/operation_extensions.dart';
import 'package:appflowy_editor_sync_plugin/src/rust/doc/document_types.dart';
import 'package:appflowy_editor_sync_plugin/types/operation_wrapper.dart';
import 'package:fpdart/fpdart.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

class TransactionAdapterHelpers {
  // Check if a Delete and Insert pair represents a Move
  static bool _isMoveOperation(
    DeleteOperation deleteOp,
    InsertOperation insertOp,
  ) {
    if (deleteOp.nodes.length != 1 || insertOp.nodes.length != 1) return false;
    final deleteNode = deleteOp.nodes.first;
    final insertNode = insertOp.nodes.first;
    return deleteNode.id == insertNode.id &&
        deleteNode.type == insertNode.type &&
        _nodesEqual(deleteNode, insertNode);
  }

  // Recursively compare nodes for equality (ID, type, attributes, delta, children)
  static bool _nodesEqual(Node node1, Node node2) {
    if (node1.id != node2.id || node1.type != node2.type) return false;
    if (!const DeepCollectionEquality().equals(
      node1.attributes,
      node2.attributes,
    ))
      return false;
    if (node1.delta?.toJson().toString() != node2.delta?.toJson().toString())
      return false;
    if (node1.children.length != node2.children.length) return false;
    for (var i = 0; i < node1.children.length; i++) {
      if (!_nodesEqual(node1.children[i], node2.children[i])) return false;
    }
    return true;
  }

  /// Convert a list of operations to operation wrappers, detecting moves
  static List<OperationWrapper> convertToOperationWrappers(
    List<Operation> operations,
    EditorStateWrapper editorStateWrapper,
  ) {
    final wrappers = <OperationWrapper>[];

    for (var i = 0; i < operations.length; i++) {
      final op = operations[i];

      // Check for move operations (delete followed by insert of same node)
      if (op is DeleteOperation && i + 1 < operations.length) {
        final nextOp = operations[i + 1];
        if (nextOp is InsertOperation && _isMoveOperation(op, nextOp)) {
          final node = op.nodes.first;
          wrappers.add(
            OperationWrapper(
              node: node,
              type: OperationWrapperType.Move,
              firstOperation: op,
              optionalSecondOperation: Some(nextOp),
            ),
          );
          i++; // Skip the next operation
          continue;
        }
      }

      // Handle other operation types
      if (op is InsertOperation) {
        for (final node in op.nodes) {
          wrappers.add(
            OperationWrapper(
              node: node,
              type: OperationWrapperType.Insert,
              firstOperation: op,
              optionalSecondOperation: const None(),
            ),
          );
        }
      } else if (op is DeleteOperation) {
        for (final node in op.nodes) {
          wrappers.add(
            OperationWrapper(
              node: node,
              type: OperationWrapperType.Delete,
              firstOperation: op,
              optionalSecondOperation: const None(),
            ),
          );
        }
      } else if (op is UpdateOperation) {
        final node = editorStateWrapper.editorState.getNodeAtPath(op.path)!;
        wrappers.add(
          OperationWrapper(
            node: node,
            type: OperationWrapperType.Update,
            firstOperation: op,
            optionalSecondOperation: const None(),
          ),
        );
      }
    }

    return wrappers;
  }

  static List<BlockActionDoc> operationWrappersToBlockActions(
    List<OperationWrapper> wrapped,
    EditorStateWrapper editorStateWrapper,
  ) {
    return wrapped
        .map((e) {
          return operationWrapperToBlockActions(e, editorStateWrapper);
        })
        .flatten
        .toList();
  }

  //Converting OperationWrapper to BlockActionDoc
  static List<BlockActionDoc> operationWrapperToBlockActions(
    OperationWrapper e,
    EditorStateWrapper editorStateWrapper,
  ) {
    if (e.type == OperationWrapperType.Move) {
      final op = e.firstOperation as DeleteOperation;
      final nextOp = e.optionalSecondOperation.toNullable()! as InsertOperation;
      final deleteNode = op.nodes.first;
      final insertNode = nextOp.nodes.first;

      final newPath = insertNode.path;

      var prevId = '';
      // if the node is the first child of the parent, then its prevId should be empty.
      final isFirstChild = newPath.previous.equals(newPath);

      if (!isFirstChild) {
        prevId = editorStateWrapper.getNodeAtPath(newPath.previous)?.id ?? '';
      }
      return [
        BlockActionDoc(
          action: BlockActionTypeDoc.move,
          block: BlockDoc(
            id: 'xxxx',
            ty: 'xxxx',
            attributes: {},
            parentId: insertNode.parent?.id ?? '', //Just this
            oldParentId: deleteNode.parent?.id ?? '', // And this
            prevId: prevId,
          ), // No block data needed; move uses paths
          path: Uint32List.fromList(nextOp.path.toList()), // New path
          oldPath: Uint32List.fromList(op.path.toList()), // Old path
        ),
      ];
    } else if (e.type == OperationWrapperType.Insert) {
      return e.firstOperation.toBlockAction(editorStateWrapper);
    } else if (e.type == OperationWrapperType.Update) {
      return e.firstOperation.toBlockAction(editorStateWrapper);
    } else if (e.type == OperationWrapperType.Delete) {
      return e.firstOperation.toBlockAction(editorStateWrapper);
    }
    throw UnimplementedError();
  }

  static List<BlockActionDoc> operationsToBlockActions(
    List<Operation> operations,
    EditorStateWrapper editorStateWrapper,
  ) {
    final wrapped = convertToOperationWrappers(operations, editorStateWrapper);
    return operationWrappersToBlockActions(wrapped, editorStateWrapper);
  }
}
