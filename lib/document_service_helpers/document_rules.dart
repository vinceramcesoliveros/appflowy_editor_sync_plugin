import 'package:appflowy_editor/appflowy_editor.dart';

/// Apply rules to the document
///
/// 1. ensure there is at least one paragraph in the document, otherwise the user will be blocked from typing
/// 2. ensure that nodes with attribute of type: heading* dont have children. The children should be moved after the heading node in the document structure.
class DocumentRules {
  DocumentRules({required this.editorState});

  final EditorState editorState;

  Future<void> applyRules({required EditorTransactionValue value}) async {
    await Future.wait([
      _ensureAtLeastOneParagraphExists(value: value),
      _ensureNoChildrenForHeadingNodes(value: value),
    ]);
  }

  Future<void> _ensureAtLeastOneParagraphExists({
    required EditorTransactionValue value,
  }) async {
    final document = editorState.document;
    if (document.root.children.isEmpty) {
      final transaction = editorState.transaction;
      transaction
        ..insertNode([0], paragraphNode())
        ..afterSelection = Selection.collapsed(Position(path: [0]));
      await editorState.apply(transaction);
    }
  }

  /// Ensure that nodes with attribute of type: heading* dont have children.
  /// The children should be moved after the heading node in the document structure.
  Future<void> _ensureNoChildrenForHeadingNodes({
    required EditorTransactionValue value,
  }) async {
    final document = editorState.document;
    final transaction = editorState.transaction;

    // Find all heading nodes with children
    final headingNodes = <Node>[];
    void findHeadingNodesWithChildren(Node node) {
      if (node.type.startsWith('heading') && node.children.isNotEmpty) {
        headingNodes.add(node);
      } else {
        for (final child in node.children) {
          findHeadingNodesWithChildren(child);
        }
      }
    }

    findHeadingNodesWithChildren(document.root);

    // Process each heading node - move its children after it
    for (final headingNode in headingNodes) {
      final headingPath = headingNode.path;
      final parentPath = headingPath.parent;
      final insertPosition = headingPath.last + 1;

      // Keep track of how many nodes we've inserted so far
      int offset = 0;

      // Move each child after the heading node
      final children = List<Node>.from(
        headingNode.children,
      ); // Create a copy to iterate
      for (final child in children) {
        // Insert the child after the heading + offset
        final targetPath = [...parentPath, insertPosition + offset];
        transaction.moveNode(targetPath, child);
        offset++;
      }
    }

    if (transaction.operations.isEmpty) {
      return;
    }

    await editorState.apply(transaction);
  }
}
