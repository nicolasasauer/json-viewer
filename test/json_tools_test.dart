import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:json_viewer/l10n/app_localizations.dart';
import 'package:json_viewer/src/json_highlighter.dart';
import 'package:json_viewer/src/json_locator.dart';
import 'package:json_viewer/src/json_tools.dart';
import 'package:json_viewer/src/json_tree_view.dart';
import 'package:json_viewer/src/readable_view.dart';

void main() {
  group('parseJson', () {
    test('parses valid JSON', () {
      final r = parseJson('{"a": [1, 2]}');
      expect(r.isValid, isTrue);
      expect(r.value, {
        'a': [1, 2],
      });
    });

    test('reports line and column of errors', () {
      final r = parseJson('{\n  "a": 1,\n  "b": ?\n}');
      expect(r.isValid, isFalse);
      expect(r.error!.line, 3);
      expect(r.error!.column, 8);
    });

    test('treats empty input as invalid', () {
      expect(parseJson('  \n').isValid, isFalse);
    });
  });

  test('childPath builds JSONPath-like paths', () {
    expect(childPath(rootPath, 'users'), r'$.users');
    expect(childPath(r'$.users', 0), r'$.users[0]');
    expect(childPath(r'$', 'first name'), r'$["first name"]');
    expect(childPath(r'$', 'a.b'), r'$["a.b"]');
  });

  test('format and minify round-trip', () {
    final value = parseJson('{"a":{"b":[true,null]}}').value;
    expect(minifyJson(value), '{"a":{"b":[true,null]}}');
    expect(
      prettyJson(value),
      '{\n  "a": {\n    "b": [\n      true,\n      null\n    ]\n  }\n}',
    );
  });

  test('tokenizer distinguishes keys from string values', () {
    const src = '{"k": "v", "n": -1.5e3, "t": true, "z": null}';
    final types = tokenizeJson(src)
        .where((t) => t.type != JsonTokenType.punctuation)
        .map((t) => t.type)
        .toList();
    expect(types, [
      JsonTokenType.key,
      JsonTokenType.string,
      JsonTokenType.key,
      JsonTokenType.number,
      JsonTokenType.key,
      JsonTokenType.boolean,
      JsonTokenType.key,
      JsonTokenType.nullValue,
    ]);
  });

  test('tokenizer survives unterminated strings', () {
    expect(() => tokenizeJson('{"abc'), returnsNormally);
    expect(() => tokenizeJson(r'"\'), returnsNormally);
  });

  group('tree', () {
    final root = parseJson('{"a": {"b": 1}, "list": [{"name": "x"}]}').value;

    test('flatten respects expanded state', () {
      final controller = JsonTreeController();
      expect(flattenJson(root, controller.isExpanded).length, 2);
      controller.expandAll(root);
      expect(
        flattenJson(root, controller.isExpanded).map((r) => r.path).toList(),
        [r'$.a', r'$.a.b', r'$.list', r'$.list[0]', r'$.list[0].name'],
      );
    });

    test('search finds keys and values and their ancestors', () {
      final r = searchJson(root, 'X');
      expect(r.matches, {r'$.list[0].name'});
      expect(r.ancestors, {r'$', r'$.list', r'$.list[0]'});
    });
  });

  test('humanizeKey', () {
    expect(humanizeKey('studyProgram'), 'Study program');
    expect(humanizeKey('target_ECTS'), 'Target ECTS');
    expect(humanizeKey('HTMLParser'), 'HTML parser');
    expect(humanizeKey('exported-at'), 'Exported at');
    expect(humanizeKey('_'), '_');
  });

  test('formatIsoDate', () async {
    await initializeDateFormatting('de');
    expect(formatIsoDate('2025-02-12', 'en'), 'Feb 12, 2025');
    expect(formatIsoDate('2025-02-12', 'de'), '12. Feb. 2025');
    expect(
      formatIsoDate('2026-10-03T14:10:00Z', 'de'),
      '3. Okt. 2026 14:10 UTC',
    );
    expect(formatIsoDate('WS 2024/25', 'en'), isNull);
  });

  test('formatBytes uses the decimal separator of the locale', () {
    expect(formatBytes(300), '300 B');
    expect(formatBytes(1331, 'en'), '1.3 KB');
    expect(formatBytes(1331, 'de'), '1,3 KB');
  });

  test('parse errors are translated', () {
    final error = parseJson('{"a": }').error!;
    expect(
      error.describe(lookupAppLocalizations(const Locale('en'))),
      'Line 1, column 7: Unexpected character',
    );
    expect(
      error.describe(lookupAppLocalizations(const Locale('de'))),
      'Zeile 1, Spalte 7: Unerwartetes Zeichen',
    );
  });

  test('locateJsonValues maps paths to source ranges', () {
    const src = '{\n  "a": [1, {"b c": "x\\"y"}],\n  "d": null\n}';
    final ranges = locateJsonValues(src);
    String at(String path) => ranges[path]!.textInside(src);
    expect(at(r'$'), src);
    expect(at(r'$.a[0]'), '1');
    expect(at(r'$.a[1]["b c"]'), r'"x\"y"');
    expect(at(r'$.d'), 'null');
  });
}
