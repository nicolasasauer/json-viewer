import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'json_tools.dart';
import 'l10n.dart';

/// Copies [text] and confirms with [message] (e.g. "Value copied").
void copyToClipboard(BuildContext context, String text, String message) {
  Clipboard.setData(ClipboardData(text: text));
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// Dialog with the full value of a node.
void showJsonValue(
  BuildContext context, {
  required String path,
  required Object? value,
  double fontSize = 14,
}) {
  showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(
        path,
        style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
      ),
      content: SingleChildScrollView(
        child: SelectableText(
          copyText(value),
          style: TextStyle(fontFamily: 'monospace', fontSize: fontSize),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(dialogContext);
            copyToClipboard(context, copyText(value), context.l10n.valueCopied);
          },
          child: Text(context.l10n.copy),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: Text(context.l10n.close),
        ),
      ],
    ),
  );
}

/// Bottom sheet with copy actions for a node (value, path, key).
void showJsonNodeActions(
  BuildContext context, {
  required String path,
  required Object? value,
  String? key,
}) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: Text(
              path,
              style: const TextStyle(fontFamily: 'monospace'),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              [
                typeName(value, context.l10n),
                describeContainer(value, context.l10n),
              ].where((s) => s.isNotEmpty).join(' · '),
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.content_copy),
            title: Text(context.l10n.copyValue),
            onTap: () {
              Navigator.pop(sheetContext);
              copyToClipboard(
                context,
                copyText(value),
                context.l10n.valueCopied,
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.route_outlined),
            title: Text(context.l10n.copyPath),
            onTap: () {
              Navigator.pop(sheetContext);
              copyToClipboard(context, path, context.l10n.pathCopied);
            },
          ),
          if (key != null)
            ListTile(
              leading: const Icon(Icons.key_outlined),
              title: Text(context.l10n.copyKey),
              onTap: () {
                Navigator.pop(sheetContext);
                copyToClipboard(context, key, context.l10n.keyCopied);
              },
            ),
        ],
      ),
    ),
  );
}
