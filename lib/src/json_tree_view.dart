import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'json_highlighter.dart';
import 'json_tools.dart';

/// One visible line in the tree.
class JsonTreeRow {
  const JsonTreeRow({
    required this.path,
    required this.label,
    required this.isIndex,
    required this.value,
    required this.depth,
  });

  final String path;

  /// Object key or array index; null for a primitive root value.
  final String? label;
  final bool isIndex;
  final Object? value;
  final int depth;

  bool get isContainer => value is Map || value is List;
}

/// Keeps track of which nodes are expanded.
class JsonTreeController extends ChangeNotifier {
  final Set<String> _expanded = {};

  bool isExpanded(String path) => _expanded.contains(path);

  void toggle(String path) {
    if (!_expanded.remove(path)) _expanded.add(path);
    notifyListeners();
  }

  /// Expands containers above [depth]; the root is level 0 and its children
  /// level 1, so the default shows the first two visible levels.
  void reset(Object? root, {int depth = 2}) {
    _expanded.clear();
    _visitContainers(root, rootPath, 0, (path, level) {
      if (level < depth) _expanded.add(path);
    });
    notifyListeners();
  }

  void expandAll(Object? root) {
    _visitContainers(root, rootPath, 0, (path, _) => _expanded.add(path));
    notifyListeners();
  }

  void collapseAll() {
    _expanded.clear();
    notifyListeners();
  }

  static void _visitContainers(
    Object? value,
    String path,
    int level,
    void Function(String path, int level) visit,
  ) {
    if (value is Map) {
      visit(path, level);
      for (final e in value.entries) {
        _visitContainers(
          e.value,
          childPath(path, e.key as String),
          level + 1,
          visit,
        );
      }
    } else if (value is List) {
      visit(path, level);
      for (var i = 0; i < value.length; i++) {
        _visitContainers(value[i], childPath(path, i), level + 1, visit);
      }
    }
  }
}

/// Search result: matching paths and the containers that must be open to show them.
class JsonSearchResult {
  const JsonSearchResult(this.matches, this.ancestors);

  final Set<String> matches;
  final Set<String> ancestors;
}

JsonSearchResult searchJson(Object? root, String query) {
  final matches = <String>{};
  final ancestors = <String>{};
  final q = query.toLowerCase();
  if (q.isEmpty) return JsonSearchResult(matches, ancestors);

  final stack = <String>[];
  void visit(Object? value, String path, String? label) {
    var hit = label != null && label.toLowerCase().contains(q);
    if (!hit && value is! Map && value is! List) {
      hit = (value is String ? value : '$value').toLowerCase().contains(q);
    }
    if (hit) {
      matches.add(path);
      ancestors.addAll(stack);
    }
    if (value is Map) {
      stack.add(path);
      for (final e in value.entries) {
        final key = e.key as String;
        visit(e.value, childPath(path, key), key);
      }
      stack.removeLast();
    } else if (value is List) {
      stack.add(path);
      for (var i = 0; i < value.length; i++) {
        visit(value[i], childPath(path, i), null);
      }
      stack.removeLast();
    }
  }

  visit(root, rootPath, null);
  return JsonSearchResult(matches, ancestors);
}

/// Flattens the visible part of the tree. The root container itself is not
/// shown as a row; its children start at depth 0.
List<JsonTreeRow> flattenJson(Object? root, bool Function(String) isOpen) {
  final rows = <JsonTreeRow>[];

  void addChildren(Object? container, String path, int depth) {
    void add(Object? value, String path, String label, bool isIndex) {
      rows.add(
        JsonTreeRow(
          path: path,
          label: label,
          isIndex: isIndex,
          value: value,
          depth: depth,
        ),
      );
      if ((value is Map || value is List) && isOpen(path)) {
        addChildren(value, path, depth + 1);
      }
    }

    if (container is Map) {
      for (final e in container.entries) {
        final key = e.key as String;
        add(e.value, childPath(path, key), key, false);
      }
    } else if (container is List) {
      for (var i = 0; i < container.length; i++) {
        add(container[i], childPath(path, i), '$i', true);
      }
    }
  }

  if (root is Map || root is List) {
    addChildren(root, rootPath, 0);
  } else {
    rows.add(
      JsonTreeRow(
        path: rootPath,
        label: null,
        isIndex: false,
        value: root,
        depth: 0,
      ),
    );
  }
  return rows;
}

class JsonTreeView extends StatefulWidget {
  const JsonTreeView({
    super.key,
    required this.value,
    required this.controller,
    required this.fontSize,
    this.searchQuery = '',
    this.header,
    this.scrollController,
  });

  final Object? value;
  final JsonTreeController controller;
  final double fontSize;
  final String searchQuery;
  final Widget? header;
  final ScrollController? scrollController;

  @override
  State<JsonTreeView> createState() => _JsonTreeViewState();
}

class _JsonTreeViewState extends State<JsonTreeView> {
  JsonSearchResult? _search;
  Object? _searchRoot;
  String? _searchQuery;

  JsonSearchResult get _currentSearch {
    if (_search == null ||
        !identical(_searchRoot, widget.value) ||
        _searchQuery != widget.searchQuery) {
      _search = searchJson(widget.value, widget.searchQuery);
      _searchRoot = widget.value;
      _searchQuery = widget.searchQuery;
    }
    return _search!;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final search = _currentSearch;
        final searching = widget.searchQuery.isNotEmpty;
        final rows = flattenJson(
          widget.value,
          (path) =>
              widget.controller.isExpanded(path) ||
              (searching && search.ancestors.contains(path)),
        );
        final header = widget.header;
        final extra = header == null ? 0 : 1;
        return ListView.builder(
          controller: widget.scrollController,
          padding: const EdgeInsets.only(bottom: 32),
          itemCount: rows.length + extra,
          itemBuilder: (context, index) {
            if (index < extra) return header;
            final row = rows[index - extra];
            return _JsonRowTile(
              row: row,
              expanded:
                  widget.controller.isExpanded(row.path) ||
                  (searching && search.ancestors.contains(row.path)),
              highlighted: searching && search.matches.contains(row.path),
              fontSize: widget.fontSize,
              onToggle: () => widget.controller.toggle(row.path),
            );
          },
        );
      },
    );
  }
}

class _JsonRowTile extends StatelessWidget {
  const _JsonRowTile({
    required this.row,
    required this.expanded,
    required this.highlighted,
    required this.fontSize,
    required this.onToggle,
  });

  final JsonTreeRow row;
  final bool expanded;
  final bool highlighted;
  final double fontSize;
  final VoidCallback onToggle;

  static const _indent = 16.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = JsonColors.of(context);
    final mono = TextStyle(
      fontFamily: 'monospace',
      fontSize: fontSize,
      height: 1.4,
      color: theme.colorScheme.onSurface,
    );
    final value = row.value;

    final spans = <InlineSpan>[];
    final label = row.label;
    if (label != null) {
      spans
        ..add(
          TextSpan(
            text: row.isIndex ? label : '"$label"',
            style: TextStyle(
              color: row.isIndex ? colors.punctuation : colors.key,
            ),
          ),
        )
        ..add(
          TextSpan(
            text: ': ',
            style: TextStyle(color: colors.punctuation),
          ),
        );
    }
    spans.add(_valueSpan(value, colors, theme));

    return Material(
      color: highlighted
          ? theme.colorScheme.secondaryContainer.withValues(alpha: 0.6)
          : Colors.transparent,
      child: InkWell(
        onTap: row.isContainer ? onToggle : () => _showValue(context),
        onLongPress: () => _showActions(context),
        child: Padding(
          padding: EdgeInsets.only(
            left: 8 + row.depth * _indent,
            right: 12,
            top: 3,
            bottom: 3,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: fontSize + 8,
                height: fontSize * 1.4,
                child: row.isContainer
                    ? Icon(
                        expanded ? Icons.expand_more : Icons.chevron_right,
                        size: fontSize + 4,
                        color: theme.colorScheme.onSurfaceVariant,
                      )
                    : null,
              ),
              Expanded(
                child: Text.rich(
                  TextSpan(children: spans),
                  style: mono,
                  maxLines: 6,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InlineSpan _valueSpan(Object? value, JsonColors colors, ThemeData theme) {
    final muted = TextStyle(color: theme.colorScheme.onSurfaceVariant);
    return switch (value) {
      Map() => TextSpan(
        children: [
          TextSpan(
            text: expanded ? '{' : '{…}',
            style: TextStyle(color: colors.punctuation),
          ),
          TextSpan(text: '  ${describeContainer(value)}', style: muted),
        ],
      ),
      List() => TextSpan(
        children: [
          TextSpan(
            text: expanded ? '[' : '[…]',
            style: TextStyle(color: colors.punctuation),
          ),
          TextSpan(text: '  ${describeContainer(value)}', style: muted),
        ],
      ),
      String() => TextSpan(
        text: '"$value"',
        style: TextStyle(color: colors.string),
      ),
      bool() => TextSpan(
        text: '$value',
        style: TextStyle(color: colors.boolean),
      ),
      num() => TextSpan(
        text: '$value',
        style: TextStyle(color: colors.number),
      ),
      _ => TextSpan(
        text: 'null',
        style: TextStyle(color: colors.nullValue),
      ),
    };
  }

  void _copy(BuildContext context, String text, String what) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('$what copied')));
  }

  void _showValue(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          row.path,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
        ),
        content: SingleChildScrollView(
          child: SelectableText(
            copyText(row.value),
            style: TextStyle(fontFamily: 'monospace', fontSize: fontSize),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _copy(context, copyText(row.value), 'Value');
            },
            child: const Text('Copy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showActions(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(
                row.path,
                style: const TextStyle(fontFamily: 'monospace'),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                [
                  typeName(row.value),
                  describeContainer(row.value),
                ].where((s) => s.isNotEmpty).join(' · '),
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.content_copy),
              title: const Text('Copy value'),
              onTap: () {
                Navigator.pop(sheetContext);
                _copy(context, copyText(row.value), 'Value');
              },
            ),
            ListTile(
              leading: const Icon(Icons.route_outlined),
              title: const Text('Copy path'),
              onTap: () {
                Navigator.pop(sheetContext);
                _copy(context, row.path, 'Path');
              },
            ),
            if (row.label != null && !row.isIndex)
              ListTile(
                leading: const Icon(Icons.key_outlined),
                title: const Text('Copy key'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _copy(context, row.label!, 'Key');
                },
              ),
          ],
        ),
      ),
    );
  }
}
