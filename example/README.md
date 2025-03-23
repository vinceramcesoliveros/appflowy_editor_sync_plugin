# What it is?

It is a plugin for the Appflowy Editor that allows for synchronization of editor state across multiple devices. It uses the Yrs library, which is a CRDT (Conflict-free Replicated Data Type) library for Rust, to enable real-time collaboration and synchronization of content.

# Example

The example demonstrates how to use the appflowy_editor_sync_plugin plugin in a Flutter application. It stores updates and data in Isar database.

//TODO: Include Isar DB inside the app - Create two models for Document and DocumentData

// Keep the user interface very simple. It should be just a Drawer with document names and option to add another document. On click on specific document it will open that document and allow editing it
// On edit it will store updatesin the isar database to DocumentData (table?)

// It neeed to implement the interfpace that the library requires\
// It should use riverpod library for state management

// It should use the appflowy_editor_sync_plugin library for synchronization
// It should use appflowy_editor for editing

---

[ ] add nextId and use that to handle the outlined cases
[ ] Maybe copy parameters from nodes when adding a node before the root node to mantain the order
