import 'dart:convert';

import 'package:flutter/services.dart' show TextRange;

import 'json_tools.dart';

/// Finds where each value of a valid JSON document starts and ends in the
/// source text, keyed by the same paths as [childPath]. Used to jump from the
/// rendered view to the matching place in the editor.
Map<String, TextRange> locateJsonValues(String source) {
  final result = <String, TextRange>{};
  var i = 0;
  final n = source.length;

  void skipWhitespace() {
    while (i < n) {
      final c = source.codeUnitAt(i);
      if (c != 0x20 && c != 0x09 && c != 0x0A && c != 0x0D) break;
      i++;
    }
  }

  void skipString() {
    i++; // opening quote
    while (i < n) {
      final c = source.codeUnitAt(i);
      if (c == 0x5C) {
        i += 2;
        continue;
      }
      i++;
      if (c == 0x22) return;
    }
  }

  void value(String path) {
    skipWhitespace();
    final start = i;
    if (i >= n) return;
    final c = source.codeUnitAt(i);
    if (c == 0x7B) {
      // {
      i++;
      skipWhitespace();
      while (i < n && source.codeUnitAt(i) != 0x7D) {
        final keyStart = i;
        skipString();
        final key = jsonDecode(source.substring(keyStart, i)) as String;
        skipWhitespace();
        i++; // :
        value(childPath(path, key));
        skipWhitespace();
        if (i < n && source.codeUnitAt(i) == 0x2C) {
          i++;
          skipWhitespace();
        }
      }
      i++;
    } else if (c == 0x5B) {
      // [
      i++;
      skipWhitespace();
      var index = 0;
      while (i < n && source.codeUnitAt(i) != 0x5D) {
        value(childPath(path, index++));
        skipWhitespace();
        if (i < n && source.codeUnitAt(i) == 0x2C) {
          i++;
          skipWhitespace();
        }
      }
      i++;
    } else if (c == 0x22) {
      skipString();
    } else {
      while (i < n) {
        final d = source.codeUnitAt(i);
        if (d == 0x2C || d == 0x5D || d == 0x7D || d <= 0x20) break;
        i++;
      }
    }
    result[path] = TextRange(start: start, end: i > n ? n : i);
  }

  value(rootPath);
  return result;
}
