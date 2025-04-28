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
  /// Converts Node to JSON preserving the node ID.
  ///
  /// @param includeParent Whether to include parent node in the output JSON.
  /// Default is false to avoid circular references.
  Map<String, Object> toJsonWithIds({bool includeParent = true}) {
    final json = {
      'id': id,
      'type': type,
      'data': attributes,
      'children':
          children
              .map((child) => child.toJsonWithIds(includeParent: includeParent))
              .toList(),
    };

    // Only include parent if explicitly requested
    if (includeParent && parent != null) {
      // Create parent JSON without its children to avoid circular references
      final parentJson = parent!.toJsonWithIds(includeParent: false);
      // Remove children from parent to prevent circular references
      (parentJson).remove('children');
      json['parent'] = parentJson;
    }

    return json;
  }

  /// Creates a Node from JSON with ID preservation.
  /// Based on the original Node.fromJson implementation with ID support added.
  /// Creates a Node from JSON with ID preservation.
  static Node fromJsonWithIds(Map<String, dynamic> json) {
    // Parse children JSON first
    final childrenJson = json['children'] as List? ?? [];
    final children =
        childrenJson.map((childJson) {
          return fromJsonWithIds(
            Map<String, Object>.from(childJson as Map<dynamic, dynamic>),
          );
        }).toList();

    // Create the node with the children already included
    final node = Node(
      id: json['id'] as String? ?? const Uuid().v4(),
      type: json['type'] as String,

      attributes: Attributes.from(json['data'] as Map? ?? {}),
      children: children, // Pass the already created children list
    );

    // Now set parent references
    for (final child in node.children) {
      child.parent = node;
    }

    return node;
  }
}

/// Utility extension to convert a Document to JSON with preserved node IDs
extension DocumentToJsonExtension on Document {
  /// Converts a Document to JSON, preserving all node IDs
  Map<String, Object> toJsonWithIds() {
    return {'document': root.toJsonWithIds()};
  }
}
