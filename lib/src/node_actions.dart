import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'json_tools.dart';

void copyToClipboard(BuildContext context, String text, String what) {
  Clipboard.setData(ClipboardData(text: text));
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text('$what copied')));
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
            copyToClipboard(context, copyText(value), 'Value');
          },
          child: const Text('Copy'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Close'),
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
                typeName(value),
                describeContainer(value),
              ].where((s) => s.isNotEmpty).join(' · '),
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.content_copy),
            title: const Text('Copy value'),
            onTap: () {
              Navigator.pop(sheetContext);
              copyToClipboard(context, copyText(value), 'Value');
            },
          ),
          ListTile(
            leading: const Icon(Icons.route_outlined),
            title: const Text('Copy path'),
            onTap: () {
              Navigator.pop(sheetContext);
              copyToClipboard(context, path, 'Path');
            },
          ),
          if (key != null)
            ListTile(
              leading: const Icon(Icons.key_outlined),
              title: const Text('Copy key'),
              onTap: () {
                Navigator.pop(sheetContext);
                copyToClipboard(context, key, 'Key');
              },
            ),
        ],
      ),
    ),
  );
}
