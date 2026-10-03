// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appTitle => 'JSON Viewer';

  @override
  String get tabView => 'Ansicht';

  @override
  String get tabForm => 'Formular';

  @override
  String get tabText => 'Text';

  @override
  String get tabSplit => 'Geteilte Ansicht';

  @override
  String get save => 'Speichern';

  @override
  String get saveAs => 'Speichern unter…';

  @override
  String get saveAnyway => 'Trotzdem speichern';

  @override
  String get saveInvalidTitle => 'Ungültiges JSON speichern?';

  @override
  String get cancel => 'Abbrechen';

  @override
  String get discard => 'Verwerfen';

  @override
  String get discardTitle => 'Änderungen verwerfen?';

  @override
  String unsavedChanges(String name) {
    return '„$name“ hat ungespeicherte Änderungen.';
  }

  @override
  String get search => 'Suchen';

  @override
  String get searchHint => 'Schlüssel und Werte durchsuchen';

  @override
  String get closeSearch => 'Suche schließen';

  @override
  String get smallerText => 'Kleinere Schrift';

  @override
  String get largerText => 'Größere Schrift';

  @override
  String get openFile => 'Datei öffnen';

  @override
  String get lightTheme => 'Helles Design';

  @override
  String get darkTheme => 'Dunkles Design';

  @override
  String get newDocument => 'Neu';

  @override
  String get pasteJson => 'JSON einfügen';

  @override
  String get copyAll => 'Alles kopieren';

  @override
  String get treeView => 'Baumansicht';

  @override
  String get friendlyKeyNames => 'Lesbare Feldnamen';

  @override
  String get expandAll => 'Alle aufklappen';

  @override
  String get collapseAll => 'Alle zuklappen';

  @override
  String get foldAll => 'Alle Blöcke einklappen';

  @override
  String get unfoldAll => 'Alle Blöcke ausklappen';

  @override
  String get syncScrolling => 'Synchron scrollen';

  @override
  String get more => 'Mehr';

  @override
  String get welcomeText =>
      'Öffne eine .json-Datei, erstelle eine neue oder füge JSON ein.';

  @override
  String get invalidJson => 'Ungültiges JSON';

  @override
  String get goToError => 'Zum Fehler';

  @override
  String get formNeedsValidJson => 'Das Formular braucht gültiges JSON';

  @override
  String get fixInTextTab => 'Im Text-Tab beheben';

  @override
  String get undo => 'Rückgängig';

  @override
  String get redo => 'Wiederholen';

  @override
  String couldNotOpen(String error) {
    return 'Datei konnte nicht geöffnet werden: $error';
  }

  @override
  String couldNotSave(String error) {
    return 'Datei konnte nicht gespeichert werden: $error';
  }

  @override
  String couldNotApply(String error) {
    return 'Änderung konnte nicht übernommen werden: $error';
  }

  @override
  String saved(String name) {
    return '$name gespeichert';
  }

  @override
  String cannotFormat(String error) {
    return 'Formatieren nicht möglich: $error';
  }

  @override
  String cannotMinify(String error) {
    return 'Minimieren nicht möglich: $error';
  }

  @override
  String get documentCopied => 'Dokument kopiert';

  @override
  String get clipboardEmpty => 'Die Zwischenablage ist leer';

  @override
  String get clipboardNoJson => 'Die Zwischenablage enthält kein gültiges JSON';

  @override
  String get openAsText => 'Als Text öffnen';

  @override
  String get valueCopied => 'Wert kopiert';

  @override
  String get pathCopied => 'Pfad kopiert';

  @override
  String get keyCopied => 'Schlüssel kopiert';

  @override
  String get copy => 'Kopieren';

  @override
  String get close => 'Schließen';

  @override
  String get copyValue => 'Wert kopieren';

  @override
  String get copyPath => 'Pfad kopieren';

  @override
  String get copyKey => 'Schlüssel kopieren';

  @override
  String get fold => 'Einklappen';

  @override
  String get unfold => 'Ausklappen';

  @override
  String get tabKey => 'Tab';

  @override
  String get format => 'Formatieren';

  @override
  String get minify => 'Minimieren';

  @override
  String get checking => 'Prüfe…';

  @override
  String validJson(String type) {
    return 'Gültiges JSON · $type';
  }

  @override
  String parseErrorAt(int line, int column, String message) {
    return 'Zeile $line, Spalte $column: $message';
  }

  @override
  String get errEmptyDocument => 'Das Dokument ist leer';

  @override
  String get errUnexpectedCharacter => 'Unerwartetes Zeichen';

  @override
  String get errUnexpectedEnd => 'Unerwartetes Ende';

  @override
  String get errUnterminatedString => 'Text ist nicht abgeschlossen';

  @override
  String keyCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Schlüssel',
      one: '1 Schlüssel',
    );
    return '$_temp0';
  }

  @override
  String itemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Einträge',
      one: '1 Eintrag',
    );
    return '$_temp0';
  }

  @override
  String fieldCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Felder',
      one: '1 Feld',
    );
    return '$_temp0';
  }

  @override
  String get typeObject => 'Objekt';

  @override
  String get typeArray => 'Liste';

  @override
  String get typeString => 'Text';

  @override
  String get typeBoolean => 'Wahrheitswert';

  @override
  String get typeNumber => 'Zahl';

  @override
  String get typeNull => 'null';

  @override
  String get kindText => 'Text';

  @override
  String get kindNumber => 'Zahl';

  @override
  String get kindBoolean => 'Ja/Nein';

  @override
  String get kindGroup => 'Gruppe';

  @override
  String get kindList => 'Liste';

  @override
  String get kindEmpty => 'Leer (null)';

  @override
  String get yes => 'Ja';

  @override
  String get no => 'Nein';

  @override
  String get empty => 'Leer';

  @override
  String get emptyList => 'Leere Liste';

  @override
  String showAll(int count) {
    return 'Alle $count Einträge anzeigen';
  }

  @override
  String get singleValueDoc => 'Dieses Dokument ist ein einzelner Wert.';

  @override
  String get makeGroup => 'In Gruppe umwandeln';

  @override
  String get makeList => 'In Liste umwandeln';

  @override
  String get emptyListHint =>
      'Diese Liste ist leer. Füge unten Einträge hinzu.';

  @override
  String get emptyDocHint =>
      'Dieses Dokument ist leer. Füge unten Felder hinzu oder beginne stattdessen mit einer Liste.';

  @override
  String get useGroupInstead => 'Stattdessen eine Gruppe';

  @override
  String get startWithList => 'Mit einer Liste beginnen';

  @override
  String get addField => 'Feld hinzufügen';

  @override
  String get addItem => 'Eintrag hinzufügen';

  @override
  String get addItemSameFields => 'Eintrag hinzufügen (gleiche Felder)';

  @override
  String get addItemOtherType => 'Eintrag anderen Typs hinzufügen';

  @override
  String get emptySetValue => 'Leer – Wert festlegen';

  @override
  String get fieldOptions => 'Feldoptionen';

  @override
  String get options => 'Optionen';

  @override
  String get rename => 'Umbenennen';

  @override
  String get changeType => 'Typ ändern';

  @override
  String get duplicate => 'Duplizieren';

  @override
  String get moveUp => 'Nach oben';

  @override
  String get moveDown => 'Nach unten';

  @override
  String get delete => 'Löschen';

  @override
  String get renameField => 'Feld umbenennen';

  @override
  String get changeTypeConfirmTitle => 'Typ ändern?';

  @override
  String changeTypeConfirmBody(String content) {
    return 'Der Inhalt ($content) wird entfernt.';
  }

  @override
  String get change => 'Ändern';

  @override
  String get enterName => 'Bitte einen Namen eingeben';

  @override
  String nameExists(String name) {
    return '„$name“ existiert bereits';
  }

  @override
  String get name => 'Name';

  @override
  String get add => 'Hinzufügen';

  @override
  String get notANumber => 'Keine Zahl';

  @override
  String get textHint => 'Text';
}
