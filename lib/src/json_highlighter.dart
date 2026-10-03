import 'package:flutter/material.dart';

/// Colors for JSON tokens, tuned for light and dark themes.
class JsonColors {
  const JsonColors({
    required this.key,
    required this.string,
    required this.number,
    required this.boolean,
    required this.nullValue,
    required this.punctuation,
  });

  factory JsonColors.of(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return JsonColors(
      key: dark ? const Color(0xFF9CDCFE) : const Color(0xFF0451A5),
      string: dark ? const Color(0xFFCE9178) : const Color(0xFFA31515),
      number: dark ? const Color(0xFFB5CEA8) : const Color(0xFF098658),
      boolean: dark ? const Color(0xFF569CD6) : const Color(0xFF0000FF),
      nullValue: dark ? const Color(0xFFC586C0) : const Color(0xFFAF00DB),
      punctuation: theme.colorScheme.onSurfaceVariant,
    );
  }

  final Color key;
  final Color string;
  final Color number;
  final Color boolean;
  final Color nullValue;
  final Color punctuation;
}

enum JsonTokenType {
  key,
  string,
  number,
  boolean,
  nullValue,
  punctuation,
  other,
}

class JsonToken {
  const JsonToken(this.type, this.start, this.end);

  final JsonTokenType type;
  final int start;
  final int end;
}

/// Lenient tokenizer used for highlighting. It never throws, so it also works
/// for invalid or half-typed JSON.
List<JsonToken> tokenizeJson(String source) {
  final tokens = <JsonToken>[];
  final n = source.length;
  var i = 0;
  while (i < n) {
    final c = source.codeUnitAt(i);
    if (c == 0x22) {
      // "
      final start = i++;
      while (i < n) {
        final d = source.codeUnitAt(i);
        if (d == 0x5C) {
          i += 2;
          continue;
        }
        i++;
        if (d == 0x22 || d == 0x0A) break;
      }
      if (i > n) i = n;
      var j = i;
      while (j < n && _isSpace(source.codeUnitAt(j))) {
        j++;
      }
      final isKey = j < n && source.codeUnitAt(j) == 0x3A;
      tokens.add(
        JsonToken(isKey ? JsonTokenType.key : JsonTokenType.string, start, i),
      );
    } else if (c == 0x2D || (c >= 0x30 && c <= 0x39)) {
      final start = i++;
      while (i < n && _isNumberChar(source.codeUnitAt(i))) {
        i++;
      }
      tokens.add(JsonToken(JsonTokenType.number, start, i));
    } else if (_isWordChar(c)) {
      final start = i++;
      while (i < n && _isWordChar(source.codeUnitAt(i))) {
        i++;
      }
      final word = source.substring(start, i);
      final type = switch (word) {
        'true' || 'false' => JsonTokenType.boolean,
        'null' => JsonTokenType.nullValue,
        _ => JsonTokenType.other,
      };
      tokens.add(JsonToken(type, start, i));
    } else if (_isPunctuation(c)) {
      tokens.add(JsonToken(JsonTokenType.punctuation, i, i + 1));
      i++;
    } else {
      i++;
    }
  }
  return tokens;
}

/// Builds a highlighted [TextSpan] for [source].
TextSpan highlightJson(String source, JsonColors colors, TextStyle base) {
  final children = <TextSpan>[];
  var pos = 0;
  for (final t in tokenizeJson(source)) {
    if (t.start > pos) {
      children.add(TextSpan(text: source.substring(pos, t.start)));
    }
    final color = switch (t.type) {
      JsonTokenType.key => colors.key,
      JsonTokenType.string => colors.string,
      JsonTokenType.number => colors.number,
      JsonTokenType.boolean => colors.boolean,
      JsonTokenType.nullValue => colors.nullValue,
      JsonTokenType.punctuation => colors.punctuation,
      JsonTokenType.other => null,
    };
    children.add(
      TextSpan(
        text: source.substring(t.start, t.end),
        style: color == null ? null : TextStyle(color: color),
      ),
    );
    pos = t.end;
  }
  if (pos < source.length) children.add(TextSpan(text: source.substring(pos)));
  return TextSpan(style: base, children: children);
}

bool _isSpace(int c) => c == 0x20 || c == 0x09 || c == 0x0A || c == 0x0D;

bool _isNumberChar(int c) =>
    (c >= 0x30 && c <= 0x39) ||
    c == 0x2E ||
    c == 0x65 ||
    c == 0x45 ||
    c == 0x2B ||
    c == 0x2D;

bool _isWordChar(int c) =>
    (c >= 0x61 && c <= 0x7A) || (c >= 0x41 && c <= 0x5A) || c == 0x5F;

bool _isPunctuation(int c) =>
    c == 0x7B || c == 0x7D || c == 0x5B || c == 0x5D || c == 0x3A || c == 0x2C;
