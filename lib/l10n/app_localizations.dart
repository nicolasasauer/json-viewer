import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'JSON Viewer'**
  String get appTitle;

  /// No description provided for @tabView.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get tabView;

  /// No description provided for @tabForm.
  ///
  /// In en, this message translates to:
  /// **'Form'**
  String get tabForm;

  /// No description provided for @tabText.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get tabText;

  /// No description provided for @tabSplit.
  ///
  /// In en, this message translates to:
  /// **'Split view'**
  String get tabSplit;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @saveAs.
  ///
  /// In en, this message translates to:
  /// **'Save as…'**
  String get saveAs;

  /// No description provided for @saveAnyway.
  ///
  /// In en, this message translates to:
  /// **'Save anyway'**
  String get saveAnyway;

  /// No description provided for @saveInvalidTitle.
  ///
  /// In en, this message translates to:
  /// **'Save invalid JSON?'**
  String get saveInvalidTitle;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @discard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get discard;

  /// No description provided for @discardTitle.
  ///
  /// In en, this message translates to:
  /// **'Discard changes?'**
  String get discardTitle;

  /// No description provided for @unsavedChanges.
  ///
  /// In en, this message translates to:
  /// **'\"{name}\" has unsaved changes.'**
  String unsavedChanges(String name);

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search keys and values'**
  String get searchHint;

  /// No description provided for @closeSearch.
  ///
  /// In en, this message translates to:
  /// **'Close search'**
  String get closeSearch;

  /// No description provided for @smallerText.
  ///
  /// In en, this message translates to:
  /// **'Smaller text'**
  String get smallerText;

  /// No description provided for @largerText.
  ///
  /// In en, this message translates to:
  /// **'Larger text'**
  String get largerText;

  /// No description provided for @openFile.
  ///
  /// In en, this message translates to:
  /// **'Open file'**
  String get openFile;

  /// No description provided for @lightTheme.
  ///
  /// In en, this message translates to:
  /// **'Light theme'**
  String get lightTheme;

  /// No description provided for @darkTheme.
  ///
  /// In en, this message translates to:
  /// **'Dark theme'**
  String get darkTheme;

  /// No description provided for @newDocument.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get newDocument;

  /// No description provided for @pasteJson.
  ///
  /// In en, this message translates to:
  /// **'Paste JSON'**
  String get pasteJson;

  /// No description provided for @copyAll.
  ///
  /// In en, this message translates to:
  /// **'Copy all'**
  String get copyAll;

  /// No description provided for @treeView.
  ///
  /// In en, this message translates to:
  /// **'Tree view'**
  String get treeView;

  /// No description provided for @friendlyKeyNames.
  ///
  /// In en, this message translates to:
  /// **'Friendly key names'**
  String get friendlyKeyNames;

  /// No description provided for @expandAll.
  ///
  /// In en, this message translates to:
  /// **'Expand all'**
  String get expandAll;

  /// No description provided for @collapseAll.
  ///
  /// In en, this message translates to:
  /// **'Collapse all'**
  String get collapseAll;

  /// No description provided for @foldAll.
  ///
  /// In en, this message translates to:
  /// **'Fold all'**
  String get foldAll;

  /// No description provided for @unfoldAll.
  ///
  /// In en, this message translates to:
  /// **'Unfold all'**
  String get unfoldAll;

  /// No description provided for @syncScrolling.
  ///
  /// In en, this message translates to:
  /// **'Sync scrolling'**
  String get syncScrolling;

  /// No description provided for @more.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get more;

  /// No description provided for @welcomeText.
  ///
  /// In en, this message translates to:
  /// **'Open a .json file, create a new one or paste JSON.'**
  String get welcomeText;

  /// No description provided for @invalidJson.
  ///
  /// In en, this message translates to:
  /// **'Invalid JSON'**
  String get invalidJson;

  /// No description provided for @goToError.
  ///
  /// In en, this message translates to:
  /// **'Go to error'**
  String get goToError;

  /// No description provided for @formNeedsValidJson.
  ///
  /// In en, this message translates to:
  /// **'The form needs valid JSON'**
  String get formNeedsValidJson;

  /// No description provided for @fixInTextTab.
  ///
  /// In en, this message translates to:
  /// **'Fix in Text tab'**
  String get fixInTextTab;

  /// No description provided for @undo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undo;

  /// No description provided for @redo.
  ///
  /// In en, this message translates to:
  /// **'Redo'**
  String get redo;

  /// No description provided for @couldNotOpen.
  ///
  /// In en, this message translates to:
  /// **'Could not open file: {error}'**
  String couldNotOpen(String error);

  /// No description provided for @couldNotSave.
  ///
  /// In en, this message translates to:
  /// **'Could not save file: {error}'**
  String couldNotSave(String error);

  /// No description provided for @couldNotApply.
  ///
  /// In en, this message translates to:
  /// **'Could not apply change: {error}'**
  String couldNotApply(String error);

  /// No description provided for @saved.
  ///
  /// In en, this message translates to:
  /// **'Saved {name}'**
  String saved(String name);

  /// No description provided for @cannotFormat.
  ///
  /// In en, this message translates to:
  /// **'Cannot format: {error}'**
  String cannotFormat(String error);

  /// No description provided for @cannotMinify.
  ///
  /// In en, this message translates to:
  /// **'Cannot minify: {error}'**
  String cannotMinify(String error);

  /// No description provided for @documentCopied.
  ///
  /// In en, this message translates to:
  /// **'Document copied'**
  String get documentCopied;

  /// No description provided for @clipboardEmpty.
  ///
  /// In en, this message translates to:
  /// **'The clipboard is empty'**
  String get clipboardEmpty;

  /// No description provided for @clipboardNoJson.
  ///
  /// In en, this message translates to:
  /// **'The clipboard does not contain valid JSON'**
  String get clipboardNoJson;

  /// No description provided for @openAsText.
  ///
  /// In en, this message translates to:
  /// **'Open as text'**
  String get openAsText;

  /// No description provided for @valueCopied.
  ///
  /// In en, this message translates to:
  /// **'Value copied'**
  String get valueCopied;

  /// No description provided for @pathCopied.
  ///
  /// In en, this message translates to:
  /// **'Path copied'**
  String get pathCopied;

  /// No description provided for @keyCopied.
  ///
  /// In en, this message translates to:
  /// **'Key copied'**
  String get keyCopied;

  /// No description provided for @copy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copy;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @copyValue.
  ///
  /// In en, this message translates to:
  /// **'Copy value'**
  String get copyValue;

  /// No description provided for @copyPath.
  ///
  /// In en, this message translates to:
  /// **'Copy path'**
  String get copyPath;

  /// No description provided for @copyKey.
  ///
  /// In en, this message translates to:
  /// **'Copy key'**
  String get copyKey;

  /// No description provided for @fold.
  ///
  /// In en, this message translates to:
  /// **'Fold'**
  String get fold;

  /// No description provided for @unfold.
  ///
  /// In en, this message translates to:
  /// **'Unfold'**
  String get unfold;

  /// No description provided for @tabKey.
  ///
  /// In en, this message translates to:
  /// **'Tab'**
  String get tabKey;

  /// No description provided for @format.
  ///
  /// In en, this message translates to:
  /// **'Format'**
  String get format;

  /// No description provided for @minify.
  ///
  /// In en, this message translates to:
  /// **'Minify'**
  String get minify;

  /// No description provided for @checking.
  ///
  /// In en, this message translates to:
  /// **'Checking…'**
  String get checking;

  /// No description provided for @validJson.
  ///
  /// In en, this message translates to:
  /// **'Valid JSON · {type}'**
  String validJson(String type);

  /// No description provided for @parseErrorAt.
  ///
  /// In en, this message translates to:
  /// **'Line {line}, column {column}: {message}'**
  String parseErrorAt(int line, int column, String message);

  /// No description provided for @errEmptyDocument.
  ///
  /// In en, this message translates to:
  /// **'Document is empty'**
  String get errEmptyDocument;

  /// No description provided for @errUnexpectedCharacter.
  ///
  /// In en, this message translates to:
  /// **'Unexpected character'**
  String get errUnexpectedCharacter;

  /// No description provided for @errUnexpectedEnd.
  ///
  /// In en, this message translates to:
  /// **'Unexpected end of input'**
  String get errUnexpectedEnd;

  /// No description provided for @errUnterminatedString.
  ///
  /// In en, this message translates to:
  /// **'Unterminated string'**
  String get errUnterminatedString;

  /// No description provided for @keyCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 key} other{{count} keys}}'**
  String keyCount(int count);

  /// No description provided for @itemCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 item} other{{count} items}}'**
  String itemCount(int count);

  /// No description provided for @fieldCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 field} other{{count} fields}}'**
  String fieldCount(int count);

  /// No description provided for @typeObject.
  ///
  /// In en, this message translates to:
  /// **'object'**
  String get typeObject;

  /// No description provided for @typeArray.
  ///
  /// In en, this message translates to:
  /// **'array'**
  String get typeArray;

  /// No description provided for @typeString.
  ///
  /// In en, this message translates to:
  /// **'string'**
  String get typeString;

  /// No description provided for @typeBoolean.
  ///
  /// In en, this message translates to:
  /// **'boolean'**
  String get typeBoolean;

  /// No description provided for @typeNumber.
  ///
  /// In en, this message translates to:
  /// **'number'**
  String get typeNumber;

  /// No description provided for @typeNull.
  ///
  /// In en, this message translates to:
  /// **'null'**
  String get typeNull;

  /// No description provided for @kindText.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get kindText;

  /// No description provided for @kindNumber.
  ///
  /// In en, this message translates to:
  /// **'Number'**
  String get kindNumber;

  /// No description provided for @kindBoolean.
  ///
  /// In en, this message translates to:
  /// **'Yes/No'**
  String get kindBoolean;

  /// No description provided for @kindGroup.
  ///
  /// In en, this message translates to:
  /// **'Group'**
  String get kindGroup;

  /// No description provided for @kindList.
  ///
  /// In en, this message translates to:
  /// **'List'**
  String get kindList;

  /// No description provided for @kindEmpty.
  ///
  /// In en, this message translates to:
  /// **'Empty (null)'**
  String get kindEmpty;

  /// No description provided for @yes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get yes;

  /// No description provided for @no.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get no;

  /// No description provided for @empty.
  ///
  /// In en, this message translates to:
  /// **'Empty'**
  String get empty;

  /// No description provided for @emptyList.
  ///
  /// In en, this message translates to:
  /// **'Empty list'**
  String get emptyList;

  /// No description provided for @showAll.
  ///
  /// In en, this message translates to:
  /// **'Show all {count} items'**
  String showAll(int count);

  /// No description provided for @singleValueDoc.
  ///
  /// In en, this message translates to:
  /// **'This document is a single value.'**
  String get singleValueDoc;

  /// No description provided for @makeGroup.
  ///
  /// In en, this message translates to:
  /// **'Make it a group'**
  String get makeGroup;

  /// No description provided for @makeList.
  ///
  /// In en, this message translates to:
  /// **'Make it a list'**
  String get makeList;

  /// No description provided for @emptyListHint.
  ///
  /// In en, this message translates to:
  /// **'This list is empty. Add items below.'**
  String get emptyListHint;

  /// No description provided for @emptyDocHint.
  ///
  /// In en, this message translates to:
  /// **'This document is empty. Add fields below, or start with a list instead.'**
  String get emptyDocHint;

  /// No description provided for @useGroupInstead.
  ///
  /// In en, this message translates to:
  /// **'Use a group instead'**
  String get useGroupInstead;

  /// No description provided for @startWithList.
  ///
  /// In en, this message translates to:
  /// **'Start with a list'**
  String get startWithList;

  /// No description provided for @addField.
  ///
  /// In en, this message translates to:
  /// **'Add field'**
  String get addField;

  /// No description provided for @addItem.
  ///
  /// In en, this message translates to:
  /// **'Add item'**
  String get addItem;

  /// No description provided for @addItemSameFields.
  ///
  /// In en, this message translates to:
  /// **'Add item (same fields)'**
  String get addItemSameFields;

  /// No description provided for @addItemOtherType.
  ///
  /// In en, this message translates to:
  /// **'Add item of another type'**
  String get addItemOtherType;

  /// No description provided for @emptySetValue.
  ///
  /// In en, this message translates to:
  /// **'Empty – set a value'**
  String get emptySetValue;

  /// No description provided for @fieldOptions.
  ///
  /// In en, this message translates to:
  /// **'Field options'**
  String get fieldOptions;

  /// No description provided for @options.
  ///
  /// In en, this message translates to:
  /// **'Options'**
  String get options;

  /// No description provided for @rename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get rename;

  /// No description provided for @changeType.
  ///
  /// In en, this message translates to:
  /// **'Change type'**
  String get changeType;

  /// No description provided for @duplicate.
  ///
  /// In en, this message translates to:
  /// **'Duplicate'**
  String get duplicate;

  /// No description provided for @moveUp.
  ///
  /// In en, this message translates to:
  /// **'Move up'**
  String get moveUp;

  /// No description provided for @moveDown.
  ///
  /// In en, this message translates to:
  /// **'Move down'**
  String get moveDown;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @renameField.
  ///
  /// In en, this message translates to:
  /// **'Rename field'**
  String get renameField;

  /// No description provided for @changeTypeConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Change type?'**
  String get changeTypeConfirmTitle;

  /// No description provided for @changeTypeConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'The {content} inside will be removed.'**
  String changeTypeConfirmBody(String content);

  /// No description provided for @change.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get change;

  /// No description provided for @enterName.
  ///
  /// In en, this message translates to:
  /// **'Enter a name'**
  String get enterName;

  /// No description provided for @nameExists.
  ///
  /// In en, this message translates to:
  /// **'\"{name}\" already exists'**
  String nameExists(String name);

  /// No description provided for @name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get name;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @notANumber.
  ///
  /// In en, this message translates to:
  /// **'Not a number'**
  String get notANumber;

  /// No description provided for @textHint.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get textHint;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @aboutText.
  ///
  /// In en, this message translates to:
  /// **'A simple app for reading and editing JSON files. No account, no ads, no tracking: your files never leave your device.'**
  String get aboutText;

  /// No description provided for @version.
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String version(String version);

  /// No description provided for @sourceCode.
  ///
  /// In en, this message translates to:
  /// **'Source code'**
  String get sourceCode;

  /// No description provided for @licenses.
  ///
  /// In en, this message translates to:
  /// **'Open-source licenses'**
  String get licenses;

  /// No description provided for @noAppForLink.
  ///
  /// In en, this message translates to:
  /// **'No app can open {url}'**
  String noAppForLink(String url);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['de', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
