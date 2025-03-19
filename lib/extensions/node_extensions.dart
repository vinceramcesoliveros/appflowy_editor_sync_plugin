import 'dart:convert';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:appflowy_editor_sync_plugin/src/rust/doc/document_types.dart';

extension DocumentComparison on Document {
  /// Deep comparison of documents based on structure and content
  bool isContentEqual(Document other) {
    if (identical(this, other)) return true;

    // Compare JSON representations (most reliable but less efficient)
    return jsonEncode(toJson()) == jsonEncode(other.toJson());
  }
}

extension AttributesExtension on Attributes {
  Map<String, String> toMap() {
    return map((key, value) => MapEntry(key, value.toString()));
  }
}

Node jsonToNode(Map<String, dynamic> json) {
  final type = json['type'] as String;
  final data = json['data'] as Map<String, dynamic>;
  final childrenJson = json['children'] as List<dynamic>;

  final children =
      childrenJson
          .map((child) => jsonToNode(child as Map<String, dynamic>))
          .toList();

  return Node(type: type, attributes: data, children: children);
}

//Create extension on Map<String, String> to convert to Attributes and try to parse the string as int or float and make it number if possible
extension Attributes2Extension on Map<String, String> {
  Attributes toAttributes() {
    final result = <String, dynamic>{};
    for (final entry in entries) {
      final key = entry.key;
      final value = entry.value;

      if (value == 'true') {
        result[key] = true;
      } else if (value == 'false') {
        result[key] = false;
      } else {
        final number = num.tryParse(value);
        if (number != null) {
          result[key] = number;
        } else {
          result[key] = value;
        }
      }
    }

    return result;
  }
}

extension BlockExtension on BlockDoc {
  Node toNode({required List<Node> children}) {
    final deltaString =
        delta != null ? jsonDecode(delta ?? '[]') as List<dynamic> : '';
    final convertedAttributes = attributes.toAttributes();
    if (deltaString != '') {
      convertedAttributes['delta'] = deltaString;
    }
    return Node(
      id: id,
      children: children,
      type: ty,
      attributes: convertedAttributes,
    );
  }
}
