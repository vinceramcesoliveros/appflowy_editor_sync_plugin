// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:convert';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:appflowy_editor_sync_plugin/editor_state_helpers/editor_state_wrapper.dart';
import 'package:appflowy_editor_sync_plugin/extensions/document_extensions.dart';

class ModifiableDocumentWithMetadata {
  Document document;
  String syncDeviceId;
  ModifiableDocumentWithMetadata._({
    required this.document,
    required this.syncDeviceId,
  });

  /// Factory from EditorStateWrapper
  factory ModifiableDocumentWithMetadata.fromEditorStateWrapper(
    EditorStateWrapper editorStateWrapper,
  ) {
    return ModifiableDocumentWithMetadata._(
      document: DocumentExtensions.fromJsonWithIds(
        editorStateWrapper.editorState.document.toJsonWithIds(),
      ),
      syncDeviceId: editorStateWrapper.syncDeviceId,
    );
  }

  //Pretty print it as json
  String prettyPrint() {
    return JsonEncoder.withIndent(' ').convert(document.toJsonWithIds());
  }
}
