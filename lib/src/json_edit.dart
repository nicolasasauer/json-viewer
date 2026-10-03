import 'dart:convert';

/// A path into a JSON value: object keys (String) and list indexes (int).
typedef JsonPath = List<Object>;

/// The value types offered when adding or converting a value.
enum JsonKind { text, number, boolean, group, list, empty }

extension JsonKindLabel on JsonKind {
  String get label => switch (this) {
    JsonKind.text => 'Text',
    JsonKind.number => 'Number',
    JsonKind.boolean => 'Yes/No',
    JsonKind.group => 'Group',
    JsonKind.list => 'List',
    JsonKind.empty => 'Empty (null)',
  };

  Object? get initialValue => switch (this) {
    JsonKind.text => '',
    JsonKind.number => 0,
    JsonKind.boolean => false,
    JsonKind.group => <String, Object?>{},
    JsonKind.list => <Object?>[],
    JsonKind.empty => null,
  };
}

JsonKind kindOf(Object? value) => switch (value) {
  String() => JsonKind.text,
  num() => JsonKind.number,
  bool() => JsonKind.boolean,
  Map() => JsonKind.group,
  List() => JsonKind.list,
  _ => JsonKind.empty,
};

/// Mutable deep copy with `Map<String, Object?>` / `List<Object?>` containers.
Object? deepCopy(Object? value) => switch (value) {
  Map() => <String, Object?>{
    for (final e in value.entries) e.key as String: deepCopy(e.value),
  },
  List() => <Object?>[for (final v in value) deepCopy(v)],
  _ => value,
};

Object? getAt(Object? root, JsonPath path) {
  var current = root;
  for (final segment in path) {
    current = switch (current) {
      Map() => current[segment],
      List() => current[segment as int],
      _ => throw ArgumentError('Path $path does not exist'),
    };
  }
  return current;
}

/// All edits copy the document first and return the new root, so the
/// previous root stays untouched (used for undo and change detection).
Object? setAt(Object? root, JsonPath path, Object? value) {
  if (path.isEmpty) return value;
  final copy = deepCopy(root);
  final parent = getAt(copy, path.sublist(0, path.length - 1));
  final last = path.last;
  if (parent is Map) {
    parent[last as String] = value;
  } else if (parent is List) {
    parent[last as int] = value;
  }
  return copy;
}

Object? removeAt(Object? root, JsonPath path) {
  final copy = deepCopy(root);
  final parent = getAt(copy, path.sublist(0, path.length - 1));
  final last = path.last;
  if (parent is Map) {
    parent.remove(last);
  } else if (parent is List) {
    parent.removeAt(last as int);
  }
  return copy;
}

/// Adds [key] to the object at [objectPath] (after [after], or at the end).
Object? addField(
  Object? root,
  JsonPath objectPath,
  String key,
  Object? value, {
  String? after,
}) {
  final copy = deepCopy(root);
  final target = getAt(copy, objectPath) as Map<String, Object?>;
  if (after == null || !target.containsKey(after)) {
    target[key] = value;
    return copy;
  }
  final entries = target.entries.toList();
  target.clear();
  for (final e in entries) {
    target[e.key] = e.value;
    if (e.key == after) target[key] = value;
  }
  return copy;
}

/// Inserts [value] into the list at [listPath] (at [index], default: end).
Object? addItem(Object? root, JsonPath listPath, Object? value, {int? index}) {
  final copy = deepCopy(root);
  final target = getAt(copy, listPath) as List<Object?>;
  target.insert(index ?? target.length, value);
  return copy;
}

/// Renames a key in place, keeping its position.
Object? renameKey(Object? root, JsonPath fieldPath, String newKey) {
  final copy = deepCopy(root);
  final parent = getAt(
    copy,
    fieldPath.sublist(0, fieldPath.length - 1),
  ) as Map<String, Object?>;
  final oldKey = fieldPath.last as String;
  final entries = parent.entries.toList();
  parent.clear();
  for (final e in entries) {
    parent[e.key == oldKey ? newKey : e.key] = e.value;
  }
  return copy;
}

/// Moves a field or list item one step up (-1) or down (+1).
Object? move(Object? root, JsonPath path, int delta) {
  final copy = deepCopy(root);
  final parent = getAt(copy, path.sublist(0, path.length - 1));
  if (parent is List) {
    final i = path.last as int;
    final j = i + delta;
    if (j < 0 || j >= parent.length) return root;
    final item = parent.removeAt(i);
    parent.insert(j, item);
  } else if (parent is Map<String, Object?>) {
    final entries = parent.entries.toList();
    final i = entries.indexWhere((e) => e.key == path.last);
    final j = i + delta;
    if (i < 0 || j < 0 || j >= entries.length) return root;
    final e = entries.removeAt(i);
    entries.insert(j, e);
    parent
      ..clear()
      ..addEntries(entries);
  }
  return copy;
}

/// Copies the value at [path] and inserts the copy right after it.
Object? duplicate(Object? root, JsonPath path) {
  final value = deepCopy(getAt(root, path));
  final parentPath = path.sublist(0, path.length - 1);
  final last = path.last;
  if (last is int) return addItem(root, parentPath, value, index: last + 1);
  final parent = getAt(root, parentPath) as Map;
  return addField(
    root,
    parentPath,
    uniqueKey(parent, last as String),
    value,
    after: last,
  );
}

/// "name" → "name 2" (or 3, …) if "name" is taken.
String uniqueKey(Map map, String base) {
  if (!map.containsKey(base)) return base;
  var n = 2;
  while (map.containsKey('$base $n')) {
    n++;
  }
  return '$base $n';
}

/// An empty value with the same shape: objects keep their keys, lists become
/// empty, strings "", numbers 0, booleans false. Used for "add another item"
/// so a new list entry has the same fields as the previous one.
Object? blankLike(Object? value) => switch (value) {
  Map() => <String, Object?>{
    for (final e in value.entries) e.key as String: blankLike(e.value),
  },
  List() => <Object?>[],
  String() => '',
  num() => 0,
  bool() => false,
  _ => null,
};

/// Converts a value to another kind, keeping what can be kept.
Object? convert(Object? value, JsonKind kind) {
  if (kindOf(value) == kind) return value;
  return switch (kind) {
    JsonKind.text => switch (value) {
      null => '',
      Map() || List() => jsonEncode(value),
      _ => '$value',
    },
    JsonKind.number => switch (value) {
      String() => num.tryParse(value.trim()) ?? 0,
      bool() => value ? 1 : 0,
      _ => 0,
    },
    JsonKind.boolean => switch (value) {
      String() => value.trim().toLowerCase() == 'true',
      num() => value != 0,
      _ => false,
    },
    JsonKind.group => <String, Object?>{},
    JsonKind.list => value == null ? <Object?>[] : <Object?>[value],
    JsonKind.empty => null,
  };
}

/// Encodes [value] using the indentation style of [original]: minified stays
/// minified, tabs stay tabs, otherwise the detected number of spaces.
String encodeLike(Object? value, String original) {
  final trimmed = original.trim();
  if (trimmed.isNotEmpty && !trimmed.contains('\n')) return jsonEncode(value);
  final match = RegExp(r'\n([ \t]+)\S').firstMatch(original);
  final indent = match == null
      ? '  '
      : match.group(1)!.startsWith('\t')
      ? '\t'
      : match.group(1)!;
  return JsonEncoder.withIndent(indent).convert(value);
}
