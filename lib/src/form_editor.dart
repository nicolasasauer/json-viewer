import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'json_edit.dart';
import 'json_tools.dart';

/// A change to the document, applied by the owner to the *current* root.
typedef JsonEdit = Object? Function(Object? root);

String _pathKey(JsonPath path) => path.fold(rootPath, childPath);

/// Structured editor: add, rename, reorder and edit fields and list items
/// without typing JSON syntax.
class JsonFormEditor extends StatefulWidget {
  const JsonFormEditor({
    super.key,
    required this.value,
    required this.onEdit,
    required this.fontSize,
    this.scrollController,
  });

  final Object? value;
  final void Function(JsonEdit edit) onEdit;
  final double fontSize;
  final ScrollController? scrollController;

  @override
  State<JsonFormEditor> createState() => _JsonFormEditorState();
}

class _JsonFormEditorState extends State<JsonFormEditor> {
  /// Path of the most recently added value; its editor gets the focus.
  String? _autofocus;
  final Set<String> _collapsed = {};

  void _toggleCollapsed(String key) => setState(() {
    if (!_collapsed.remove(key)) _collapsed.add(key);
  });

  void _edit(JsonEdit edit, {JsonPath? focus}) {
    if (focus != null) _autofocus = _pathKey(focus);
    widget.onEdit(edit);
  }

  @override
  Widget build(BuildContext context) {
    final b = _FormBuilder(this, context);
    final root = widget.value;
    final List<Widget> children;
    if (root is Map) {
      children = [
        if (root.isEmpty) b.emptyRootHint(isList: false),
        for (final key in root.keys) b.field(key as String, root[key], [key]),
        b.addFieldButton(const [], root),
      ];
    } else if (root is List) {
      children = [
        if (root.isEmpty) b.emptyRootHint(isList: true),
        for (var i = 0; i < root.length; i++) b.item(i, root[i], [i]),
        b.addItemButton(const [], root),
      ];
    } else {
      children = [b.primitiveRoot(root)];
    }
    return ListView(
      controller: widget.scrollController,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      children: children,
    );
  }
}

class _FormBuilder {
  _FormBuilder(this.state, this.context) : theme = Theme.of(context);

  final _JsonFormEditorState state;
  final BuildContext context;
  final ThemeData theme;

  double get fontSize => state.widget.fontSize;
  Color get muted => theme.colorScheme.onSurfaceVariant;

  void edit(JsonEdit e, {JsonPath? focus}) => state._edit(e, focus: focus);

  // ---- Fields and items ------------------------------------------------------

  Widget field(String key, Object? value, JsonPath path) {
    final keyLabel = InkWell(
      borderRadius: BorderRadius.circular(4),
      onTap: () => _rename(path, key),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(
          key,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.primary,
          ),
        ),
      ),
    );
    if (value is Map || value is List) {
      return _container(
        path: path,
        header: keyLabel,
        value: value,
        menu: _menu(path, value, isField: true, key: key),
      );
    }
    return Padding(
      key: ValueKey(_pathKey(path)),
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Align(alignment: Alignment.centerLeft, child: keyLabel),
              ),
              _menu(path, value, isField: true, key: key),
            ],
          ),
          valueEditor(value, path),
        ],
      ),
    );
  }

  Widget item(int index, Object? value, JsonPath path) {
    final label = Text(
      '#${index + 1}',
      style: TextStyle(fontSize: fontSize, color: muted),
    );
    if (value is Map || value is List) {
      final title = value is Map ? _itemTitle(value) : null;
      return _container(
        path: path,
        header: title == null
            ? label
            : Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: '#${index + 1}  '),
                    TextSpan(
                      text: title,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
                style: TextStyle(fontSize: fontSize, color: muted),
                overflow: TextOverflow.ellipsis,
              ),
        value: value,
        menu: _menu(path, value, isField: false),
      );
    }
    return Padding(
      key: ValueKey(_pathKey(path)),
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(width: fontSize * 2.6, child: label),
          Expanded(child: valueEditor(value, path)),
          _menu(path, value, isField: false),
        ],
      ),
    );
  }

  Widget _container({
    required JsonPath path,
    required Widget header,
    required Object? value,
    required Widget menu,
  }) {
    final key = _pathKey(path);
    final open = !state._collapsed.contains(key);
    final children = <Widget>[
      if (value is Map) ...[
        for (final k in value.keys) field(k as String, value[k], [...path, k]),
        addFieldButton(path, value),
      ] else if (value is List) ...[
        for (var i = 0; i < value.length; i++) item(i, value[i], [...path, i]),
        addItemButton(path, value),
      ],
    ];
    return Card.outlined(
      key: ValueKey(key),
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 2, 4, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: Icon(open ? Icons.expand_more : Icons.chevron_right),
                  onPressed: () => state._toggleCollapsed(key),
                ),
                Expanded(
                  child: Row(
                    children: [
                      Flexible(child: header),
                      const SizedBox(width: 8),
                      Text(
                        value is Map
                            ? '${value.length} ${value.length == 1 ? 'field' : 'fields'}'
                            : describeContainer(value),
                        style: TextStyle(fontSize: fontSize - 1, color: muted),
                      ),
                    ],
                  ),
                ),
                menu,
              ],
            ),
            if (open)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 8, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: children,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget primitiveRoot(Object? value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'This document is a single value.',
          style: TextStyle(fontSize: fontSize, color: muted),
        ),
        const SizedBox(height: 8),
        valueEditor(value, const []),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: () => edit((_) => <String, Object?>{}),
              icon: const Icon(Icons.data_object),
              label: const Text('Make it a group'),
            ),
            OutlinedButton.icon(
              onPressed: () => edit((r) => <Object?>[r]),
              icon: const Icon(Icons.format_list_bulleted),
              label: const Text('Make it a list'),
            ),
          ],
        ),
      ],
    );
  }

  Widget emptyRootHint({required bool isList}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isList
                ? 'This list is empty. Add items below.'
                : 'This document is empty. Add fields below, '
                      'or start with a list instead.',
            style: TextStyle(fontSize: fontSize, color: muted),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () =>
                edit((_) => isList ? <String, Object?>{} : <Object?>[]),
            icon: Icon(isList ? Icons.data_object : Icons.format_list_bulleted),
            label: Text(isList ? 'Use a group instead' : 'Start with a list'),
          ),
        ],
      ),
    );
  }

  // ---- Add buttons -------------------------------------------------------

  Widget addFieldButton(JsonPath objectPath, Map object) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: () async {
          final result = await showAddFieldDialog(context, object.keys);
          if (result == null) return;
          edit(
            (r) => addField(r, objectPath, result.key, result.value),
            focus: [...objectPath, result.key],
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Add field'),
      ),
    );
  }

  Widget addItemButton(JsonPath listPath, List list) {
    Future<void> pickKind() async {
      final value = await showPickValueDialog(context, title: 'Add item');
      if (value == null) return;
      edit(
        (r) => addItem(r, listPath, value.value),
        focus: [...listPath, list.length],
      );
    }

    return Row(
      children: [
        TextButton.icon(
          onPressed: list.isEmpty
              ? pickKind
              : () => edit(
                  // Same shape as the last item: objects keep their fields.
                  (r) => addItem(r, listPath, blankLike(list.last)),
                  focus: [
                    ...listPath,
                    list.length,
                    if (list.last is Map && (list.last as Map).isNotEmpty)
                      (list.last as Map).keys.first as String,
                  ],
                ),
          icon: const Icon(Icons.add),
          label: Text(
            list.isNotEmpty && list.last is Map
                ? 'Add item (same fields)'
                : 'Add item',
          ),
        ),
        if (list.isNotEmpty)
          IconButton(
            tooltip: 'Add item of another type',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.more_horiz),
            onPressed: pickKind,
          ),
      ],
    );
  }

  // ---- Value editors ---------------------------------------------------------

  Widget valueEditor(Object? value, JsonPath path) {
    final key = _pathKey(path);
    final autofocus = state._autofocus == key;
    switch (value) {
      case bool():
        return Row(
          children: [
            Switch(
              value: value,
              onChanged: (v) => edit((r) => setAt(r, path, v)),
            ),
            const SizedBox(width: 8),
            Text(value ? 'Yes' : 'No', style: TextStyle(fontSize: fontSize)),
          ],
        );
      case null:
        return Align(
          alignment: Alignment.centerLeft,
          child: ActionChip(
            avatar: const Icon(Icons.edit_outlined, size: 18),
            label: const Text('Empty – set a value'),
            onPressed: () => _changeType(path, value),
          ),
        );
      case num():
        return _InlineField(
          key: ValueKey('$key#num'),
          value: '$value',
          numeric: true,
          autofocus: autofocus,
          fontSize: fontSize,
          onCommit: (text) => edit(
            (r) => setAt(r, path, int.tryParse(text) ?? num.parse(text)),
          ),
        );
      case String():
        return _InlineField(
          key: ValueKey('$key#text'),
          value: value,
          autofocus: autofocus,
          fontSize: fontSize,
          onCommit: (text) => edit((r) => setAt(r, path, text)),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  // ---- Menu --------------------------------------------------------------

  Widget _menu(
    JsonPath path,
    Object? value, {
    required bool isField,
    String? key,
  }) {
    return PopupMenuButton<VoidCallback>(
      tooltip: 'Field options',
      icon: Icon(Icons.more_vert, color: muted, semanticLabel: 'Options'),
      onSelected: (action) => action(),
      itemBuilder: (_) => [
        if (isField)
          PopupMenuItem(
            value: () => _rename(path, key!),
            child: const ListTile(
              leading: Icon(Icons.drive_file_rename_outline),
              title: Text('Rename'),
            ),
          ),
        PopupMenuItem(
          value: () => _changeType(path, value),
          child: const ListTile(
            leading: Icon(Icons.swap_horiz),
            title: Text('Change type'),
          ),
        ),
        PopupMenuItem(
          value: () => edit((r) => duplicate(r, path)),
          child: const ListTile(
            leading: Icon(Icons.copy_all_outlined),
            title: Text('Duplicate'),
          ),
        ),
        PopupMenuItem(
          value: () => edit((r) => move(r, path, -1)),
          child: const ListTile(
            leading: Icon(Icons.arrow_upward),
            title: Text('Move up'),
          ),
        ),
        PopupMenuItem(
          value: () => edit((r) => move(r, path, 1)),
          child: const ListTile(
            leading: Icon(Icons.arrow_downward),
            title: Text('Move down'),
          ),
        ),
        PopupMenuItem(
          value: () => edit((r) => removeAt(r, path)),
          child: ListTile(
            leading: Icon(Icons.delete_outline, color: theme.colorScheme.error),
            title: Text(
              'Delete',
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _rename(JsonPath path, String key) async {
    final parent = getAt(state.widget.value, path.sublist(0, path.length - 1));
    final taken = parent is Map ? parent.keys.where((k) => k != key) : const [];
    final newKey = await showKeyDialog(
      context,
      title: 'Rename field',
      initial: key,
      taken: taken,
    );
    if (newKey == null || newKey == key) return;
    edit((r) => renameKey(r, path, newKey));
  }

  Future<void> _changeType(JsonPath path, Object? value) async {
    final kind = await showDialog<JsonKind>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Change type'),
        children: [
          for (final k in JsonKind.values)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, k),
              child: Row(
                children: [
                  Icon(_kindIcon(k), size: 20),
                  const SizedBox(width: 12),
                  Text(k.label),
                  if (k == kindOf(value)) ...[
                    const Spacer(),
                    const Icon(Icons.check, size: 20),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
    if (kind == null || kind == kindOf(value)) return;
    final lossy =
        (value is Map && value.isNotEmpty ||
            value is List && value.isNotEmpty) &&
        kind != JsonKind.text;
    if (lossy && context.mounted) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Change type?'),
          content: Text(
            'The ${describeContainer(value)} inside will be removed.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Change'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    edit((r) => setAt(r, path, convert(getAt(r, path), kind)), focus: path);
  }
}

const _titleKeys = ['title', 'name', 'label', 'displayName', 'heading', 'id'];

String? _itemTitle(Map item) {
  for (final k in _titleKeys) {
    final v = item[k];
    if (v is String && v.isNotEmpty || v is num) return '$v';
  }
  return null;
}

IconData _kindIcon(JsonKind kind) => switch (kind) {
  JsonKind.text => Icons.short_text,
  JsonKind.number => Icons.pin_outlined,
  JsonKind.boolean => Icons.toggle_on_outlined,
  JsonKind.group => Icons.data_object,
  JsonKind.list => Icons.format_list_bulleted,
  JsonKind.empty => Icons.block,
};

// ---- Dialogs -----------------------------------------------------------------

/// A value chosen in a dialog (wrapped so that `null` is a valid choice).
class PickedValue {
  const PickedValue(this.value);
  final Object? value;
}

/// Reads JSON from the clipboard; shows a snack bar and returns null if the
/// clipboard holds no valid JSON.
Future<PickedValue?> readClipboardJson(BuildContext context) async {
  final text = (await Clipboard.getData(Clipboard.kTextPlain))?.text ?? '';
  final parsed = parseJson(text);
  if (parsed.isValid) return PickedValue(deepCopy(parsed.value));
  if (context.mounted) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            text.trim().isEmpty
                ? 'The clipboard is empty'
                : 'The clipboard does not contain valid JSON',
          ),
        ),
      );
  }
  return null;
}

class _KindChips extends StatelessWidget {
  const _KindChips({required this.selected, required this.onSelected});

  final Object selected; // JsonKind or 'clipboard'
  final ValueChanged<Object> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final k in JsonKind.values)
          ChoiceChip(
            showCheckmark: false,
            avatar: Icon(_kindIcon(k), size: 18),
            label: Text(k.label),
            selected: selected == k,
            onSelected: (_) => onSelected(k),
          ),
        ChoiceChip(
          showCheckmark: false,
          avatar: const Icon(Icons.content_paste, size: 18),
          label: const Text('Paste JSON'),
          selected: selected == 'clipboard',
          onSelected: (_) => onSelected('clipboard'),
        ),
      ],
    );
  }
}

Future<PickedValue?> _resolve(BuildContext context, Object choice) async {
  if (choice is JsonKind) return PickedValue(choice.initialValue);
  return readClipboardJson(context);
}

Future<({String key, Object? value})?> showAddFieldDialog(
  BuildContext context,
  Iterable<Object?> existingKeys,
) async {
  final taken = existingKeys.toSet();
  final controller = TextEditingController();
  Object choice = JsonKind.text;
  String? error;
  final result = await showDialog<({String key, Object choice})>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        void submit() {
          final key = controller.text.trim();
          if (key.isEmpty) {
            setState(() => error = 'Enter a name');
          } else if (taken.contains(key)) {
            setState(() => error = '"$key" already exists');
          } else {
            Navigator.pop(context, (key: key, choice: choice));
          }
        }

        return AlertDialog(
          title: const Text('Add field'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: controller,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: 'Name',
                    errorText: error,
                  ),
                  onSubmitted: (_) => submit(),
                ),
                const SizedBox(height: 16),
                _KindChips(
                  selected: choice,
                  onSelected: (c) => setState(() => choice = c),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(onPressed: submit, child: const Text('Add')),
          ],
        );
      },
    ),
  );
  // The controller is not disposed here: the dialog may still be animating
  // out and using it. Without listeners it is simply garbage collected.
  if (result == null || !context.mounted) return null;
  final value = await _resolve(context, result.choice);
  if (value == null) return null;
  return (key: result.key, value: value.value);
}

Future<PickedValue?> showPickValueDialog(
  BuildContext context, {
  required String title,
}) async {
  final choice = await showDialog<Object>(
    context: context,
    builder: (context) => SimpleDialog(
      title: Text(title),
      children: [
        for (final k in JsonKind.values)
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, k),
            child: Row(
              children: [
                Icon(_kindIcon(k), size: 20),
                const SizedBox(width: 12),
                Text(k.label),
              ],
            ),
          ),
        SimpleDialogOption(
          onPressed: () => Navigator.pop(context, 'clipboard'),
          child: const Row(
            children: [
              Icon(Icons.content_paste, size: 20),
              SizedBox(width: 12),
              Text('Paste JSON'),
            ],
          ),
        ),
      ],
    ),
  );
  if (choice == null || !context.mounted) return null;
  return _resolve(context, choice);
}

Future<String?> showKeyDialog(
  BuildContext context, {
  required String title,
  required String initial,
  required Iterable<Object?> taken,
}) async {
  final controller = TextEditingController(text: initial)
    ..selection = TextSelection(baseOffset: 0, extentOffset: initial.length);
  final takenSet = taken.toSet();
  String? error;
  final result = await showDialog<String>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        void submit() {
          final key = controller.text.trim();
          if (key.isEmpty) {
            setState(() => error = 'Enter a name');
          } else if (takenSet.contains(key)) {
            setState(() => error = '"$key" already exists');
          } else {
            Navigator.pop(context, key);
          }
        }

        return AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(labelText: 'Name', errorText: error),
            onSubmitted: (_) => submit(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(onPressed: submit, child: const Text('Save')),
          ],
        );
      },
    ),
  );
  // The controller is not disposed here: the dialog may still be animating
  // out and using it. Without listeners it is simply garbage collected.
  return result;
}

// ---- Inline text field ---------------------------------------------------------

/// Text/number field that writes back after a short pause, on submit and
/// when it loses focus.
class _InlineField extends StatefulWidget {
  const _InlineField({
    super.key,
    required this.value,
    required this.onCommit,
    required this.fontSize,
    this.numeric = false,
    this.autofocus = false,
  });

  final String value;
  final void Function(String text) onCommit;
  final double fontSize;
  final bool numeric;
  final bool autofocus;

  @override
  State<_InlineField> createState() => _InlineFieldState();
}

class _InlineFieldState extends State<_InlineField> {
  late final _controller = TextEditingController(text: widget.value);
  final _focus = FocusNode();
  Timer? _debounce;
  String? _error;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) _commit();
    });
  }

  @override
  void didUpdateWidget(_InlineField old) {
    super.didUpdateWidget(old);
    if (!_focus.hasFocus && widget.value != _controller.text) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    // Flush an edit that has not been written back yet (e.g. mode switch).
    final text = _controller.text;
    if (text != widget.value && _valid(text)) {
      final commit = widget.onCommit;
      WidgetsBinding.instance.addPostFrameCallback((_) => commit(text));
    }
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  bool _valid(String text) => !widget.numeric || num.tryParse(text) != null;

  void _commit() {
    _debounce?.cancel();
    final text = _controller.text;
    if (text == widget.value) return;
    if (!_valid(text)) {
      setState(() => _error = 'Not a number');
      return;
    }
    if (_error != null) setState(() => _error = null);
    widget.onCommit(text);
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      focusNode: _focus,
      autofocus: widget.autofocus,
      maxLines: widget.numeric ? 1 : null,
      keyboardType: widget.numeric
          ? const TextInputType.numberWithOptions(signed: true, decimal: true)
          : TextInputType.multiline,
      style: TextStyle(fontSize: widget.fontSize + 1),
      decoration: InputDecoration(
        isDense: true,
        border: const OutlineInputBorder(),
        errorText: _error,
        hintText: widget.numeric ? '0' : 'Text',
      ),
      onChanged: (_) {
        _debounce?.cancel();
        _debounce = Timer(const Duration(milliseconds: 700), _commit);
      },
      onSubmitted: (_) => _commit(),
    );
  }
}
