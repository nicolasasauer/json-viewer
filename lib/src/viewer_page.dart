import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'about.dart';
import 'file_bridge.dart';
import 'form_editor.dart';
import 'json_edit.dart';
import 'json_editor.dart';
import 'json_text_controller.dart';
import 'json_locator.dart';
import 'json_tools.dart';
import 'json_tree_view.dart';
import 'l10n.dart';
import 'readable_view.dart';

/// The tabs at the top. [split] is only offered on wide screens.
enum ViewMode { view, form, text, split }

/// How the view tab presents the document.
enum ViewStyle { readable, tree }

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

  double _fontSize = 14;
  bool _searching = false;
  bool _syncScroll = true;

  /// Whether the screen is wide enough for split view (set in build).
  bool _wide = false;

  /// The mode actually shown: split falls back to text on narrow screens.
  ViewMode get _shown =>
      _mode == ViewMode.split && !_wide ? ViewMode.text : _mode;

  /// Undo/redo for form edits (the text editor has its own history).
  final List<String> _undo = [];
  final List<String> _redo = [];

  /// The split-view pane the user last touched; only it drives the other one.
  ScrollController? _scrollLeader;

  JsonParseResult _parsed = parseJson('');
  String _parsedText = '';
  Timer? _parseTimer;

  AppLocalizations get _l => context.l10n;

  bool get _dirty => _hasDocument && _controller.text != _savedText;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
    _bridge.setOnFileOpened(
      (file) => _openWithConfirm(file),
      onError: (e) => _snack(_l.couldNotOpen('$e')),
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
      _snack(_l.couldNotOpen('$e'));
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
      _mode = ViewMode.form;
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
        text.trim().isEmpty ? _l.clipboardEmpty : _l.clipboardNoJson,
        action: text.trim().isEmpty
            ? null
            : SnackBarAction(
                label: _l.openAsText,
                onPressed: () async {
                  if (!await _confirmDiscard() || !mounted) return;
                  _newDocument(text: text, name: 'Pasted.json');
                  setState(() => _mode = ViewMode.text);
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
      _snack(_l.couldNotApply('$e'));
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

  // ---- Actions --------------------------------------------------------------

  Future<void> _open() async {
    if (!await _confirmDiscard()) return;
    try {
      final file = await _bridge.openDocument();
      if (file != null && mounted) _load(file);
    } catch (e) {
      _snack(_l.couldNotOpen(_errorText(e)));
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
          title: Text(_l.saveInvalidTitle),
          content: Text(parsed.error!.describe(_l)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(_l.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(_l.saveAnyway),
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
      _snack(_l.saved(_fileName));
      return true;
    } catch (e) {
      _snack(
        _l.couldNotSave(_errorText(e)),
        action: saveAs
            ? null
            : SnackBarAction(
                label: _l.saveAs,
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
        title: Text(_l.discardTitle),
        content: Text(_l.unsavedChanges(_fileName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, _DiscardChoice.cancel),
            child: Text(_l.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, _DiscardChoice.discard),
            child: Text(_l.discard),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, _DiscardChoice.save),
            child: Text(_l.save),
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
      if (mode == ViewMode.form || mode == ViewMode.text) _searching = false;
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
      _snack(_l.cannotFormat(parsed.error!.describe(_l)));
      return;
    }
    _replaceText(prettyJson(parsed.value));
  }

  void _minify() {
    final parsed = _parseNow();
    if (!parsed.isValid) {
      _snack(_l.cannotMinify(parsed.error!.describe(_l)));
      return;
    }
    _replaceText(minifyJson(parsed.value));
  }

  void _jumpToError() {
    final offset = _parsed.error?.offset;
    if (_shown != ViewMode.text && _shown != ViewMode.split) {
      _setMode(ViewMode.text);
    }
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

  Future<void> _openUrl(String url) async {
    try {
      if (!await _bridge.openUrl(url)) _snack(_l.noAppForLink(url));
    } catch (e) {
      _snack(_l.noAppForLink(url));
    }
  }

  void _changeFontSize(double delta) =>
      setState(() => _fontSize = (_fontSize + delta).clamp(10, 28));

  void _copyAll() {
    Clipboard.setData(ClipboardData(text: _controller.text));
    _snack(_l.documentCopied);
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
    if (_mode != ViewMode.view) {
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
    _wide = wide;
    return PopScope(
      canPop: !_dirty && !_searching && _mode == ViewMode.view,
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
        (_shown == ViewMode.view || _shown == ViewMode.split) &&
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
              _hasDocument ? _fileName : _l.appTitle,
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
            segments: [
              ButtonSegment(
                value: ViewMode.view,
                icon: Icon(
                  Icons.visibility_outlined,
                  semanticLabel: _l.tabView,
                ),
                tooltip: _l.tabView,
              ),
              ButtonSegment(
                value: ViewMode.form,
                icon: Icon(Icons.edit_outlined, semanticLabel: _l.tabForm),
                tooltip: _l.tabForm,
              ),
              ButtonSegment(
                value: ViewMode.text,
                icon: Icon(Icons.code, semanticLabel: _l.tabText),
                tooltip: _l.tabText,
              ),
              if (wide)
                ButtonSegment(
                  value: ViewMode.split,
                  icon: Icon(
                    Icons.vertical_split_outlined,
                    semanticLabel: _l.tabSplit,
                  ),
                  tooltip: _l.tabSplit,
                ),
            ],
            selected: {_shown},
            onSelectionChanged: (s) => _setMode(s.first),
          ),
        const SizedBox(width: 4),
        if (_hasDocument)
          IconButton(
            tooltip: _l.save,
            icon: const Icon(Icons.save_outlined),
            onPressed: canSave ? _save : null,
          ),
        if (treeAvailable && wide)
          IconButton(
            tooltip: _l.search,
            icon: Icon(Icons.search, semanticLabel: _l.search),
            onPressed: () => setState(() => _searching = !_searching),
          ),
        if (wide) ...[
          IconButton(
            tooltip: _l.smallerText,
            icon: const Text('A−', style: TextStyle(fontSize: 18)),
            onPressed: () => _changeFontSize(-1),
          ),
          IconButton(
            tooltip: _l.largerText,
            icon: const Text('A+', style: TextStyle(fontSize: 18)),
            onPressed: () => _changeFontSize(1),
          ),
          IconButton(
            tooltip: _l.openFile,
            icon: const Icon(Icons.folder_open_outlined),
            onPressed: _open,
          ),
          IconButton(
            tooltip: dark ? _l.lightTheme : _l.darkTheme,
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
        child: ListTile(
          leading: const Icon(Icons.note_add_outlined),
          title: Text(_l.newDocument),
        ),
      ),
      PopupMenuItem(
        value: _pasteAsNew,
        child: ListTile(
          leading: const Icon(Icons.content_paste),
          title: Text(_l.pasteJson),
        ),
      ),
      if (!wide)
        PopupMenuItem(
          value: _open,
          child: ListTile(
            leading: const Icon(Icons.folder_open_outlined),
            title: Text(_l.openFile),
          ),
        ),
      if (_hasDocument)
        PopupMenuItem(
          value: () => _save(saveAs: true),
          child: ListTile(
            leading: const Icon(Icons.save_as_outlined),
            title: Text(_l.saveAs),
          ),
        ),
      if (_hasDocument)
        PopupMenuItem(
          value: _copyAll,
          child: ListTile(
            leading: const Icon(Icons.content_copy),
            title: Text(_l.copyAll),
          ),
        ),
      if (_hasDocument) const PopupMenuDivider(),
      if (valid && (_shown == ViewMode.view || _shown == ViewMode.split)) ...[
        CheckedPopupMenuItem(
          value: () => setState(() {
            _style = _style == ViewStyle.tree
                ? ViewStyle.readable
                : ViewStyle.tree;
            _searching = false;
          }),
          checked: _style == ViewStyle.tree,
          child: Text(_l.treeView),
        ),
        if (_style == ViewStyle.readable)
          CheckedPopupMenuItem(
            value: () => setState(() => _humanizeKeys = !_humanizeKeys),
            checked: _humanizeKeys,
            child: Text(_l.friendlyKeyNames),
          ),
      ],
      if (treeAvailable) ...[
        if (!wide)
          PopupMenuItem(
            value: () => setState(() => _searching = true),
            child: ListTile(
              leading: const Icon(Icons.search),
              title: Text(_l.search),
            ),
          ),
        PopupMenuItem(
          value: () => _tree.expandAll(_parsed.value),
          child: ListTile(
            leading: const Icon(Icons.unfold_more),
            title: Text(_l.expandAll),
          ),
        ),
        PopupMenuItem(
          value: _tree.collapseAll,
          child: ListTile(
            leading: const Icon(Icons.unfold_less),
            title: Text(_l.collapseAll),
          ),
        ),
      ],
      if (_hasDocument &&
          (_shown == ViewMode.text || _shown == ViewMode.split)) ...[
        PopupMenuItem(
          value: _controller.foldAll,
          child: ListTile(
            leading: const Icon(Icons.unfold_less),
            title: Text(_l.foldAll),
          ),
        ),
        PopupMenuItem(
          value: _controller.unfoldAll,
          child: ListTile(
            leading: const Icon(Icons.unfold_more),
            title: Text(_l.unfoldAll),
          ),
        ),
      ],
      if (_shown == ViewMode.split)
        CheckedPopupMenuItem(
          value: () => setState(() => _syncScroll = !_syncScroll),
          checked: _syncScroll,
          child: Text(_l.syncScrolling),
        ),
      if (!wide) ...[
        const PopupMenuDivider(),
        PopupMenuItem(
          value: () => _changeFontSize(-1),
          child: ListTile(
            leading: const Icon(Icons.text_decrease),
            title: Text(_l.smallerText),
          ),
        ),
        PopupMenuItem(
          value: () => _changeFontSize(1),
          child: ListTile(
            leading: const Icon(Icons.text_increase),
            title: Text(_l.largerText),
          ),
        ),
        PopupMenuItem(
          value: widget.onToggleTheme,
          child: ListTile(
            leading: Icon(
              dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
            ),
            title: Text(dark ? _l.lightTheme : _l.darkTheme),
          ),
        ),
      ],
    ];
    items.addAll([
      const PopupMenuDivider(),
      PopupMenuItem(
        value: () => showAboutAppDialog(context, onOpenUrl: _openUrl),
        child: ListTile(
          leading: const Icon(Icons.info_outline),
          title: Text(_l.about),
        ),
      ),
    ]);
    return PopupMenuButton<VoidCallback>(
      tooltip: _l.more,
      icon: Icon(Icons.more_vert, semanticLabel: _l.more),
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
            hintText: _l.searchHint,
            prefixIcon: const Icon(Icons.search),
            suffixIcon: IconButton(
              tooltip: _l.closeSearch,
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
    switch (_shown) {
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
      case ViewMode.form:
        return _buildFormEditor();
      case ViewMode.text:
        return _buildTextEditor();
      case ViewMode.split:
        return Row(
          children: [
            Expanded(
              child: _syncedPane(
                _editorScroll,
                _viewerScroll,
                _buildTextEditor(),
              ),
            ),
            const VerticalDivider(width: 1),
            Expanded(
              child: _syncedPane(_viewerScroll, _editorScroll, _buildViewer()),
            ),
          ],
        );
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
            Text(_l.appTitle, style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              _l.welcomeText,
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
                  label: Text(_l.openFile),
                ),
                OutlinedButton.icon(
                  onPressed: _create,
                  icon: const Icon(Icons.note_add_outlined),
                  label: Text(_l.newDocument),
                ),
                OutlinedButton.icon(
                  onPressed: _pasteAsNew,
                  icon: const Icon(Icons.content_paste),
                  label: Text(_l.pasteJson),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildViewer() {
    final parsed = _shown == ViewMode.split ? _parsed : _parseNow();
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
                _l.invalidJson,
                style: TextStyle(color: theme.colorScheme.onErrorContainer),
              ),
              subtitle: Text(
                parsed.error!.describe(_l),
                style: TextStyle(color: theme.colorScheme.onErrorContainer),
              ),
              trailing: TextButton(
                onPressed: _jumpToError,
                child: Text(_l.goToError),
              ),
            ),
          ),
          if (_shown == ViewMode.view) ...[
            const SizedBox(height: 12),
            SelectableText(_controller.text, style: mono),
          ],
        ],
      );
    }

    final value = parsed.value;
    final split = _shown == ViewMode.split;
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

  Widget _buildSummary(Object? value, {double horizontalPadding = 16}) {
    final theme = Theme.of(context);
    final parts = [
      typeName(value, _l),
      describeContainer(value, _l),
      formatBytes(_controller.text.length),
    ].where((s) => s.isNotEmpty);
    return Padding(
      padding: EdgeInsets.fromLTRB(horizontalPadding, 12, horizontalPadding, 8),
      child: Text(
        parts.join(' · '),
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _buildTextEditor() {
    return JsonEditor(
      controller: _controller,
      focusNode: _editorFocus,
      fontSize: _fontSize,
      parseResult: _parsed,
      upToDate: _parsedText == _controller.text,
      onFormat: _format,
      onMinify: _minify,
      onErrorTap: _jumpToError,
      scrollController: _shown == ViewMode.split ? _editorScroll : null,
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
                    _l.formNeedsValidJson,
                    style: TextStyle(color: theme.colorScheme.onErrorContainer),
                  ),
                  subtitle: Text(
                    parsed.error!.describe(_l),
                    style: TextStyle(color: theme.colorScheme.onErrorContainer),
                  ),
                  trailing: TextButton(
                    onPressed: _jumpToError,
                    child: Text(_l.fixInTextTab),
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
                  tooltip: _l.undo,
                  icon: Icon(Icons.undo, semanticLabel: _l.undo),
                  onPressed: _undo.isEmpty ? null : _undoEdit,
                ),
                IconButton(
                  tooltip: _l.redo,
                  icon: Icon(Icons.redo, semanticLabel: _l.redo),
                  onPressed: _redo.isEmpty ? null : _redoEdit,
                ),
                const Spacer(),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
