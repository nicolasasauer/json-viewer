import 'package:flutter/material.dart';

import 'json_tools.dart';

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
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            expands: true,
            maxLines: null,
            minLines: null,
            textAlignVertical: TextAlignVertical.top,
            keyboardType: TextInputType.multiline,
            autocorrect: false,
            enableSuggestions: false,
            smartQuotesType: SmartQuotesType.disabled,
            smartDashesType: SmartDashesType.disabled,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: fontSize,
              height: 1.4,
              color: theme.colorScheme.onSurface,
            ),
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.fromLTRB(16, 16, 16, 32),
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
          symbol('Tab', '  '),
          symbol('true', 'true'),
          symbol('false', 'false'),
          symbol('null', 'null'),
          const VerticalDivider(indent: 10, endIndent: 10),
          TextButton.icon(
            onPressed: onFormat,
            icon: const Icon(Icons.format_indent_increase, size: 18),
            label: const Text('Format'),
          ),
          TextButton.icon(
            onPressed: onMinify,
            icon: const Icon(Icons.compress, size: 18),
            label: const Text('Minify'),
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
        ? 'Checking…'
        : valid
        ? 'Valid JSON · ${typeName(parseResult.value)}'
        : '${parseResult.error}';

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
