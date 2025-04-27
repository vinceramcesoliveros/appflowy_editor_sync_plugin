import 'dart:convert';
import 'dart:typed_data';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:appflowy_editor_sync_plugin/convertors/transaction_adapter_helpers.dart';
import 'package:appflowy_editor_sync_plugin/document_service_helpers/diff_deltas.dart';
import 'package:appflowy_editor_sync_plugin/editor_state_helpers/editor_state_wrapper.dart';
import 'package:appflowy_editor_sync_plugin/extensions/node_extensions.dart';
import 'package:appflowy_editor_sync_plugin/src/rust/doc/document_types.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

extension BlockActionAdapter on Operation {
  List<BlockActionDoc> toBlockAction(EditorStateWrapper editorStateWrapper) {
    final op = this;
    if (op is InsertOperation) {
      return op.toBlockAction(editorStateWrapper);
    } else if (op is UpdateOperation) {
      return op.toBlockAction(editorStateWrapper);
    } else if (op is DeleteOperation) {
      return op.toBlockAction(editorStateWrapper);
    }
    throw UnimplementedError();
  }
}

extension on InsertOperation {
  List<BlockActionDoc> toBlockAction(
    EditorStateWrapper editorStateWrapper, {
    Node? previousNode,
    Node? nextNode,
    Node? parentNode,
  }) {
    var currentPath = path;
    final actions = <BlockActionDoc>[];
    for (final node in nodes) {
      final parentId =
          parentNode?.id ??
          TransactionAdapterHelpers.parentFromPath(
            editorStateWrapper.editorState.document,
            currentPath,
          ).id;
      // node.parent?.id ??
      //     editorStateWrapper.getNodeAtPath(currentPath.parent)?.id ??
      //     '';
      assert(parentId.isNotEmpty);

      var prevId = '';
      // if the node is the first child of the parent, then its prevId should be empty.
      final isFirstChild = currentPath.previous.equals(currentPath);

      if (!isFirstChild) {
        prevId =
            previousNode?.id ??
            editorStateWrapper.getNodeAtPath(currentPath.previous)?.id ??
            '';
      }

      var nextId = '';

      //If the node is the last child of the parent, then its nextId should be empty.
      final isLastChild = currentPath.next.equals(currentPath);
      if (!isLastChild) {
        nextId = editorStateWrapper.getNodeAtPath(currentPath.next)?.id ?? '';
      }

      //If I have a parent from insert, don't share nextid
      if (parentNode != null) {
        nextId = '';
      }

      //TODO: Maybe use prevID to set it faste the previous node if it exists
      // BUt currently it seems to me that it should work well enough with just the indexes

      // create the external text if the node contains the delta in its data.
      final delta = node.delta;
      String? encodedDelta;
      if (delta != null) {
        encodedDelta = jsonEncode(node.delta!.toJson());
      }

      if (prevId == nextId && currentPath[0] == -1) {
        prevId = '';
        nextId = '';
      }

      final blockAction = BlockActionDoc(
        action: BlockActionTypeDoc.insert,
        block: BlockDoc(
          id: node.id,
          ty: node.type,
          attributes:
              node.attributes.toMap()..addAll({
                'device': editorStateWrapper.syncDeviceId,
                'timestamp': DateTime.now().toIso8601String(),
              }),
          delta: encodedDelta,
          parentId: node.type == 'page' ? null : parentId, //HANDLING EDGE CASE
          prevId: prevId == '' ? null : prevId, // Previous ID
          nextId: nextId == '' ? null : nextId, // Next ID
        ),
        path: Uint32List.fromList(currentPath.toList()),
      );

      actions.add(blockAction);
      if (node.children.isNotEmpty) {
        Node? prevChild;
        for (final child in node.children) {
          actions.addAll(
            InsertOperation(child.path, [child]).toBlockAction(
              editorStateWrapper,
              previousNode: prevChild,
              parentNode: node,
            ),
          );
          prevChild = child;
        }
      }
      previousNode = node;
      currentPath = currentPath.next;
    }

    return actions;
  }
}

extension on UpdateOperation {
  List<BlockActionDoc> toBlockAction(EditorStateWrapper editorStateWrapper) {
    final actions = <BlockActionDoc>[];

    // if the attributes are both empty, we don't need to update
    //You can also check for changes in a text, because the text is a delta
    // inside attributes
    if (const DeepCollectionEquality().equals(attributes, oldAttributes)) {
      return actions;
    }
    final node = editorStateWrapper.getNodeAtPath(path);
    if (node == null) {
      assert(false, 'node not found at path: $path');
      return actions;
    }
    // final parentId =
    //     node.parent?.id ??
    //     editorStateWrapper.getNodeAtPath(path.parent)?.id ??
    //     '';
    final parentId =
        TransactionAdapterHelpers.parentFromPath(
          editorStateWrapper.editorState.document,
          node.path,
        ).id;
    assert(parentId.isNotEmpty);

    // create the external text if the node contains the delta in its data.
    final prevDelta = oldAttributes[blockComponentDelta];
    final delta = attributes[blockComponentDelta];

    final diff =
        prevDelta != null && delta != null
            ? diffDeltas(
              jsonEncode(Delta.fromJson(prevDelta)),
              jsonEncode(Delta.fromJson(delta)),
            )
            : null;

    final composedAttributes = composeAttributes(oldAttributes, attributes);
    final composedDelta = composedAttributes?[blockComponentDelta];
    composedAttributes?.remove(blockComponentDelta);

    final blockAction = BlockActionDoc(
      action: BlockActionTypeDoc.update,
      block: BlockDoc(
        id: node.id,
        ty: node.type,
        // I am using compose attributes to say that I had changed all attributes at once
        // So that we don't have some wierd combinations of attributes
        attributes: composedAttributes?.toMap() ?? {},
        delta: diff,
        parentId: parentId,
      ),
      path: Uint32List.fromList(path.toList()),
    );

    actions.add(blockAction);

    return actions;
  }
}

extension on DeleteOperation {
  List<BlockActionDoc> toBlockAction(EditorStateWrapper editorStateWrapper) {
    final actions = <BlockActionDoc>[];
    for (final node in nodes) {
      final parentId =
          TransactionAdapterHelpers.parentFromPath(
            editorStateWrapper.editorState.document,
            node.path,
          ).id;
      // final parentId =
      //     node.parent?.id ??
      //     editorStateWrapper.getNodeAtPath(path.parent)?.id ??
      //     '';
      assert(parentId.isNotEmpty);

      final blockAction = BlockActionDoc(
        action: BlockActionTypeDoc.delete,
        block: BlockDoc(
          id: node.id,
          ty: node.type,
          attributes: {},
          parentId: parentId,
        ),
        path: Uint32List.fromList(path.toList()),
      );

      actions.add(blockAction);
    }
    return actions;
  }
}
