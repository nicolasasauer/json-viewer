import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'json_highlighter.dart';

/// Text controller for the JSON editor: syntax highlighting plus VS Code
/// style folding of `{…}` / `[…]` blocks.
///
/// Folding never changes the text. The hidden characters are rendered as
/// zero-size placeholders (one per character), so offsets, selection,
/// copy and save keep working on the full document.
class JsonEditingController extends TextEditingController {
  JsonEditingController({super.text});

  /// Above this size highlighting and folding are skipped to keep typing
  /// responsive.
  static const highlightLimit = 200000;

  /// Offsets of the opening brackets of folded blocks.
  final Set<int> _folded = {};

  String? _pairsText;
  Map<int, int> _pairs = const {};

  /// Multi-line bracket pairs (opening offset → closing offset). Tolerant:
  /// works on invalid JSON too and ignores brackets inside strings.
  Map<int, int> get foldablePairs {
    if (!identical(_pairsText, text)) {
      _pairsText = text;
      _pairs = text.length > highlightLimit
          ? const {}
          : findFoldablePairs(text);
    }
    return _pairs;
  }

  bool isFolded(int start) => _folded.contains(start);

  bool get hasFolds => _folded.isNotEmpty;

  void toggleFold(int start) {
    if (!_folded.remove(start)) {
      if (!foldablePairs.containsKey(start)) return;
      _folded.add(start);
    }
    notifyListeners();
  }

  /// Folds every block below the root, so the top-level keys stay visible.
  void foldAll() {
    final pairs = foldablePairs;
    final root = pairs.keys.isEmpty
        ? null
        : pairs.keys.reduce((a, b) => a < b ? a : b);
    _folded
      ..clear()
      ..addAll(pairs.keys.where((s) => s != root));
    notifyListeners();
  }

  void unfoldAll() {
    if (_folded.isEmpty) return;
    _folded.clear();
    notifyListeners();
  }

  /// Start offsets of blocks hidden inside another folded block.
  bool isHiddenStart(int start) {
    final pairs = foldablePairs;
    for (final s in _folded) {
      final e = pairs[s];
      if (e != null && s < start && start < e) return true;
    }
    return false;
  }

  @override
  set value(TextEditingValue newValue) {
    if (_folded.isNotEmpty) {
      if (newValue.text != text) _shiftFolds(text, newValue.text);
      _unfoldAround(newValue.selection);
    }
    super.value = newValue;
  }

  /// Keeps folds attached to their blocks when text before them changes;
  /// a fold whose block is edited is opened.
  void _shiftFolds(String oldText, String newText) {
    var prefix = 0;
    final minLen = oldText.length < newText.length
        ? oldText.length
        : newText.length;
    while (prefix < minLen &&
        oldText.codeUnitAt(prefix) == newText.codeUnitAt(prefix)) {
      prefix++;
    }
    var suffix = 0;
    while (suffix < minLen - prefix &&
        oldText.codeUnitAt(oldText.length - 1 - suffix) ==
            newText.codeUnitAt(newText.length - 1 - suffix)) {
      suffix++;
    }
    final changeEnd = oldText.length - suffix; // in old text
    final delta = newText.length - oldText.length;
    final oldPairs = foldablePairs;
    final shifted = <int>{};
    for (final s in _folded) {
      final e = oldPairs[s];
      if (e == null) continue;
      if (changeEnd <= s) {
        shifted.add(s + delta);
      } else if (prefix > e) {
        shifted.add(s);
      }
      // Otherwise the edit touches the block: open it.
    }
    _folded
      ..clear()
      ..addAll(shifted);
    // Validate against the new text.
    final newPairs = newText.length > highlightLimit
        ? const <int, int>{}
        : findFoldablePairs(newText);
    _folded.removeWhere((s) => !newPairs.containsKey(s));
    _pairsText = newText;
    _pairs = newPairs;
  }

  /// Opens folds the caret moved into (e.g. tapping the … placeholder).
  void _unfoldAround(TextSelection selection) {
    if (!selection.isValid) return;
    final pairs = foldablePairs;
    _folded.removeWhere((s) {
      final e = pairs[s];
      if (e == null) return true;
      bool inside(int o) => o > s + 1 && o < e;
      return inside(selection.baseOffset) || inside(selection.extentOffset);
    });
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    if (text.length > highlightLimit) {
      return super.buildTextSpan(
        context: context,
        style: style,
        withComposing: withComposing,
      );
    }
    final composing = withComposing && value.isComposingRangeValid
        ? value.composing
        : TextRange.empty;
    return buildFoldedSpan(
      text: text,
      colors: JsonColors.of(context),
      base: style ?? const TextStyle(),
      folded: _folded,
      pairs: foldablePairs,
      composing: composing,
      placeholder: (start) => _FoldPlaceholder(
        onTap: () => toggleFold(start),
        fontSize: style?.fontSize ?? 14,
      ),
    );
  }
}

/// Finds multi-line `{…}` / `[…]` pairs; brackets inside strings are ignored.
Map<int, int> findFoldablePairs(String text) {
  final pairs = <int, int>{};
  final stack = <int>[];
  final n = text.length;
  var i = 0;
  while (i < n) {
    final c = text.codeUnitAt(i);
    if (c == 0x22) {
      i++;
      while (i < n) {
        final d = text.codeUnitAt(i);
        if (d == 0x5C) {
          i += 2;
          continue;
        }
        i++;
        if (d == 0x22 || d == 0x0A) break;
      }
      continue;
    }
    if (c == 0x7B || c == 0x5B) {
      stack.add(i);
    } else if ((c == 0x7D || c == 0x5D) && stack.isNotEmpty) {
      final open = stack.removeLast();
      final expected = text.codeUnitAt(open) == 0x7B ? 0x7D : 0x5D;
      if (c == expected && text.substring(open, i).contains('\n')) {
        pairs[open] = i;
      }
    }
    i++;
  }
  return pairs;
}

const _hiddenStyle = TextStyle(
  fontSize: 0.01,
  color: Color(0x00000000),
  letterSpacing: 0,
  wordSpacing: 0,
);

/// Builds the highlighted span. Characters strictly inside a folded pair are
/// hidden: the first becomes a "…" chip, newlines become zero-size
/// placeholders (so the block collapses onto one line), the rest tiny text.
TextSpan buildFoldedSpan({
  required String text,
  required JsonColors colors,
  required TextStyle base,
  required Set<int> folded,
  required Map<int, int> pairs,
  required TextRange composing,
  required Widget Function(int start) placeholder,
}) {
  final n = text.length;
  // Per character: token type (0 = plain) and flags.
  final types = Uint8List(n);
  for (final t in tokenizeJson(text)) {
    final type = t.type.index + 1;
    for (var i = t.start; i < t.end && i < n; i++) {
      types[i] = type;
    }
  }
  const hidden = 1, chip = 2, composingFlag = 4;
  final flags = Uint8List(n);
  final chipStart = <int, int>{}; // chip offset → fold start
  final starts = folded.toList()..sort();
  var hiddenUntil = -1;
  for (final s in starts) {
    final e = pairs[s];
    if (e == null || s < hiddenUntil || e - s < 2) continue;
    for (var i = s + 1; i < e; i++) {
      flags[i] |= hidden;
    }
    flags[s + 1] |= chip;
    chipStart[s + 1] = s;
    hiddenUntil = e;
  }
  if (composing.isValid && !composing.isCollapsed) {
    for (var i = composing.start; i < composing.end && i < n; i++) {
      flags[i] |= composingFlag;
    }
  }

  TextStyle? styleFor(int type, int flag) {
    if (flag & hidden != 0) return _hiddenStyle;
    final color = switch (type) {
      1 => colors.key,
      2 => colors.string,
      3 => colors.number,
      4 => colors.boolean,
      5 => colors.nullValue,
      6 => colors.punctuation,
      _ => null,
    };
    final underline = flag & composingFlag != 0;
    if (color == null && !underline) return null;
    return TextStyle(
      color: color,
      decoration: underline ? TextDecoration.underline : null,
    );
  }

  final children = <InlineSpan>[];
  var runStart = 0;
  void flush(int end) {
    if (end > runStart) {
      children.add(
        TextSpan(
          text: text.substring(runStart, end),
          style: styleFor(types[runStart], flags[runStart] & ~chip),
        ),
      );
    }
    runStart = end;
  }

  for (var i = 0; i < n; i++) {
    final f = flags[i];
    final special =
        f & chip != 0 || (f & hidden != 0 && text.codeUnitAt(i) == 0x0A);
    if (special) {
      flush(i);
      children.add(
        f & chip != 0
            ? WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: placeholder(chipStart[i]!),
              )
            : const WidgetSpan(child: SizedBox.shrink()),
      );
      runStart = i + 1;
      continue;
    }
    if (i > runStart &&
        (types[i] != types[runStart] ||
            (flags[i] & ~chip) != (flags[runStart] & ~chip))) {
      flush(i);
    }
  }
  flush(n);
  return TextSpan(style: base, children: children);
}

class _FoldPlaceholder extends StatelessWidget {
  const _FoldPlaceholder({required this.onTap, required this.fontSize});

  final VoidCallback onTap;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: scheme.secondaryContainer,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          '…',
          style: TextStyle(
            fontSize: fontSize,
            height: 1.2,
            color: scheme.onSecondaryContainer,
          ),
        ),
      ),
    );
  }
}
