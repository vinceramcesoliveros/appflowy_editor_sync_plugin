import 'package:appflowy_editor_sync_plugin/src/rust/frb_generated.dart';

/// It must be called on initialization of the app. It will call RustLib.init
// So that the Rust library is initialized and ready to use.

Future<void> initAppFlowyEditorSync() async {
  await RustLib.init();
}
