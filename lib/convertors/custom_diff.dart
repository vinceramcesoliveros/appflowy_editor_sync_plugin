import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:collection/collection.dart';

const _equality = DeepCollectionEquality();
const _listEquality = ListEquality<int>();

List<Operation> diffDocumentsCustom2(
  Document oldDocument,
  Document newDocument,
) {
  return diffNodesCustom2(oldDocument.root, newDocument.root);
}

List<Operation> diffNodesCustom2(Node oldNode, Node newNode) {
  // Gather all operations first without worrying about path shifts
  final rawOperations = _gatherRawOperations(oldNode, newNode);

  // Sort operations to ensure correct order of application
  // Updates first, then deletes from last to first, then inserts from first to last
  return _adjustOperationPaths(rawOperations);
}

List<Operation> _gatherRawOperations(Node oldNode, Node newNode) {
  final operations = <Operation>[];

  if (!_equality.equals(oldNode.attributes, newNode.attributes)) {
    operations.add(
      UpdateOperation(oldNode.path, newNode.attributes, oldNode.attributes),
    );
  }

  final oldChildrenById = {
    for (final child in oldNode.children) child.id: child,
  };
  final newChildrenById = {
    for (final child in newNode.children) child.id: child,
  };

  // Identify insertions and updates
  for (final newChild in newNode.children) {
    final oldChild = oldChildrenById[newChild.id];
    if (oldChild == null) {
      // Insert operation
      operations.add(InsertOperation(newChild.path, [newChild]));
    }
    //Check for move operations
    else if (!_listEquality.equals(oldChild.path, newChild.path)) {
      // Mark as move operation instead of delete+insert
      // We'll use a special tag to identify moves during path adjustment
      operations.add(DeleteOperation(oldChild.path, [oldChild]));
      operations.add(InsertOperation(newChild.path, [newChild]));
    } else {
      // Recursive diff for updates
      operations.addAll(_gatherRawOperations(oldChild, newChild));
    }
  }

  // Identify deletions
  oldChildrenById.keys.where((id) => !newChildrenById.containsKey(id)).forEach((
    id,
  ) {
    final oldChild = oldChildrenById[id]!;
    operations.add(DeleteOperation(oldChild.path, [oldChild]));
  });

  return operations;
}

List<Operation> _adjustOperationPaths(List<Operation> rawOperations) {
  // Group operations by type for easier handling
  final updates = <UpdateOperation>[];
  final deletes = <DeleteOperation>[];
  final inserts = <InsertOperation>[];

  // First pass: categorize operations
  for (final op in rawOperations) {
    if (op is UpdateOperation) {
      updates.add(op);
    } else if (op is DeleteOperation) {
      deletes.add(op);
    } else if (op is InsertOperation) {
      inserts.add(op);
    }
  }

  // Sort delete operations from bottom to top to avoid path shifts affecting earlier deletes
  deletes.sort((a, b) => b.path.compareTo(a.path));

  // Sort insert operations from top to bottom
  inserts.sort((a, b) => a.path.compareTo(b.path));

  // Combine consecutive deletes and inserts if possible
  final combinedDeletes = _combineConsecutiveOperations<DeleteOperation>(
    deletes,
  );
  final combinedInserts = _combineConsecutiveOperations<InsertOperation>(
    inserts,
  );

  // Reconstruct the operation list in the correct order for application:
  // 1. Updates (don't change structure)
  // 2. Deletes (from bottom to top)
  // 3. Inserts (from top to bottom)
  return [...updates, ...combinedDeletes, ...combinedInserts];
}

List<T> _combineConsecutiveOperations<T extends Operation>(List<T> operations) {
  if (operations.isEmpty) return [];

  final result = <T>[];
  T? current;

  for (final op in operations) {
    if (current == null) {
      current = op;
      continue;
    }

    // Try to combine consecutive operations
    if (op is InsertOperation &&
        current is InsertOperation &&
        op.path.equals(current.path.next)) {
      // Combine inserts
      final combinedNodes = [
        ...(current as InsertOperation).nodes,
        ...(op as InsertOperation).nodes,
      ];
      current = InsertOperation(current.path, combinedNodes) as T;
    } else if (op is DeleteOperation &&
        current is DeleteOperation &&
        op.path.equals(current.path.next)) {
      // Combine deletes
      final combinedNodes = [
        ...(current as DeleteOperation).nodes,
        ...(op as DeleteOperation).nodes,
      ];
      current = DeleteOperation(current.path, combinedNodes) as T;
    } else {
      // Can't combine, add current to result and set current to op
      result.add(current);
      current = op;
    }
  }

  // Don't forget the last operation
  if (current != null) {
    result.add(current);
  }

  return result;
}

extension on Path {
  // Compare paths - returns true if this path is greater than the other path
  // Used for sorting paths in hierarchical order
  int compareTo(Path other) {
    // Compare path lengths first - shorter paths come first
    if (length != other.length) {
      // If paths are of different lengths, check the common ancestor parts
      final minLength = length < other.length ? length : other.length;

      for (var i = 0; i < minLength; i++) {
        if (this[i] != other[i]) {
          return this[i].compareTo(other[i]);
        }
      }

      // If all common parts are equal, longer path comes later
      return length > other.length ? 1 : -1;
    }

    // If paths are of equal length, compare each component
    for (var i = 0; i < length; i++) {
      if (this[i] != other[i]) {
        return this[i].compareTo(other[i]);
      }
    }

    // Paths are identical
    return 0;
  }
}
