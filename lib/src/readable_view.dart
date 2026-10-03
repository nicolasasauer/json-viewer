import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'json_highlighter.dart';
import 'json_tools.dart';
import 'node_actions.dart';

/// Renders JSON as a document instead of code: objects become sections with
/// headings, uniform lists of objects become tables, values lose their quotes
/// and get friendly formatting (check marks, color swatches, dates).
class ReadableJsonView extends StatelessWidget {
  const ReadableJsonView({
    super.key,
    required this.value,
    required this.fontSize,
    this.humanizeKeys = true,
    this.onNodeTap,
    this.scrollController,
    this.header,
  });

  final Object? value;
  final double fontSize;
  final bool humanizeKeys;

  /// Tap on a value; null means tapping does nothing special.
  final void Function(String path)? onNodeTap;
  final ScrollController? scrollController;
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    final r = _Renderer(context, fontSize, humanizeKeys, onNodeTap);
    final root = value;
    final items = <Widget Function()>[
      if (header != null) () => header!,
      if (root is Map && root.isNotEmpty)
        for (final e in root.entries)
          () => r.property(e.key as String, e.value, rootPath, 0)
      else if (root is List && root.isNotEmpty)
        () => r.list(root, rootPath, 0)
      else
        () => Padding(
          padding: const EdgeInsets.only(top: 8),
          child: r.value(root, rootPath),
        ),
    ];
    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 48),
      itemCount: items.length,
      itemBuilder: (context, i) => items[i](),
    );
  }
}

const _titleKeys = [
  'title',
  'name',
  'label',
  'displayName',
  'heading',
  'id',
  'key',
];
const _maxInitialItems = 100;

final _hexColor = RegExp(
  r'^#(?:[0-9a-fA-F]{3}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$',
);
final _isoDate = RegExp(r'^\d{4}-\d{2}-\d{2}$');
final _isoDateTime = RegExp(r'^\d{4}-\d{2}-\d{2}[T ]\d{2}:\d{2}');
final _url = RegExp(r'^https?://\S+$');
const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// "studyProgram" → "Study program", "target_ECTS" → "Target ECTS".
String humanizeKey(String key) {
  final spaced = key
      .replaceAllMapped(RegExp(r'([a-z0-9])([A-Z])'), (m) => '${m[1]} ${m[2]}')
      .replaceAllMapped(
        RegExp(r'([A-Z]+)([A-Z][a-z])'),
        (m) => '${m[1]} ${m[2]}',
      )
      .replaceAll(RegExp(r'[_\-.]+'), ' ')
      .trim();
  if (spaced.isEmpty) return key;
  final words = spaced.split(RegExp(r'\s+'));
  return [
    for (var i = 0; i < words.length; i++)
      _isAcronym(words[i])
          ? words[i]
          : i == 0
          ? words[i][0].toUpperCase() + words[i].substring(1)
          : words[i].toLowerCase(),
  ].join(' ');
}

bool _isAcronym(String w) =>
    w.length > 1 && w == w.toUpperCase() && w != w.toLowerCase();

/// Formats ISO dates ("2025-02-12" → "12 Feb 2025"); null if not a date.
String? formatIsoDate(String s) {
  if (!_isoDate.hasMatch(s) && !_isoDateTime.hasMatch(s)) return null;
  final d = DateTime.tryParse(s);
  if (d == null) return null;
  final date = '${d.day} ${_months[d.month - 1]} ${d.year}';
  if (_isoDate.hasMatch(s)) return date;
  final time =
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  return '$date, $time${d.isUtc ? ' UTC' : ''}';
}

class _Renderer {
  _Renderer(this.context, this.fontSize, this.humanize, this.onNodeTap)
    : theme = Theme.of(context),
      colors = JsonColors.of(context);

  final BuildContext context;
  final double fontSize;
  final bool humanize;
  final void Function(String path)? onNodeTap;
  final ThemeData theme;
  final JsonColors colors;

  Color get muted => theme.colorScheme.onSurfaceVariant;

  TextStyle get valueStyle => TextStyle(
    fontSize: fontSize + 1,
    height: 1.4,
    color: theme.colorScheme.onSurface,
  );

  TextStyle get labelStyle =>
      TextStyle(fontSize: fontSize, height: 1.4, color: muted);

  String label(String key) => humanize ? humanizeKey(key) : key;

  /// Makes [child] tappable (jump to source) and long-pressable (copy actions).
  Widget interactive(
    Widget child, {
    required String path,
    required Object? value,
    String? key,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: onNodeTap == null ? null : () => onNodeTap!(path),
      onLongPress: () =>
          showJsonNodeActions(context, path: path, value: value, key: key),
      child: child,
    );
  }

  // ---- Structure -----------------------------------------------------------

  Widget property(String key, Object? value, String parentPath, int depth) {
    final path = childPath(parentPath, key);
    if (value is Map || value is List) {
      return _Section(
        depth: depth,
        title: label(key),
        subtitle: describeContainer(value),
        fontSize: fontSize,
        onHeaderLongPress: () =>
            showJsonNodeActions(context, path: path, value: value, key: key),
        onHeaderTap: onNodeTap == null ? null : () => onNodeTap!(path),
        child: value is Map
            ? object(value, path, depth + 1)
            : list(value as List, path, depth + 1),
      );
    }
    return interactive(
      _FieldRow(
        label: Text(label(key), style: labelStyle),
        value: this.value(value, path),
      ),
      path: path,
      value: value,
      key: key,
    );
  }

  Widget object(Map value, String path, int depth, {String? skipKey}) {
    if (value.isEmpty) return emptyNote('Empty');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final e in value.entries)
          if (e.key != skipKey) property(e.key as String, e.value, path, depth),
      ],
    );
  }

  Widget list(List value, String path, int depth) {
    if (value.isEmpty) return emptyNote('Empty list');

    if (value.every((v) => v is! Map && v is! List)) {
      final short =
          value.length <= 50 &&
          value.every(
            (v) => v is! String || (v.length <= 40 && !v.contains('\n')),
          );
      return short ? chips(value, path) : bullets(value, path);
    }

    if (value.every((v) => v is Map)) {
      final columns = <String>{
        for (final m in value.cast<Map>()) ...m.keys.cast<String>(),
      };
      final flat = value.cast<Map>().every(
        (m) => m.values.every((v) => v is! Map && v is! List),
      );
      if (flat && columns.length <= 8) {
        return _Capped(
          count: value.length,
          builder: (shown) =>
              table(value.cast<Map>(), columns.toList(), path, shown),
        );
      }
    }

    return _Capped(
      count: value.length,
      itemBuilder: (i) => card(value[i], childPath(path, i), i, depth),
    );
  }

  Widget card(Object? item, String path, int index, int depth) {
    String? title;
    String? titleKey;
    if (item is Map) {
      for (final k in _titleKeys) {
        final v = item[k];
        if (v is String && v.isNotEmpty || v is num) {
          title = '$v';
          titleKey = k;
          break;
        }
      }
    }
    final Widget body = item is Map
        ? object(item, path, depth + 1, skipKey: titleKey)
        : item is List
        ? list(item, path, depth + 1)
        : value(item, path);
    return Card.outlined(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            interactive(
              Row(
                children: [
                  Text(
                    '${index + 1}',
                    style: labelStyle.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(width: 10),
                  if (title != null)
                    Expanded(
                      child: Text(
                        title,
                        style: valueStyle.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                ],
              ),
              path: path,
              value: item,
            ),
            if (item is Map || item is List) const SizedBox(height: 4),
            body,
          ],
        ),
      ),
    );
  }

  Widget table(List<Map> rows, List<String> columns, String path, int shown) {
    final border = BorderSide(color: theme.colorScheme.outlineVariant);
    Widget cell(Widget child, String cellPath, Object? v, String? key) =>
        interactive(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: child,
          ),
          path: cellPath,
          value: v,
          key: key,
        );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Container(
        decoration: BoxDecoration(
          border: Border.fromBorderSide(border),
          borderRadius: BorderRadius.circular(8),
        ),
        clipBehavior: Clip.antiAlias,
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              // Narrow tables stretch their last column to fill the width.
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: Table(
                defaultColumnWidth: const IntrinsicColumnWidth(),
                columnWidths: {
                  columns.length - 1: const IntrinsicColumnWidth(flex: 1),
                },
                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                border: TableBorder(horizontalInside: border),
                children: [
                  TableRow(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainer,
                    ),
                    children: [
                      for (final c in columns)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          child: Text(
                            label(c),
                            style: labelStyle.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                  for (var i = 0; i < shown; i++)
                    TableRow(
                      children: [
                        for (final c in columns)
                          rows[i].containsKey(c)
                              ? cell(
                                  value(
                                    rows[i][c],
                                    childPath(childPath(path, i), c),
                                    compact: true,
                                  ),
                                  childPath(childPath(path, i), c),
                                  rows[i][c],
                                  c,
                                )
                              : const SizedBox.shrink(),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget chips(List value, String path) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (var i = 0; i < value.length; i++)
            interactive(
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: DefaultTextStyle.merge(
                  style: TextStyle(
                    color: theme.colorScheme.onSecondaryContainer,
                  ),
                  child: this.value(
                    value[i],
                    childPath(path, i),
                    compact: true,
                  ),
                ),
              ),
              path: childPath(path, i),
              value: value[i],
            ),
        ],
      ),
    );
  }

  Widget bullets(List value, String path) {
    return _Capped(
      count: value.length,
      itemBuilder: (i) => interactive(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('•  ', style: valueStyle.copyWith(color: muted)),
              Expanded(child: this.value(value[i], childPath(path, i))),
            ],
          ),
        ),
        path: childPath(path, i),
        value: value[i],
      ),
    );
  }

  Widget emptyNote(String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Text(text, style: labelStyle.copyWith(fontStyle: FontStyle.italic)),
  );

  // ---- Values ---------------------------------------------------------------

  Widget value(Object? v, String path, {bool compact = false}) {
    final style = compact
        ? valueStyle.copyWith(fontSize: fontSize)
        : valueStyle;
    switch (v) {
      case null:
        return Text('—', style: style.copyWith(color: muted));
      case bool():
        final yes = theme.brightness == Brightness.dark
            ? const Color(0xFF81C784)
            : const Color(0xFF2E7D32);
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              v ? Icons.check_circle : Icons.cancel_outlined,
              size: style.fontSize! + 3,
              color: v ? yes : muted,
            ),
            const SizedBox(width: 6),
            Text(v ? 'Yes' : 'No', style: style),
          ],
        );
      case num():
        return Text(
          '$v',
          style: style.copyWith(
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        );
      case String():
        if (v.isEmpty) {
          return Text(
            'Empty',
            style: style.copyWith(color: muted, fontStyle: FontStyle.italic),
          );
        }
        if (_hexColor.hasMatch(v)) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: style.fontSize! + 2,
                height: style.fontSize! + 2,
                decoration: BoxDecoration(
                  color: _parseHex(v),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                v.toUpperCase(),
                style: style.copyWith(fontFamily: 'monospace'),
              ),
            ],
          );
        }
        final date = formatIsoDate(v);
        if (date != null) return Text(date, style: style);
        if (_url.hasMatch(v)) {
          return Text(
            v,
            style: style.copyWith(
              color: theme.colorScheme.primary,
              decoration: TextDecoration.underline,
              decorationColor: theme.colorScheme.primary,
            ),
          );
        }
        return Text(v, style: style);
      default:
        return Text('$v', style: style);
    }
  }

  static Color _parseHex(String hex) {
    var h = hex.substring(1);
    if (h.length == 3) h = h.split('').map((c) => '$c$c').join();
    if (h.length == 6) h = 'FF$h';
    // CSS uses #RRGGBBAA; Flutter wants AARRGGBB.
    if (hex.length == 9) h = h.substring(6) + h.substring(0, 6);
    return Color(int.parse(h, radix: 16));
  }
}

/// Label and value side by side on wide screens, stacked on narrow ones.
class _FieldRow extends StatelessWidget {
  const _FieldRow({required this.label, required this.value});

  final Widget label;
  final Widget value;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 480;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 4),
          child: wide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: math.min(220, constraints.maxWidth * 0.35),
                      child: Padding(
                        padding: const EdgeInsets.only(top: 1, right: 12),
                        child: label,
                      ),
                    ),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: value,
                      ),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [label, const SizedBox(height: 1), value],
                ),
        );
      },
    );
  }
}

/// Heading with an indented, collapsible body.
class _Section extends StatefulWidget {
  const _Section({
    required this.depth,
    required this.title,
    required this.subtitle,
    required this.fontSize,
    required this.child,
    required this.onHeaderLongPress,
    this.onHeaderTap,
  });

  final int depth;
  final String title;
  final String subtitle;
  final double fontSize;
  final Widget child;
  final VoidCallback onHeaderLongPress;
  final VoidCallback? onHeaderTap;

  @override
  State<_Section> createState() => _SectionState();
}

class _SectionState extends State<_Section> {
  bool _open = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size =
        widget.fontSize +
        switch (widget.depth) {
          0 => 6,
          1 => 3,
          _ => 1,
        };
    return Padding(
      padding: EdgeInsets.only(top: widget.depth == 0 ? 18 : 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: () {
              setState(() => _open = !_open);
              widget.onHeaderTap?.call();
            },
            onLongPress: widget.onHeaderLongPress,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Flexible(
                    child: Text(
                      widget.title,
                      style: TextStyle(
                        fontSize: size,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    widget.subtitle,
                    style: TextStyle(
                      fontSize: widget.fontSize - 1,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    _open ? Icons.expand_less : Icons.expand_more,
                    size: widget.fontSize + 4,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          if (_open)
            Container(
              margin: const EdgeInsets.only(left: 2, top: 2),
              padding: const EdgeInsets.only(left: 12),
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(
                    color: theme.colorScheme.outlineVariant,
                    width: 2,
                  ),
                ),
              ),
              child: widget.child,
            ),
        ],
      ),
    );
  }
}

/// Builds only the first [_maxInitialItems] items, with a button to show all.
class _Capped extends StatefulWidget {
  const _Capped({required this.count, this.itemBuilder, this.builder})
    : assert((itemBuilder == null) != (builder == null));

  final int count;

  /// Builds one item; the items are stacked in a column.
  final Widget Function(int index)? itemBuilder;

  /// Builds the whole block for the first `shown` items.
  final Widget Function(int shown)? builder;

  @override
  State<_Capped> createState() => _CappedState();
}

class _CappedState extends State<_Capped> {
  bool _all = false;

  @override
  Widget build(BuildContext context) {
    final shown = _all
        ? widget.count
        : math.min(widget.count, _maxInitialItems);
    final itemBuilder = widget.itemBuilder;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (itemBuilder != null)
          for (var i = 0; i < shown; i++) itemBuilder(i)
        else
          widget.builder!(shown),
        if (shown < widget.count)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => setState(() => _all = true),
              child: Text('Show all ${widget.count} items'),
            ),
          ),
      ],
    );
  }
}
