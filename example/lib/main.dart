// main.dart
import 'dart:typed_data';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:appflowy_editor_sync_plugin/editor_state_sync_wrapper.dart';
import 'package:appflowy_editor_sync_plugin/types/sync_db_attributes.dart';
import 'package:appflowy_editor_sync_plugin/types/update_types.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'main.g.dart';

// ====================
// Models
// ====================
@Collection()
class Document {
  late int id;
  String? name;
  DateTime? createdAt;
  String? rootId;
}

@Collection()
class DocumentData {
  late int id;
  List<int>? data;
  int? documentId;
}

// ====================
// Providers
// ====================
@Riverpod(keepAlive: true)
Isar isar(Ref ref) {
  throw UnimplementedError('Isar provider must be overridden');
}

@Riverpod(keepAlive: true)
class Documents extends _$Documents {
  Isar get _isar => ref.read(isarProvider);

  @override
  List<Document> build() => _isar.documents.where().findAll();

  Future<void> addDocument(String name) async {
    final doc =
        Document()
          ..name = name
          ..createdAt = DateTime.now();
    _isar.write((isar) async {
      isar.documents.put(doc);
    });
    ref.invalidateSelf();
  }

  Future<void> deleteDocument(int id) async {
    await _isar.write((isar) async {
      isar.documents.delete(id);
      isar.documentDatas.where().documentIdEqualTo(id).deleteAll();
    });
    ref.invalidateSelf();
  }
}

@riverpod
List<DocumentData> docData(Ref ref, {required int docId}) {
  return ref
      .read(isarProvider)
      .documentDatas
      .where()
      .documentIdEqualTo(docId)
      .findAll();
}

@riverpod
Document doc(Ref ref, {required int docId}) {
  return ref.read(isarProvider).documents.get(docId)!;
}

@Riverpod(keepAlive: true)
class EditorStateWrapper extends _$EditorStateWrapper {
  Isar get _isar => ref.read(isarProvider);

  @override
  FutureOr<EditorState> build(String docId) {
    final wrapper = EditorStateSyncWrapper(
      syncAttributes: SyncAttributes(
        getRootNodeId: () async {
          return _isar.documents
              .where()
              .idEqualTo(int.parse(docId))
              .findFirst()
              ?.rootId;
        },
        saveRootNodeId: (String rootId) async {
          await _isar.write((isar) async {
            final docData =
                isar.documents.where().idEqualTo(int.parse(docId)).findFirst();
            if (docData != null) {
              docData.rootId = rootId;
              isar.documents.put(docData);
            }
          });
        },
        getUpdates: () async {
          final data =
              _isar.documentDatas
                  .where()
                  .documentIdEqualTo(int.parse(docId))
                  .findAll();
          return data.map((e) {
            return (e.id.toString(), Uint8List.fromList(e.data!));
          }).toList();
        },
        getUpdatesStream: _isar.documentDatas
            .where()
            .documentIdEqualTo(int.parse(docId))
            .watch(fireImmediately: true)
            .asyncMap((data) {
              return data
                  .map(
                    (e) => DbUpdate(
                      update: Uint8List.fromList(e.data!),
                      id: e.id.toString(),
                    ),
                  )
                  .toList();
            }),
        saveUpdate: (Uint8List update) async {
          final docData =
              DocumentData()
                ..data = update
                ..documentId = int.parse(docId);
          await _isar.write((isar) async {
            isar.documentDatas.put(docData);
          });
        },
      ),
    )..initAndHandleChanges();

    return wrapper.initAndHandleChanges();
  }
}

// ====================
// Main App
// ====================
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final isar = Isar.open(
    directory: Isar.defaultName,
    engine: IsarEngine.isar,
    schemas: [DocumentSchema, DocumentDataSchema],
  );

  runApp(
    ProviderScope(
      overrides: [isarProvider.overrideWithValue(isar)],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Document Editor',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const DocumentListView(),
    );
  }
}

// ====================
// Views
// ====================
class DocumentListView extends ConsumerWidget {
  const DocumentListView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final documents = ref.watch(documentsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Documents')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateDialog(ref),
        child: const Icon(Icons.add),
      ),
      body: ListView.builder(
        itemCount: documents.length,
        itemBuilder:
            (context, index) => ListTile(
              title: Text(documents[index].name ?? ""),
              onTap:
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (context) => DocumentEditorScreen(
                            docId: documents[index].id.toString(),
                          ),
                    ),
                  ),
              trailing: IconButton(
                icon: const Icon(Icons.delete),
                onPressed:
                    () => ref
                        .read(documentsProvider.notifier)
                        .deleteDocument(documents[index].id),
              ),
            ),
      ),
    );
  }

  void _showCreateDialog(WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
      context: ref.context,
      builder:
          (context) => AlertDialog(
            title: const Text('New Document'),
            content: TextField(controller: controller),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  ref
                      .read(documentsProvider.notifier)
                      .addDocument(controller.text);
                  Navigator.pop(context);
                },
                child: const Text('Create'),
              ),
            ],
          ),
    );
  }
}

class DocumentEditorScreen extends ConsumerWidget {
  final String docId;

  const DocumentEditorScreen({super.key, required this.docId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Editing Document $docId'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Consumer(
        builder: (context, ref, child) {
          final editorState = ref.watch(editorStateWrapperProvider(docId));
          return editorState.when(
            data: (editorState) {
              return AppFlowyEditor(editorState: editorState);
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(child: Text('Error: $error')),
          );
        },
      ),
    );
  }
}
