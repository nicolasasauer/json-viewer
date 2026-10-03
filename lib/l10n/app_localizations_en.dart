// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'JSON Viewer';

  @override
  String get tabView => 'View';

  @override
  String get tabForm => 'Form';

  @override
  String get tabText => 'Text';

  @override
  String get tabSplit => 'Split view';

  @override
  String get save => 'Save';

  @override
  String get saveAs => 'Save as…';

  @override
  String get saveAnyway => 'Save anyway';

  @override
  String get saveInvalidTitle => 'Save invalid JSON?';

  @override
  String get cancel => 'Cancel';

  @override
  String get discard => 'Discard';

  @override
  String get discardTitle => 'Discard changes?';

  @override
  String unsavedChanges(String name) {
    return '\"$name\" has unsaved changes.';
  }

  @override
  String get search => 'Search';

  @override
  String get searchHint => 'Search keys and values';

  @override
  String get closeSearch => 'Close search';

  @override
  String get smallerText => 'Smaller text';

  @override
  String get largerText => 'Larger text';

  @override
  String get openFile => 'Open file';

  @override
  String get lightTheme => 'Light theme';

  @override
  String get darkTheme => 'Dark theme';

  @override
  String get newDocument => 'New';

  @override
  String get pasteJson => 'Paste JSON';

  @override
  String get copyAll => 'Copy all';

  @override
  String get treeView => 'Tree view';

  @override
  String get friendlyKeyNames => 'Friendly key names';

  @override
  String get expandAll => 'Expand all';

  @override
  String get collapseAll => 'Collapse all';

  @override
  String get foldAll => 'Fold all';

  @override
  String get unfoldAll => 'Unfold all';

  @override
  String get syncScrolling => 'Sync scrolling';

  @override
  String get more => 'More';

  @override
  String get welcomeText =>
      'Open a .json file, create a new one or paste JSON.';

  @override
  String get invalidJson => 'Invalid JSON';

  @override
  String get goToError => 'Go to error';

  @override
  String get formNeedsValidJson => 'The form needs valid JSON';

  @override
  String get fixInTextTab => 'Fix in Text tab';

  @override
  String get undo => 'Undo';

  @override
  String get redo => 'Redo';

  @override
  String couldNotOpen(String error) {
    return 'Could not open file: $error';
  }

  @override
  String couldNotSave(String error) {
    return 'Could not save file: $error';
  }

  @override
  String couldNotApply(String error) {
    return 'Could not apply change: $error';
  }

  @override
  String saved(String name) {
    return 'Saved $name';
  }

  @override
  String cannotFormat(String error) {
    return 'Cannot format: $error';
  }

  @override
  String cannotMinify(String error) {
    return 'Cannot minify: $error';
  }

  @override
  String get documentCopied => 'Document copied';

  @override
  String get clipboardEmpty => 'The clipboard is empty';

  @override
  String get clipboardNoJson => 'The clipboard does not contain valid JSON';

  @override
  String get openAsText => 'Open as text';

  @override
  String get valueCopied => 'Value copied';

  @override
  String get pathCopied => 'Path copied';

  @override
  String get keyCopied => 'Key copied';

  @override
  String get copy => 'Copy';

  @override
  String get close => 'Close';

  @override
  String get copyValue => 'Copy value';

  @override
  String get copyPath => 'Copy path';

  @override
  String get copyKey => 'Copy key';

  @override
  String get fold => 'Fold';

  @override
  String get unfold => 'Unfold';

  @override
  String get tabKey => 'Tab';

  @override
  String get format => 'Format';

  @override
  String get minify => 'Minify';

  @override
  String get checking => 'Checking…';

  @override
  String validJson(String type) {
    return 'Valid JSON · $type';
  }

  @override
  String parseErrorAt(int line, int column, String message) {
    return 'Line $line, column $column: $message';
  }

  @override
  String get errEmptyDocument => 'Document is empty';

  @override
  String get errUnexpectedCharacter => 'Unexpected character';

  @override
  String get errUnexpectedEnd => 'Unexpected end of input';

  @override
  String get errUnterminatedString => 'Unterminated string';

  @override
  String keyCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count keys',
      one: '1 key',
    );
    return '$_temp0';
  }

  @override
  String itemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '1 item',
    );
    return '$_temp0';
  }

  @override
  String fieldCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fields',
      one: '1 field',
    );
    return '$_temp0';
  }

  @override
  String get typeObject => 'object';

  @override
  String get typeArray => 'array';

  @override
  String get typeString => 'string';

  @override
  String get typeBoolean => 'boolean';

  @override
  String get typeNumber => 'number';

  @override
  String get typeNull => 'null';

  @override
  String get kindText => 'Text';

  @override
  String get kindNumber => 'Number';

  @override
  String get kindBoolean => 'Yes/No';

  @override
  String get kindGroup => 'Group';

  @override
  String get kindList => 'List';

  @override
  String get kindEmpty => 'Empty (null)';

  @override
  String get yes => 'Yes';

  @override
  String get no => 'No';

  @override
  String get empty => 'Empty';

  @override
  String get emptyList => 'Empty list';

  @override
  String showAll(int count) {
    return 'Show all $count items';
  }

  @override
  String get singleValueDoc => 'This document is a single value.';

  @override
  String get makeGroup => 'Make it a group';

  @override
  String get makeList => 'Make it a list';

  @override
  String get emptyListHint => 'This list is empty. Add items below.';

  @override
  String get emptyDocHint =>
      'This document is empty. Add fields below, or start with a list instead.';

  @override
  String get useGroupInstead => 'Use a group instead';

  @override
  String get startWithList => 'Start with a list';

  @override
  String get addField => 'Add field';

  @override
  String get addItem => 'Add item';

  @override
  String get addItemSameFields => 'Add item (same fields)';

  @override
  String get addItemOtherType => 'Add item of another type';

  @override
  String get emptySetValue => 'Empty – set a value';

  @override
  String get fieldOptions => 'Field options';

  @override
  String get options => 'Options';

  @override
  String get rename => 'Rename';

  @override
  String get changeType => 'Change type';

  @override
  String get duplicate => 'Duplicate';

  @override
  String get moveUp => 'Move up';

  @override
  String get moveDown => 'Move down';

  @override
  String get delete => 'Delete';

  @override
  String get renameField => 'Rename field';

  @override
  String get changeTypeConfirmTitle => 'Change type?';

  @override
  String changeTypeConfirmBody(String content) {
    return 'The $content inside will be removed.';
  }

  @override
  String get change => 'Change';

  @override
  String get enterName => 'Enter a name';

  @override
  String nameExists(String name) {
    return '\"$name\" already exists';
  }

  @override
  String get name => 'Name';

  @override
  String get add => 'Add';

  @override
  String get notANumber => 'Not a number';

  @override
  String get textHint => 'Text';
}
