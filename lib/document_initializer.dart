import 'dart:typed_data';

import 'package:appflowy_editor_sync_plugin/convertors/transaction_adapter_helpers.dart';
import 'package:appflowy_editor_sync_plugin/document_service_helpers/document_service_wrapper.dart';
import 'package:appflowy_editor_sync_plugin/editor_state_helpers/editor_state_wrapper.dart';

class DocumentInitializer {
  DocumentInitializer({required this.documentService});

  final DocumentServiceWrapper documentService;

  Future<(EditorStateWrapper, List<Uint8List>)> initEmptyDocument() async {
    final editorStateWrapper = EditorStateWrapper.factoryBlank();
    final initialOperations =
        editorStateWrapper.getAllContentAsInsertOperationsForBlankDocument();

    final initEmptyDocUpdates = await documentService.initEmptyDoc();
    final applyingInitialOperationsUpdates = await documentService.applyAction(
      actions: TransactionAdapterHelpers.operationsToBlockActions(
        initialOperations,
        editorStateWrapper,
      ),
    );

    return applyingInitialOperationsUpdates.match(
      () => (editorStateWrapper, [initEmptyDocUpdates]),
      (updates) {
        return (editorStateWrapper, [initEmptyDocUpdates, updates]);
      },
    );
  }

  Future<EditorStateWrapper> initDocumentWithUpdates(
    List<(String, Uint8List)> updates,
    String rootNodeId,
  ) async {
    await documentService.applyUpdates(update: updates);
    final result = await documentService.getDocumentJson();

    final editorStateWrapper = EditorStateWrapper.factoryFromDocumentState(
      result,
      rootNodeId,
    );

    return editorStateWrapper;
  }
}
