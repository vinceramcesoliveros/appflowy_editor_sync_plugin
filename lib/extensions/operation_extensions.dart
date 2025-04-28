import 'dart:convert';
import 'dart:typed_data';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:appflowy_editor_sync_plugin/convertors/transaction_adapter_helpers.dart';
import 'package:appflowy_editor_sync_plugin/document_service_helpers/diff_deltas.dart';
import 'package:appflowy_editor_sync_plugin/document_service_helpers/document_with_metadata.dart';
import 'package:appflowy_editor_sync_plugin/extensions/node_extensions.dart';
import 'package:appflowy_editor_sync_plugin/src/rust/doc/document_types.dart';
import 'package:flutter/foundation.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

extension BlockActionAdapter on Operation {
  List<BlockActionDoc> toBlockAction(
    ModifiableDocumentWithMetadata currentDocumentCopy,
  ) {
    debugPrint('🔄 Converting $runtimeType to block action');
    final op = this;
    if (op is InsertOperation) {
      return op.toBlockAction(currentDocumentCopy);
    } else if (op is UpdateOperation) {
      return op.toBlockAction(currentDocumentCopy);
    } else if (op is DeleteOperation) {
      return op.toBlockAction(currentDocumentCopy);
    }
    debugPrint('❌ Unsupported operation type: ${op.runtimeType}');
    throw UnimplementedError('Unsupported operation type: ${op.runtimeType}');
  }
}

extension on InsertOperation {
  List<BlockActionDoc> toBlockAction(
    ModifiableDocumentWithMetadata currentDocumentCopy, {
    Node? previousNode,
    Node? nextNode,
    Node? parentNode,
  }) {
    debugPrint('📥 Processing InsertOperation');
    debugPrint(
      '🔄 InsertOperation: ${JsonEncoder.withIndent(' ').convert(toJson())}',
    );
    debugPrint('🔍 Insert path: $path');
    if (previousNode != null)
      debugPrint('👈 Previous node: ${previousNode.id}');
    if (nextNode != null) debugPrint('👉 Next node: ${nextNode.id}');
    if (parentNode != null) debugPrint('👆 Parent node: ${parentNode.id}');

    debugPrint(
      '📄 Document state: ${currentDocumentCopy.prettyPrint()} root children',
    );

    var insertPath = path;
    var currentPath = path;
    final actions = <BlockActionDoc>[];
    // Track previous node between iterations
    Node? currentPreviousNode = previousNode;

    // For multiple nodes, we need to handle the connections between them
    final nodesList = nodes.toList();
    debugPrint('🔍 Inserting ${nodesList.length} node(s)');

    for (int i = 0; i < nodesList.length; i++) {
      final node = nodesList[i];
      final isLastNodeInBatch = i == nodesList.length - 1;
      debugPrint(
        '🔍 Processing node ${i + 1}/${nodesList.length}: ID ${node.id}, type ${node.type}',
      );

      final parent =
          parentNode ??
          TransactionAdapterHelpers.parentFromPath(
            currentDocumentCopy.document,
            currentPath,
          );
      final parentId = parent.id;
      debugPrint('👆 Parent ID: $parentId');
      assert(parentId.isNotEmpty);

      var prevId = '';
      // if the node is the first child of the parent, then its prevId should be empty.
      final isFirstChild = currentPath.previous.equals(currentPath);
      debugPrint('🔍 Is first child: $isFirstChild');

      if (!isFirstChild) {
        prevId =
            currentPreviousNode?.id ??
            currentDocumentCopy.document.nodeAtPath(insertPath.previous)?.id ??
            '';
        debugPrint('👈 Previous node ID: $prevId');
      } else {
        debugPrint('👈 No previous node (first child)');
      }

      //THE NEXT ID IS ONLY USED WHN PREVID = NULL
      var nextId = '';

      // If this isn't the last node in our batch, the next ID should be the next node in our batch
      if (!isLastNodeInBatch) {
        nextId = nodesList[i + 1].id;
        debugPrint('👉 Next node is another node in batch: $nextId');
      } else {
        if (insertPath.isNotEmpty) {
          nextId =
              nextNode?.id ??
              currentDocumentCopy.document.nodeAtPath(insertPath)?.id ??
              "";
          debugPrint('👉 Next node ID: $nextId');
        }
      }

      //If I have a parent from insert, don't share nextid
      if (parentNode != null && isLastNodeInBatch) {
        debugPrint('👉 Clearing nextId because this is a child node insert');
        nextId = '';
      }

      // create the external text if the node contains the delta in its data.
      final delta = node.delta;
      String? encodedDelta;
      if (delta != null) {
        encodedDelta = jsonEncode(node.delta!.toJson());
        debugPrint('📝 Node contains delta text');
      }

      if (prevId == nextId && currentPath.elementAtOrNull(0) == -1) {
        debugPrint('⚠️ prevId equals nextId, clearing both');
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
                'device': currentDocumentCopy.syncDeviceId,
                'timestamp': DateTime.now().toIso8601String(),
              }),
          delta: encodedDelta,
          parentId: node.type == 'page' ? null : parentId, //HANDLING EDGE CASE
          prevId: prevId == '' ? null : prevId, // Previous ID
          nextId: nextId == '' ? null : nextId, // Next ID
        ),
        path: Uint32List.fromList(currentPath.toList()),
      );

      debugPrint('✅ Created insert BlockActionDoc:');
      debugPrint(
        '  - Block ID: ${blockAction.block.id}, type: ${blockAction.block.ty}',
      );
      debugPrint('  - parentId: ${blockAction.block.parentId}');
      debugPrint(
        '  - prevId: ${blockAction.block.prevId}, nextId: ${blockAction.block.nextId}',
      );

      actions.add(blockAction);

      if (node.children.isNotEmpty) {
        debugPrint(
          '👶 Processing ${node.children.length} children of node ${node.id}',
        );
        Node? prevChild;
        for (int i = 0; i < node.children.length; i++) {
          final child = node.children[i];
          final isLast = i == node.children.length - 1;
          debugPrint(
            '🔍 Processing child ${i + 1}/${node.children.length}: ${child.id}',
          );

          final childActions = InsertOperation(child.path, [
            child,
          ]).toBlockAction(
            currentDocumentCopy,
            previousNode: prevChild,
            parentNode: node,
            nextNode: isLast ? null : node.children[i + 1],
          );

          debugPrint(
            '✅ Added ${childActions.length} actions for child ${child.id}',
          );
          actions.addAll(childActions);
          prevChild = child;
        }
      }

      // Update the previous node for the next iteration
      currentPreviousNode = node;
      currentPath = currentPath.next;
    }
    if (parentNode == null) {
      //Apply the operation to the current document
      debugPrint(
        '🔄 Applying insert operation to document at path $insertPath',
      );
      currentDocumentCopy.document.insert(path, nodes);
      debugPrint(
        '📄 Document after insert: ${currentDocumentCopy.prettyPrint()} root children',
      );
    }

    return actions;
  }
}

extension on UpdateOperation {
  List<BlockActionDoc> toBlockAction(
    ModifiableDocumentWithMetadata currentDocumentCopy,
  ) {
    debugPrint('🔄 Processing UpdateOperation at path: $path');
    debugPrint(
      '📄 Document state: ${currentDocumentCopy.prettyPrint()} root children',
    );

    final actions = <BlockActionDoc>[];

    // if the attributes are both empty, we don't need to update
    if (const DeepCollectionEquality().equals(attributes, oldAttributes)) {
      debugPrint('⚠️ Update skipped: attributes are identical');
      return actions;
    }

    final node = currentDocumentCopy.document.nodeAtPath(path);
    if (node == null) {
      debugPrint('❌ Node not found at path: $path');
      assert(false, 'node not found at path: $path');
      return actions;
    }

    debugPrint('🔍 Updating node: ${node.id}, type: ${node.type}');

    final parentId =
        TransactionAdapterHelpers.parentFromPath(
          currentDocumentCopy.document,
          node.path,
        ).id;
    debugPrint('👆 Parent ID: $parentId');
    assert(parentId.isNotEmpty);

    // create the external text if the node contains the delta in its data.
    final prevDelta = oldAttributes[blockComponentDelta];
    final delta = attributes[blockComponentDelta];

    String? diff;
    if (prevDelta != null && delta != null) {
      debugPrint('📝 Computing delta diff');
      diff = diffDeltas(
        jsonEncode(Delta.fromJson(prevDelta)),
        jsonEncode(Delta.fromJson(delta)),
      );
    }

    final composedAttributes = composeAttributes(oldAttributes, attributes);
    final composedDelta = composedAttributes?[blockComponentDelta];
    composedAttributes?.remove(blockComponentDelta);

    debugPrint(
      '🔍 Composed attributes: ${composedAttributes?.keys.join(", ")}',
    );

    final blockAction = BlockActionDoc(
      action: BlockActionTypeDoc.update,
      block: BlockDoc(
        id: node.id,
        ty: node.type,
        attributes: composedAttributes?.toMap() ?? {},
        delta: diff,
        parentId: parentId,
      ),
      path: Uint32List.fromList(path.toList()),
    );

    debugPrint('✅ Created update BlockActionDoc:');
    debugPrint(
      '  - Block ID: ${blockAction.block.id}, type: ${blockAction.block.ty}',
    );
    debugPrint('  - Has delta diff: ${diff != null}');

    actions.add(blockAction);

    // Apply the operation to the current document
    debugPrint('🔄 Applying update to current document');
    currentDocumentCopy.document.update(path, attributes);
    debugPrint(
      '📄 Document after update: ${currentDocumentCopy.prettyPrint()} root children',
    );

    return actions;
  }
}

extension on DeleteOperation {
  List<BlockActionDoc> toBlockAction(
    ModifiableDocumentWithMetadata currentDocument,
  ) {
    debugPrint('🗑️ Processing DeleteOperation at path: $path');
    debugPrint(
      '📄 Document state: ${currentDocument.prettyPrint()} root children',
    );
    debugPrint('🔍 Deleting ${nodes.length} node(s)');

    final actions = <BlockActionDoc>[];

    for (final node in nodes) {
      debugPrint(
        '🔍 Processing node for deletion: ${node.id}, type: ${node.type}',
      );

      final parentId =
          TransactionAdapterHelpers.parentFromPath(
            currentDocument.document,
            node.path,
          ).id;
      debugPrint('👆 Parent ID: $parentId');
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

      debugPrint('✅ Created delete BlockActionDoc:');
      debugPrint(
        '  - Block ID: ${blockAction.block.id}, type: ${blockAction.block.ty}',
      );
      debugPrint('  - parentId: ${blockAction.block.parentId}');

      actions.add(blockAction);
    }

    // Apply the operation to the current document
    debugPrint('🔄 Applying delete to current document');
    currentDocument.document.delete(path, nodes.length);
    debugPrint(
      '📄 Document after delete: ${currentDocument.prettyPrint()} root children',
    );

    return actions;
  }
}
