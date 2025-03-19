import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:appflowy_editor_sync_plugin/convertors/custom_diff.dart';
import 'package:appflowy_editor_sync_plugin/extensions/document_state_extensions.dart';
import 'package:appflowy_editor_sync_plugin/src/rust/doc/document_types.dart';
import 'package:uuid/uuid.dart';

class EditorStateWrapper {
  EditorStateWrapper({required this.editorState});

  //Add a factory method withDocument
  factory EditorStateWrapper.factoryWithDocument(Document document) {
    // Logic to create editor state with document
    return EditorStateWrapper(editorState: EditorState(document: document));
  }

  //Add a factory method withDocument
  factory EditorStateWrapper.factoryFromDocumentState(
    DocumentState documentState,
    String rootNode,
  ) {
    final document = documentState.toDocument(rootNode);
    if (document == null) {
      throw Exception('Document is null');
    }
    // Logic to create editor state with document
    return EditorStateWrapper(editorState: EditorState(document: document));
  }

  //Add a factory method blank
  factory EditorStateWrapper.factoryBlank() {
    // Logic to create editor state blank
    return EditorStateWrapper(editorState: EditorState.blank());
  }

  late String syncDeviceId = Uuid().v4();

  List<Operation> diffEditorStateWrappers(EditorStateWrapper other) {
    return diffWithDocument(other.editorState.document);
  }

  String get rootNodeId {
    return editorState.document.root.id;
  }

  EditorState editorState;

  Node? getNodeAtPath(Path path) {
    return editorState.getNodeAtPath(path);
  }

  void applyRemoteChanges(List<Operation> operations) {
    final transaction = editorState.transaction;
    transaction.operations.clear();
    transaction.operations.addAll(operations);

    editorState.apply(transaction, isRemote: true);
  }

  Stream<EditorTransactionValue> listenEditorChanges() {
    return editorState.transactionStream;
  }

  List<Operation> diffWithDocument(Document newDocument) {
    return diffDocumentsCustom2(editorState.document, newDocument);
  }

  List<Operation> getAllContentAsInsertOperationsForBlankDocument() {
    final rootNode = editorState.document.root;
    rootNode.parent = null;

    return [
      InsertOperation([], [rootNode]),
    ];
  }
}
