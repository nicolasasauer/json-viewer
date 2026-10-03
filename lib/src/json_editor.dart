import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderEditable;

import 'json_text_controller.dart';
import 'json_tools.dart';
import 'l10n.dart';

/// Plain-text JSON editor with a symbol bar and a validation status line.
class JsonEditor extends StatelessWidget {
  const JsonEditor({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.fontSize,
    required this.parseResult,
    required this.upToDate,
    required this.onFormat,
    required this.onMinify,
    required this.onErrorTap,
    this.scrollController,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final double fontSize;
  final JsonParseResult parseResult;

  /// False while the user is typing and validation has not caught up yet.
  final bool upToDate;
  final VoidCallback onFormat;
  final VoidCallback onMinify;
  final VoidCallback onErrorTap;
  final ScrollController? scrollController;

  /// Inserts [text] at the cursor (replacing any selection) and places the
  /// cursor [cursorBack] characters before the end of the inserted text.
  void _insert(String text, {int cursorBack = 0}) {
    final value = controller.value;
    final sel = value.selection.isValid
        ? value.selection
        : TextSelection.collapsed(offset: value.text.length);
    final newText = value.text.replaceRange(sel.start, sel.end, text);
    controller.value = value.copyWith(
      text: newText,
      selection: TextSelection.collapsed(
        offset: sel.start + text.length - cursorBack,
      ),
      composing: TextRange.empty,
    );
    focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Expanded(
          child: _FoldableTextField(
            controller: controller,
            focusNode: focusNode,
            scrollController: scrollController,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: fontSize,
              height: 1.4,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ),
        const Divider(height: 1),
        _SymbolBar(onInsert: _insert, onFormat: onFormat, onMinify: onMinify),
        _StatusLine(
          parseResult: parseResult,
          upToDate: upToDate,
          onErrorTap: onErrorTap,
        ),
      ],
    );
  }
}

/// The editor's text field with a VS Code style fold gutter on the left.
class _FoldableTextField extends StatefulWidget {
  const _FoldableTextField({
    required this.controller,
    required this.focusNode,
    required this.style,
    this.scrollController,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final TextStyle style;
  final ScrollController? scrollController;

  @override
  State<_FoldableTextField> createState() => _FoldableTextFieldState();
}

class _FoldMarker {
  const _FoldMarker(this.start, this.top, this.height, this.folded);

  final int start;
  final double top;
  final double height;
  final bool folded;

  @override
  bool operator ==(Object other) =>
      other is _FoldMarker &&
      other.start == start &&
      other.top == top &&
      other.height == height &&
      other.folded == folded;

  @override
  int get hashCode => Object.hash(start, top, height, folded);
}

class _FoldableTextFieldState extends State<_FoldableTextField> {
  static const _gutter = 26.0;
  static const _maxMarkers = 3000;

  final _fieldKey = GlobalKey();
  ScrollController? _ownScroll;
  List<_FoldMarker> _markers = const [];
  bool _scheduled = false;

  ScrollController get _scroll =>
      widget.scrollController ?? (_ownScroll ??= ScrollController());

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_schedule);
    _scroll.addListener(_schedule);
  }

  @override
  void didUpdateWidget(_FoldableTextField old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_schedule);
      widget.controller.addListener(_schedule);
    }
    final oldScroll = old.scrollController ?? _ownScroll;
    if (oldScroll != _scroll) {
      oldScroll?.removeListener(_schedule);
      _scroll.addListener(_schedule);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_schedule);
    _scroll.removeListener(_schedule);
    _ownScroll?.dispose();
    super.dispose();
  }

  void _schedule() {
    if (_scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (mounted) _updateMarkers();
    });
  }

  RenderEditable? _findRenderEditable() {
    RenderEditable? result;
    void visit(Element e) {
      if (result != null) return;
      if (e is RenderObjectElement && e.renderObject is RenderEditable) {
        result = e.renderObject as RenderEditable;
        return;
      }
      e.visitChildElements(visit);
    }

    final root = _fieldKey.currentContext;
    if (root is Element) root.visitChildElements(visit);
    return result;
  }

  /// Positions the fold arrows next to the lines that open a block.
  void _updateMarkers() {
    final c = widget.controller;
    var markers = <_FoldMarker>[];
    final editable = _findRenderEditable();
    final box = context.findRenderObject();
    if (c is JsonEditingController &&
        editable != null &&
        editable.hasSize &&
        box is RenderBox &&
        box.hasSize) {
      final pairs = c.foldablePairs;
      if (pairs.length <= _maxMarkers) {
        for (final start in pairs.keys) {
          if (c.isHiddenStart(start)) continue;
          final rect = editable.getLocalRectForCaret(
            TextPosition(offset: start),
          );
          final top = box
              .globalToLocal(editable.localToGlobal(rect.topLeft))
              .dy;
          if (top < -rect.height || top > box.size.height) continue;
          markers.add(_FoldMarker(start, top, rect.height, c.isFolded(start)));
        }
      }
    }
    if (!_listEquals(markers, _markers)) setState(() => _markers = markers);
  }

  static bool _listEquals(List<_FoldMarker> a, List<_FoldMarker> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    _schedule(); // layout may have changed (resize, font size)
    final scheme = Theme.of(context).colorScheme;
    final c = widget.controller;
    return Stack(
      clipBehavior: Clip.hardEdge,
      children: [
        Positioned.fill(
          child: TextField(
            key: _fieldKey,
            controller: c,
            focusNode: widget.focusNode,
            scrollController: _scroll,
            expands: true,
            maxLines: null,
            minLines: null,
            textAlignVertical: TextAlignVertical.top,
            keyboardType: TextInputType.multiline,
            autocorrect: false,
            enableSuggestions: false,
            smartQuotesType: SmartQuotesType.disabled,
            smartDashesType: SmartDashesType.disabled,
            style: widget.style,
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.fromLTRB(_gutter, 16, 16, 32),
            ),
          ),
        ),
        if (c is JsonEditingController)
          for (final m in _markers)
            Positioned(
              left: 2,
              top: m.top,
              width: _gutter - 4,
              height: m.height,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => c.toggleFold(m.start),
                child: Icon(
                  m.folded ? Icons.chevron_right : Icons.expand_more,
                  size: 18,
                  color: m.folded ? scheme.primary : scheme.outline,
                  semanticLabel: m.folded
                      ? context.l10n.unfold
                      : context.l10n.fold,
                ),
              ),
            ),
      ],
    );
  }
}

class _SymbolBar extends StatelessWidget {
  const _SymbolBar({
    required this.onInsert,
    required this.onFormat,
    required this.onMinify,
  });

  final void Function(String text, {int cursorBack}) onInsert;
  final VoidCallback onFormat;
  final VoidCallback onMinify;

  @override
  Widget build(BuildContext context) {
    Widget symbol(String label, String insert, {int back = 0}) => TextButton(
      style: TextButton.styleFrom(
        minimumSize: const Size(44, 40),
        padding: const EdgeInsets.symmetric(horizontal: 8),
      ),
      onPressed: () => onInsert(insert, cursorBack: back),
      child: Text(
        label,
        style: const TextStyle(fontFamily: 'monospace', fontSize: 16),
      ),
    );

    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        children: [
          symbol('{ }', '{}', back: 1),
          symbol('[ ]', '[]', back: 1),
          symbol('" "', '""', back: 1),
          symbol(':', ': '),
          symbol(',', ','),
          symbol(context.l10n.tabKey, '  '),
          symbol('true', 'true'),
          symbol('false', 'false'),
          symbol('null', 'null'),
          const VerticalDivider(indent: 10, endIndent: 10),
          TextButton.icon(
            onPressed: onFormat,
            icon: const Icon(Icons.format_indent_increase, size: 18),
            label: Text(context.l10n.format),
          ),
          TextButton.icon(
            onPressed: onMinify,
            icon: const Icon(Icons.compress, size: 18),
            label: Text(context.l10n.minify),
          ),
        ],
      ),
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({
    required this.parseResult,
    required this.upToDate,
    required this.onErrorTap,
  });

  final JsonParseResult parseResult;
  final bool upToDate;
  final VoidCallback onErrorTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final valid = parseResult.isValid;
    final color = !upToDate
        ? theme.colorScheme.onSurfaceVariant
        : valid
        ? theme.colorScheme.primary
        : theme.colorScheme.error;
    final icon = !upToDate
        ? Icons.more_horiz
        : valid
        ? Icons.check_circle_outline
        : Icons.error_outline;
    final text = !upToDate
        ? context.l10n.checking
        : valid
        ? context.l10n.validJson(typeName(parseResult.value, context.l10n))
        : parseResult.error!.describe(context.l10n);

    return Material(
      color: theme.colorScheme.surfaceContainer,
      child: InkWell(
        onTap: upToDate && !valid ? onErrorTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(color: color),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
