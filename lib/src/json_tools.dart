import 'dart:convert';

/// A JSON syntax error with a human-friendly position.
class JsonParseError {
  const JsonParseError(this.message, {this.offset, this.line, this.column});

  final String message;

  /// Character offset into the source, if known.
  final int? offset;
  final int? line;
  final int? column;

  @override
  String toString() =>
      line == null ? message : 'Line $line, column $column: $message';
}

/// Result of parsing a JSON document.
class JsonParseResult {
  const JsonParseResult.valid(this.value) : error = null;
  const JsonParseResult.invalid(JsonParseError this.error) : value = null;

  final Object? value;
  final JsonParseError? error;

  bool get isValid => error == null;
}

JsonParseResult parseJson(String source) {
  if (source.trim().isEmpty) {
    return const JsonParseResult.invalid(JsonParseError('Document is empty'));
  }
  try {
    return JsonParseResult.valid(jsonDecode(source));
  } on FormatException catch (e) {
    final offset = e.offset;
    if (offset == null || offset < 0 || offset > source.length) {
      return JsonParseResult.invalid(JsonParseError(e.message));
    }
    var line = 1;
    var lineStart = 0;
    for (var i = 0; i < offset; i++) {
      if (source.codeUnitAt(i) == 0x0A) {
        line++;
        lineStart = i + 1;
      }
    }
    return JsonParseResult.invalid(
      JsonParseError(
        e.message,
        offset: offset,
        line: line,
        column: offset - lineStart + 1,
      ),
    );
  }
}

String prettyJson(Object? value) =>
    const JsonEncoder.withIndent('  ').convert(value);

String minifyJson(Object? value) => jsonEncode(value);

final _identifier = RegExp(r'^[A-Za-z_$][A-Za-z0-9_$]*$');

/// Root path used by [childPath].
const rootPath = r'$';

/// Builds a JSONPath-style path such as `$.users[0]["first name"]`.
String childPath(String parent, Object keyOrIndex) {
  if (keyOrIndex is int) return '$parent[$keyOrIndex]';
  final key = keyOrIndex as String;
  if (_identifier.hasMatch(key)) return '$parent.$key';
  return '$parent[${jsonEncode(key)}]';
}

/// Short description of a container, e.g. "3 keys" or "1 item".
String describeContainer(Object? value) {
  if (value is Map) {
    return '${value.length} ${value.length == 1 ? 'key' : 'keys'}';
  }
  if (value is List) {
    return '${value.length} ${value.length == 1 ? 'item' : 'items'}';
  }
  return '';
}

String typeName(Object? value) => switch (value) {
  null => 'null',
  Map() => 'object',
  List() => 'array',
  String() => 'string',
  bool() => 'boolean',
  num() => 'number',
  _ => value.runtimeType.toString(),
};

/// Text to put on the clipboard for a node: strings unquoted, everything else as JSON.
String copyText(Object? value) {
  if (value is String) return value;
  if (value is Map || value is List) return prettyJson(value);
  return jsonEncode(value);
}

String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}
