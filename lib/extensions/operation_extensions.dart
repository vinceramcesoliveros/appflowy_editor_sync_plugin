import 'dart:convert';
import 'dart:typed_data';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:appflowy_editor_sync_plugin/convertors/transaction_adapter_helpers.dart';
import 'package:appflowy_editor_sync_plugin/document_service_helpers/diff_deltas.dart';
import 'package:appflowy_editor_sync_plugin/document_service_helpers/document_with_metadata.dart';
import 'package:appflowy_editor_sync_plugin/extensions/node_extensions.dart';
import 'package:appflowy_editor_sync_plugin/src/rust/doc/document_types.dart';
import 'package:appflowy_editor_sync_plugin/utils/debug_print_custom.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

extension BlockActionAdapter on Operation {
  List<BlockActionDoc> toBlockAction(
    ModifiableDocumentWithMetadata currentDocumentCopy,
  ) {
    debugPrintCustom('🔄 Converting $runtimeType to block action');
    final op = this;
    if (op is InsertOperation) {
      return op.toBlockAction(currentDocumentCopy);
    } else if (op is UpdateOperation) {
      return op.toBlockAction(currentDocumentCopy);
    } else if (op is DeleteOperation) {
      return op.toBlockAction(currentDocumentCopy);
    }
    debugPrintCustom('❌ Unsupported operation type: ${op.runtimeType}');
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
    debugPrintCustom('📥 Processing InsertOperation');
    debugPrintCustom(
      '🔄 InsertOperation: ${JsonEncoder.withIndent(' ').convert(toJson())}',
    );
    debugPrintCustom('🔍 Insert path: $path');
    if (previousNode != null)
      debugPrintCustom('👈 Previous node: ${previousNode.id}');
    if (nextNode != null) debugPrintCustom('👉 Next node: ${nextNode.id}');
    if (parentNode != null)
      debugPrintCustom('👆 Parent node: ${parentNode.id}');

    debugPrintCustom(
      '📄 Document state: ${currentDocumentCopy.prettyPrint()} root children',
    );

    var insertPath = path;
    var currentPath = path;
    final actions = <BlockActionDoc>[];
    // Track previous node between iterations
    Node? currentPreviousNode = previousNode;

    // For multiple nodes, we need to handle the connections between them
    final nodesList = nodes.toList();
    debugPrintCustom('🔍 Inserting ${nodesList.length} node(s)');

    for (int i = 0; i < nodesList.length; i++) {
      final node = nodesList[i];
      final isLastNodeInBatch = i == nodesList.length - 1;
      debugPrintCustom(
        '🔍 Processing node ${i + 1}/${nodesList.length}: ID ${node.id}, type ${node.type}',
      );

      final parent =
          parentNode ??
          TransactionAdapterHelpers.parentFromPath(
            currentDocumentCopy.document,
            currentPath,
          );
      final parentId = parent.id;
      debugPrintCustom('👆 Parent ID: $parentId');
      assert(parentId.isNotEmpty);

      var prevId = '';
      // if the node is the first child of the parent, then its prevId should be empty.
      final isFirstChild = currentPath.previous.equals(currentPath);
      debugPrintCustom('🔍 Is first child: $isFirstChild');

      if (!isFirstChild) {
        prevId =
            currentPreviousNode?.id ??
            currentDocumentCopy.document.nodeAtPath(insertPath.previous)?.id ??
            '';
        debugPrintCustom('👈 Previous node ID: $prevId');
      } else {
        debugPrintCustom('👈 No previous node (first child)');
      }

      //THE NEXT ID IS ONLY USED WHN PREVID = NULL
      var nextId = '';

      // If this isn't the last node in our batch, the next ID should be the next node in our batch
      if (!isLastNodeInBatch) {
        nextId = nodesList[i + 1].id;
        debugPrintCustom('👉 Next node is another node in batch: $nextId');
      } else {
        if (insertPath.isNotEmpty) {
          nextId =
              nextNode?.id ??
              currentDocumentCopy.document.nodeAtPath(insertPath)?.id ??
              "";
          debugPrintCustom('👉 Next node ID: $nextId');
        }
      }

      //If I have a parent from insert, don't share nextid
      if (parentNode != null && isLastNodeInBatch) {
        debugPrintCustom(
          '👉 Clearing nextId because this is a child node insert',
        );
        nextId = '';
      }

      // create the external text if the node contains the delta in its data.
      final delta = node.delta;
      String? encodedDelta;
      if (delta != null) {
        encodedDelta = jsonEncode(node.delta!.toJson());
        debugPrintCustom('📝 Node contains delta text');
      }

      if (prevId == nextId && currentPath.elementAtOrNull(0) == -1) {
        debugPrintCustom('⚠️ prevId equals nextId, clearing both');
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

      debugPrintCustom('✅ Created insert BlockActionDoc:');
      debugPrintCustom(
        '  - Block ID: ${blockAction.block.id}, type: ${blockAction.block.ty}',
      );
      debugPrintCustom('  - parentId: ${blockAction.block.parentId}');
      debugPrintCustom(
        '  - prevId: ${blockAction.block.prevId}, nextId: ${blockAction.block.nextId}',
      );

      actions.add(blockAction);

      if (node.children.isNotEmpty) {
        debugPrintCustom(
          '👶 Processing ${node.children.length} children of node ${node.id}',
        );
        Node? prevChild;
        for (int i = 0; i < node.children.length; i++) {
          final child = node.children[i];
          final isLast = i == node.children.length - 1;
          debugPrintCustom(
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

          debugPrintCustom(
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
      debugPrintCustom(
        '🔄 Applying insert operation to document at path $insertPath',
      );
      currentDocumentCopy.document.insert(path, nodes);
      debugPrintCustom(
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
    debugPrintCustom('🔄 Processing UpdateOperation at path: $path');
    debugPrintCustom(
      '📄 Document state: ${currentDocumentCopy.prettyPrint()} root children',
    );

    final actions = <BlockActionDoc>[];

    // if the attributes are both empty, we don't need to update
    if (const DeepCollectionEquality().equals(attributes, oldAttributes)) {
      debugPrintCustom('⚠️ Update skipped: attributes are identical');
      return actions;
    }

    final node = currentDocumentCopy.document.nodeAtPath(path);
    if (node == null) {
      debugPrintCustom('❌ Node not found at path: $path');
      assert(false, 'node not found at path: $path');
      return actions;
    }

    debugPrintCustom('🔍 Updating node: ${node.id}, type: ${node.type}');

    final parentId =
        TransactionAdapterHelpers.parentFromPath(
          currentDocumentCopy.document,
          node.path,
        ).id;
    debugPrintCustom('👆 Parent ID: $parentId');
    assert(parentId.isNotEmpty);

    // create the external text if the node contains the delta in its data.
    final prevDelta = oldAttributes[blockComponentDelta];
    final delta = attributes[blockComponentDelta];

    String? diff;
    if (prevDelta != null && delta != null) {
      debugPrintCustom('📝 Computing delta diff');
      diff = diffDeltas(
        jsonEncode(Delta.fromJson(prevDelta)),
        jsonEncode(Delta.fromJson(delta)),
      );
    }

    final composedAttributes = composeAttributes(oldAttributes, attributes);
    final composedDelta = composedAttributes?[blockComponentDelta];
    composedAttributes?.remove(blockComponentDelta);

    debugPrintCustom(
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

    debugPrintCustom('✅ Created update BlockActionDoc:');
    debugPrintCustom(
      '  - Block ID: ${blockAction.block.id}, type: ${blockAction.block.ty}',
    );
    debugPrintCustom('  - Has delta diff: ${diff != null}');

    actions.add(blockAction);

    // Apply the operation to the current document
    debugPrintCustom('🔄 Applying update to current document');
    currentDocumentCopy.document.update(path, attributes);
    debugPrintCustom(
      '📄 Document after update: ${currentDocumentCopy.prettyPrint()} root children',
    );

    return actions;
  }
}

extension on DeleteOperation {
  List<BlockActionDoc> toBlockAction(
    ModifiableDocumentWithMetadata currentDocument,
  ) {
    debugPrintCustom('🗑️ Processing DeleteOperation at path: $path');
    // debugPrintCustom(
    //   '📄 Document state: ${currentDocument.prettyPrint()} root children',
    // );
    debugPrintCustom('🔍 Deleting ${nodes.length} node(s)');

    final actions = <BlockActionDoc>[];

    for (final node in nodes) {
      debugPrintCustom(
        '🔍 Processing node for deletion: ${node.id}, type: ${node.type}',
      );

      final parentId =
          TransactionAdapterHelpers.parentFromPath(
            currentDocument.document,
            node.path,
          ).id;
      debugPrintCustom('👆 Parent ID: $parentId');
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

      debugPrintCustom('✅ Created delete BlockActionDoc:');
      debugPrintCustom(
        '  - Block ID: ${blockAction.block.id}, type: ${blockAction.block.ty}',
      );
      debugPrintCustom('  - parentId: ${blockAction.block.parentId}');

      actions.add(blockAction);
    }

    // Apply the operation to the current document
    debugPrintCustom('🔄 Applying delete to current document');
    currentDocument.document.delete(path, nodes.length);
    // debugPrintCustom(
    //   '📄 Document after delete: ${currentDocument.prettyPrint()} root children',
    // );

    return actions;
  }
}
