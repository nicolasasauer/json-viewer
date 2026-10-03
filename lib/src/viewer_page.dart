import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'file_bridge.dart';
import 'form_editor.dart';
import 'json_edit.dart';
import 'json_editor.dart';
import 'json_highlighter.dart';
import 'json_locator.dart';
import 'json_tools.dart';
import 'json_tree_view.dart';
import 'readable_view.dart';

enum ViewMode { view, edit, split }

enum ViewStyle { readable, tree, text }

enum _DiscardChoice { cancel, discard, save }

class ViewerPage extends StatefulWidget {
  const ViewerPage({super.key, required this.onToggleTheme, this.bridge});

  final VoidCallback onToggleTheme;
  final FileBridge? bridge;

  @override
  State<ViewerPage> createState() => _ViewerPageState();
}

class _ViewerPageState extends State<ViewerPage> {
  late final FileBridge _bridge = widget.bridge ?? FileBridge();
  final _controller = JsonEditingController();
  final _editorFocus = FocusNode();
  final _tree = JsonTreeController();
  final _searchController = TextEditingController();
  final _editorScroll = ScrollController();
  final _viewerScroll = ScrollController();

  bool _hasDocument = false;
  String _fileName = 'Untitled.json';
  String? _uri;
  String _savedText = '';

  ViewMode _mode = ViewMode.view;
  ViewStyle _style = ViewStyle.readable;
  bool _humanizeKeys = true;

  /// Raw text view: show the file formatted instead of exactly as stored.
  bool _formatRaw = false;
  double _fontSize = 14;
  bool _searching = false;
  bool _syncScroll = true;

  /// Edit mode shows the form editor (true) or the text editor (false).
  bool _formEditor = true;

  /// Undo/redo for form edits (the text editor has its own history).
  final List<String> _undo = [];
  final List<String> _redo = [];

  /// The split-view pane the user last touched; only it drives the other one.
  ScrollController? _scrollLeader;

  JsonParseResult _parsed = parseJson('');
  String _parsedText = '';
  Timer? _parseTimer;
  String? _prettyCache;
  Object? _prettyCacheValue;

  bool get _dirty => _hasDocument && _controller.text != _savedText;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
    _bridge.setOnFileOpened(
      (file) => _openWithConfirm(file),
      onError: (e) => _snack('Could not open file: $e'),
    );
    _loadInitialFile();
  }

  @override
  void dispose() {
    _parseTimer?.cancel();
    _controller.dispose();
    _editorFocus.dispose();
    _tree.dispose();
    _searchController.dispose();
    _editorScroll.dispose();
    _viewerScroll.dispose();
    super.dispose();
  }

  // ---- Document state -------------------------------------------------------

  Future<void> _loadInitialFile() async {
    try {
      final file = await _bridge.getInitialFile();
      if (file != null && mounted) _load(file);
    } on MissingPluginException {
      // Not running on Android (e.g. tests); start empty.
    } catch (e) {
      _snack('Could not open file: $e');
    }
  }

  void _load(OpenedFile file) {
    _parseTimer?.cancel();
    _controller.value = TextEditingValue(text: file.content);
    setState(() {
      _hasDocument = true;
      _fileName = file.name;
      _uri = file.uri;
      _savedText = file.content;
      _mode = ViewMode.view;
      _undo.clear();
      _redo.clear();
      _searching = false;
      _searchController.clear();
      _reparse();
    });
    _tree.reset(_parsed.value);
  }

  void _newDocument({String text = '{\n}', String name = 'Untitled.json'}) {
    _controller.value = TextEditingValue(text: text);
    setState(() {
      _hasDocument = true;
      _fileName = name;
      _uri = null;
      _savedText = text;
      _mode = ViewMode.edit;
      _formEditor = true;
      _searching = false;
      _undo.clear();
      _redo.clear();
      _reparse();
    });
    _tree.reset(_parsed.value);
  }

  /// Creates a new document from JSON on the clipboard.
  Future<void> _pasteAsNew() async {
    final text = (await Clipboard.getData(Clipboard.kTextPlain))?.text ?? '';
    final parsed = parseJson(text);
    if (!mounted) return;
    if (!parsed.isValid) {
      _snack(
        text.trim().isEmpty
            ? 'The clipboard is empty'
            : 'The clipboard does not contain valid JSON',
        action: text.trim().isEmpty
            ? null
            : SnackBarAction(
                label: 'Open as text',
                onPressed: () async {
                  if (!await _confirmDiscard() || !mounted) return;
                  _newDocument(text: text, name: 'Pasted.json');
                  setState(() => _formEditor = false);
                },
              ),
      );
      return;
    }
    if (!await _confirmDiscard() || !mounted) return;
    _newDocument(text: prettyJson(parsed.value), name: 'Pasted.json');
    setState(() => _mode = ViewMode.view);
  }

  /// Applies a structured edit from the form editor to the text.
  void _applyEdit(JsonEdit edit) {
    final parsed = _parseNow();
    if (!parsed.isValid) return;
    final before = _controller.text;
    final Object? value;
    try {
      value = edit(deepCopy(parsed.value));
    } catch (e) {
      _snack('Could not apply change: $e');
      return;
    }
    final after = encodeLike(value, before);
    if (after == before) return;
    _undo.add(before);
    if (_undo.length > 200) _undo.removeAt(0);
    _redo.clear();
    _replaceTextKeepingHistory(after);
  }

  void _undoEdit() {
    if (_undo.isEmpty) return;
    _redo.add(_controller.text);
    _replaceTextKeepingHistory(_undo.removeLast());
  }

  void _redoEdit() {
    if (_redo.isEmpty) return;
    _undo.add(_controller.text);
    _replaceTextKeepingHistory(_redo.removeLast());
  }

  void _replaceTextKeepingHistory(String text) {
    _controller.value = TextEditingValue(text: text);
    setState(_reparse);
  }

  void _onTextChanged() {
    if (_controller.text == _parsedText) return;
    setState(() {}); // dirty marker
    _parseTimer?.cancel();
    _parseTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted && _controller.text != _parsedText) setState(_reparse);
    });
  }

  void _reparse() {
    _parsedText = _controller.text;
    _parsed = parseJson(_parsedText);
  }

  /// Ensures the parse result is up to date (used before view switches and saves).
  JsonParseResult _parseNow() {
    _parseTimer?.cancel();
    if (_controller.text != _parsedText) _reparse();
    return _parsed;
  }

  String _prettyText(Object? value) {
    if (_prettyCache == null || !identical(_prettyCacheValue, value)) {
      _prettyCache = prettyJson(value);
      _prettyCacheValue = value;
    }
    return _prettyCache!;
  }

  // ---- Actions --------------------------------------------------------------

  Future<void> _open() async {
    if (!await _confirmDiscard()) return;
    try {
      final file = await _bridge.openDocument();
      if (file != null && mounted) _load(file);
    } catch (e) {
      _snack('Could not open file: ${_errorText(e)}');
    }
  }

  Future<void> _openWithConfirm(OpenedFile file) async {
    if (await _confirmDiscard() && mounted) _load(file);
  }

  Future<void> _create() async {
    if (await _confirmDiscard() && mounted) _newDocument();
  }

  Future<bool> _save({bool saveAs = false}) async {
    if (!_hasDocument) return false;
    // Let a focused form field write back its pending edit first.
    FocusManager.instance.primaryFocus?.unfocus();
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return false;
    final text = _controller.text;
    final parsed = _parseNow();
    if (!parsed.isValid) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Save invalid JSON?'),
          content: Text('${parsed.error}'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save anyway'),
            ),
          ],
        ),
      );
      if (ok != true) return false;
    }
    try {
      final uri = _uri;
      if (!saveAs && uri != null) {
        await _bridge.saveFile(uri, text);
      } else {
        final created = await _bridge.createDocument(_fileName, text);
        if (created == null) return false;
        _fileName = created.name;
        _uri = created.uri;
      }
      if (!mounted) return true;
      setState(() => _savedText = text);
      _snack('Saved $_fileName');
      return true;
    } catch (e) {
      _snack(
        'Could not save file: ${_errorText(e)}',
        action: saveAs
            ? null
            : SnackBarAction(
                label: 'Save as',
                onPressed: () => _save(saveAs: true),
              ),
      );
      return false;
    }
  }

  /// Returns true if it is OK to replace or leave the current document.
  Future<bool> _confirmDiscard() async {
    if (!_dirty) return true;
    final choice = await showDialog<_DiscardChoice>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard changes?'),
        content: Text('"$_fileName" has unsaved changes.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, _DiscardChoice.cancel),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, _DiscardChoice.discard),
            child: const Text('Discard'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, _DiscardChoice.save),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    return switch (choice) {
      _DiscardChoice.discard => true,
      _DiscardChoice.save => await _save(),
      _ => false,
    };
  }

  void _setMode(ViewMode mode) {
    setState(() {
      _parseNow();
      _mode = mode;
      if (mode == ViewMode.edit) _searching = false;
    });
  }

  void _replaceText(String text) {
    _controller.value = TextEditingValue(
      text: text,
      selection: const TextSelection.collapsed(offset: 0),
    );
    setState(_reparse);
  }

  void _format() {
    final parsed = _parseNow();
    if (!parsed.isValid) {
      _snack('Cannot format: ${parsed.error}');
      return;
    }
    _replaceText(prettyJson(parsed.value));
  }

  void _minify() {
    final parsed = _parseNow();
    if (!parsed.isValid) {
      _snack('Cannot minify: ${parsed.error}');
      return;
    }
    _replaceText(minifyJson(parsed.value));
  }

  void _jumpToError() {
    final offset = _parsed.error?.offset;
    if (_mode == ViewMode.view) _setMode(ViewMode.edit);
    if (_formEditor) setState(() => _formEditor = false);
    if (offset != null) {
      final o = offset.clamp(0, _controller.text.length);
      _controller.selection = TextSelection.collapsed(offset: o);
    }
    _editorFocus.requestFocus();
  }

  /// Split view: selects the value at [path] in the editor and scrolls to it.
  void _revealInEditor(String path) {
    final text = _controller.text;
    if (!_parseNow().isValid) return;
    final range = locateJsonValues(text)[path];
    if (range == null) return;
    // Containers: put the cursor at the opening bracket; values: select them.
    final first = text.codeUnitAt(range.start);
    final isContainer = first == 0x7B || first == 0x5B;
    _scrollLeader = null;
    _controller.selection = isContainer
        ? TextSelection.collapsed(offset: range.start)
        : TextSelection(baseOffset: range.start, extentOffset: range.end);
    _editorFocus.requestFocus();
  }

  void _changeFontSize(double delta) =>
      setState(() => _fontSize = (_fontSize + delta).clamp(10, 28));

  void _copyAll() {
    Clipboard.setData(ClipboardData(text: _controller.text));
    _snack('Document copied');
  }

  void _snack(String message, {SnackBarAction? action}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message), action: action));
  }

  String _errorText(Object e) =>
      e is PlatformException ? (e.message ?? e.code) : e.toString();

  Future<void> _handleBack() async {
    if (_searching) {
      setState(() {
        _searching = false;
        _searchController.clear();
      });
      return;
    }
    if (_mode == ViewMode.edit) {
      _setMode(ViewMode.view);
      return;
    }
    if (await _confirmDiscard()) {
      await SystemNavigator.pop();
    }
  }

  // ---- UI -------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 720;
    return PopScope(
      canPop: !_dirty && !_searching && _mode != ViewMode.edit,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleBack();
      },
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.keyS, control: true): _save,
          const SingleActivator(LogicalKeyboardKey.keyO, control: true): _open,
        },
        child: Scaffold(
          appBar: _buildAppBar(wide),
          body: SafeArea(top: false, child: _buildBody(wide)),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(bool wide) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final canSave = _hasDocument && (_dirty || _uri == null);
    final treeAvailable =
        _hasDocument &&
        _mode != ViewMode.edit &&
        _style == ViewStyle.tree &&
        _parsed.isValid;

    return AppBar(
      titleSpacing: 16,
      shape: Border(bottom: BorderSide(color: theme.dividerColor)),
      title: Row(
        children: [
          if (wide) ...[
            Icon(Icons.data_object, color: theme.colorScheme.primary),
            const SizedBox(width: 12),
          ],
          Flexible(
            child: Text(
              _hasDocument ? _fileName : 'JSON Viewer',
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (_dirty)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Text(
                '•',
                style: TextStyle(color: theme.colorScheme.primary),
              ),
            ),
        ],
      ),
      actions: [
        if (_hasDocument)
          SegmentedButton<ViewMode>(
            showSelectedIcon: false,
            style: const ButtonStyle(
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            segments: const [
              ButtonSegment(
                value: ViewMode.view,
                icon: Icon(Icons.visibility_outlined, semanticLabel: 'View'),
                tooltip: 'View',
              ),
              ButtonSegment(
                value: ViewMode.edit,
                icon: Icon(Icons.edit_outlined, semanticLabel: 'Edit'),
                tooltip: 'Edit',
              ),
              ButtonSegment(
                value: ViewMode.split,
                icon: Icon(
                  Icons.vertical_split_outlined,
                  semanticLabel: 'Split view',
                ),
                tooltip: 'Split view',
              ),
            ],
            selected: {_mode},
            onSelectionChanged: (s) => _setMode(s.first),
          ),
        const SizedBox(width: 4),
        if (_hasDocument)
          IconButton(
            tooltip: 'Save',
            icon: const Icon(Icons.save_outlined),
            onPressed: canSave ? _save : null,
          ),
        if (treeAvailable && wide)
          IconButton(
            tooltip: 'Search',
            icon: const Icon(Icons.search, semanticLabel: 'Search'),
            onPressed: () => setState(() => _searching = !_searching),
          ),
        if (wide) ...[
          IconButton(
            tooltip: 'Smaller text',
            icon: const Text('A−', style: TextStyle(fontSize: 18)),
            onPressed: () => _changeFontSize(-1),
          ),
          IconButton(
            tooltip: 'Larger text',
            icon: const Text('A+', style: TextStyle(fontSize: 18)),
            onPressed: () => _changeFontSize(1),
          ),
          IconButton(
            tooltip: 'Open file',
            icon: const Icon(Icons.folder_open_outlined),
            onPressed: _open,
          ),
          IconButton(
            tooltip: dark ? 'Light theme' : 'Dark theme',
            icon: Icon(
              dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
            ),
            onPressed: widget.onToggleTheme,
          ),
        ],
        _buildMenu(wide, dark, treeAvailable),
        const SizedBox(width: 4),
      ],
      bottom: _searching && treeAvailable ? _buildSearchBar() : null,
    );
  }

  Widget _buildMenu(bool wide, bool dark, bool treeAvailable) {
    final valid = _hasDocument && _parsed.isValid;
    final items = <PopupMenuEntry<VoidCallback>>[
      PopupMenuItem(
        value: _create,
        child: const ListTile(
          leading: Icon(Icons.note_add_outlined),
          title: Text('New'),
        ),
      ),
      PopupMenuItem(
        value: _pasteAsNew,
        child: const ListTile(
          leading: Icon(Icons.content_paste),
          title: Text('Paste JSON'),
        ),
      ),
      if (!wide)
        PopupMenuItem(
          value: _open,
          child: const ListTile(
            leading: Icon(Icons.folder_open_outlined),
            title: Text('Open file'),
          ),
        ),
      if (_hasDocument)
        PopupMenuItem(
          value: () => _save(saveAs: true),
          child: const ListTile(
            leading: Icon(Icons.save_as_outlined),
            title: Text('Save as…'),
          ),
        ),
      if (_hasDocument)
        PopupMenuItem(
          value: _copyAll,
          child: const ListTile(
            leading: Icon(Icons.content_copy),
            title: Text('Copy all'),
          ),
        ),
      if (_hasDocument) const PopupMenuDivider(),
      if (treeAvailable && !wide)
        PopupMenuItem(
          value: () => setState(() => _searching = true),
          child: const ListTile(
            leading: Icon(Icons.search),
            title: Text('Search'),
          ),
        ),
      if (valid && _mode != ViewMode.edit) ...[
        if (_style == ViewStyle.readable)
          CheckedPopupMenuItem(
            value: () => setState(() => _humanizeKeys = !_humanizeKeys),
            checked: _humanizeKeys,
            child: const Text('Friendly key names'),
          ),
        const PopupMenuDivider(),
      ],
      if (treeAvailable) ...[
        PopupMenuItem(
          value: () => _tree.expandAll(_parsed.value),
          child: const ListTile(
            leading: Icon(Icons.unfold_more),
            title: Text('Expand all'),
          ),
        ),
        PopupMenuItem(
          value: _tree.collapseAll,
          child: const ListTile(
            leading: Icon(Icons.unfold_less),
            title: Text('Collapse all'),
          ),
        ),
      ],
      if (_mode == ViewMode.split)
        CheckedPopupMenuItem(
          value: () => setState(() => _syncScroll = !_syncScroll),
          checked: _syncScroll,
          child: const Text('Sync scrolling'),
        ),
      if (valid) ...[
        PopupMenuItem(
          value: _format,
          child: const ListTile(
            leading: Icon(Icons.format_indent_increase),
            title: Text('Format'),
          ),
        ),
        PopupMenuItem(
          value: _minify,
          child: const ListTile(
            leading: Icon(Icons.compress),
            title: Text('Minify'),
          ),
        ),
      ],
      if (!wide) ...[
        const PopupMenuDivider(),
        PopupMenuItem(
          value: () => _changeFontSize(-1),
          child: const ListTile(
            leading: Icon(Icons.text_decrease),
            title: Text('Smaller text'),
          ),
        ),
        PopupMenuItem(
          value: () => _changeFontSize(1),
          child: const ListTile(
            leading: Icon(Icons.text_increase),
            title: Text('Larger text'),
          ),
        ),
        PopupMenuItem(
          value: widget.onToggleTheme,
          child: ListTile(
            leading: Icon(
              dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
            ),
            title: Text(dark ? 'Light theme' : 'Dark theme'),
          ),
        ),
      ],
    ];
    return PopupMenuButton<VoidCallback>(
      tooltip: 'More',
      icon: const Icon(Icons.more_vert, semanticLabel: 'More'),
      onSelected: (action) => action(),
      itemBuilder: (_) => items,
    );
  }

  PreferredSizeWidget _buildSearchBar() {
    return PreferredSize(
      preferredSize: const Size.fromHeight(56),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: TextField(
          controller: _searchController,
          autofocus: true,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            isDense: true,
            hintText: 'Search keys and values',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: IconButton(
              tooltip: 'Close search',
              icon: const Icon(Icons.close),
              onPressed: () => setState(() {
                _searching = false;
                _searchController.clear();
              }),
            ),
            border: const OutlineInputBorder(),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(bool wide) {
    if (!_hasDocument) return _buildWelcome();
    switch (_mode) {
      case ViewMode.view:
        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: _style == ViewStyle.readable ? 960 : 1100,
            ),
            child: _buildViewer(),
          ),
        );
      case ViewMode.edit:
        return _buildEditor();
      case ViewMode.split:
        final divider = wide
            ? const VerticalDivider(width: 1)
            : const Divider(height: 1);
        final children = [
          Expanded(
            child: _syncedPane(_editorScroll, _viewerScroll, _buildEditor()),
          ),
          divider,
          Expanded(
            child: _syncedPane(_viewerScroll, _editorScroll, _buildViewer()),
          ),
        ];
        return wide ? Row(children: children) : Column(children: children);
    }
  }

  /// Wraps a split-view pane so scrolling it scrolls the other pane to the
  /// same relative position. Proportional, because the editor text and the
  /// tree have no line-by-line correspondence (collapsed nodes, minified files).
  Widget _syncedPane(
    ScrollController own,
    ScrollController other,
    Widget child,
  ) {
    return Listener(
      onPointerDown: (_) => _scrollLeader = own,
      onPointerSignal: (_) => _scrollLeader = own,
      child: NotificationListener<ScrollUpdateNotification>(
        onNotification: (n) {
          if (!_syncScroll ||
              _scrollLeader != own ||
              n.metrics.axis != Axis.vertical ||
              !other.hasClients) {
            return false;
          }
          final max = n.metrics.maxScrollExtent;
          final fraction = max <= 0 ? 0.0 : n.metrics.pixels / max;
          final target = other.position;
          target.jumpTo(
            (fraction * target.maxScrollExtent).clamp(
              target.minScrollExtent,
              target.maxScrollExtent,
            ),
          );
          return false;
        },
        child: child,
      ),
    );
  }

  Widget _buildWelcome() {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.data_object, size: 72, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text('JSON Viewer', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              'Open a .json file, create a new one or paste JSON.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                FilledButton.icon(
                  onPressed: _open,
                  icon: const Icon(Icons.folder_open_outlined),
                  label: const Text('Open file'),
                ),
                OutlinedButton.icon(
                  onPressed: _create,
                  icon: const Icon(Icons.note_add_outlined),
                  label: const Text('New'),
                ),
                OutlinedButton.icon(
                  onPressed: _pasteAsNew,
                  icon: const Icon(Icons.content_paste),
                  label: const Text('Paste JSON'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildViewer() {
    final parsed = _mode == ViewMode.split ? _parsed : _parseNow();
    final theme = Theme.of(context);
    final mono = TextStyle(
      fontFamily: 'monospace',
      fontSize: _fontSize,
      height: 1.4,
      color: theme.colorScheme.onSurface,
    );

    if (!parsed.isValid) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: theme.colorScheme.errorContainer,
            child: ListTile(
              leading: Icon(
                Icons.error_outline,
                color: theme.colorScheme.onErrorContainer,
              ),
              title: Text(
                'Invalid JSON',
                style: TextStyle(color: theme.colorScheme.onErrorContainer),
              ),
              subtitle: Text(
                '${parsed.error}',
                style: TextStyle(color: theme.colorScheme.onErrorContainer),
              ),
              trailing: TextButton(
                onPressed: _jumpToError,
                child: const Text('Go to error'),
              ),
            ),
          ),
          if (_mode == ViewMode.view) ...[
            const SizedBox(height: 12),
            SelectableText(_controller.text, style: mono),
          ],
        ],
      );
    }

    final value = parsed.value;
    if (_style == ViewStyle.text) {
      // Raw text: the document exactly as stored (or formatted on request,
      // without changing the document).
      final text = _formatRaw ? _prettyText(value) : _controller.text;
      final span = text.length > JsonEditingController.highlightLimit
          ? TextSpan(text: text, style: mono)
          : highlightJson(text, JsonColors.of(context), mono);
      return SingleChildScrollView(
        controller: _mode == ViewMode.split ? _viewerScroll : null,
        padding: const EdgeInsets.fromLTRB(0, 0, 0, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSummary(value),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SelectableText.rich(span),
            ),
          ],
        ),
      );
    }

    final split = _mode == ViewMode.split;
    if (_style == ViewStyle.readable) {
      return ReadableJsonView(
        value: value,
        fontSize: _fontSize,
        humanizeKeys: _humanizeKeys,
        header: _buildSummary(value, horizontalPadding: 4),
        scrollController: split ? _viewerScroll : null,
        onNodeTap: split ? _revealInEditor : null,
      );
    }

    return JsonTreeView(
      value: value,
      controller: _tree,
      fontSize: _fontSize,
      searchQuery: _searching ? _searchController.text : '',
      header: _buildSummary(value),
      scrollController: split ? _viewerScroll : null,
      onNodeTap: split ? _revealInEditor : null,
    );
  }

  /// Summary line (type, size) with the view style switcher.
  Widget _buildSummary(Object? value, {double horizontalPadding = 16}) {
    final theme = Theme.of(context);
    final parts = [
      typeName(value),
      describeContainer(value),
      formatBytes(_controller.text.length),
    ].where((s) => s.isNotEmpty);
    return Padding(
      padding: EdgeInsets.fromLTRB(horizontalPadding, 8, horizontalPadding, 8),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 8,
        children: [
          Text(
            parts.join(' · '),
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_style == ViewStyle.text) ...[
                FilterChip(
                  label: const Text('Formatted'),
                  selected: _formatRaw,
                  visualDensity: VisualDensity.compact,
                  onSelected: (v) => setState(() => _formatRaw = v),
                ),
                const SizedBox(width: 8),
              ],
              SegmentedButton<ViewStyle>(
                showSelectedIcon: false,
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                segments: const [
                  ButtonSegment(
                    value: ViewStyle.readable,
                    tooltip: 'Readable view',
                    icon: Icon(
                      Icons.chrome_reader_mode_outlined,
                      size: 18,
                      semanticLabel: 'Readable view',
                    ),
                  ),
                  ButtonSegment(
                    value: ViewStyle.tree,
                    tooltip: 'Tree view',
                    icon: Icon(
                      Icons.account_tree_outlined,
                      size: 18,
                      semanticLabel: 'Tree view',
                    ),
                  ),
                  ButtonSegment(
                    value: ViewStyle.text,
                    tooltip: 'Raw text',
                    icon: Icon(
                      Icons.data_object,
                      size: 18,
                      semanticLabel: 'Raw text',
                    ),
                  ),
                ],
                selected: {_style},
                onSelectionChanged: (s) => setState(() {
                  _style = s.first;
                  if (_style != ViewStyle.tree) _searching = false;
                }),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEditor() {
    if (_mode == ViewMode.edit && _formEditor) return _buildFormEditor();
    return JsonEditor(
      controller: _controller,
      focusNode: _editorFocus,
      fontSize: _fontSize,
      parseResult: _parsed,
      upToDate: _parsedText == _controller.text,
      onFormat: _format,
      onMinify: _minify,
      onErrorTap: _jumpToError,
      scrollController: _mode == ViewMode.split ? _editorScroll : null,
      onSwitchToForm: _mode == ViewMode.edit
          ? () => setState(() {
              _parseNow();
              _formEditor = true;
            })
          : null,
    );
  }

  Widget _buildFormEditor() {
    final theme = Theme.of(context);
    final parsed = _parseNow();
    final Widget body = parsed.isValid
        ? Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: JsonFormEditor(
                value: parsed.value,
                onEdit: _applyEdit,
                fontSize: _fontSize,
              ),
            ),
          )
        : ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                color: theme.colorScheme.errorContainer,
                child: ListTile(
                  leading: Icon(
                    Icons.error_outline,
                    color: theme.colorScheme.onErrorContainer,
                  ),
                  title: Text(
                    'The form needs valid JSON',
                    style: TextStyle(color: theme.colorScheme.onErrorContainer),
                  ),
                  subtitle: Text(
                    '${parsed.error}',
                    style: TextStyle(color: theme.colorScheme.onErrorContainer),
                  ),
                  trailing: TextButton(
                    onPressed: () {
                      setState(() => _formEditor = false);
                      _jumpToError();
                    },
                    child: const Text('Fix in text'),
                  ),
                ),
              ),
            ],
          );
    return Column(
      children: [
        Expanded(child: body),
        const Divider(height: 1),
        Material(
          color: theme.colorScheme.surfaceContainer,
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Undo',
                  icon: const Icon(Icons.undo, semanticLabel: 'Undo'),
                  onPressed: _undo.isEmpty ? null : _undoEdit,
                ),
                IconButton(
                  tooltip: 'Redo',
                  icon: const Icon(Icons.redo, semanticLabel: 'Redo'),
                  onPressed: _redo.isEmpty ? null : _redoEdit,
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => setState(() => _formEditor = false),
                  icon: const Icon(Icons.data_object),
                  label: const Text('Edit as text'),
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
