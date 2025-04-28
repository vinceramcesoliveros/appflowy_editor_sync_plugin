///
library;
// factory Document.fromJson(Map<String, dynamic> json) {
//   assert(json['document'] is Map);

//   final document = Map<String, Object>.from(json['document'] as Map);
//   final root = Node.fromJson(document);
//   return Document(root: root);
// }

//   factory Node.fromJson(Map<String, Object> json) {
//   final node = Node(
//     type: json['type'] as String,
//     attributes: Attributes.from(json['data'] as Map? ?? {}),
//     children: (json['children'] as List? ?? [])
//         .map((e) => Map<String, Object>.from(e))
//         .map((e) => Node.fromJson(e)),
//   );

//   for (final child in node.children) {
//     child.parent = node;
//   }

//   return node;
// }

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:uuid/uuid.dart';

/// Extensions to enhance Document and Node with ID-preserving JSON conversion.
/// These extensions closely follow the original Document.fromJson and Node.fromJson
/// implementations but add support for preserving node IDs during conversion.

extension DocumentExtensions on Document {
  /// Creates a Document from JSON with preserved node IDs.
  /// Based on the original Document.fromJson implementation.
  static Document fromJsonWithIds(Map<String, dynamic> json) {
    assert(json['document'] is Map, 'document field must be a Map');

    final document = Map<String, dynamic>.from(json['document'] as Map);
    final root = NodeExtensionsCustom.fromJsonWithIds(document);
    return Document(root: root);
  }
}

extension NodeExtensionsCustom on Node {
  /// Creates a Node from JSON with ID preservation.
  /// Based on the original Node.fromJson implementation with ID support added.
  static Node fromJsonWithIds(Map<String, dynamic> json) {
    final node = Node(
      id:
          json['id'] as String? ??
          const Uuid().v4(), // Use existing ID or generate new one
      type: json['type'] as String,
      attributes: Attributes.from(json['data'] as Map? ?? {}),
      children: (json['children'] as List? ?? [])
          .map((e) => Map<String, Object>.from(e as Map<dynamic, dynamic>))
          .map(NodeExtensionsCustom.fromJsonWithIds),
    );

    for (final child in node.children) {
      child.parent = node;
    }

    return node;
  }

  /// Converts Node to JSON preserving the node ID.
  Map<String, Object> toJsonWithIds() {
    return {
      'id': id,
      'type': type,
      'data': attributes,
      'children': children.map((child) => child.toJsonWithIds()).toList(),
    };
  }
}

/// Utility extension to convert a Document to JSON with preserved node IDs
extension DocumentToJsonExtension on Document {
  /// Converts a Document to JSON, preserving all node IDs
  Map<String, Object> toJsonWithIds() {
    return {'document': root.toJsonWithIds()};
  }
}
