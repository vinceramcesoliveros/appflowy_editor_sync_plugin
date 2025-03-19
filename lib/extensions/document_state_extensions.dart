import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:appflowy_editor_sync_plugin/extensions/node_extensions.dart';
import 'package:appflowy_editor_sync_plugin/src/rust/doc/document_types.dart';
import 'package:dartx/dartx.dart';

extension DocumentStateExtension on DocumentState {
  Document? toDocument(String rootId) {
    try {
      final root = buildNode(rootId);

      if (root != null) {
        return Document(root: root);
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  Node? buildNode(String id) {
    final block = blocks[id];
    final childrenIds = childrenMap[id];

    final children = <Node>[];
    if (childrenIds != null && childrenIds.isNotEmpty) {
      children.addAll(childrenIds.map(buildNode).whereNotNull());
    }

    final node = block?.toNode(children: children);

    for (final element in children) {
      element.parent = node;
    }

    return node;
  }
}
